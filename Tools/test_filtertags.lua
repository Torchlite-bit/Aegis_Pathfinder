--[[
	The filter tags added to the Optimized and zone guides, through the real
	parser.

	The Auction House, Group and Dungeon switches hide steps at parse time.
	These guides carried no tags until the owner's review
	(docs/review/filter_decisions.json, applied by Tools/apply_filter_tags.py);
	this checks the tags landed where the switches can see them: a group quest
	and the quests that follow it hide in Solo mode and show in Group mode, an
	Auction House step hides with Auction House steps off, a dungeon quest
	hides when its dungeon is unticked -- and every tag applied is still there.

	Run:  lua5.1 Tools/test_filtertags.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

C_Timer = { After = function() end }
C_QuestLog = { RequestLoadQuestByID = function() end, GetNumQuestObjectives = function() return nil end }
C_Item = { RequestLoadItemDataByID = function() end }

AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {},
	db = { char = { completion = {}, turnins = {}, Dungeons = {} }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder:IsDebugging() return false end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder.split(sep, s)
	local fields = {}
	string.gsub(s, string.format("([^%s]+)", sep), function(c) fields[table.getn(fields) + 1] = c end)
	return fields
end
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
end

-- A Human Paladin, so the Tome of Divinity steps are on the route at all.
UnitClass = function() return "Paladin", "PALADIN" end
dofile("Parser.lua")
function AegisPathfinder:SmartSkipToStep() end
function AegisPathfinder:WarmCaches() end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

dofile("Guides/Optimized/Alliance/01_10_Elwynn_Forest.lua")
dofile("Guides/Alliance/12_17_Westfall.lua")
dofile("Guides/Alliance/28_29_Duskwood.lua")
dofile("Guides/Optimized/Alliance/10_12_Westfall.lua")

local char = AegisPathfinder.db.char

-- How many of a guide's parsed steps name `text`, under the given settings.
local function count(guide, text, playstyle, ah, dungeons)
	char.PlayStyle, char.UseAH, char.Dungeons = playstyle, ah, dungeons or {}
	char.currentguide = nil
	AegisPathfinder:LoadGuide(guide)
	local n = 0
	for _, q in ipairs(AegisPathfinder.quests) do
		if string.find(q, text, 1, true) then n = n + 1 end
	end
	return n
end

local ELWYNN = "Optimized/Elwynn Forest (1-10)"
check(count(ELWYNN, "Discover Rolf's Fate", "SOLO", false) == 0,
	"a group quest should be hidden in Solo mode")
check(count(ELWYNN, "Discover Rolf's Fate", "GROUP", false) == 2,
	"a group quest should be shown in Group mode -- accept and turn in")
check(count(ELWYNN, "Report to Thomas", "SOLO", false) == 0,
	"the quest after a group quest can't be picked up solo either")
check(count(ELWYNN, "Report to Thomas", "GROUP", false) > 0,
	"the quest after a group quest shows in Group mode")
check(count(ELWYNN, "Shipment to Stormwind", "SOLO", false) > 0,
	"a quest whose id only sat on a tagged travel step is untouched")

-- Answers changed after the review: these can be done without the Auction
-- House, and the travel step is not Hogger's.
check(count("Westfall (12-17)", "The Tome of Divinity (Part 5)", "SOLO", false) == 3,
	"the Tome of Divinity needs only Linen Cloth, which drops -- it stays with Auction House steps off")
check(count("Optimized/Westfall (10-12)", "Stormwind City@", "SOLO", false) > 0,
	"the trip to Stormwind for Shipment to Stormwind stays in Solo mode")

local DUSKWOOD = "Duskwood (28-29)"
check(count(DUSKWOOD, "[Bronze Tube]", "SOLO", false) == 0,
	"an Auction House buy step should be hidden with Auction House steps off")
check(count(DUSKWOOD, "[Bronze Tube]", "SOLO", true) == 1,
	"an Auction House buy step should show with Auction House steps on")

-- Solo Self-Found: no Auction House whatever its switch says, and no step
-- that needs another player.
char.SelfFound = true
check(count(DUSKWOOD, "[Bronze Tube]", "SOLO", true) == 0,
	"Solo Self-Found hides Auction House steps even with them switched on")
AegisPathfinder:RegisterGuide("Trade Test (1-2)", nil, "Alliance", function()
	return "N Ask a mage for water |N|Trade for it| |TRADE|\nN Drink |N|Sit down|\n"
end)
check(count("Trade Test (1-2)", "Ask a mage", "SOLO", true) == 0, "Solo Self-Found hides a |TRADE| step")
check(count("Trade Test (1-2)", "Drink", "SOLO", true) == 1, "and keeps the rest")
char.SelfFound = false
check(count("Trade Test (1-2)", "Ask a mage", "SOLO", false) == 1, "a |TRADE| step shows otherwise")

local WESTFALL = "Westfall (12-17)"
check(count(WESTFALL, "The Defias Brotherhood (Part 2)", "SOLO", false, {}) == 0,
	"a Deadmines quest should be hidden with the Deadmines unticked")
check(count(WESTFALL, "The Defias Brotherhood (Part 2)", "SOLO", false, { DM = true }) > 0,
	"a Deadmines quest should show with the Deadmines ticked")

-- Every approved tag is still in place.
local rc = os.execute("python3 Tools/apply_filter_tags.py --check > /dev/null")
check(rc == 0, "apply_filter_tags.py --check: an approved tag is missing or a reviewed step moved")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("FilterTags: %d checks", checks))
if table.getn(failures) == 0 then
	print("All filter tag checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
