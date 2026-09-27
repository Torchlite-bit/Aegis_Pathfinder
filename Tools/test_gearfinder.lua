--[[
	Tests for the Gear Finder (GearFinder.lua): which dungeons it looks in,
	which of their drops it weighs, loading the ones the client has not seen,
	the upgrades by slot, the window, and naming upgrades on walking in --
	through the real item score, on a small made-up GearData.

	Run:  lua5.1 Tools/test_gearfinder.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local now = 100
GetTime = function() return now end
local printed = {}
AegisPathfinder = { db = { char = {}, profile = {} } }
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder.FormatCopper(c) return c .. "c" end

local level, faction = 20, "Alliance"
UnitLevel = function() return level end
UnitFactionGroup = function() return faction end
UnitClass = function() return "Warrior", "WARRIOR" end
GetTalentTabInfo = function(tab) return "Arms", "icon", tab == 1 and 11 or 0 end
GetSpellName = function() return nil end
GetItemQualityColor = function() return 1, 1, 1, "|cff0070dd" end
GameTooltip.SetHyperlink = function(self, l) self.__link = l end
GameTooltip.Hide = function() end

-- Items the client has; the rest it is asked for.
local ITEMS, asked = {}, {}
C_Item = { RequestLoadItemDataByID = function(id) table.insert(asked, id) end }
local function item(id, loc, str, quality, level)
	ITEMS[id] = { loc = loc, quality = quality, level = level,
		lines = { "Item " .. id, "+" .. str .. " Strength" } }
end
GetItemInfo = function(it)
	local _, _, id = string.find(it, "item:(%d+)")
	local def = ITEMS[tonumber(id)]
	if not def then return nil end
	return "Item " .. id, it, def.quality or 3, def.level or 20, "Armor", "Plate", 1, def.loc, "icon"
end
local worn = {}
GetInventoryItemLink = function(unit, slot)
	return worn[slot] and ("|Hitem:" .. worn[slot] .. ":0:0:0|h[x]|h")
end

dofile("Theme.lua")
dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
dofile("GearData.lua")
dofile("GearAdvisor.lua")
dofile("GearFinder.lua")
local A, IS, GF = AegisPathfinder, AegisPathfinder.ItemScore, AegisPathfinder.GearFinder
function IS:ReadLines(it)
	local _, _, id = string.find(it, "item:(%d+)")
	local out = {}
	for _, l in ipairs(ITEMS[tonumber(id)].lines) do table.insert(out, { left = l }) end
	return out
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function run(f, script)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local old = this
	this = f
	h()
	this = old
end

-- The real data is there and in the shape the finder reads.
local real = AegisPathfinder.GearData
check(table.getn(real.dungeons) >= 20, "the dungeons and raids are in GearData")
local dm
for _, d in ipairs(real.dungeons) do if d.code == "DM" then dm = d end end
check(dm and dm.lo == 18 and table.getn(dm.loot) > 10, "the Deadmines, with its loot")
local vanCleef
for _, drop in ipairs(dm.loot) do if drop[2] == "Edwin VanCleef" then vanCleef = drop end end
check(vanCleef and real.items[vanCleef[1]] and real.items[vanCleef[1]][1], "VanCleef's drops, with their slot")
-- Bosses a script summons are on no map; the data names them.
local sources = {}
for _, d in ipairs(real.dungeons) do
	for _, drop in ipairs(d.loot) do sources[drop[2] .. " @ " .. d.code] = true end
end
check(sources["Ragnaros @ MC"] and sources["Nefarian @ BWL"] and sources["Darkmaster Gandling @ SCHOLO"],
	"summoned bosses' loot is there, in their instances")
-- Turtle WoW's own dungeons, from pfQuest-turtle.
local turtle = {}
for _, d in ipairs(real.dungeons) do if d.turtle then turtle[d.name] = d end end
local cg = turtle["Crescent Grove"]
check(cg and cg.kind == "dungeon" and cg.lo >= 30 and cg.hi <= 40 and cg.lo <= cg.hi,
	"Crescent Grove, at the levels its creatures are, got %s-%s", tostring(cg and cg.lo), tostring(cg and cg.hi))
check(sources["Grovetender Engryss @ CG"] and sources["High Priestess A'lathea @ CG"], "with its bosses' drops")
local unknown = 0
for _, drop in ipairs(cg.loot) do if not real.items[drop[1]] then unknown = unknown + 1 end end
check(unknown > 0, "Turtle's own items, which the client describes, not the data")
for _, name in ipairs({ "Dragonmaw Retreat", "Stormwrought Ruins", "Gilneas City", "Hateforge Quarry",
	"Karazhan Crypt", "The Black Morass", "Stormwind Vault" }) do
	check(turtle[name] and turtle[name].kind == "dungeon" and table.getn(turtle[name].loot) > 10,
		"%s is there, with its loot", name)
end
check(turtle["Emerald Sanctum"] and turtle["Emerald Sanctum"].kind == "raid"
	and turtle["Tower of Karazhan"] and turtle["Tower of Karazhan"].kind == "raid", "and Turtle's raids, as raids")
for name, d in pairs(turtle) do
	check(d.hi <= 60, "%s's levels are ones a player can be, got %s", name, tostring(d.hi))
end

-- A small world to look in.
AegisPathfinder.GearData = {
	sell = {},
	dungeons = {
		{ code = "DM", name = "The Deadmines", lo = 18, hi = 25, kind = "dungeon", loot = {
			{ 101, "Edwin VanCleef", 20 }, { 102, "Cookie", 65 }, { 103, "Mr. Smite", 40 },
			{ 104, "Gilnid", 30 }, { 105, "Captain Greenskin", 30 },
		} },
		{ code = "WC", name = "Wailing Caverns", lo = 18, hi = 25, kind = "dungeon", loot = {
			{ 111, "Mutanus", 25 }, { 112, "Lady Anacondra", 20 }, { 113, "Lord Pythas", 20 },
			{ 114, "Lord Cobrahn", 20 }, { 115, "Lord Serpentis", 20 },
		} },
		{ code = "RFC", name = "Ragefire Chasm", lo = 13, hi = 18, kind = "dungeon", faction = "Horde", loot = {
			{ 121, "Taragaman", 30 },
		} },
		{ code = "SFK", name = "Shadowfang Keep", lo = 23, hi = 29, kind = "dungeon", loot = {
			{ 131, "Arugal", 30 },
		} },
		{ code = "ZG", name = "Zul'Gurub", lo = 60, hi = 60, kind = "raid", loot = {
			{ 141, "Hakkar", 10 },
		} },
		-- One of Turtle's own: its items have no entry below.
		{ code = "CG", name = "Crescent Grove", lo = 18, hi = 25, kind = "dungeon", turtle = true, loot = {
			{ 201, "Grovetender", 25 }, { 202, "Elder", 100 }, { 203, "Warden", 30 },
			{ 204, "Keeper", 20 }, { 205, "Raxxieth", 25 },
		} },
	},
	items = {
		[101] = { "INVTYPE_CHEST", 3, 20, 0 }, [102] = { "INVTYPE_HEAD", 2, 19, 0 },
		[103] = { "INVTYPE_2HWEAPON", 3, 20, 0 }, [104] = { "INVTYPE_HEAD", 2, 19, 0 },
		[105] = { "INVTYPE_HEAD", 2, 30, 0 },       -- too high for now
		[111] = { "INVTYPE_HEAD", 2, 18, 0 }, [112] = { "INVTYPE_HEAD", 2, 18, 0 },
		[113] = { "INVTYPE_HEAD", 2, 18, 128 },     -- mages only
		[114] = { "INVTYPE_WRIST", 2, 18, 0 },       -- not loaded yet
		[115] = { "INVTYPE_HEAD", 2, 18, 0 },
		[121] = { "INVTYPE_HEAD", 3, 16, 0 }, [131] = { "INVTYPE_HEAD", 3, 23, 0 },
		[141] = { "INVTYPE_HEAD", 4, 60, 0 },
	},
}
item(101, "INVTYPE_CHEST", 12); item(102, "INVTYPE_HEAD", 8); item(103, "INVTYPE_2HWEAPON", 20)
item(104, "INVTYPE_HEAD", 11); item(105, "INVTYPE_HEAD", 30); item(111, "INVTYPE_HEAD", 9)
item(112, "INVTYPE_HEAD", 14); item(113, "INVTYPE_HEAD", 40); item(121, "INVTYPE_HEAD", 50)
item(131, "INVTYPE_HEAD", 13); item(141, "INVTYPE_HEAD", 99); item(115, "INVTYPE_HEAD", 12)
item(900, "INVTYPE_HEAD", 10)
item(201, "INVTYPE_FEET", 7)                -- Turtle's own boots
item(202, "", 99)                           -- a badge: not gear
item(203, "INVTYPE_FEET", 50, 0)            -- grey
item(205, "INVTYPE_FEET", 60, 3, 30)        -- too high for now; 204 not loaded yet
worn[1] = 900
A.db.char.Dungeons = { DM = true, WC = true, SFK = true }

-- Where it looks ------------------------------------------------------------------

local function codes()
	local out = {}
	for _, d in ipairs(GF:Dungeons()) do out[d.code] = true end
	return out
end
local c = codes()
check(c.DM and c.WC, "the dungeons at your level")
check(not c.RFC, "not the other side's")
check(c.SFK, "one starting a few levels above you")
check(not c.ZG, "no raids until you ask")
A.db.char.Dungeons.WC = false
check(not codes().WC, "not a dungeon you have unticked")
A.db.char.Dungeons.WC = true
GF.Settings().raids = true
check(not codes().ZG, "a raid only at its level, even when asked")
GF.Settings().raids = false
check(GF.ForClass(128, "MAGE") and not GF.ForClass(128, "WARRIOR") and GF.ForClass(0, "WARRIOR"),
	"class masks read")
A.db.char.SelfFound = true
check(table.getn(GF:Dungeons()) == 0, "Solo Self-Found runs no dungeons, so none are looked in")
A.db.char.SelfFound = nil
check(codes().DM, "and off again, they are")

-- What it finds -----------------------------------------------------------------------

local weighed = {}
local compare = IS.Compare
function IS:Compare(it, w)
	local _, _, id = string.find(it, "item:(%d+)")
	weighed[tonumber(id)] = true
	return compare(self, it, w)
end
local results, missing = GF:Find()
check(not weighed[202] and not weighed[203], "a badge or a grey item is never even weighed")
local slots = {}
for _, g in ipairs(results) do slots[g.slot] = g.entries end
check(slots.Head and slots.Head[1].id == 112, "the best head first (+14 over +10), got %s",
	tostring(slots.Head and slots.Head[1].id))
check(table.getn(slots.Head) == 3, "at most three a slot (of four), got %d", slots.Head and table.getn(slots.Head) or 0)
check(slots.Head[3].id == 115, "the three best: +14, +13, +12, got %s", tostring(slots.Head[3].id))
for _, e in ipairs(slots.Head) do
	check(e.id ~= 102, "not one that is worse than what you wear")
	check(e.id ~= 105, "not one too far above your level")
	check(e.id ~= 113, "not one for another class")
end
check(slots.Chest and slots.Chest[1].compare.emptySlot, "a slot you have nothing in")
check(slots.Weapon and slots.Weapon[1].id == 103 and slots.Weapon[1].source == "Mr. Smite",
	"weapons, with who drops them")
check(missing == 2 and not slots.Wrist, "items not loaded yet are counted, not guessed at")
check(slots.Feet and slots.Feet[1].id == 201 and slots.Feet[1].dungeon == "Crescent Grove"
	and slots.Feet[1].source == "Grovetender", "a Turtle dungeon's own item, described by the client")
check(table.getn(slots.Feet) == 1, "not its badge, its grey, or one above your level (%d listed)", table.getn(slots.Feet))
check(slots.Feet[1].level == 20, "at the level the client gives it")
check(results[1].slot == "Head", "slots in the character sheet's order, got %s", results[1].slot)

-- Loading what the client has not seen.
check(GF:Pending() == 2, "they are queued to load")
now = now + 1
run(GF.events, "OnUpdate")
check(asked[1] == 114 and asked[2] == 204, "and asked for the safe way, Turtle's own too")
item(114, "INVTYPE_WRIST", 4)
item(204, "INVTYPE_FINGER", 5)
results, missing = GF:Find()
check(missing == 0, "once they have come, nothing is missing")
slots = {}
for _, g in ipairs(results) do slots[g.slot] = g.entries end
check(slots.Finger and slots.Finger[1].id == 204, "and the Turtle item that came is weighed")

-- The window --------------------------------------------------------------------------

GF:Toggle()
local frame = GF.frame
run(frame, "OnShow")
check(frame:IsShown(), "the toggle opens it")
local row = frame.rows[1]
check(row:IsShown() and row.slot:GetText() == "Head", "the first row names the slot, got %s", tostring(row.slot:GetText()))
check(row.name:GetText() == "|cff0070ddItem 112|r", "the item, in its quality's colour")
check(row.gain:GetText() == "+40%", "what it gains, got %s", tostring(row.gain:GetText()))
check(row.where:GetText() == "Lady Anacondra, Wailing Caverns \194\183 20%", "and where it drops, got %s",
	tostring(row.where:GetText()))
check(frame.rows[2].slot:GetText() == "", "the slot is named once")
check(string.find(frame.note:GetText(), "The Deadmines", 1, true), "the note names where it looked")
A.db.char.SelfFound = true
GF:Refresh()
check(frame.note:GetText() == "Solo Self-Found is on, so it looks in no dungeons.", "with Self-Found on it says why it is empty, got %s",
	tostring(frame.note:GetText()))
A.db.char.SelfFound = nil
GF:Refresh()
run(row, "OnEnter")
check(GameTooltip.__link == "item:112:0:0:0", "hovering a row shows the item")
run(frame.raids, "OnClick")
check(GF.Settings().raids, "the raids switch")
run(frame.raids, "OnClick")
worn[1] = 121
GF:Refresh()
check(string.find(frame.note:GetText(), "Nothing in", 1, true) or frame.rows[1].slot:GetText() ~= "Head",
	"with better gear on, fewer upgrades")
worn[1] = 900
GF:Refresh()

-- Walking into a dungeon ----------------------------------------------------------------

printed = {}
GF:Announce("Wailing Caverns")
check(printed[1] and string.find(printed[1], "Upgrades in Wailing Caverns: Item 112 +40%", 1, true),
	"entering a dungeon names its upgrades, got %s", tostring(printed[1]))
printed = {}
GF:Announce("Elwynn Forest")
check(printed[1] == nil, "not somewhere that is not a dungeon")
A.db.char.Dungeons.WC = false
GF:Announce("Wailing Caverns")
check(printed[1] ~= nil, "a dungeon you have unticked still says, once you are in it")
check(A.db.char.Dungeons.WC == false, "without changing what you ticked")
GF.Settings().announce = false
printed = {}
GF:Announce("Wailing Caverns")
check(printed[1] == nil, "and not at all when switched off")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("GearFinder: %d checks", checks))
if table.getn(failures) == 0 then
	print("All gear finder checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
