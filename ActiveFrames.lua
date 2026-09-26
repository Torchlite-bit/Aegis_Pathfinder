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
	marks them for what the quest wants with them: a star to talk, a square
	to interact with, a skull to kill, a cross to loot. RestedXP does this with a macro; a 1.12 addon may call TargetByName
	and SetRaidTarget itself, so this needs none.

	Quest icons put the same marks on by themselves as you mouse over or
	target anyone the current step or any quest in your log wants.

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
local STAR, SQUARE, CROSS, SKULL = 1, 6, 7, 8
AegisPathfinder.RAID_MARKS = { STAR = STAR, SQUARE = SQUARE, CROSS = CROSS, SKULL = SKULL }

--[[ Quest icons: which mark says what, as RestedXP has them.

	  star    talk      gives or takes the quest, or a trainer or vendor
	  square  interact  a friendly NPC the objectives involve
	  skull   kill      an enemy the quest wants dead
	  cross   loot      an enemy that drops what the quest wants collected
]]
local CONTEXT_MARK = { talk = STAR, interact = SQUARE, kill = SKULL, loot = CROSS }
local MARK_NAME = { [STAR] = "a star (talk)", [SQUARE] = "a square (interact)",
	[SKULL] = "a skull (kill)", [CROSS] = "a cross (loot)" }

-- The raid-marker sheet is a 4x4 grid in index order.
local MARK_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function MarkCoords(index)
	local col, row = math.mod(index - 1, 4), math.floor((index - 1) / 4)
	return col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25
end

BINDING_HEADER_AEGISPATHFINDER = "Aegis: Pathfinder"
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

-- A target list builder: `add(name, kind, context)` keeps the first of each
-- name, up to `max`, marked for its context.
local function TargetList(action, max)
	local out, seen = {}, {}
	local function add(name, kind, context)
		if not name or seen[name] or table.getn(out) >= max then return end
		seen[name] = true
		table.insert(out, { name = name, kind = kind, context = context,
			mark = CONTEXT_MARK[context], action = action })
	end
	return out, add
end

-- Who quest `qid` sends you to, by what the step does with it: its givers
-- to ACCEPT, its takers to TURNIN, and for COMPLETE its objective units
-- (friends to interact with, enemies to kill) then whoever drops its
-- objective items, likeliest first.
local function QuestTargets(qid, action, add)
	local quests = pfDB and pfDB.quests and pfDB.quests.data
	local quest = qid and quests and quests[qid]
	if not quest then return end

	local function units(list, context)
		for _, id in ipairs(list or {}) do
			local friend = PfFriendly(id)
			add(PfUnitName(id), friend and "npc" or "enemy",
				context or (friend and "interact" or "kill"))
		end
	end

	if action == "ACCEPT" then
		units(quest.start and quest.start.U, "talk")
	elseif action == "TURNIN" then
		units(quest["end"] and quest["end"].U, "talk")
	elseif action == "COMPLETE" then
		units(quest.obj and quest.obj.U)
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
			units(ids, "loot")
		end
	end
end

--- Whom step `i` (the current one by default) wants you to find:
--- { name, kind = "npc"|"enemy", context, mark, action }, at most
--- MAX_TARGETS. `context` is talk, interact, kill or loot; `mark` the raid
--- mark that says so.
function AegisPathfinder:GetActiveTargets(i)
	i = i or self.current
	if not self.actions or not i or not self.actions[i] then return {} end
	local action = self.actions[i]
	local out, add = TargetList(action, MAX_TARGETS)

	for _, name in ipairs(self:GetObjectiveTag("NPC", i) or {}) do add(name, "npc", "talk") end
	QuestTargets(tonumber((self:GetObjectiveTag("QID", i))), action, add)
	return out
end

--[[ Quest icons.

	The mark goes on by itself when you mouse over or target someone a quest
	wants: the current step's targets, and for every other quest in your log
	its objectives -- or, once it is complete, whoever takes it. Only on the
	unmarked, the living and the non-players, and not in a raid, where marks
	belong to its leaders.
]]
local MAX_ICON_TARGETS = 40

--- Everyone quest icons may mark, by name: the step's first, then the log's.
function AegisPathfinder:GetQuestIconTargets(stepTargets)
	local byName, count = {}, 0
	local function keep(t)
		if not byName[t.name] and count < MAX_ICON_TARGETS then
			byName[t.name] = t
			count = count + 1
		end
	end
	for _, t in ipairs(stepTargets or {}) do keep(t) end

	-- The quest log's ids come from ClassicAPI; without it, the step alone.
	local ids = C_QuestLog and C_QuestLog.GetQuestIDForLogIndex
	if not ids or not pfDB then return byName end
	for li = 1, GetNumQuestLogEntries() or 0 do
		local _, _, _, isHeader, _, isComplete = GetQuestLogTitle(li)
		local qid = not isHeader and ids(li)
		if qid then
			local action = isComplete == 1 and "TURNIN" or "COMPLETE"
			local list, add = TargetList(action, MAX_TARGETS)
			QuestTargets(qid, action, add)
			for _, t in ipairs(list) do keep(t) end
		end
	end
	return byName
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

