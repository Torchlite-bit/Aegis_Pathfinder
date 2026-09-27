--[[ ItemScore.lua -- what an item is worth to you, and whether it beats what
	you are wearing.

	A 1.12 client cannot ask an item for its stats: they are only ever written
	on its tooltip. So an item is read the way a player reads it -- a hidden
	tooltip is filled with it, and each line is matched against the stat
	patterns in ItemScoreData.lua (OctoPawn's, MIT). The stats found are
	weighted for your class and spec, past a soft cap each further point
	counting for less, and summed: the item's score.

	Your spec is the talent tree you have put most points into, until you pick
	one; below level 10, with no talents, it is your class's usual levelling
	spec. Weights you change are kept per spec, on top of the defaults.

	Comparing is by slot. A ring or trinket is weighed against the weaker of
	the two you wear -- the one it would replace -- and a one-hander against
	your off hand too if you can dual wield. A two-hander is weighed against
	your main and off hand together. Enchants are left out on both sides, so
	an enchanted old item does not hide a better new one.

	Whether you can use an item is read off the same tooltip: the client
	colours red what you cannot use -- the armour or weapon type, a class or
	race you are not, a skill you lack. A red "Requires Level" alone means you
	can, later.
]]

local AegisPathfinder = AegisPathfinder
local Data = AegisPathfinder.ItemScoreData

local IS = {}
AegisPathfinder.ItemScore = IS

-- Talent trees as the 1.12 client names them, to the spec keys in the data.
local TREE_SPEC = {
	["Beast Mastery"] = "BeastMastery",
	["Feral Combat"] = "FeralCat",
}

-- Before talents: each class's usual levelling spec.
local LEVELLING_SPEC = {
	WARRIOR = "Arms", PALADIN = "Retribution", HUNTER = "BeastMastery", ROGUE = "Combat",
	PRIEST = "Shadow", SHAMAN = "Enhancement", MAGE = "Frost", WARLOCK = "Affliction",
	DRUID = "FeralCat",
}

local SPEC_LABEL = {
	BeastMastery = "Beast Mastery",
	FeralCat = "Feral (cat)",
	FeralBear = "Feral (bear)",
	EnhancementTank = "Enhancement (tank)",
}

-- Where each kind of item goes. Two slots: it takes whichever it beats more.
local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
	INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
	INVTYPE_RELIC = { 18 },
}
IS.SLOTS = SLOTS

local MAINHAND, OFFHAND = 16, 17

--[[ Settings ]]

local function settings()
	local db = AegisPathfinder.db.char
	db.itemscore = db.itemscore or {}
	local s = db.itemscore
	if s.tooltips == nil then s.tooltips = true end
	s.custom = s.custom or {}
	return s
end
IS.Settings = settings

function IS:Class()
	local _, token = UnitClass("player")
	return token
end

--- Every spec the data has for a class, in a steady order.
function IS:Specs(class)
	local out = {}
	for spec in pairs(Data.weights[class or self:Class()] or {}) do table.insert(out, spec) end
	table.sort(out)
	return out
end

function IS:SpecLabel(spec)
	return SPEC_LABEL[spec] or spec
end

--- The tree with most points in it; nil with none spent.
function IS:DetectSpec(class)
	class = class or self:Class()
	local best, bestPoints = nil, 0
	for tab = 1, 3 do
		local name, _, points = GetTalentTabInfo(tab)
		if name and (points or 0) > bestPoints then
			best, bestPoints = TREE_SPEC[name] or string.gsub(name, " ", ""), points
		end
	end
	if best and Data.weights[class] and Data.weights[class][best] then return best end
	return nil
end

--- The spec scored for: the one picked, else the talents', else levelling's.
function IS:Spec()
	local class = self:Class()
	local picked = settings().spec
	if picked and Data.weights[class] and Data.weights[class][picked] then return picked, "picked" end
	local detected = self:DetectSpec(class)
	if detected then return detected, "talents" end
	return LEVELLING_SPEC[class], "levelling"
