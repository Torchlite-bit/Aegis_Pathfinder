--[[ TalentAdvisor.lua -- the Talent Advisor: which talent each point goes to.

	Two builds a character: the levelling build for your class, followed
	until 60, then the build for your preferred spec -- the one picked on the
	Item Score page -- or whichever you choose. The builds are data, by
	talent name (TalentBuilds.lua, written by Tools/build/talent_builds.py),
	and each is checked against the tree the game has before it is followed:
	one that does not fit says so and is not followed.

	It only recommends; it never spends a point. Points spent where the build
	puts none (or more than it puts) are "off the build", and it carries on
	from the build's closest point. It never says to respec: at 60, with
	every point on the levelling build, it says your spec's build is ready
	for when you do.

	This is the engine: reading the tree, choosing the build, the next point,
	what is off the build, and the lines it says.
]]

local AegisPathfinder = AegisPathfinder

local TA = {}
AegisPathfinder.TalentAdvisor = TA

-- Points by 60: one a level from 10.
TA.POINTS = 51
TA.FIRST_LEVEL = 10

-- Item Score's specs that are not a talent tree's name.
local SPEC_TREE = {
	BeastMastery = "Beast Mastery",
	FeralCat = "Feral Combat", FeralBear = "Feral Combat",
	EnhancementTank = "Enhancement",
}

local function Char() return AegisPathfinder.db and AegisPathfinder.db.char end

