--[[ GearFinder.lua -- upgrades waiting in the dungeons you run, as Zygor's Gear
	Finder has.

	GearData.lua lists what drops in each dungeon and raid (from CMaNGOS, with
	Turtle WoW's changes laid over it, and for Turtle's own from pfQuest-turtle): the item, who drops it and how
	often, and the item's slot, quality, required level and classes. Turtle's
	own items come with none of that; the client says what they are once it
	has loaded them -- slot, quality and level from GetItemInfo, and whether
	your class can use one from the red lines on its tooltip, as for any item. The finder takes the dungeons you can go to
	-- those starting no more than a few levels above you, on your side, not
	unticked among the options' dungeons; raids only when you ask -- and
	weighs each of their items for your spec against what you wear, with the
	item score. What beats it is listed by slot, best first, with where it
	drops.

	An item has to be in the client's cache to be read. Those that are not
	are asked for the safe way (ClassicAPI's C_Item.RequestLoadItemDataByID)
	a few at a time, and the list fills in as they arrive.

	Walking into a dungeon says, in chat, which of its drops are upgrades.

	Not only drops: quest rewards from quests you have still to do, gear a
	reputation vendor sells, and crafted gear (GearData's quests, repgear and
	crafted), each switched in the options. Those are looked at only near your
	level -- no more than AHEAD above it and BELOW under it -- since there are
	thousands, and each has to be loaded to be weighed. Crafted gear that binds
	on pickup counts only if you have the profession; so does all of it under
	Solo Self-Found, when nobody else may make it for you.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local GF = {}
AegisPathfinder.GearFinder = GF

-- Layout and timing, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local L = {
	WIDTH = 380, PAD = 12, ROW_H = 34, ROWS = 10, BUTTON_H = 22, SCROLL_W = 10,
	CHROME_TOP = 30 + 18, PER_SLOT = 3,
	AHEAD = 3,              -- dungeons and items up to this many levels above you
	LOAD_BATCH = 5, LOAD_EVERY = 0.1, REFRESH_EVERY = 0.5,
	NAMED = 4,              -- the note names this many places it looked, then counts
	BELOW = 10,             -- quest, reputation and crafted gear this far under your level
	RANKS = { [0] = "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" },
	LOAD_GIVE_UP = 10,      -- seconds after the last request: an item never sent is not waited for
}
L.NOTE_TOP = L.CHROME_TOP + 8
L.SWITCH_TOP = L.NOTE_TOP + 44
L.LIST_TOP = L.SWITCH_TOP + 22 + 8
L.LIST_H = L.ROWS * L.ROW_H
L.HEIGHT = L.LIST_TOP + L.LIST_H + L.PAD

-- The slots, in the order the character sheet has them.
local GROUPS = {
	{ "Head", { INVTYPE_HEAD = true } },
	{ "Neck", { INVTYPE_NECK = true } },
	{ "Shoulder", { INVTYPE_SHOULDER = true } },
	{ "Back", { INVTYPE_CLOAK = true } },
	{ "Chest", { INVTYPE_CHEST = true, INVTYPE_ROBE = true } },
	{ "Wrist", { INVTYPE_WRIST = true } },
	{ "Hands", { INVTYPE_HAND = true } },
	{ "Waist", { INVTYPE_WAIST = true } },
	{ "Legs", { INVTYPE_LEGS = true } },
	{ "Feet", { INVTYPE_FEET = true } },
	{ "Finger", { INVTYPE_FINGER = true } },
	{ "Trinket", { INVTYPE_TRINKET = true } },
	{ "Weapon", { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true } },
	{ "Off hand", { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true } },
	{ "Ranged", { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true } },
}

-- Each class's bit in an item's class mask.
local CLASS_BIT = {
	WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
	SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

local function settings()
	local db = AegisPathfinder.db.char
	db.gearfinder = db.gearfinder or {}
	local s = db.gearfinder
	if s.enabled == nil then s.enabled = true end
	if s.raids == nil then s.raids = false end
	if s.announce == nil then s.announce = true end
	for _, key in ipairs({ "quests", "reputation", "crafted" }) do
		if s[key] == nil then s[key] = true end
	end
	return s
end
GF.Settings = settings

--- Whether an item's class mask lets your class use it.
function GF.ForClass(mask, class)
	if not mask or mask == 0 then return true end
	local bit = CLASS_BIT[class]
	if not bit then return true end
	return math.mod(math.floor(mask / bit), 2) == 1
end

--- The dungeons the finder looks in, for your level and side.
function GF:Dungeons()
	local level = UnitLevel("player") or 1
	local faction = UnitFactionGroup("player")
	local chips = AegisPathfinder.db.char.Dungeons or {}
	local s = settings()
	local out = {}
	-- Solo Self-Found runs no dungeons.
	if AegisPathfinder.db.char.SelfFound then return out end
	for _, d in ipairs(AegisPathfinder.GearData.dungeons) do
		local ok = d.lo <= level + L.AHEAD
		if d.kind == "raid" and not s.raids then ok = false end
		if d.faction and faction and d.faction ~= faction then ok = false end
		-- A dungeon unticked among the options' dungeons is one you do not run.
		if chips[d.code] == false then ok = false end
		if ok then table.insert(out, d) end
	end
	return out
end

--[[ Loading items the client has not seen ]]

local loadQueue, requested = {}, {}

local function wantLoaded(id)
	if requested[id] then return end
	requested[id] = true
	table.insert(loadQueue, id)
end

function GF:Pending()
	return table.getn(loadQueue)
end

function GF:DrainLoads()
	local n = 0
	while n < L.LOAD_BATCH and table.getn(loadQueue) > 0 do
		local id = table.remove(loadQueue, 1)
		if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
		n = n + 1
	end
end

--[[ Finding upgrades ]]

--- What the data says about an item -- { slot, quality, required level,
--- class mask } -- or, for Turtle's own items, what the client does once it
--- has the item: nil until then, false if it is not gear worth weighing.
local function describe(items, id, it)
	local meta = items[id]
	if meta then return meta end
	local _, _, quality, minLevel, _, _, _, loc = GetItemInfo(it)
	if not quality then return nil end
	if quality < 2 or not loc or loc == "" or not AegisPathfinder.ItemScore.SLOTS[loc] then return false end
	return { loc, quality, minLevel or 0, 0 }
end

local results, missing = {}, 0

--- Your professions, by name, with your skill in each.
local function Professions()
	local out = {}
	for i = 1, (GetNumSkillLines and GetNumSkillLines() or 0) do
		local name, isHeader, _, rank = GetSkillLineInfo(i)
		if name and not isHeader then out[name] = rank end
	end
	return out
end

--- Gear from quests you have still to do, reputation vendors and crafting,
--- near your level, for your side and class: { item, where it comes from }.
function GF:Others(level, class)
	local data, s, db = AegisPathfinder.GearData, settings(), AegisPathfinder.db.char
	local faction = UnitFactionGroup("player")
	local out = {}
	local function near(id)
		local m = data.items[id]
		return m and m[3] <= level + L.AHEAD and m[3] >= level - L.BELOW
	end
	local function ours(side) return side == "" or not faction or side == faction end
	if s.quests then
		for q, d in pairs(data.quests or {}) do
			local done = (db.completedquestsbyid and db.completedquestsbyid[q])
				or (AegisPathfinder.IsQuestCompletedOnServer and AegisPathfinder:IsQuestCompletedOnServer(q))
			if not done and d[2] <= level + L.AHEAD and ours(d[3]) and GF.ForClass(d[4], class) then
				local where = "Quest: " .. d[1]
				if d[5] > 0 then where = where .. " (" .. L.RANKS[d[6]] .. ", " .. data.factions[d[5]][1] .. ")" end
				for _, id in ipairs(d[7]) do
					if near(id) then table.insert(out, { id, where }) end
				end
			end
		end
	end
	if s.reputation then
		for id, d in pairs(data.repgear or {}) do
			local f = data.factions[d[1]]
			if near(id) and ours(f[2]) then
				table.insert(out, { id, L.RANKS[d[2]] .. " with " .. f[1] .. " \194\183 " .. d[3] })
			end
		end
	end
	if s.crafted then
		local mine = Professions()
		for id, d in pairs(data.crafted or {}) do
			local skill = mine[d[1]]
			-- Bind on pickup, or Solo Self-Found: only if you make it yourself.
			if near(id) and (skill or not (d[3] or db.SelfFound)) then
				table.insert(out, { id, d[1] .. " " .. d[2] .. (skill and "" or " \194\183 made by a crafter") })
			end
		end
	end
	return out
end

--- Every upgrade in the dungeons you run: by slot, best first, at most a
--- few per slot. Items not loaded yet are asked for, and counted.
function GF:Find()
	local IS = AegisPathfinder.ItemScore
	local items = AegisPathfinder.GearData.items
	local level = UnitLevel("player") or 1
	local _, class = UnitClass("player")
	local weights = IS:Weights()
	local bySlot, seen = {}, {}
	missing = 0
	-- One item from anywhere: weighed, and kept if it is an upgrade. A drop
	-- has its dungeon, who drops it and the chance; anything else says where.
	local function consider(id, dungeon, code, source, chance, where)
		local it = "item:" .. id .. ":0:0:0"
		local meta = not seen[id] and describe(items, id, it)
		if meta == nil and not seen[id] then
			-- One of Turtle's own, not loaded yet: nothing to go on until it is.
			seen[id] = true
			wantLoaded(id)
			missing = missing + 1
		elseif meta and meta[3] <= level + L.AHEAD and GF.ForClass(meta[4], class) then
			seen[id] = true
			if not GetItemInfo(it) then
				wantLoaded(id)
				missing = missing + 1
			else
				local c = IS:Compare(it, weights)
				if c and c.usable and not c.noCompare and (c.delta or 0) > 0.0001 then
					bySlot[meta[1]] = bySlot[meta[1]] or {}
					table.insert(bySlot[meta[1]], {
						id = id, item = it, dungeon = dungeon, code = code, source = source,
						chance = chance, where = where, compare = c, level = meta[3],
					})
				end
			end
		end
	end
	for _, d in ipairs(self:Dungeons()) do
		for _, drop in ipairs(d.loot) do consider(drop[1], d.name, d.code, drop[2], drop[3]) end
	end
	for _, o in ipairs(self:Others(level, class)) do consider(o[1], nil, nil, nil, nil, o[2]) end
	results = {}
	for _, g in ipairs(GROUPS) do
		local list = {}
		for loc in pairs(g[2]) do
			for _, e in ipairs(bySlot[loc] or {}) do table.insert(list, e) end
		end
		table.sort(list, function(a, b)
			if a.compare.delta ~= b.compare.delta then return a.compare.delta > b.compare.delta end
			return a.id < b.id
		end)
		for i = L.PER_SLOT + 1, table.getn(list) do list[i] = nil end
		if table.getn(list) > 0 then table.insert(results, { slot = g[1], entries = list }) end
	end
	return results, missing
end

function GF:Results() return results, missing end

--- The upgrades that drop in one dungeon, best first.
function GF:UpgradesIn(name)
	local out = {}
	for _, g in ipairs(results) do
		for _, e in ipairs(g.entries) do
			if e.dungeon == name then table.insert(out, e) end
		end
	end
	table.sort(out, function(a, b) return a.compare.delta > b.compare.delta end)
	return out
end

--[[ The window ]]

function GF:CreateWindow()
	local frame = CreateFrame("Frame", "AegisPathfinderGearFinder", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(L.WIDTH)
	frame:SetHeight(L.HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	Theme:Panel(frame, "panel")
	frame:Hide()
	Theme:Chrome(frame, "Gear finder", Theme:PositionSaver("finderframe"))

	local note = Theme:FinePrint(frame, L.WIDTH - L.PAD * 2)
	note:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.NOTE_TOP)
	frame.note = note

	local raids = Theme:Switch(frame, "Include raids", function(on)
		settings().raids = on
		frame.offset = 0
		if on then
			AegisPathfinder:Print("Raids added to the Gear finder. The first time, their items have to "
				.. "load from the server: it can take a minute or two, and the list fills in as they arrive.")
		end
		GF:Refresh()
	end)
	raids:SetWidth(L.WIDTH - L.PAD * 2)
	raids:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.SWITCH_TOP)
	frame.raids = raids

	frame.rows = {}
	for i = 1, L.ROWS do
		local row = CreateFrame("Button", nil, frame)
		row:SetHeight(L.ROW_H)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -(L.LIST_TOP + (i - 1) * L.ROW_H))
		row:SetPoint("RIGHT", frame, "RIGHT", -L.PAD - L.SCROLL_W - 6, 0)
		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetTexture(Theme.texture.solid)
		hl:SetAllPoints(row)
		hl:SetVertexColor(1, 1, 1, 0.04)

		local slot = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(slot, "display", 10)
		slot:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
		slot:SetWidth(56)
		slot:SetJustifyH("LEFT")
		Theme:TextColor(slot, "textDim")
		local name = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(name, "body", 12)
		name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 4, 0)
		name:SetPoint("RIGHT", row, "RIGHT", -48, 0)
		name:SetJustifyH("LEFT")
		local gain = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(gain, "display", 11)
		gain:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -3)
		gain:SetJustifyH("RIGHT")
		Theme:TextColor(gain, "accent")
		local where = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(where, "body", 10)
		where:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
		where:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		where:SetJustifyH("LEFT")
		Theme:TextColor(where, "textDim")
		row.slot, row.name, row.gain, row.where = slot, name, gain, where

		-- GameTooltip, because only it can show a game item.
		row:SetScript("OnEnter", function()
			if this.entry and GetItemInfo(this.entry.item) then
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetHyperlink(this.entry.item)
				GameTooltip:Show()
			end
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.rows[i] = row
	end

	local bar = Theme:ScrollBar(frame, L.SCROLL_W)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD + 2, -(L.LIST_TOP + L.SCROLL_W))
	bar:SetHeight(L.LIST_H - L.SCROLL_W * 2)
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	bar:SetScript("OnValueChanged", function()
		frame.offset = math.floor((arg1 or 0) + 0.5)
		GF:Paint()
	end)
	bar.up:SetScript("OnClick", function() bar:SetValue(math.max(0, bar:GetValue() - 1)) end)
	bar.down:SetScript("OnClick", function()
		local _, hi = bar:GetMinMaxValues()
		bar:SetValue(math.min(hi, bar:GetValue() + 1))
	end)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function()
		local _, hi = bar:GetMinMaxValues()
		local v = bar:GetValue() - (arg1 or 0)
		if v < 0 then v = 0 elseif v > hi then v = hi end
		bar:SetValue(v)
	end)
	frame.bar = bar
	frame.offset = 0

	frame:SetScript("OnShow", function()
		this.offset = 0
		local guide = AegisPathfinder.objectiveframe
		if not Theme:RestorePosition(this, "finderframe") and guide and AegisPathfinder.GetQuadrant then
			local _, _, hhalf = AegisPathfinder.GetQuadrant(guide)
			this:ClearAllPoints()
			if hhalf == "LEFT" then
				this:SetPoint("TOPLEFT", guide, "TOPRIGHT", 8, 0)
			else
				this:SetPoint("TOPRIGHT", guide, "TOPLEFT", -8, 0)
			end
		end
		GF:Refresh()
	end)
	table.insert(UISpecialFrames, "AegisPathfinderGearFinder")
	self.frame = frame
