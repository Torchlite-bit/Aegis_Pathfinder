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
	what is off the build, the lines it says, and the chat on a level up.
	TalentWindow.lua draws it on Blizzard's talent window.
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
	-- No talents read (the client has not sent them yet): nothing to say,
	-- rather than a build found not to fit for the rest of the session.
	if not next(tree.talent) then return nil end
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
		unspent = unspent, fits = fit.ok, why = fit.why, builds = builds, choice = s.talentbuild }
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
	if build == builds.levelling then return (className or "Class") .. " leveling" end
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

local function Points(n) return n .. (n == 1 and " point" or " points") end

--- The name of the build followed now: "Warrior leveling", "Fury at 60".
function TA:Label(state)
	return TA.BuildLabel(state.builds, state.build, (UnitClass("player")))
end

--- What "Leveling, then my spec at 60" says now: your spec by name, and
--- at 60 which of the two it is following.
function TA.AutoLabel(state, preferred)
	if not preferred then return "Leveling, then my spec at 60" end
	if not state or state.choice ~= "auto" or (state.level or 0) < 60 then
		return "Leveling, then " .. preferred.spec .. " at 60"
	end
	if state.build == state.builds.levelling then return "Leveling (done), then " .. preferred.spec end
	return preferred.spec .. ", my spec"
end

--- "Build to follow", as a dropdown's items: levelling then your spec, the
--- levelling build, and each spec's build at 60, yours marked.
function TA:BuildItems(state)
	local builds = state and state.builds or self:ClassBuilds()
	if not builds then return {} end
	local preferred = self:PreferredBuild(builds)
	local items = {
		{ value = "auto", label = TA.AutoLabel(state, preferred) },
		{ value = "levelling", label = ((UnitClass("player")) or "Class") .. " leveling" },
	}
	for _, b in ipairs(builds.specs) do
		table.insert(items, { value = b.spec, label = b.spec .. " at 60" .. (b == preferred and " (my spec)" or "") })
	end
	return items
end

--- What the strip over the talent window says: where the next point goes,
--- and how many points are off the build (or why the build is not
--- followed). Returns the line and the warning, either may be nil.
function TA:StripLines(state)
	if not state.fits then return nil, TA.UnfitLine(self:Label(state), state.why) end
	local line
	local preferred = self:PreferredBuild(state.builds)
	local t = state.next and state.tree.talent[state.next]
	if state.ready and preferred then
		line = "All 51 points spent. Your " .. preferred.spec .. " build is ready for when you respec."
	elseif state.waiting then
		line = state.waiting .. " needs more points in its tree first."
	elseif not t then
		line = "Every point of this build is spent."
	elseif state.unspent > 0 then
		line = "Next: " .. state.next .. ", rank " .. state.rank .. " of " .. t.max
			.. (state.unspent > 1 and " (" .. state.unspent .. " points to spend)" or "")
	elseif state.level < 60 then
		line = "Your point at level " .. (state.level + 1) .. " goes to " .. state.next .. "."
	else
		line = "Next, after a respec: " .. state.next .. "."
	end
	local warn
	if (state.offTotal or 0) > 0 then
		warn = Points(state.offTotal) .. " off the build. It carries on from the closest point."
	end
	return line, warn
end

--- How a talent is marked on the window: "todo" with the points the build
--- puts there, "done" once you have them all, "off" with the points you
--- have past them; nil for a talent the build leaves alone. And whether
--- the next point goes there.
function TA.Mark(state, name)
	local have, want = state.ranks[name] or 0, state.targets[name] or 0
	local kind, text
	if have > want then
		kind, text = "off", "+" .. (have - want)
	elseif want > 0 then
		kind, text = have >= want and "done" or "todo", tostring(want)
	end
	return kind, text, state.next == name
end

--- The advisor's lines on a talent's tooltip.
function TA:TipLines(state, name)
	local lines = {}
	local have, want = state.ranks[name] or 0, state.targets[name] or 0
	local label = self:Label(state)
	if want > 0 then
		local line = label .. " puts " .. Points(want) .. " here"
		if have > want then line = line .. "; you have " .. have
		elseif have == want then line = line .. ": done" end
		table.insert(lines, "Pathfinder: " .. line .. ".")
	elseif have > 0 then
		table.insert(lines, "Pathfinder: " .. label .. " puts no points here.")
	end
	if state.next == name then table.insert(lines, "Your next point goes here.") end
	return lines
end

--[[ Chat ------------------------------------------------------------------------ ]]

-- Builds already said not to fit, this session: once is enough.
TA.warned = {}

--- Say once a session that a build does not fit the tree. A warning, so it
--- shows with Pathfinder's chat messages off.
function TA:WarnUnfit(state)
	if TA.warned[state.build] then return end
	TA.warned[state.build] = true
	local c = AegisPathfinder.Theme and AegisPathfinder.Theme:Code("goldDeep") or ""
	AegisPathfinder:Print(c .. TA.UnfitLine(self:Label(state), state.why) .. "|r")
end

--- On a level up: the talent to take with the new point. `level` is the
--- event's; the point may not be counted yet, so there is at least one.
function TA:LevelUp(level)
	local s = self:Settings()
	if not (s and s.talentadvisor and level and level >= TA.FIRST_LEVEL) then return end
	local state = self:State(nil, level, math.max(1, (UnitCharacterPoints("player")) or 0))
	if not state then return end
	if not state.fits then return self:WarnUnfit(state) end
	if s.talentchat == false or not state.next then return end
	local t = state.tree.talent[state.next]
	AegisPathfinder:Say(TA.LevelLine(level, state.next, state.rank, t.max, state.tree.tabs[t.tab].name))
end

--- When points are spent or given: at 60 with all 51 on the levelling
--- build, say once that your spec's is ready; a respec says it again later.
function TA:PointsChanged()
	local s = self:Settings()
	if not (s and s.talentadvisor) then return end
	local state = self:State()
	if not (state and state.fits) then return end
	if not state.ready then
		s.talentready = nil
		return
	end
	if s.talentready then return end
	s.talentready = true
	local preferred = self:PreferredBuild(state.builds)
	if preferred then AegisPathfinder:Say(TA.ReadyLine(preferred.spec)) end
end

--- Draw the talent window again, if it is open: the settings changed.
function TA:Refresh()
	if TA.Window then TA.Window:Repaint() end
end

-- Registered as the file loads; until the settings are there they are let go.
local events = CreateFrame("Frame")
TA.events = events
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:SetScript("OnEvent", function()
	if not AegisPathfinder.db then return end
	if event == "PLAYER_LEVEL_UP" then
		TA:LevelUp(tonumber(arg1))
	else
		TA:PointsChanged()
	end
end)