end

function IS:SetSpec(spec)
	settings().spec = spec
	self:Changed()
end

local function customKey(class, spec) return class .. ":" .. spec end

--- The weights for a class and spec: the defaults, with your changes on top.
function IS:Weights(class, spec)
	class = class or self:Class()
	if not spec then spec = self:Spec() end
	local out = {}
	for stat, w in pairs((Data.weights[class] or {})[spec] or {}) do out[stat] = w end
	for stat, w in pairs(settings().custom[customKey(class, spec)] or {}) do out[stat] = w end
	return out
end

function IS:IsCustom(class, spec)
	return next(settings().custom[customKey(class or self:Class(), spec or self:Spec())] or {}) ~= nil
end

--- Change one weight of the spec scored for. Setting it back to the
--- default removes the change.
function IS:SetWeight(stat, value)
	local class, spec = self:Class(), self:Spec()
	local key = customKey(class, spec)
	local custom = settings().custom
	custom[key] = custom[key] or {}
	local default = ((Data.weights[class] or {})[spec] or {})[stat] or 0
	if math.abs((value or 0) - default) < 0.00005 then
		custom[key][stat] = nil
	else
		custom[key][stat] = value
	end
	if not next(custom[key]) then custom[key] = nil end
	self:Changed()
end

function IS:ResetWeights()
	settings().custom[customKey(self:Class(), self:Spec())] = nil
	self:Changed()
end

local function trimNum(v)
	local s = string.format("%.4f", v)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return s
end

--[[ Sharing weights, in OctoPawn's own string -- OPW1:CLASS:SPEC:*STAT:v|STAT:v,
	only the stats that differ from the defaults -- so a scale moves between
	the two addons unchanged. ]]
function IS:Export()
	local class, spec = self:Class(), self:Spec()
	local parts = {}
	for stat, v in pairs(settings().custom[customKey(class, spec)] or {}) do
		table.insert(parts, stat .. ":" .. trimNum(v))
	end
	table.sort(parts)
	return "OPW1:" .. class .. ":" .. spec .. ":*" .. table.concat(parts, "|")
end

