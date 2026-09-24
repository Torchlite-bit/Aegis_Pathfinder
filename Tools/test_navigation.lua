--[[
	Tests for the waypoint providers and the arrow setting.

	The fake TomTom below behaves as TomTom-TWOW (github.com/laytya/TomTom-TWOW)
	does where it matters here:

	  - AddMFWaypoint fills a nil `crazy` from its own "autoqueue" setting,
	    which defaults on, so leaving it out aims TomTom's arrow anyway;
	  - LoadWayPoint only uses its default callbacks -- the ones behind the
	    map and minimap pins' tooltips and click menu -- when the waypoint
	    brings none of its own;
	  - RemoveWaypoint clears the arrow if it was pointing at that waypoint.

	Run:  lua5.1 Tools/test_navigation.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

GetLocale = function() return "enUS" end
GetMapContinents = function() return "Eastern Kingdoms" end
GetMapZones = function() return "Dun Morogh", "Elwynn Forest" end
IsAddOnLoaded = function() return false end
WorldMapFrame = CreateFrame("Frame", nil, UIParent)
WorldMapFrame:Hide()

AegisPathfinder = { db = { char = { waypointprovider = "auto" }, profile = {} } }
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder:SetTurnedIn() end
function AegisPathfinder:GetObjectiveInfo() return nil end
function AegisPathfinder:UpdateNavCallout() end

dofile("Locale.lua")
AegisPathfinder.Locale = AEGISPATHFINDER_LOCALE
dofile("Navigation.lua")

-- TomTom-TWOW, as far as these tests reach into it.
local DEFAULT_CALLBACKS = { minimap = { tooltip_show = "pin tooltip" }, world = { tooltip_show = "map tooltip" } }
TomTom = { waypoints = {}, autoqueue = true }
function TomTom:DefaultCallbacks()
	return { minimap = DEFAULT_CALLBACKS.minimap, world = DEFAULT_CALLBACKS.world }
end
function TomTom:AddMFWaypoint(c, z, x, y, opts)
	if opts.crazy == nil then opts.crazy = self.autoqueue end
	local uid = { continent = c, zone = z, x = x, y = y, title = opts.title,
		crazy = opts.crazy, callbacks = opts.callbacks }
	table.insert(self.waypoints, uid)
	if uid.crazy then self.active_waypoint = uid end
	if not uid.callbacks then uid.callbacks = self:DefaultCallbacks() end
	return uid
end
function TomTom:RemoveWaypoint(uid)
	for k, w in ipairs(self.waypoints) do
		if w == uid then table.remove(self.waypoints, k) break end
	end
	if self.active_waypoint == uid then self.active_waypoint = nil end
end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local db = AegisPathfinder.db.char
local function travel()
	-- A RUN step with coordinates in its note: a waypoint, and an arrival
	-- callback that completes the step.
	AegisPathfinder:ParseAndMapCoords(nil, "RUN", "Head for Goldshire (42.1, 65.3)",
		"Goldshire", "Elwynn Forest")
	return TomTom.waypoints[table.getn(TomTom.waypoints)]
end

-- Pathfinder's arrow alone, the default -------------------------------------------

check(AegisPathfinder:GetArrowMode() == "pathfinder", "ours alone by default, got %s",
	AegisPathfinder:GetArrowMode())
local wp = travel()
check(wp ~= nil, "the step's waypoint still goes to TomTom")
check(wp and wp.crazy == false,
	"but TomTom's arrow is told no outright -- left nil, its autoqueue would aim it anyway")
check(TomTom.active_waypoint == nil, "so TomTom's arrow is not pointing at it")
check(AegisPathfinder.waypointtarget and AegisPathfinder.waypointtarget.x == 42.1,
	"while ours still has the waypoint to point at")
check(wp and wp.title == "Pathfinder: Goldshire",
	"titled for this addon, not the old TurtleGuide [TG] tag, got '%s'", tostring(wp and wp.title))

-- The pins keep TomTom's own tooltips and menus.
check(wp and wp.callbacks.minimap == DEFAULT_CALLBACKS.minimap
	and wp.callbacks.world == DEFAULT_CALLBACKS.world,
	"a travel step's pins keep TomTom's tooltip and click menu")
check(wp and wp.callbacks.distance and wp.callbacks.distance[15],
	"and add the arrival callback that completes the step")

-- Both -----------------------------------------------------------------------------

-- SetArrowMode re-sends the current step; stand in for the engine.
function AegisPathfinder:ForceWaypointUpdate() travel() end
AegisPathfinder:SetArrowMode("both")
wp = TomTom.waypoints[table.getn(TomTom.waypoints)]
check(table.getn(TomTom.waypoints) == 1, "changing the setting replaces the waypoint rather than adding one")
check(TomTom.active_waypoint == wp and wp.crazy == true, "Both aims TomTom's arrow at it")
check(db.shownavcallout == true, "and keeps ours")

-- And back: TomTom lets it go.
AegisPathfinder:SetArrowMode("pathfinder")
check(TomTom.active_waypoint == nil, "switching back takes TomTom's arrow off our waypoint")

-- pfQuest ----------------------------------------------------------------------------

local nodes, target = {}, nil
pfMap = {
	AddNode = function(_, meta) table.insert(nodes, meta) end,
	DeleteNode = function() nodes = {} end,
	GetMapIDByName = function() return 12 end,
}
pfQuest = { route = {
	SetTarget = function(t) target = t end,
	IsTarget = function(t) return target and t and target.title == t.title end,
} }
db.waypointprovider = "pfquest"
AegisPathfinder:SetArrowMode("pathfinder")
check(table.getn(nodes) == 1 and nodes[1].arrow == false,
	"pfQuest gets the pin without its arrow flag")
check(target == nil, "and its arrow is not aimed at it")
AegisPathfinder:SetArrowMode("provider")
check(nodes[table.getn(nodes)].arrow == true and target ~= nil,
	"the waypoint addon's arrow aims pfQuest's")
check(db.shownavcallout == false, "and turns ours off")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Navigation: %d checks", checks))
if table.getn(failures) == 0 then
	print("All navigation checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