end

--- The list as rows: a slot's first entry names the slot, the rest do not.
function GF:Lines()
	local lines = {}
	for _, g in ipairs(results) do
		for i, e in ipairs(g.entries) do
			table.insert(lines, { slot = i == 1 and g.slot or "", entry = e })
		end
	end
	return lines
end

function GF:Paint()
	local frame = self.frame
	if not frame then return end
	local IS = AegisPathfinder.ItemScore
	local lines = self:Lines()
	local over = math.max(0, table.getn(lines) - L.ROWS)
	frame.bar:SetMinMaxValues(0, over)
	if (frame.offset or 0) > over then frame.offset = over end
	for i, row in ipairs(frame.rows) do
		local line = lines[i + (frame.offset or 0)]
		if line then
			local e = line.entry
			local name, _, quality = GetItemInfo(e.item)
			local _, _, _, hex = GetItemQualityColor(quality or 2)
			row.entry = e
			row.slot:SetText(line.slot)
			row.name:SetText((hex or "") .. (name or ("item " .. e.id)) .. "|r")
			row.gain:SetText(AegisPathfinder.GearAdvisor.Gain(e.compare))
			local at = (e.level > (UnitLevel("player") or 1)) and (" \194\183 at level " .. e.level) or ""
			row.where:SetText(e.where and (e.where .. at)
				or string.format("%s, %s \194\183 %s%%%s", e.source, e.dungeon, e.chance, at))
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end
	local dungeons = self:Dungeons()
	-- Where it looked: named, if a few; counted, if many -- at 60 it is
	-- every dungeon there is, too many names for the note.
	local names, nd, nr = {}, 0, 0
	for _, d in ipairs(dungeons) do
		table.insert(names, d.name)
		if d.kind == "raid" then nr = nr + 1 else nd = nd + 1 end
	end
	local function count(n, one) return n .. " " .. one .. (n == 1 and "" or "s") end
	local s = settings()
	local places = {}
	if table.getn(names) > 0 then
		table.insert(places, table.getn(names) <= L.NAMED and table.concat(names, ", ")
			or (count(nd, "dungeon") .. (nr > 0 and (" and " .. count(nr, "raid")) or "")))
	end
	if s.quests then table.insert(places, "quests") end
	if s.reputation then table.insert(places, "reputation") end
	if s.crafted then table.insert(places, "crafting") end
	local n = table.getn(places)
	local where = n <= 1 and (places[1] or "")
		or (table.concat(places, ", ", 1, n - 1) .. " and " .. places[n])
	local text
	if not s.enabled then
		text = "The gear finder is switched off in the options."
	elseif n == 0 then
		text = "No dungeon at your level is ticked in the options."
	elseif table.getn(lines) == 0 and missing == 0 then
		text = "Nothing from " .. where .. " beats what you wear for " .. IS:SpecLabel((IS:Spec())) .. "."
	else
		text = "Upgrades for " .. IS:SpecLabel((IS:Spec())) .. " from " .. where .. "."
	end
	if s.enabled and table.getn(dungeons) == 0 and AegisPathfinder.db.char.SelfFound then
		text = "Solo Self-Found is on, so it looks in no dungeons. " .. (n > 0 and text or "")
	end
	if missing > 0 then
		text = text .. string.format(" Loading %d more items...", missing)
		-- Raids are hundreds more; say why it is taking a while.
		if s.raids then text = text .. " Raids take a minute or two, the first time." end
	end
	frame.note:SetText(text)
	frame.raids:SetOn(settings().raids)
