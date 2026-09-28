--[[
	The route packs against the guides they name.

	A route is what a character is taken through: the next guide after one on
	your route is the route's next leg (Core.lua's GetRouteSuccessor), and the
	first-time setup counts each dungeon's quests along it. So every leg must
	be a guide your faction has -- a leg that names none is where the guide
	stops -- and every guide's own next link, the way on for a guide picked off
	the route, must name one too. DungeonQuests.lua, the setup's counts, must
	be what Tools/build_dungeon_quests.py makes of these routes today.

	Run:  lua5.1 Tools/test_routes.lua
]]

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, unpack(arg))) end
end

-- Every guide, by faction, and its next link.
local guides = {}          -- faction -> name -> next
AegisPathfinder = {}
function AegisPathfinder:RegisterGuide(name, nextzone, faction)
	guides[faction] = guides[faction] or {}
	guides[faction][name] = nextzone or ""
end
function AegisPathfinder:RegisterQuestShellPlusGuide() end
for file in io.popen("find Guides -name '*.lua' | sort"):lines() do
	local chunk = loadfile(file)
	if chunk then pcall(chunk) end
end

local packs = {}
function AegisPathfinder:RegisterRoute() end
function AegisPathfinder:RegisterRoutePack(name, pack) packs[name] = pack end
dofile("Routes/Routes.lua")

local ALLIANCE = { Human = true, Dwarf = true, Gnome = true, NightElf = true, HighElf = true }
local function has(faction, name)
	return (guides[faction] and guides[faction][name]) or (guides.Both and guides.Both[name])
end

local legs = 0
for pack, info in pairs(packs) do
	for race, route in pairs(info.routes) do
		local faction = ALLIANCE[race] and "Alliance" or "Horde"
		for i, leg in ipairs(route) do
			legs = legs + 1
			check(has(faction, leg.guide), "%s / %s leg %d: no %s guide %q", pack, race, i, faction, leg.guide)
		end
	end
end
check(legs > 300, "the packs' routes are all read, got %d legs", legs)
-- Kamisayo Speedrun is hidden until its guides are added, and a character
-- that had picked it moves to RestedXP (Core.lua's MoveOffRetiredPack).
check(not packs["Kamisayo Speedrun"], "Kamisayo Speedrun is not offered: none of its guides exist")
do
	local core = io.open("Core.lua"):read("*a")
	local function lift(from, to)
		local a = string.find(core, from, 1, true)
		local b = string.find(core, to, a or 1, true)
		assert(a and b, "could not find " .. from .. " in Core.lua")
		assert(loadstring(string.sub(core, a, b - 1)))()
	end
	lift("AegisPathfinder.RETIRED_PACKS =", "\n")
	lift("function AegisPathfinder:MoveOffRetiredPack()", "-- Get the currently active route pack")
	AegisPathfinder.routepacks = packs
	local function after(saved)
		AegisPathfinder.db = { char = { routepack = saved } }
		AegisPathfinder:MoveOffRetiredPack()
		return AegisPathfinder.db.char.routepack
	end
	check(after("Kamisayo Speedrun") == "RestedXP", "a Kamisayo character moves to RestedXP, got %s", tostring(after("Kamisayo Speedrun")))
	check(packs[after("Kamisayo Speedrun")], "which is a pack")
	check(after("RXP Hardcore") == "RXP Hardcore" and after(nil) == nil, "and nobody else moves")
end

-- The next links.
for faction, names in pairs(guides) do
	for name, nextname in pairs(names) do
		if nextname ~= "" then
			local ok = has(faction, nextname) or (faction == "Both" and (has("Alliance", nextname) or has("Horde", nextname)))
			check(ok, "%s (%s): its next guide %q does not exist", name, faction, nextname)
		end
	end
end

-- Where the routes part: RestedXP takes the Eastern Kingdoms races through
-- Redridge at 19, Night Elves through Darkshore.
local function after(pack, race, name)
	for i, leg in ipairs(packs[pack].routes[race]) do
		if leg.guide == name then return packs[pack].routes[race][i + 1].guide end
	end
end
check(after("RestedXP", "Human", "RXP/16-19 Darkshore") == "RXP/19-20 Redridge",
	"RestedXP Humans go to Redridge at 19, got %s", tostring(after("RestedXP", "Human", "RXP/16-19 Darkshore")))
check(after("RestedXP", "NightElf", "RXP/16-19 Darkshore") == "RXP/19-21 Darkshore/Ashenvale",
	"Night Elves stay in Darkshore")
check(after("VanillaGuide", "Human", "Optimized/Wetlands (30-30)") == "Optimized/Hillsbrad (30-31)",
	"the Optimized route goes on past 30")

-- DungeonQuests.lua: fresh, and what it says holds together.
local rc = os.execute("python3 Tools/build_dungeon_quests.py --check > /dev/null")
check(rc == 0, "DungeonQuests.lua is out of date: run python3 Tools/build_dungeon_quests.py")
dofile("DungeonQuests.lua")
local DQ = AegisPathfinder.DUNGEON_QUESTS
check(type(DQ) == "table" and AegisPathfinder.DUNGEON_RECOMMEND == 5, "the counts load")
for pack, races in pairs(DQ) do
	check(packs[pack], "counts for a pack that exists: %s", pack)
	for race, codes in pairs(races) do
		check(packs[pack] and packs[pack].routes[race], "%s: counts for a race it has a route for: %s", pack, race)
		for code, list in pairs(codes) do
			for _, q in ipairs(list) do
				local id = type(q) == "table" and q[1] or q
				check(type(id) == "number", "%s / %s / %s: a quest id, got %s", pack, race, code, tostring(id))
			end
		end
	end
end
local function n(pack, race, code) return table.getn((DQ[pack] and DQ[pack][race] and DQ[pack][race][code]) or {}) end
check(n("RestedXP", "Human", "DM") >= 20, "RestedXP takes a Human through the Deadmines' quests, got %d", n("RestedXP", "Human", "DM"))
check(n("RestedXP", "NightElf", "DM") == 0, "and not a Night Elf, who never goes, got %d", n("RestedXP", "NightElf", "DM"))
check(n("RestedXP", "Human", "GNOMER") >= 12, "Gnomeregan's quests are handed in, got %d", n("RestedXP", "Human", "GNOMER"))
check(n("VanillaGuide", "Orc", "BRD") < 5, "the Optimized guides take the Horde through few")

print(string.format("Routes: %d checks", checks))
if table.getn(failures) == 0 then
	print("All route checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
