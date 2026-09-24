--[[
	ActiveFrames.lua -- the Active Items and Active Targets windows.

	Two small windows in the manner of RestedXP's, hanging under the guide.

	Active Items holds a button for every item the guide wants you to use: the
	current step's |U| item, and the |U| item of any other step whose quest is
	in your log and not yet done. It replaced a single floating button that
	only ever showed the current step's.

	Active Targets holds a button for whoever the current step wants you to
	find -- the quest's giver or hand-in, what its objectives want killed or
	drop, the trainer a profession step sends you to. A click targets them and
	marks them: a star on a friendly NPC, a skull (then a cross, for a second
	kind) on an enemy. RestedXP does this with a macro; a 1.12 addon may call
	TargetByName and SetRaidTarget itself, so this needs none.

	The names come from the step's |NPC| tag, and from pfQuest's database by
	the step's quest id: its starters, enders, objective units, and the units
	that drop its objective items. Without pfQuest, only |NPC| steps have
	targets.

	Both windows hide when they have nothing to show. Each drags by its title
	and remembers where it was left; until then Items hangs under the guide
	and Targets under Items. /apg target and /apg useitem, and two key
	bindings, do what the first buttons do -- /apg target cycles through the
	targets on each press, which is the macro RestedXP asks you to make.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local TILE = 32
local GAP = 4
local PAD = 6
local HEADER_H = 18
local INSET = 3
local MAX_ITEMS = 6
local MAX_TARGETS = 4
local THROTTLE = 0.25

-- SetRaidTarget's indices.
local STAR, CROSS, SKULL = 1, 7, 8
AegisPathfinder.RAID_MARKS = { STAR = STAR, CROSS = CROSS, SKULL = SKULL }
local MARK_NAME = { [STAR] = "a star", [CROSS] = "a cross", [SKULL] = "a skull" }

-- The raid-marker sheet is a 4x4 grid in index order.
local MARK_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function MarkCoords(index)
	local col, row = math.mod(index - 1, 4), math.floor((index - 1) / 4)
	return col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25
end

BINDING_HEADER_AEGISPATHFINDER = "AEGIS: Pathfinder"
BINDING_NAME_AEGISPATHFINDER_ACTIVEITEM = "Use the first active item"
BINDING_NAME_AEGISPATHFINDER_ACTIVETARGET = "Target and mark the next active target"

--[[ The data. ]]

-- Every item in the bags by id: where the first stack is, how many in all,
-- and its icon. By link rather than ClassicAPI, so it is the stock API.
local function BagScan()
	local held = {}
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link = GetContainerItemLink(bag, slot)
			local _, _, id = string.find(link or "", "item:(%d+)")
			id = tonumber(id)
			if id then
				local texture, count = GetContainerItemInfo(bag, slot)
				local entry = held[id]
				if entry then
					entry.count = entry.count + (count or 1)
				else
					held[id] = { bag = bag, slot = slot, count = count or 1, texture = texture }
				end
			end
		end
	end
	return held
end

-- Which steps carry a |U| item, remembered per step list.
local useTags, useSteps
local function UseSteps(self)
	if useTags ~= self.tags then
		useTags, useSteps = self.tags, {}
		for i, tags in pairs(self.tags or {}) do
			if type(tags) == "string" and string.find(tags, "|U|", 1, true) then
				table.insert(useSteps, i)
			end
		end
		table.sort(useSteps)
	end
	return useSteps
end

--- The items to offer: { id, step, bag, slot, count, texture }, the current
--- step's first. Only what is in the bags -- a button for an item you do
--- not have does nothing.
function AegisPathfinder:GetActiveItems()
	local out = {}
	if not self.actions or not self.current or not self.actions[self.current] then return out end

	local held, seen = BagScan(), {}
	local function add(id, step)
		id = tonumber(id)
		local h = id and held[id]
		if not h or seen[id] or table.getn(out) >= MAX_ITEMS then return end
		seen[id] = true
		table.insert(out, { id = id, step = step, bag = h.bag, slot = h.slot,
			count = h.count, texture = h.texture })
	end

	add(self:GetObjectiveTag("U", self.current), self.current)
	for _, i in ipairs(UseSteps(self)) do
		if i ~= self.current then
			local turnedin, logi, complete = self:GetObjectiveStatus(i)
			if not turnedin and logi and not complete then
				add(self:GetObjectiveTag("U", i), i)
			end
		end
	end
	return out
end

local function PfUnitName(id)
	local loc = pfDB and pfDB.units and pfDB.units.loc
	return loc and loc[id]
end

-- pfQuest marks the NPCs friendly to a faction with its letter.
local function PfFriendly(id)
	local data = pfDB and pfDB.units and pfDB.units.data and pfDB.units.data[id]
	local fac = data and data.fac
	if not fac then return false end
	local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
	return string.find(fac, mine, 1, true) ~= nil
end

--- Whom step `i` (the current one by default) wants you to find:
--- { name, kind = "npc"|"enemy", mark, action }, at most MAX_TARGETS.
function AegisPathfinder:GetActiveTargets(i)
	i = i or self.current
	local out = {}
	if not self.actions or not i or not self.actions[i] then return out end
	local action = self.actions[i]

	local seen, enemies = {}, 0
	local function add(name, kind)
		if not name or seen[name] or table.getn(out) >= MAX_TARGETS then return end
		seen[name] = true
		local mark = STAR
		if kind == "enemy" then
			enemies = enemies + 1
			mark = enemies == 1 and SKULL or CROSS
		end
		table.insert(out, { name = name, kind = kind, mark = mark, action = action })
	end
	local function units(list)
		for _, id in ipairs(list or {}) do
			add(PfUnitName(id), PfFriendly(id) and "npc" or "enemy")
		end
	end

	for _, name in ipairs(self:GetObjectiveTag("NPC", i) or {}) do add(name, "npc") end

	local qid = tonumber((self:GetObjectiveTag("QID", i)))
	local quests = pfDB and pfDB.quests and pfDB.quests.data
	local quest = qid and quests and quests[qid]
	if not quest then return out end

	if action == "ACCEPT" then
		units(quest.start and quest.start.U)
	elseif action == "TURNIN" then
		units(quest["end"] and quest["end"].U)
	elseif action == "COMPLETE" then
		units(quest.obj and quest.obj.U)
		-- Whoever drops what it wants collected, likeliest first.
		local items = pfDB.items and pfDB.items.data
		for _, itemId in ipairs(quest.obj and quest.obj.I or {}) do
			local drops = items and items[itemId] and items[itemId].U
			local sorted = {}
			for unit, chance in pairs(drops or {}) do
				table.insert(sorted, { id = unit, chance = tonumber(chance) or 0 })
			end
			table.sort(sorted, function(a, b)
				if a.chance ~= b.chance then return a.chance > b.chance end
				return a.id < b.id
			end)
			local ids = {}
			for _, d in ipairs(sorted) do table.insert(ids, d.id) end
			units(ids)
		end
	end
	return out
end

--[[ The actions. ]]

local activeItems, activeTargets = {}, {}

--- Use the `n`th active item (the first by default).
function AegisPathfinder:UseActiveItem(n)
	local entry = activeItems[n or 1]
	if not entry then
		self:Print("No item to use on this step.")
		return false
	end
	-- Where it is now: the bags can change under a list built a moment ago.
	local h = BagScan()[entry.id]
	if not h then
		self:Print("That item is no longer in your bags.")
		return false
	end
	UseContainerItem(h.bag, h.slot)
	-- Using a USE step's own item is the step.
	if entry.step == self.current and self:GetObjectiveInfo() == "USE" then self:SetTurnedIn() end
	return true
end

--- Target `entry` by name and mark it. False, and a word in chat unless
--- `quiet`, when nobody by that name is close enough.
function AegisPathfinder:TargetActive(entry, quiet)
	if not entry then return false end
	TargetByName(entry.name, true)
	if not UnitExists("target") or UnitName("target") ~= entry.name then
		if not quiet then self:Print(entry.name .. " isn't close enough to target.") end
		return false
	end
	-- What the client says about the unit outranks what the database did.
	local mark = STAR
	if UnitCanAttack("player", "target") then
		mark = entry.kind == "enemy" and entry.mark or SKULL
	end
	if SetRaidTarget and GetRaidTargetIndex("target") ~= mark then
		SetRaidTarget("target", mark)
	end
	return true
end

--- Target the next of the step's targets after whichever is targeted now,
--- so pressing it again moves on. What /apg target and the key binding do.
function AegisPathfinder:TargetNextActive()
	local n = table.getn(activeTargets)
	if n == 0 then
		self:Print("Nobody to target on this step.")
		return false
	end
	local current = UnitExists("target") and UnitName("target")
	local start = 1
	for i, t in ipairs(activeTargets) do
		if t.name == current then start = i + 1 end
	end
	for k = 0, n - 1 do
		if self:TargetActive(activeTargets[math.mod(start - 1 + k, n) + 1], true) then return true end
	end
	self:Print("None of this step's targets is close enough to target.")
	return false
end

--[[ The windows. ]]

local items, targets

-- A tile: the theme's rounded square, an icon inside it, a count and a mark
-- in its corners.
local function Tile(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(TILE); b:SetHeight(TILE)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.fill = Theme:NineSlice(b, Theme.texture.tabFill, "BACKGROUND", "panel2")
	b.border = Theme:NineSlice(b, Theme.texture.tabBorder, "BORDER", "subtle")

	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", INSET, -INSET)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -INSET, INSET)

	b.count = b:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(b.count, "display", 10, "OUTLINE")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	Theme:TextColor(b.count, "text")

	b.mark = b:CreateTexture(nil, "OVERLAY")
	b.mark:SetTexture(MARK_SHEET)
	b.mark:SetWidth(12); b.mark:SetHeight(12)
	b.mark:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 3)
	b.mark:Hide()

	-- Pressed: the icon sinks a pixel, as a button face would.
	b:SetScript("OnMouseDown", function()
		this.icon:SetPoint("TOPLEFT", this, "TOPLEFT", INSET + 1, -INSET - 1)
		this.icon:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT", -INSET + 1, INSET - 1)
	end)
	b:SetScript("OnMouseUp", function()
		this.icon:SetPoint("TOPLEFT", this, "TOPLEFT", INSET, -INSET)
		this.icon:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT", -INSET, INSET)
	end)
	return b
end

local function Window(name, title, key)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetWidth(TILE + PAD * 2)
	f:SetHeight(HEADER_H + PAD * 2 + TILE)
	Theme:Panel(f, "panel")

	local header = Theme:Header(f, HEADER_H)
	header.wordmark:Hide()
	local label = header:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(label, "display", 11)
	label:SetPoint("CENTER", header, "CENTER", 0, 0)
	label:SetText(string.upper(title))
	Theme:TextColor(label, "text")

	header:MakeDragHandle(f, Theme:PositionSaver(key))
	-- A window mid-drag is not re-anchored under the cursor.
	local start, stop = header:GetScript("OnDragStart"), header:GetScript("OnDragStop")
	header:SetScript("OnDragStart", function() f.moving = true; start() end)
	header:SetScript("OnDragStop", function() stop(); f.moving = nil end)

	f.header, f.label, f.key, f.tiles = header, label, key, {}
	f:Hide()
	return f
end

-- Size `f` to `n` tiles, and hand back its first `n`, built as needed.
local function Fit(f, n, build)
	for i = table.getn(f.tiles) + 1, n do
		local b = build(f)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i - 1) * (TILE + GAP), -(HEADER_H + PAD))
		b.index = i
		f.tiles[i] = b
	end
	for i, b in ipairs(f.tiles) do
		if i <= n then b:Show() else b:Hide() end
	end
	local tiles = PAD * 2 + n * TILE + math.max(n - 1, 0) * GAP
	f:SetWidth(math.max(tiles, math.ceil(f.label:GetStringWidth()) + 24))