end

function GF:Refresh()
	if settings().enabled then self:Find() else results, missing = {}, 0 end
	self:Paint()
end

function GF:Toggle()
	if not self.frame then self:CreateWindow() end
	if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

function AegisPathfinder:ToggleGearFinder()
	GF:Toggle()
end

--[[ Walking into a dungeon ]]

function GF:Announce(zone)
	if not settings().enabled or not settings().announce then return end
	local known
	for _, d in ipairs(AegisPathfinder.GearData.dungeons) do
		if d.name == zone then known = d end
	end
	if not known then return end
	-- Look in this dungeon even if it is not one the finder would pick.
	local raids, chips = settings().raids, AegisPathfinder.db.char.Dungeons or {}
	local chip = chips[known.code]
	settings().raids, chips[known.code] = true, nil
	self:Find()
	settings().raids, chips[known.code] = raids, chip
	local ups = self:UpgradesIn(zone)
	if table.getn(ups) == 0 then return end
	local parts = {}
	for i = 1, math.min(3, table.getn(ups)) do
		local e = ups[i]
		local name = GetItemInfo(e.item)
		table.insert(parts, (name or ("item " .. e.id)) .. " " .. AegisPathfinder.GearAdvisor.Gain(e.compare)
			.. " (" .. e.source .. ")")
	end
	AegisPathfinder:Print(string.format("Upgrades in %s: %s%s", zone, table.concat(parts, "; "),
		table.getn(ups) > 3 and string.format(", and %d more -- /apg finder", table.getn(ups) - 3) or "."))