-- Mark `unit` for `entry`'s context. What the client says outranks the
-- database: someone to kill or loot who cannot be attacked is someone to
-- interact with. The same mark is not set again -- setting it again is how
-- the stock UI takes one off.
local function Mark(entry, unit)
	unit = unit or "target"
	local mark = entry.mark or STAR
	if (entry.context == "kill" or entry.context == "loot") and not UnitCanAttack("player", unit) then
		mark = SQUARE
	end
	if SetRaidTarget and GetRaidTargetIndex(unit) ~= mark then
		SetRaidTarget(unit, mark)
	end
	return true
end

local iconTargets = {}

--- Quest icons: mark `unit` ("mouseover" or "target") if a quest wants it.
function AegisPathfinder:AutoMark(unit)
	local char = self.db and self.db.char
	if not char or char.questicons == false then return false end
	if not UnitExists(unit) or UnitIsPlayer(unit) or UnitIsDead(unit) then return false end
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then return false end
	-- Someone's mark already, ours or a party member's.
	if GetRaidTargetIndex(unit) then return false end
	local entry = iconTargets[UnitName(unit)]
	if not entry then return false end
	return Mark(entry, unit)
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
	return Mark(entry)
end

--- Mark the current target, if it is one of the step's. The last line of the
--- AegisTarget macro, after its /target lines have found someone.
function AegisPathfinder:MarkTarget()
	if not UnitExists("target") then return false end
	local name = UnitName("target")
	for _, t in ipairs(activeTargets) do
		if t.name == name then return Mark(t) end
	end
	return false
end

--- Target the first of the step's targets that is in range -- what the
--- AegisTarget macro does, and its button in the Macros window.
function AegisPathfinder:TargetAnyActive()
	if table.getn(activeTargets) == 0 then
		self:Print("Nobody to target on this step.")
		return false
	end
	for _, t in ipairs(activeTargets) do
		if self:TargetActive(t, true) then return true end
	end
	self:Print("None of this step's targets is close enough to target.")
	return false
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

--[[ The macros.

	RestedXP keeps a targeting macro up to date for you, so it can sit on an
	action bar. So does this: two character macros, AegisTarget and AegisItem,
	made on first use and rewritten whenever the step changes.

	AegisTarget is a /target line per target and a line to mark whoever that
	found. /target keeps the last name it finds, so the step's first target
	goes last. AegisItem uses the first active item -- 1.12 has no /use -- and
	takes that item's icon when the macro icon list has it, so the button on
	your bar shows what it will use.

	1.12 gives each character 18 macros. With none free, nothing is made and
	the window says so. A macro is never rewritten while the macro window is
	open: the stock UI would save its own copy of the text over ours.
]]

local MACRO_SLOTS = 18         -- per character, and per account, on 1.12
local MACRO_LETTERS = 255
local TARGET_MACRO, ITEM_MACRO = "AegisTarget", "AegisItem"
AegisPathfinder.MACROS = { TARGET = TARGET_MACRO, ITEM = ITEM_MACRO }
-- Icons by name: the macro icon list is read at run time, and the first of
-- these it has is the targeting macro's.
local TARGET_ICONS = { "ability_hunter_snipershot", "ability_townwatch", "inv_misc_spyglass_02" }
local QUESTION_MARK = 1        -- the first macro icon

--- The macro index of `name`, among the account's and this character's.
local function FindMacro(name)
	local account, character = GetNumMacros()
	for i = 1, account or 0 do
		if GetMacroInfo(i) == name then return i end
	end
	for i = MACRO_SLOTS + 1, MACRO_SLOTS + (character or 0) do
		if GetMacroInfo(i) == name then return i end
	end
end
AegisPathfinder.FindMacro = FindMacro

-- Macro icon indices by texture file name, lower case, built on first use.
local iconIndex
local function MacroIcon(file)
	if not file then return QUESTION_MARK end
	if not iconIndex then
		iconIndex = {}
		for i = 1, GetNumMacroIcons() or 0 do
			local _, _, base = string.find(string.lower(GetMacroIconInfo(i) or ""), "([^\\]+)$")
			if base and not iconIndex[base] then iconIndex[base] = i end
		end
	end
	local _, _, base = string.find(string.lower(file), "([^\\]+)$")
	return base and iconIndex[base] or nil