--- Returns true, or false and why not. Weights for another spec of your
--- class switch you to it; another class's are refused.
function IS:Import(text)
	text = string.gsub(text or "", "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local _, _, class, spec, rest = string.find(text, "^OPW1:([%w_]+):([%w_]+):%*(.*)$")
	if not class then return false, "Not a weights string (OPW1:CLASS:SPEC:*...)." end
	if class ~= self:Class() then return false, "Those weights are for a " .. class .. "." end
	if not (Data.weights[class] and Data.weights[class][spec]) then
		return false, "There is no " .. spec .. " spec for your class."
	end
	local custom = {}
	for chunk in string.gfind(rest, "[^|]+") do
		local _, _, stat, v = string.find(chunk, "^([^:]+):(%-?[%d%.]+)$")
		if not stat or not tonumber(v) then return false, "Could not read \"" .. chunk .. "\"." end
		custom[stat] = tonumber(v)
	end
	local s = settings()
	s.spec = spec
	s.custom[customKey(class, spec)] = next(custom) and custom or nil
	self:Changed()
	return true
end

--[[ Reading an item ]]

local cache = {}

--- A link's item string with its enchant and unique id cleared: the item
--- as it drops, random suffix and all.
function IS:BaseItem(link)
	if not link then return nil end
	local _, _, id, _, suffix = string.find(link, "item:(%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	if not id then
		_, _, id = string.find(link, "item:(%d+)")
		suffix = "0"
	end
	if not id then return nil end
	return "item:" .. id .. ":0:" .. suffix .. ":0"
end

local scanTip
--- The tooltip's lines for an item string: { left, right, leftRed, rightRed }.
--- Tests replace this; everything else goes through it.
function IS:ReadLines(item)
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "AegisPathfinderScanTip", nil, "GameTooltipTemplate")
	end
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTip:ClearLines()
	scanTip:SetHyperlink(item)
	local lines = {}
	for i = 1, scanTip:NumLines() do
		local l = getglobal("AegisPathfinderScanTipTextLeft" .. i)
		local r = getglobal("AegisPathfinderScanTipTextRight" .. i)
		local function red(fs)
			if not fs or not fs:IsShown() then return false end
			local cr, cg, cb = fs:GetTextColor()
			return cr and cr > 0.9 and cg < 0.2 and cb < 0.2
		end
		table.insert(lines, {
			left = l and l:GetText(), right = r and r:IsShown() and r:GetText(),
			leftRed = red(l), rightRed = red(r),
		})
	end
	scanTip:Hide()
	return lines
end

local function numberNear(line, upper, pattern)
	local s = string.find(upper, pattern)
	if not s then return nil end
	local _, _, after = string.find(string.sub(line, s), "([%+%-]?%d+%.?%d*)")
	if after then return tonumber(after) end
	local last
	for n in string.gfind(string.sub(line, 1, s - 1), "([%+%-]?%d+%.?%d*)") do last = n end
	return last and tonumber(last)
end

local function isSetBonus(upper)
	return string.find(upper, "%)%s*SET%s*:") or string.find(upper, "^SET%s*:") or string.find(upper, "SET BONUS")
end

local SPELL_SCHOOL = { "NATURE DAMAGE", "FIRE DAMAGE", "FROST DAMAGE", "SHADOW DAMAGE", "ARCANE DAMAGE", "HOLY DAMAGE" }

--- The stats on one line of a tooltip, added into `totals`. The rules are
--- OctoPawn's: the first pattern for a stat wins, a set bonus counts for
--- nothing, and a school's spell damage is not also general spell damage.
--- One is stricter: a "chance on hit" line's numbers are the proc's -- 90
--- Fire damage on a sword is not 90 spell damage for you -- so only an
--- extra-attack chance counts from one.
local function readStats(line, totals, state)
	local upper = string.upper(line)
	if isSetBonus(upper) then return end
	if string.find(upper, "DAMAGE PER SECOND") or string.find(upper, "DPS") then state.pastDPS = true end
	-- Above the DPS line, "damage" is the weapon's hit range, not a stat.
	if not (state.pastDPS or not string.find(upper, "DAMAGE") or string.find(upper, "PER SECOND")
		or string.find(upper, "SPELLS")) then
		return
	end
	for _, word in ipairs({ "REQUIRES", "SOULBOUND", "UNIQUE", "LEVEL", "BIND", "MADE BY", "DURABILITY" }) do
		if string.find(upper, word) then return end
	end
	local procLine = string.find(upper, "CHANCE ON HIT") ~= nil
	local matched = {}
	for _, p in ipairs(Data.patterns) do
		local pattern, stat = p[1], p[2]
		if not matched[stat] and string.find(upper, pattern) then
			local skip = false
			if procLine and stat ~= "EXTRA ATTACK" then
				skip = true
			elseif stat == "HIT" and string.find(upper, "SPELL") then
				skip = true
			elseif stat == "SPELL DAMAGE" or stat == "SPELL POWER" then
				for _, school in ipairs(SPELL_SCHOOL) do
					if matched[school] then skip = true end
				end
			elseif stat == "ATTACK POWER" then
				skip = matched["FERAL ATTACK POWER"] or matched["RANGED ATTACK POWER"] or matched["ATTACK POWER UNDEAD"]
					or string.find(upper, "FERAL") or string.find(upper, "IN CAT") or string.find(upper, "IN BEAR")
					or string.find(upper, "MOONKIN") or string.find(upper, "UNDEAD")
			end
			if not skip then
				local n = numberNear(line, upper, pattern)
				if stat == "EXTRA ATTACK" or (not n and stat == "LIFESTEAL") then
					local _, _, pct = string.find(line, "([%+%-]?%d+%.?%d*)%s*%%")
					if pct then n = tonumber(pct) end
				end
				if n then
					matched[stat] = true
					totals[stat] = (totals[stat] or 0) + n
				end
			end
		end
	end
end

--- What an item is: its stats, where it goes, and whether you can use it
--- (now, later, or never). Cached by item string.
function IS:Read(link)
	local item = self:BaseItem(link)
	if not item then return nil end
	if cache[item] then return cache[item] end
	-- An item the client has not seen is never put in a tooltip: on 1.12 that
	-- asks the server for it, and some servers disconnect you for asking.
	local name, _, _, _, _, _, _, equipLoc = GetItemInfo(item)
	if not name then return nil end
	local info = { item = item, equipLoc = equipLoc, stats = {}, usable = true }
	local state = {}
	for i, l in ipairs(self:ReadLines(item)) do
		if l.left then
			local _, _, level = string.find(l.left, "^Requires Level (%d+)")
			if level then
				info.level = tonumber(level)
				if l.leftRed then info.later = true end
			elseif l.leftRed and not string.find(l.left, "^Durability") and i > 1 then
				info.usable = false
			end
			if i > 1 then readStats(l.left, info.stats, state) end
		end
		if l.rightRed and l.right then info.usable = false end
	end
	cache[item] = info
	return info
end

--- The score of a set of stats with a set of weights, soft caps applied.
function IS:ScoreStats(stats, weights)
	local total = 0
	for stat, value in pairs(stats) do
		local w = weights[stat] or 0
		if w ~= 0 then
			local cap = Data.softcaps[stat]
			local v = value
			if cap and v > cap.cap then v = cap.cap + (v - cap.cap) * cap.after end
			total = total + v * w
		end
	end
	return total
end

function IS:Score(link, weights)
	local info = self:Read(link)
	if not info then return nil end
	return self:ScoreStats(info.stats, weights or self:Weights()), info
end

--[[ Comparing with what you wear ]]

local canDualWield
function IS:CanDualWield()
	if canDualWield == nil then
		canDualWield = false
		local i = 1
		while true do
			local name = GetSpellName(i, "spell")
			if not name then break end
			if name == "Dual Wield" then canDualWield = true; break end
			i = i + 1
		end
	end
	return canDualWield
end

--- The score of what you wear in a slot (0 if nothing), and its info.
function IS:EquippedScore(slot, weights)
	local link = GetInventoryItemLink("player", slot)
	if not link then return 0, nil end
	local score, info = self:Score(link, weights)
	return score or 0, info
end

--- How an item compares with what you wear.
--- Returns { score, equipped, delta, pct, slot, usable, later, emptySlot, noCompare }
--- or nil for something you do not wear.
function IS:Compare(link, weights)
	weights = weights or self:Weights()
	local score, info = self:Score(link, weights)
	if not score or not info.equipLoc or not SLOTS[info.equipLoc] then return nil end
	local out = { score = score, usable = info.usable, later = info.later, level = info.level }

	local loc = info.equipLoc
	local slots = SLOTS[loc]
	if loc == "INVTYPE_WEAPON" and self:CanDualWield() then slots = { MAINHAND, OFFHAND } end

	local mainScore, mainInfo = self:EquippedScore(MAINHAND, weights)
	local twoHanded = mainInfo and mainInfo.equipLoc == "INVTYPE_2HWEAPON"

	if loc == "INVTYPE_2HWEAPON" then
		local offScore = twoHanded and 0 or self:EquippedScore(OFFHAND, weights)
		out.slot, out.equipped = MAINHAND, mainScore + offScore
	elseif twoHanded and (loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE") then
		-- An off-hand is only half of what would replace a two-hander.
		out.slot, out.noCompare = OFFHAND, true
		return out
	else
		-- The slot it would replace: the weakest of those it fits.
		for _, slot in ipairs(slots) do
			local s = self:EquippedScore(slot, weights)
			if not out.slot or s < out.equipped then out.slot, out.equipped = slot, s end
		end
		if twoHanded and out.slot == OFFHAND then out.slot, out.equipped = MAINHAND, mainScore end
	end
	out.emptySlot = not GetInventoryItemLink("player", out.slot)
	out.delta = score - out.equipped
	if out.equipped > 0 then out.pct = out.delta / out.equipped * 100 end
	return out
end

--- An upgrade you can wear now (or, with `later`, once you reach its level).
function IS:IsUpgrade(link, later)
	local c = self:Compare(link)
	if not c or c.noCompare or not c.usable then return false, c end
	if c.later and not later then return false, c end
	return c.delta > 0.0001, c
end

--[[ Keeping it current ]]

local listeners = {}
function IS:OnChange(fn) table.insert(listeners, fn) end

--- Weights or spec changed: every score is stale, the stats are not.
function IS:Changed()
	for _, fn in ipairs(listeners) do fn() end
end

--- What the client says about items changed (a level, a new weapon skill).
function IS:Forget()
	cache = {}
	canDualWield = nil
	self:Changed()
end

--[[ Tooltips ]]

--- The line added under an item: its score, and against what you wear.
function IS:TooltipText(link)
	if not settings().tooltips then return nil end
	local ok, c = pcall(function() return self:Compare(link) end)
	if not ok or not c then return nil end
	local spec = self:SpecLabel((self:Spec()))
	local left = "Pathfinder (" .. spec .. ")"
	local right = string.format("%.1f", c.score)
	local color = "|cffd0d0d0"
	if not c.usable then
		right, color = "not for you", "|cff9d9d9d"
	elseif c.noCompare then
		right = right .. " (with a two-hander on)"
	elseif c.emptySlot then
		right, color = right .. "  empty slot", "|cff40ff40"
	elseif c.pct then
		local sign = c.pct >= 0 and "+" or ""
		color = c.pct > 0.05 and "|cff40ff40" or (c.pct < -0.05 and "|cffff5050" or color)
		right = right .. string.format("  %s%.0f%%", sign, c.pct)
		if c.later then right = right .. " at " .. c.level end
	end
	return left, color .. right .. "|r"
end

local function addLine(tip, link)
	if not link then return end
	local left, right = IS:TooltipText(link)
	if left then
		tip:AddDoubleLine(left, right, 0.62, 0.84, 0.43, 1, 1, 1)
		tip:Show()
	end
end

-- Each way the client fills a tooltip with an item, and how to get its link.
local SETTERS = {
	SetBagItem = function(bag, slot) return GetContainerItemLink(bag, slot) end,
	SetInventoryItem = function(unit, slot) return GetInventoryItemLink(unit, slot) end,
	SetLootItem = function(slot) return GetLootSlotLink(slot) end,
	SetQuestItem = function(kind, index) return GetQuestItemLink(kind, index) end,
	SetQuestLogItem = function(kind, index) return GetQuestLogItemLink(kind, index) end,
	SetMerchantItem = function(index) return GetMerchantItemLink(index) end,
	SetAuctionItem = function(kind, index) return GetAuctionItemLink(kind, index) end,
	SetTradePlayerItem = function(index) return GetTradePlayerItemLink(index) end,
	SetTradeTargetItem = function(index) return GetTradeTargetItemLink(index) end,
	SetHyperlink = function(link) return link end,
}

function IS:HookTooltip(tip)
	if not tip or tip.__aegisScored then return end
	tip.__aegisScored = true
	for method, getLink in pairs(SETTERS) do
		local original, find = tip[method], getLink
		if original then
			tip[method] = function(self, a1, a2, a3)
				local r1, r2, r3 = original(self, a1, a2, a3)
				local okLink, link = pcall(find, a1, a2, a3)
				if okLink and link and string.find(link, "item:") then addLine(self, link) end
				return r1, r2, r3
			end
		end
	end
end

--[[ Events ]]

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:SetScript("OnEvent", function()
	if event == "CHARACTER_POINTS_CHANGED" then
		IS:Changed()
	else
		IS:Forget()
	end
end)

function IS:Initialize()
	self:HookTooltip(GameTooltip)
	self:HookTooltip(ItemRefTooltip)
end