end

--[[ Events ]]

local events = CreateFrame("Frame")
GF.events = events
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", function()
	if event == "ZONE_CHANGED_NEW_AREA" then
		GF:Announce(GetRealZoneText())
	elseif GF.frame and GF.frame:IsShown() and (event ~= "UNIT_INVENTORY_CHANGED" or arg1 == "player") then
		this.refreshAt = GetTime()
	end
end)
events:SetScript("OnUpdate", function()
	local now = GetTime()
	if table.getn(loadQueue) > 0 and now - (this.loadedAt or 0) >= L.LOAD_EVERY then
		this.loadedAt = now
		GF:DrainLoads()
		this.refreshAt = this.refreshAt or now
	end
	-- While items arrive, the open window refills now and then -- until a
	-- while after the last request, so an item the server never sends is not
	-- waited for for ever.
	if this.refreshAt and now - this.refreshAt >= L.REFRESH_EVERY then
		this.refreshAt = nil
		if GF.frame and GF.frame:IsShown() then
			GF:Refresh()
			if missing > 0 and now - (this.loadedAt or 0) < L.LOAD_GIVE_UP then this.refreshAt = now end
		end
	end
end)

function GF:Initialize()
	AegisPathfinder.ItemScore:OnChange(function()
		if GF.frame and GF.frame:IsShown() then GF.events.refreshAt = GetTime() end
	end)
end