end

-- Until dragged, Items hangs under the guide and Targets under Items -- or
-- under the guide, while Items has nothing to show.
local function Place(f, under)
	if f.moving or Theme:RestorePosition(f, f.key) then return end
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", under, "BOTTOMRIGHT", 0, -6)
end

local function ItemTile(parent)
	local b = Tile(parent)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetScript("OnClick", function() AegisPathfinder:UseActiveItem(this.index) end)
	-- GameTooltip, because only it can show a game item.
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local entry = activeItems[this.index]
		if not entry then return end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetBagItem(entry.bag, entry.slot)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		this.border:SetTint("subtle")
		GameTooltip:Hide()
	end)
	return b
end

local function TargetTile(parent)
	local b = Tile(parent)
	b:SetScript("OnClick", function() AegisPathfinder:TargetActive(activeTargets[this.index]) end)
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local entry = activeTargets[this.index]
		if not entry then return end
		Theme:ShowTip(this, "TOP", entry.name, {
			string.format("Click to target and mark with %s.", MARK_NAME[entry.mark] or "a mark"),
		})
	end)
	b:SetScript("OnLeave", function()
		AegisPathfinder:PaintTargetBorders()
		Theme:HideTip(this)
	end)
	return b
end

function AegisPathfinder:CreateActiveFrames()
	if items then return end
	items = Window("AegisPathfinderActiveItems", "Active Items", "activeitems")
	targets = Window("AegisPathfinderActiveTargets", "Active Targets", "activetargets")
	self.activeitemsframe, self.activetargetsframe = items, targets