--- The advisor's settings for this character: on, the build to follow
--- ("auto": levelling until 60, then your spec's), and the chat line.
function TA:Settings()
	local char = Char()
	if not char then return nil end
	if char.talentadvisor == nil then char.talentadvisor = true end
	if char.talentchat == nil then char.talentchat = true end
	char.talentbuild = char.talentbuild or "auto"
	return char
end

--[[ Builds ----------------------------------------------------------------------- ]]

--- A build's order -- talent, rank, talent, rank, ... -- as its points, one
--- talent name a point.
function TA.Expand(order)
	local points, have = {}, {}
	for i = 1, table.getn(order), 2 do
		local name, upto = order[i], order[i + 1]
		for _ = (have[name] or 0) + 1, upto do table.insert(points, name) end
		if upto > (have[name] or 0) then have[name] = upto end
	end
	return points
end

--- How many points each talent gets: { talent = ranks }.
function TA.Targets(points)
	local t = {}
	for _, name in ipairs(points) do t[name] = (t[name] or 0) + 1 end
	return t
end

--- A build's points, worked out once.
function TA.Points(build)
	if not build.points then build.points = TA.Expand(build.order) end
	return build.points
end

--- The builds for a class (a token: "WARRIOR").
function TA:ClassBuilds(class)
	if not class then
		local _
		_, class = UnitClass("player")
	end
	return AegisPathfinder.TalentBuilds and AegisPathfinder.TalentBuilds[class]
end

--- A class's build at 60 for a spec, by its tree's name or Item Score's.
function TA.SpecBuild(builds, spec)
	if not (builds and spec) then return nil end
	spec = SPEC_TREE[spec] or spec
	for _, b in ipairs(builds.specs) do
		if b.spec == spec then return b end
	end
	return nil
end

--- Your preferred spec's build: the spec picked on the Item Score page, or
--- the one it works out from your talents.
function TA:PreferredBuild(builds)
	local IS = AegisPathfinder.ItemScore
	local spec = IS and IS.Spec and IS:Spec()
	return TA.SpecBuild(builds, spec)
end

--[[ The tree --------------------------------------------------------------------- ]]

--- The tree the game has, read from the talent API: { tabs = { { name,
--- talents } }, talent = { name -> { name, tab, index, tier, column, max,
--- rank, pre } } }. A talent's prerequisite is the one the client names
--- first, by name.
function TA.ReadTree()
	local tree = { tabs = {}, talent = {} }
	for tab = 1, (GetNumTalentTabs and GetNumTalentTabs() or 0) do
		local tabName = GetTalentTabInfo(tab)
		local at, list = {}, {}
		for i = 1, GetNumTalents(tab) do
			local name, _, tier, column, rank, maxRank = GetTalentInfo(tab, i)
			if name then
				local t = { name = name, tab = tab, index = i, tier = tier, column = column,
					rank = rank or 0, max = maxRank or 1 }
				t.preTier, t.preColumn = GetTalentPrereqs(tab, i)
				at[tier .. ":" .. column] = t
				tree.talent[name] = t
				table.insert(list, t)
			end
		end
		for _, t in ipairs(list) do
			local p = t.preTier and at[t.preTier .. ":" .. t.preColumn]
			t.pre = p and p.name or nil
		end
		tree.tabs[tab] = { name = tabName, talents = list }
	end
	return tree
end

--- The ranks you have: { talent = rank }, only those with a point.
function TA.Ranks(tree)
	local ranks = {}
	for name, t in pairs(tree.talent) do
		if t.rank > 0 then ranks[name] = t.rank end
	end
	return ranks
end

function TA.Total(ranks)
	local n = 0
	for _, r in pairs(ranks) do n = n + r end
	return n
end

--- Points spent in one tree.
function TA.Spent(tree, ranks, tab)
	local n = 0
	for name, r in pairs(ranks) do
		local t = tree.talent[name]
		if t and t.tab == tab then n = n + r end
	end
	return n
end

--- Whether a talent can take another point now: ranks left, 5 points in its
--- tree a row above it, its prerequisite at full rank.
function TA.CanLearn(tree, ranks, name)
	local t = tree.talent[name]
	if not t or (ranks[name] or 0) >= t.max then return false end
	if TA.Spent(tree, ranks, t.tab) < 5 * (t.tier - 1) then return false end
	if t.pre and (ranks[t.pre] or 0) < tree.talent[t.pre].max then return false end
	return true
end

--- Whether a build fits the tree: every talent in it, no more ranks than it
--- has, each point learnable in its order, and 51 of them. Returns true, or
--- false and why ("it has no Master Strike").
function TA.Fits(tree, build)
	local ranks = {}
	local points = TA.Points(build)
	for _, name in ipairs(points) do
		local t = tree.talent[name]
		if not t then return false, "it has no " .. name end
		if (ranks[name] or 0) >= t.max then
			return false, name .. " has " .. t.max .. (t.max == 1 and " rank" or " ranks")
		end
		if not TA.CanLearn(tree, ranks, name) then
			return false, name .. " can't be learnt where the build puts it"
		end
		ranks[name] = (ranks[name] or 0) + 1
	end
	if table.getn(points) ~= TA.POINTS then
		return false, "it has " .. table.getn(points) .. " points, not " .. TA.POINTS
	end
	return true
end

--[[ Following a build ------------------------------------------------------------- ]]

--- The next point: the build's first point you do not have that you can
--- learn now. With points off the build a later point may come first, as
--- the closest one you can take. Returns the talent and the rank it goes
--- to; or nil and the talent that is waiting for more points in its tree.
function TA.Next(tree, ranks, points)
	local seen, waiting = {}, nil
	for _, name in ipairs(points) do
		seen[name] = (seen[name] or 0) + 1
		if seen[name] > (ranks[name] or 0) then
			waiting = waiting or name
			if TA.CanLearn(tree, ranks, name) then return name, (ranks[name] or 0) + 1 end
		end
	end
	return nil, waiting
end

--- The points you have that the build does not put there: { talent =
--- extra }, and how many in all.
function TA.Off(ranks, targets)
	local off, total = {}, 0
	for name, r in pairs(ranks) do
		local extra = r - (targets[name] or 0)
		if extra > 0 then
			off[name] = extra
			total = total + extra
		end
	end
	return off, total
end

--- The build to follow. `choice` is "auto", "levelling" or a spec's name.
--- Auto follows the levelling build until 60, and at 60 while every point
--- you have is on it (then `ready` is true once all 51 are spent); after a
--- respec, or with points elsewhere, your preferred spec's.
function TA.Choose(builds, choice, preferred, level, ranks)
	if not builds then return nil end
	if choice == "levelling" then return builds.levelling end
	if choice and choice ~= "auto" then
		local b = TA.SpecBuild(builds, choice)
		if b then return b end
	end
	local lev = builds.levelling
	if not preferred or (level or 0) < 60 then return lev end
	local total = TA.Total(ranks)
	local _, off = TA.Off(ranks, TA.Targets(TA.Points(lev)))
	if total > 0 and off == 0 then return lev, total >= TA.POINTS end
	return preferred
end

-- What each build was found to be against the tree, for this session:
-- build -> { ok, why }. The tree does not change while you play.
TA.fit = {}

--- Everything the window and chat need, now: the build, whether it fits,
--- the next point, the targets, what is off the build, points to spend.
--- `tree`, `level` and `unspent` default to the game's.
function TA:State(tree, level, unspent)
	local s = self:Settings()
	local builds = self:ClassBuilds()
	if not (s and builds) then return nil end
	tree = tree or TA.ReadTree()
	level = level or UnitLevel("player")
	if not unspent then unspent = (UnitCharacterPoints("player")) or 0 end
	local ranks = TA.Ranks(tree)
	local build, ready = TA.Choose(builds, s.talentbuild, self:PreferredBuild(builds), level, ranks)
	if not build then return nil end
	local fit = TA.fit[build]
	if not fit then
		local ok, why = TA.Fits(tree, build)
		fit = { ok = ok, why = why }
		TA.fit[build] = fit
	end
	local state = { tree = tree, ranks = ranks, build = build, ready = ready, level = level,
		unspent = unspent, fits = fit.ok, why = fit.why, builds = builds }
	if not fit.ok then return state end
	local points = TA.Points(build)
	state.targets = TA.Targets(points)
	state.off, state.offTotal = TA.Off(ranks, state.targets)
	state.next, state.rank = TA.Next(tree, ranks, points)
	if not state.next then state.waiting = state.rank; state.rank = nil end
	return state
end

--[[ What it says ------------------------------------------------------------------ ]]

--- A build's name, as the window's menu and chat give it.
function TA.BuildLabel(builds, build, className)
	if build == builds.levelling then return (className or "Class") .. " levelling" end
	return build.spec .. " at 60"
end

--- On a level up with a point to spend.
function TA.LevelLine(level, talent, rank, max, treeName)
	return string.format("Level %d: a talent point to spend. Take %s (rank %d of %d) in %s.",
		level, talent, rank, max, treeName)
end

--- At 60 with all 51 points on the levelling build.
function TA.ReadyLine(spec)
	return "All 51 points are spent. Your " .. spec .. " build is ready for when you respec: "
		.. "pick it under Following on the talent window to see it."
end

--- When a build does not fit the tree the game has.
function TA.UnfitLine(label, why)
	return "The " .. label .. " build doesn't fit your talent tree (" .. why
		.. "), so the Talent Advisor won't follow it."
end
