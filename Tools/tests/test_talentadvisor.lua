--[[
	Tests for the Talent Advisor's engine (TalentAdvisor.lua) and its builds
	(TalentBuilds.lua), against the trees Turtle WoW has
	(Tools/tests/talent_trees.lua, written by Tools/build/talent_builds.py).

	Every build has to fit its class's tree and be learnt point by point in
	its order -- 5 points a row, prerequisites first, no more ranks than a
	talent has, 51 by 60 -- with the advisor naming each point in turn; the
	next point at a level has to be the build's; points off the build have
	to be counted and the advisor carry on from the closest point; a build
	that does not fit the tree has to say why; and the build followed has to
	be the levelling one until 60, then your spec's.

	Run:  lua5.1 Tools/tests/test_talentadvisor.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = { db = { char = {}, profile = {} } }
local A = AegisPathfinder
dofile("TalentBuilds.lua")
dofile("TalentAdvisor.lua")
local TA = A.TalentAdvisor
local TREES = dofile("Tools/tests/talent_trees.lua")

local checks, failures = 0, {}
local function check(cond, msg, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(msg, unpack(arg))) end
end

-- The talent API for a class's trees, with the ranks given.
local CLASS_NAME = { WARRIOR = "Warrior", MAGE = "Mage", ROGUE = "Rogue", PRIEST = "Priest", WARLOCK = "Warlock",
	HUNTER = "Hunter", PALADIN = "Paladin", SHAMAN = "Shaman", DRUID = "Druid" }
local current = { ranks = {} }
local function UseClass(class, trees)
	current.class, current.trees, current.ranks = class, trees or TREES[class], {}
	UnitClass = function() return CLASS_NAME[class], class end
	GetNumTalentTabs = function() return table.getn(current.trees) end
	GetTalentTabInfo = function(t) return current.trees[t].name, "icon", 0, "bg" end
	GetNumTalents = function(t) return table.getn(current.trees[t].talents) end
	GetTalentInfo = function(t, i)
		local x = current.trees[t].talents[i]
		return x[1], "icon", x[2], x[3], current.ranks[x[1]] or 0, x[4], nil, 1
	end
	GetTalentPrereqs = function(t, i)
		local x = current.trees[t].talents[i]
		if x[5] > 0 then return x[5], x[6], nil end
	end
end

-- A copy of a class's trees with one talent changed (nil: taken out).
local function Changed(class, name, fn)
	local out = {}
	for _, tree in ipairs(TREES[class]) do
		local talents = {}
		for _, x in ipairs(tree.talents) do
			if x[1] == name then
				local y = fn and fn({ x[1], x[2], x[3], x[4], x[5], x[6] })
				if y then table.insert(talents, y) end
			else
				table.insert(talents, x)
			end
		end
		table.insert(out, { name = tree.name, talents = talents })
	end
	return out
end

local function Copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end

-- Ranks after the first n points of a list.
local function After(points, n)
	local r = {}
	for k = 1, n do r[points[k]] = (r[points[k]] or 0) + 1 end
	return r
end

-- Every build fits its tree, and is learnt point by point ---------------------

do
	local classes = {}
	for class in pairs(A.TalentBuilds) do table.insert(classes, class) end
	table.sort(classes)
	check(table.getn(classes) == 9, "builds for all nine classes, got %d", table.getn(classes))
	for _, class in ipairs(classes) do
		check(TREES[class] ~= nil, "%s: the tests have its tree", class)
		UseClass(class)
		local tree = TA.ReadTree()
		local builds = A.TalentBuilds[class]
		check(table.getn(builds.specs) == 3, "%s: a build at 60 for each of three specs", class)
		local all = { builds.levelling }
		for _, b in ipairs(builds.specs) do table.insert(all, b) end
		for _, b in ipairs(all) do
			local label = class .. " " .. (b == builds.levelling and "levelling" or b.spec)
			local ok, why = TA.Fits(tree, b)
			check(ok, "%s fits the tree, got %s", label, tostring(why))
			-- Learn it as the advisor says, from no points: each point the
			-- build's next, one a level from 10.
			local points = TA.Points(b)
			local ranks, steps, wrong = {}, 0, nil
			for k = 1, table.getn(points) do
				local name, rank = TA.Next(tree, ranks, points)
				if name ~= points[k] or rank ~= (ranks[name] or 0) + 1 then
					wrong = wrong or string.format("point %d (level %d): %s %s, not %s", k, TA.FIRST_LEVEL + k - 1,
						tostring(name), tostring(rank), points[k])
				end
				if not name then break end
				ranks[name] = (ranks[name] or 0) + 1
				steps = steps + 1
			end
			check(not wrong, "%s: the advisor names each point in turn, got %s", label, tostring(wrong))
			check(steps == TA.POINTS, "%s: 51 points by 60, got %d", label, steps)
			check(TA.Next(tree, ranks, points) == nil, "%s: nothing after the last point", label)
			local _, off = TA.Off(ranks, TA.Targets(points))
			check(off == 0, "%s: no point off the build when following it", label)
		end
	end
end

-- The next point at a level ------------------------------------------------------

do
	UseClass("WARRIOR")
	local tree = TA.ReadTree()
	local lev = A.TalentBuilds.WARRIOR.levelling
	local points = TA.Points(lev)
	-- Level 21 spent the twelfth point: the thirteenth, at 22, is Deep
	-- Wounds' third rank.
	local name, rank = TA.Next(tree, After(points, 12), points)
	check(name == "Deep Wounds" and rank == 3, "at 22: Deep Wounds 3, got %s %s", tostring(name), tostring(rank))
	check(TA.LevelLine(22, name, rank, tree.talent[name].max, tree.tabs[tree.talent[name].tab].name)
		== "Level 22: a talent point to spend. Take Deep Wounds (rank 3 of 3) in Arms.", "said in chat so")
	name = TA.Next(tree, After(points, 30), points)
	check(name == "Mortal Strike", "the 31st point, at 40: Mortal Strike, got %s", tostring(name))
	name = TA.Next(tree, After(points, 31), points)
	check(name == "Cruelty", "then Fury, from 41, got %s", tostring(name))
end

-- Points off the build ------------------------------------------------------------

do
	UseClass("WARRIOR")
	local tree = TA.ReadTree()
	local points = TA.Points(A.TalentBuilds.WARRIOR.levelling)
	local targets = TA.Targets(points)
	-- At 29: the build's first 18 points, and two in Improved Thunder Clap
	-- where the build has the 19th and 20th.
	local ranks = After(points, 18)
	ranks["Improved Thunder Clap"] = 2
	local off, total = TA.Off(ranks, targets)
	check(total == 2 and off["Improved Thunder Clap"] == 2, "two points off the build, in Improved Thunder Clap")
	local name, rank = TA.Next(tree, ranks, points)
	check(name == "Impale" and rank == 1, "it carries on: Impale, the 19th point, got %s %s", tostring(name),
		tostring(rank))
	-- More ranks than the build puts there.
	ranks = After(points, 10)
	ranks["Tactical Mastery"] = 5
	off, total = TA.Off(ranks, { ["Tactical Mastery"] = 3, ["Improved Heroic Strike"] = 3, ["Improved Rend"] = 2,
		["Improved Charge"] = 2 })
	check(total == 2 and off["Tactical Mastery"] == 2, "two more in a talent than the build puts there")
	-- Every point in Fury instead: the build's first point is still there to take.
	ranks = { ["Cruelty"] = 5, ["Booming Voice"] = 5, ["Unbridled Wrath"] = 1 }
	name = TA.Next(tree, ranks, points)
	check(name == "Improved Heroic Strike", "eleven points elsewhere: back to the build's first, got %s", tostring(name))
	-- A point the tree is not ready for: nothing to take, and what waits.
	local waiting
	name, waiting = TA.Next(tree, {}, { "Mortal Strike" })
	check(name == nil and waiting == "Mortal Strike", "a talent 30 points down waits, got %s %s", tostring(name),
		tostring(waiting))
end

-- A build that doesn't fit the tree -----------------------------------------------

do
	local lev = A.TalentBuilds.WARRIOR.levelling
	UseClass("WARRIOR", Changed("WARRIOR", "Master Strike", nil))
	local ok, why = TA.Fits(TA.ReadTree(), lev)
	check(not ok and why == "it has no Master Strike", "a talent the tree lacks, got %s", tostring(why))
	UseClass("WARRIOR", Changed("WARRIOR", "Cruelty", function(x) x[4] = 3 return x end))
	ok, why = TA.Fits(TA.ReadTree(), lev)
	check(not ok and why == "Cruelty has 3 ranks", "fewer ranks than the build puts there, got %s", tostring(why))
	UseClass("WARRIOR", Changed("WARRIOR", "Mortal Strike", function(x) x[5], x[6] = 5, 3 return x end))
	ok, why = TA.Fits(TA.ReadTree(), lev)
	check(not ok and why == "Mortal Strike can't be learnt where the build puts it",
		"a prerequisite the build skips, got %s", tostring(why))
	check(TA.UnfitLine("Warrior levelling", "it has no Master Strike") == "The Warrior levelling build doesn't fit "
		.. "your talent tree (it has no Master Strike), so the Talent Advisor won't follow it.", "said so in chat")
	ok = TA.Fits(TA.ReadTree(), { order = { "Improved Heroic Strike", 3 } })
	check(not ok, "a build short of 51 points doesn't fit")
end

-- Which build is followed ---------------------------------------------------------

do
	local builds = A.TalentBuilds.WARRIOR
	local fury = TA.SpecBuild(builds, "Fury")
	local lev = builds.levelling
	local full = TA.Targets(TA.Points(lev))
	check(TA.Choose(builds, "auto", fury, 30, After(TA.Points(lev), 21)) == lev, "auto, before 60: levelling")
	local b, ready = TA.Choose(builds, "auto", fury, 60, full)
	check(b == lev and ready, "at 60 with all 51 on it: levelling, and your spec's is ready")
	b, ready = TA.Choose(builds, "auto", fury, 60, After(TA.Points(lev), 50))
	check(b == lev and not ready, "at 60 with the last point to spend: still levelling")
	check(TA.Choose(builds, "auto", fury, 60, {}) == fury, "after a respec at 60: your spec's")
	local elsewhere = Copy(full)
	elsewhere["Booming Voice"] = 2
	check(TA.Choose(builds, "auto", fury, 60, elsewhere) == fury, "at 60 with points off levelling: your spec's")
	check(TA.Choose(builds, "auto", nil, 60, {}) == lev, "no spec known: levelling")
	check(TA.Choose(builds, "levelling", fury, 60, {}) == lev, "levelling chosen: levelling")
	check(TA.Choose(builds, "Protection", fury, 20, {}) == TA.SpecBuild(builds, "Protection"), "a spec chosen: that one")
	check(TA.SpecBuild(A.TalentBuilds.HUNTER, "BeastMastery").spec == "Beast Mastery", "Item Score's BeastMastery")
	check(TA.SpecBuild(A.TalentBuilds.DRUID, "FeralBear").spec == "Feral Combat", "and FeralBear")
	check(TA.SpecBuild(A.TalentBuilds.SHAMAN, "EnhancementTank").spec == "Enhancement", "and EnhancementTank")
	check(TA.ReadyLine("Fury") == "All 51 points are spent. Your Fury build is ready for when you respec: pick it "
		.. "under Following on the talent window to see it.", "the line at 60")
end

-- All of it from the game --------------------------------------------------------

do
	UseClass("DRUID")
	A.ItemScore = { Spec = function() return "FeralCat", "picked" end }
	A.db.char = {}
	local lev = A.TalentBuilds.DRUID.levelling
	local points = TA.Points(lev)
	current.ranks = After(points, 5)
	UnitLevel = function() return 15 end
	UnitCharacterPoints = function() return 1, 0 end
	TA.fit = {}
	local s = TA:State()
	check(s and s.build == lev and s.fits, "a level 15 druid follows the levelling build")
	check(s and s.next == points[6] and s.rank == 1, "its sixth point next, got %s", tostring(s and s.next))
	check(s and s.unspent == 1 and s.offTotal == 0, "one point to spend, none off the build")
	check(A.db.char.talentadvisor == true and A.db.char.talentchat == true and A.db.char.talentbuild == "auto",
		"on to start with, the chat line too, following levelling then your spec")
	-- At 60 after a respec: Feral Combat, the spec Item Score has.
	current.ranks = {}
	UnitLevel = function() return 60 end
	UnitCharacterPoints = function() return 51, 0 end
	s = TA:State()
	check(s and s.build.spec == "Feral Combat" and s.next == TA.Points(s.build)[1],
		"at 60 after a respec: your spec's build, from its first point")
	-- A tree it doesn't fit.
	UseClass("DRUID", Changed("DRUID", "Ferocity", nil))
	TA.fit = {}
	s = TA:State(nil, 15, 1)
	check(s and not s.fits and s.why == "it has no Ferocity" and s.next == nil, "a tree it doesn't fit: why, and no point")
	TA.fit = {}
end

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("TalentAdvisor: %d checks", checks))
if table.getn(failures) == 0 then
	print("All talent advisor checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