end

--- Recount and repaint both windows.
function AegisPathfinder:PaintActiveFrames()
	if not items then self:CreateActiveFrames() end
	local char = self.db and self.db.char or {}
	local guide = self.objectiveframe or UIParent

	activeItems = char.showactiveitems ~= false and self:GetActiveItems() or {}
	local n = table.getn(activeItems)
	if n > 0 then
		Fit(items, n, ItemTile)
		for i = 1, n do
			local b, entry = items.tiles[i], activeItems[i]
			b.icon:SetTexture(entry.texture)
			b.count:SetText(entry.count > 1 and tostring(entry.count) or "")
		end
		Place(items, guide)
		items:Show()
	else
		items:Hide()
	end

	activeTargets = char.showactivetargets ~= false and self:GetActiveTargets() or {}
	n = table.getn(activeTargets)
	if n > 0 then
		Fit(targets, n, TargetTile)
		for i = 1, n do
			local b, entry = targets.tiles[i], activeTargets[i]
			local glyph = entry.kind == "enemy" and Theme.actionIcon.K
				or Theme.actionIconByName[entry.action] or Theme.actionIcon.N
			b.icon:SetTexture(glyph)
			Theme:Tint(b.icon, entry.kind == "enemy" and "danger" or "text")
			b.mark:SetTexCoord(MarkCoords(entry.mark))
			b.mark:Show()
			b.count:SetText("")
		end
		Place(targets, items:IsShown() and items or guide)
		targets:Show()
	else
		targets:Hide()
	end
	self:PaintTargetBorders()
