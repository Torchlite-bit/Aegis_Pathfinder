--[[
	The dungeon guides (Guides/Dungeons/, written by
	Tools/build/build_dungeon_guides.py), through the real parser.

	A dungeon guide is picked from the guide list: it picks up the dungeon's
	quests, puts the arrow on the entrance, and hands everything in after.
	This checks that each one is current with its generator, is listed in its
	side's Guides.xml, parses, has a travel step to the entrance the arrow can
	point at, and leaves no loose ends: nothing handed in before it is picked
	up, nothing picked up and never handed in, no objective before its quest.
	Windhorn Canyon, patch 1.18.1's dungeon, has its quests on both sides.

	Run:  lua5.1 Tools/tests/test_dungeonguides.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
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
local registered = {}
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
	table.insert(registered, { name = name, nextzone = nextzone, faction = faction, loader = loader })
end

dofile("Parser.lua")
function AegisPathfinder:SmartSkipToStep() end
function AegisPathfinder:WarmCaches() end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local rc = os.execute("python3 Tools/build/build_dungeon_guides.py --check > /dev/null")
check(rc == 0, "Guides/Dungeons/ is out of date: run python3 Tools/build/build_dungeon_guides.py")

local guides = {}          -- name -> { faction, text }
for _, side in ipairs({ "Alliance", "Horde" }) do
	local listed = {}
	for file in string.gfind(io.open("Guides/Dungeons/" .. side .. "/Guides.xml"):read("*a"), '<Script file="([^"]+)"/>') do
		listed[file] = true
	end
	for path in io.popen("ls Guides/Dungeons/" .. side .. "/*.lua"):lines() do
		local _, _, file = string.find(path, "([^/]+)$")
		check(listed[file], "%s is not in %s's Guides.xml", path, side)
		local before = table.getn(registered)
		dofile(path)
		local g = registered[before + 1]
		check(table.getn(registered) == before + 1, "%s registers one guide", path)
		if g then
			check(string.find(g.name, "^Dungeons/.+ %(%d+%-%d+%)$"), "%s: a dungeon guide's name, got %s", path, g.name)
			check(g.faction == side, "%s: registered for %s, got %s", path, side, tostring(g.faction))
			check(g.nextzone == nil, "%s: a dungeon guide leads nowhere after", path)
			guides[g.name .. "@" .. side] = { name = g.name, side = side, text = g.loader() }
		end
	end
end

local n = 0
for _, g in pairs(guides) do
	n = n + 1
	-- The raw steps, in order.
	local accepted, handed, entrance = {}, {}, false
	local _, _, title = string.find(g.name, "^Dungeons/(.+) %(")
	for line in string.gfind(g.text, "[^\n]+") do
		local _, _, action, rest = string.find(line, "^(%a) (.*)$")
		local _, _, qid = string.find(line, "|QID|(%d+)|")
		local optional = string.find(line, "|O|", 1, true)
		if action == "R" and string.find(line, "|Z|", 1, true) and string.find(line, "%(%d+%.?%d*, %d+%.?%d*%)|") then
			entrance = true
		end
		if qid then
			if action == "A" then
				accepted[qid] = optional and "optional" or "yes"
			elseif action == "C" then
				check(accepted[qid], "%s (%s): objectives of %s before it is picked up", g.name, g.side, qid)
			elseif action == "T" then
				check(accepted[qid] or optional, "%s (%s): %s handed in before it is picked up", g.name, g.side, qid)
				handed[qid] = true
			end
		end
	end
	check(entrance, "%s (%s): no travel step with a zone and a point for the arrow", g.name, g.side)
	for qid, how in pairs(accepted) do
		check(handed[qid] or how == "optional", "%s (%s): %s is picked up and never handed in", g.name, g.side, qid)
	end
	-- Through the parser: every step shows, none dropped for a filter.
	AegisPathfinder.db.char.currentguide = nil
	AegisPathfinder.db.char.PlayStyle = "GROUP"
	AegisPathfinder:LoadGuide(g.name)
	check(AegisPathfinder.quests and table.getn(AegisPathfinder.quests) > 5,
		"%s (%s) parses, got %d steps", g.name, g.side, AegisPathfinder.quests and table.getn(AegisPathfinder.quests) or 0)
end
check(n == 42, "a guide per dungeon and side, Ragefire Chasm the Horde's only and the Stockade the Alliance's: 42, got %d", n)

-- Windhorn Canyon, 1.18.1's dungeon.
local function has(key, qid)
	return guides[key] and string.find(guides[key].text, "|QID|" .. qid .. "|", 1, true) ~= nil
end
local WHC = "Dungeons/Windhorn Canyon (26-30)"
check(has(WHC .. "@Alliance", 41976), "In Search of Tauren Relics, from Ironforge")
for _, qid in ipairs({ 41977, 41978, 41982, 41939 }) do
	check(has(WHC .. "@Horde", qid), "Windhorn Canyon's Horde quest %d", qid)
end
check(guides[WHC .. "@Horde"] and string.find(guides[WHC .. "@Horde"].text,
	"R Windhorn Canyon |N|[^|]*%(64%.6, 45%.9%)| |Z|Thousand Needles|"), "the arrow goes to the Windhorn Caverns in Thousand Needles")
check(guides[WHC .. "@Horde"] and string.find(guides[WHC .. "@Horde"].text,
	"A Vortalus.- Edict |QID|41939|[^\n]*|C|Shaman|"), "Vortalus' Edict is the Shaman's")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("Dungeon guides: %d checks", checks))
if table.getn(failures) == 0 then
	print("All dungeon guide checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
