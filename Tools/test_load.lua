--[[
	The whole addon, loaded as the client loads it: every .lua file in the
	.toc, in order, with the real Ace2 libraries.

	A file that stops part-way while loading takes everything after the line
	that failed with it, and the errors that follow name other files. Core.lua
	built its race table from ClassicAPI at load, and indexed
	GetFactionInfo(i).groupTag -- nil for a race with no faction group, which
	ChrRaces has (creature races). So Core.lua stopped at that line: no
	OnInitialize, so no saved settings ("ItemScore.lua:72: attempt to index
	field 'db'"), no GetObjectiveInfo ("QuestTracker.lua:177: attempt to call
	method 'GetObjectiveInfo'").

	Run:  lua5.1 Tools/test_load.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

-- What the Ace2 libraries and the files reach for as they load.
table.setn = function() end               -- Lua 5.0's; 5.1 only complains
debugstack = function() return "Interface\\AddOns\\Aegis_Pathfinder\\Core.lua:6: in main chunk\n" end
geterrorhandler = function() return function() end end
GetBuildInfo = function() return "1.12.1", "5875", "Sep 19 2006", 11200 end
GetLocale = function() return "enUS" end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
UnitClass = function() return "Paladin", "PALADIN" end
UnitRace = function() return "Human", "Human" end
UnitFactionGroup = function() return "Alliance" end
FACTION_HORDE, FACTION_ALLIANCE, PLAYER_OF_REALM = "Horde", "Alliance", "%s of %s"
CHARACTER, REALM, CLASS = "Character: ", "Realm: ", "Class: "
IsAddOnLoaded = function() return false end
LoadAddOn = function() return false end
GetNumAddOns = function() return 1 end
GetAddOnInfo = function() return "Aegis_Pathfinder", "Aegis: Pathfinder", "", true, true end
GetAddOnMetadata = function() return nil end
IsLoggedIn = function() return false end
GetMapContinents = function() return "Kalimdor", "Eastern Kingdoms" end
GetMapZones = function(c) if c == 1 then return "Durotar" end return "Elwynn Forest" end
GetNumQuestLogEntries = function() return 0 end
SlashCmdList, hash_SlashCmdList, UISpecialFrames = {}, {}, {}
DEFAULT_CHAT_FRAME = CreateFrame("Frame")
DEFAULT_CHAT_FRAME.AddMessage = function() end

-- ClassicAPI, with a race that has no faction group, as ChrRaces' creature
-- races do: GetFactionInfo is nil for it.
local RACES = { { "Human", "Human", "Alliance" }, { "Orc", "Orc", "Horde" }, { "Fel Orc", "FelOrc", nil } }
C_CreatureInfo = {
	GetRaceInfo = function(i)
		local r = RACES[i]
		return r and { raceName = r[1], clientFileString = r[2], raceID = i }
	end,
	GetFactionInfo = function(i)
		local r = RACES[i]
		return r and r[3] and { name = r[3], groupTag = r[3] }
	end,
}
local function anything() return setmetatable({}, { __index = function() return function() end end }) end
C_QuestLog, C_Item = anything(), anything()
C_Timer = { After = function() end, NewTicker = function() end }
UnitRaceBase = function() return "Human", "Human" end
CLASSIC_API_VERSION = 10509

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local files = {}
for line in io.lines("Aegis_Pathfinder.toc") do
	line = string.gsub(line, "\r", "")
	if not string.find(line, "^#") and string.find(line, "%.lua$") then
		table.insert(files, (string.gsub(line, "\\", "/")))
	end
end
check(table.getn(files) > 30, "the .toc lists the addon's files, got %d", table.getn(files))

for _, f in ipairs(files) do
	local chunk, err = loadfile(f)
	check(chunk ~= nil, "%s parses: %s", f, tostring(err))
	if chunk then
		local ok, e = pcall(chunk)
		check(ok, "%s loads to its end: %s", f, tostring(e))
		if not ok then break end
	end
end

local A = AegisPathfinder
check(A and type(A.OnInitialize) == "function", "Core.lua defines OnInitialize, so the settings are made")
check(A and type(A.GetObjectiveInfo) == "function", "and GetObjectiveInfo, the flight-point watcher's")
check(A and A.turtleRaces.Human and A.turtleRaces.Human.faction == "Alliance"
	and A.turtleRaces.Orc and A.turtleRaces.Orc.faction == "Horde", "the playable races are read, with their side")
check(A and A.turtleRaces.FelOrc == nil, "and a race with no side is left out, not an error")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Load: %d checks", checks))
if table.getn(failures) == 0 then
	print("All load checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