end

--- Light the tile of whoever is targeted now.
function AegisPathfinder:PaintTargetBorders()
	if not targets then return end
	local current = UnitExists("target") and UnitName("target")
	for i, b in ipairs(targets.tiles) do
		local entry = activeTargets[i]
		b.border:SetTint(entry and entry.name == current and "accent" or "subtle")
	end
end

--[[ Keeping up.

	The step settling asks for a repaint on the next frame. Bag updates come
	in bursts, so they ask for one THROTTLE later, and a burst is one repaint.
	A new target only relights the tiles, which is cheap enough to do at once.
]]
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
	if GetTime() < (this.due or 0) then return end
	this:Hide()
	AegisPathfinder:PaintActiveFrames()
end)
AegisPathfinder.activeDriver = driver

local function Request(delay)
	local due = GetTime() + (delay or 0)
	if not driver:IsShown() or due < (driver.due or 0) then driver.due = due end
	driver:Show()
end

function AegisPathfinder:RefreshActiveFrames()
	Request(0)
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function()
	if event == "PLAYER_TARGET_CHANGED" then
		AegisPathfinder:PaintTargetBorders()
	else
		Request(THROTTLE)
	end
end)
AegisPathfinder.activeEvents = events

--- Put each window back where the player left it, at login.
function AegisPathfinder:PositionActiveFrames()
	if not items then self:CreateActiveFrames() end
	Theme:RestorePosition(items, "activeitems")
	Theme:RestorePosition(targets, "activetargets")
end

--- Forget where they were dragged; they hang under the guide again.
function AegisPathfinder:ResetActiveFrames()
	Theme:ForgetPosition("activeitems")
	Theme:ForgetPosition("activetargets")
	-- The old single use-item button's spot.
	Theme:ForgetPosition("itemframe")
	if items then self:PaintActiveFrames() end
end

AegisPathfinder:CreateActiveFrames()