end

local function TargetIcon()
	for _, file in ipairs(TARGET_ICONS) do
		local i = MacroIcon(file)
		if i then return i end
	end
	return QUESTION_MARK
end

--- AegisTarget's text for `targets`.
function AegisPathfinder:TargetMacroBody(targets)
	if table.getn(targets or {}) == 0 then return "/apg target" end
	local mark = "/script AegisPathfinder:MarkTarget()"
	local lines = {}
	for i = table.getn(targets), 1, -1 do
		table.insert(lines, "/target " .. targets[i].name)
	end
	-- What does not fit goes, least wanted first: those are the top lines.
	while table.getn(lines) > 1 and string.len(table.concat(lines, "\n") .. "\n" .. mark) > MACRO_LETTERS do
		table.remove(lines, 1)
	end
	table.insert(lines, mark)
	return table.concat(lines, "\n")
end

-- The stock action bars repaint a button when its slot changes, not when the
-- macro in it does; a new icon would wait for the next page turn otherwise.
local BARS = { "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
	"MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton" }
local function RepaintBars(name)
	if not ActionButton_Update or not ActionButton_GetPagedID or not GetActionText then return end
	local saved = this
	for _, bar in ipairs(BARS) do
		for i = 1, 12 do
			local b = getglobal(bar .. i)
			if b then
				local ok, slot = pcall(ActionButton_GetPagedID, b)
				if ok and slot and GetActionText(slot) == name then
					this = b
					pcall(ActionButton_Update)
				end
			end
		end
	end
	this = saved
end

-- Rewrite one macro, or make it when `create`. Returns its index, and true
-- when it was made; nil when there is no such macro and none was made.
local function WriteMacro(name, icon, body, create)
	local index = FindMacro(name)
	if index then
		local _, texture, old = GetMacroInfo(index)
		if old ~= body or texture ~= GetMacroIconInfo(icon) then
			index = EditMacro(index, name, icon, body) or index
			RepaintBars(name)
		end
		return index
	end
	if not create then return nil end
	local _, character = GetNumMacros()
	if (character or 0) >= MACRO_SLOTS then return nil end
	return CreateMacro(name, icon, body, nil, 1), true
end

--- Bring AegisTarget and AegisItem up to date -- always, so one on an action
--- bar never aims at a step that is over -- and make them when `create`.
--- False while the macro window is open, so the caller tries again.
function AegisPathfinder:SyncMacros(create)
	if MacroFrame and MacroFrame:IsVisible() then return false end
	local item = activeItems[1]
	local t, newT = WriteMacro(TARGET_MACRO, TargetIcon(), self:TargetMacroBody(activeTargets), create)
	local i, newI = WriteMacro(ITEM_MACRO, item and MacroIcon(item.texture) or QUESTION_MARK, "/apg useitem", create)
	if newT or newI then
		local made = (newT and newI) and "macros AegisTarget and AegisItem"
			or newT and "macro AegisTarget" or "macro AegisItem"
		self:Print("Made the character " .. made .. ". Drag from the Macros window onto an action bar; they follow the guide from then on.")
	end
	-- Only a macro that should exist and does not is a full book.
	if create then self.macroFull = not (t and i) or nil end
	return true
end

--[[ The windows. ]]

local items, targets, macros
local Request   -- ask for a repaint; defined with the driver below

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

-- A macro's tile: click does what the macro does, dragging it picks the
-- macro up to drop on an action bar.
local function MacroTile(parent, name)
	local b = Tile(parent)
	b.macro = name
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function()
		local index = FindMacro(this.macro)
		if index then
			PickupMacro(index)
		else
			AegisPathfinder:Print("There was no free character macro slot for " .. this.macro .. ".")
		end
	end)
	b:SetScript("OnLeave", function()
		this.border:SetTint("subtle")
		Theme:HideTip(this)
		GameTooltip:Hide()
	end)
	return b
end

local DRAG_HINT = "Drag onto an action bar: it follows the guide from then on."

local function MacroTargetTile(parent)
	local b = MacroTile(parent, TARGET_MACRO)
	b:SetScript("OnClick", function() AegisPathfinder:TargetAnyActive() end)
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local lines = {}
		for _, t in ipairs(activeTargets) do table.insert(lines, "/target " .. t.name) end
		table.insert(lines, AegisPathfinder.macroFull and "No free character macro slot to make it in." or DRAG_HINT)
		Theme:ShowTip(this, "TOP", TARGET_MACRO .. " -- target and mark", lines)
	end)
	return b
end

local function MacroItemTile(parent)
	local b = MacroTile(parent, ITEM_MACRO)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetScript("OnClick", function() AegisPathfinder:UseActiveItem(1) end)
	-- GameTooltip, because only it can show a game item.
	b:SetScript("OnEnter", function()
		this.border:SetTint("accent")
		local entry = activeItems[1]
		if not entry then return end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetBagItem(entry.bag, entry.slot)
		GameTooltip:AddLine(ITEM_MACRO .. ": " .. (AegisPathfinder.macroFull
			and "no free character macro slot to make it in." or DRAG_HINT), 0.78, 0.78, 0.74, 1)
		GameTooltip:Show()
	end)
	return b
end

function AegisPathfinder:CreateActiveFrames()
	if items then return end
	items = Window("AegisPathfinderActiveItems", "Active Items", "activeitems")
	targets = Window("AegisPathfinderActiveTargets", "Active Targets", "activetargets")
	macros = Window("AegisPathfinderMacros", "Macros", "activemacros")
	macros.targetTile = MacroTargetTile(macros)
	macros.itemTile = MacroItemTile(macros)
	self.activeitemsframe, self.activetargetsframe, self.macrosframe = items, targets, macros
end

-- The Macros window: a tile for whichever of the two has something to do.
local function PaintMacros(self, char, under)
	macros.targetTile:Hide()
	macros.itemTile:Hide()
	if char.showmacros == false then
		macros:Hide()
		return
	end

	local shown = {}
	if table.getn(activeTargets) > 0 then table.insert(shown, macros.targetTile) end
	if activeItems[1] then table.insert(shown, macros.itemTile) end

	-- The macros themselves, made once there is something for them to do;
	-- again in a moment if the macro window is open.
	if not self:SyncMacros(table.getn(shown) > 0) then Request(1) end
	if table.getn(shown) == 0 then
		macros:Hide()
		return
	end

	for i, b in ipairs(shown) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", macros, "TOPLEFT", PAD + (i - 1) * (TILE + GAP), -(HEADER_H + PAD))
		b:Show()
	end
	local n = table.getn(shown)
	macros:SetWidth(math.max(PAD * 2 + n * TILE + (n - 1) * GAP, math.ceil(macros.label:GetStringWidth()) + 24))

	-- The targeting macro wears its own icon, as it will on a bar.
	local index, texture = FindMacro(TARGET_MACRO), nil
	if index then _, texture = GetMacroInfo(index) end
	local t = macros.targetTile
	if texture then
		t.icon:SetTexture(texture)
		t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		t.icon:SetVertexColor(1, 1, 1, 1)
	else
		t.icon:SetTexture(Theme.actionIcon.K)
		t.icon:SetTexCoord(0, 1, 0, 1)
		Theme:Tint(t.icon, "danger")
	end
	t.mark:SetTexCoord(MarkCoords(activeTargets[1] and activeTargets[1].mark or SKULL))
	t.mark:Show()

	local item = activeItems[1]
	if item then
		macros.itemTile.icon:SetTexture(item.texture)
		macros.itemTile.count:SetText(item.count > 1 and tostring(item.count) or "")
	end

	Place(macros, under)
	macros:Show()
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

	-- The step's targets feed the macro and the quest icons as well, so they
	-- are worked out whether or not their window is showing.
	activeTargets = self:GetActiveTargets()
	iconTargets = self:GetQuestIconTargets(activeTargets)
	n = char.showactivetargets ~= false and table.getn(activeTargets) or 0
	if n > 0 then
		Fit(targets, n, TargetTile)
		for i = 1, n do
			local b, entry = targets.tiles[i], activeTargets[i]
			local hostile = entry.context == "kill" or entry.context == "loot"
			local glyph = hostile and Theme.actionIcon.K
				or entry.context == "interact" and Theme.actionIcon.U
				or Theme.actionIconByName[entry.action] or Theme.actionIcon.N
			b.icon:SetTexture(glyph)
			Theme:Tint(b.icon, hostile and "danger" or "text")
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

	PaintMacros(self, char, targets:IsShown() and targets or items:IsShown() and items or guide)
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

Request = function(delay)
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
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:SetScript("OnEvent", function()
	if event == "PLAYER_TARGET_CHANGED" then
		AegisPathfinder:PaintTargetBorders()
		AegisPathfinder:AutoMark("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		AegisPathfinder:AutoMark("mouseover")
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
	Theme:RestorePosition(macros, "activemacros")
end

--- Forget where they were dragged; they hang under the guide again.
function AegisPathfinder:ResetActiveFrames()
	Theme:ForgetPosition("activeitems")
	Theme:ForgetPosition("activetargets")
	Theme:ForgetPosition("activemacros")
	-- The old single use-item button's spot.
	Theme:ForgetPosition("itemframe")
	if items then self:PaintActiveFrames() end
end

AegisPathfinder:CreateActiveFrames()
