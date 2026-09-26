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

-- Pointing -------------------------------------------------------------------

--[[ Our arrow's bearing. What went wrong in game: TomTom's Astrolabe, when it
	cannot place the player in a zone, leaves the hidden world map on the
	continent view. The map then reports a position but zone 0, and our
	same-zone code read that as "the waypoint is in another zone" and hid,
	while TomTom's arrow -- through Astrolabe -- kept pointing. ]]
db.waypointprovider = "tomtom"
AegisPathfinder:SetArrowMode("pathfinder")
check(AegisPathfinder.waypointtarget ~= nil, "the step has a waypoint to point at")

GetPlayerFacing = function() return 0 end        -- facing north
local mapZone, mapReset = 0, false               -- left on the continent view
GetCurrentMapContinent = function() return 1 end
GetCurrentMapZone = function() return mapZone end
GetPlayerMapPosition = function() return 0.4, 0.4 end
SetMapToCurrentZone = function() mapZone, mapReset = 2, true end

-- TomTom-TWOW's Astrolabe: the player in another zone of the continent, the
-- waypoint 300 yd east and 400 yd north of them.
Astrolabe = {
	GetCurrentPlayerPosition = function() return 1, 1, 0.9, 0.9 end,
	ComputeDistance = function() return 500, 300, -400 end,
}
local bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(bearing ~= nil, "with the map on the continent view it still points (%s)", tostring(why))
check(bearing and math.abs(bearing - math.atan2(300, 400)) < 1e-6,
	"towards the waypoint, got %s", tostring(bearing))
check(yards == 500, "measured in yards by Astrolabe, got %s", tostring(yards))
check(not mapReset, "and without yanking the player's map about")

-- A zone Astrolabe has no dimensions for comes back 0, 0, 0: unknown, not
-- "standing on it". Fall back rather than point straight ahead at 0 yd.
Astrolabe.ComputeDistance = function() return 0, 0, 0 end
mapZone, mapReset = 0, false
bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(mapReset, "an unknown zone falls back to the map, re-centring it off the continent view")
check(bearing ~= nil and yards == nil,
	"which points in the same zone without claiming a distance (%s)", tostring(why))

-- Without Astrolabe: same zone only, and a continent-view map is re-centred
-- rather than read as another zone.
Astrolabe = nil
mapZone, mapReset = 0, false
bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(mapReset and bearing ~= nil, "without Astrolabe it re-centres the map and points (%s)", tostring(why))
SetMapToCurrentZone = function() mapZone = 1 end     -- the player really is elsewhere
mapZone = 0
bearing, yards, why = AegisPathfinder:GetWaypointBearing()
check(bearing == nil and string.find(why or "", "another zone", 1, true),
	"and in another zone it hides, saying why, got '%s'", tostring(why))

-- The waypoint addon's arrow ------------------------------------------------------------

--[[ crazy = false keeps TomTom's arrow off our waypoint when it is added, but
	TomTom-TWOW's GoToNextWayPoint -- when its arrow's target is reached or
	cleared, or on resurrection -- hands the arrow to the last waypoint in its
	list, ours included. The Arrow setting takes it back. ]]
function TomTom:ClearCrazyArrow() self.active_waypoint = nil end
local ours = TomTom.waypoints[table.getn(TomTom.waypoints)]
TomTom.active_waypoint = ours                     -- GoToNextWayPoint's doing
AegisPathfinder:EnforceArrowMode()
check(TomTom.active_waypoint == nil, "set to Pathfinder's, TomTom's arrow is taken off our waypoint")

local theirs = { title = "The player's own waypoint" }
TomTom.active_waypoint = theirs
AegisPathfinder:EnforceArrowMode()
check(TomTom.active_waypoint == theirs, "but never off a waypoint the player made themselves")

AegisPathfinder:SetArrowMode("both")
TomTom.active_waypoint = ours
AegisPathfinder:EnforceArrowMode()
check(TomTom.active_waypoint == ours, "and with Both it is left pointing")

-- Trainers by name, from pfQuest ---------------------------------------------------

--[[ Profession steps name who to go to but carry no coordinates; the names
	are looked up in pfQuest's unit database. Here: two Expert enchanting
	trainers, one inside a dungeon the world map cannot show. ]]
pfDB = {
	zones = { loc = { [12] = "Elwynn Forest", [1] = "Dun Morogh", [1337] = "Uldaman" } },
	units = {
		loc = { [11072] = "Kitta Firewind", [7406] = "Annora", [5] = "Tomas", [6] = "Cook Ghilm" },
		data = {
			[11072] = { coords = { { 64.5, 69.5, 12, 0 } } },
			[7406]  = { coords = { { 38.0, 70.0, 1337, 0 } } },
			[5]     = { coords = { { 44.0, 66.0, 12, 0 } } },
			[6]     = { coords = { { 68.0, 54.0, 1, 0 } } },
		},
	},
}
db.waypointprovider = "tomtom"
AegisPathfinder:ClearWaypoint()
check(AegisPathfinder:MapNearestNPC({ "Annora", "Kitta Firewind" }, "Train Expert Enchanting"),
	"a trainer is found by name")
local wpt = AegisPathfinder.waypointtarget
check(wpt and wpt.zoneindex == 2 and wpt.x == 64.5,
	"the one the map can show -- Kitta in Elwynn, not Annora inside Uldaman")
check(TomTom.waypoints[table.getn(TomTom.waypoints)].title
	== "Pathfinder: Train Expert Enchanting (Kitta Firewind)",
	"and the waypoint says who, got '%s'", tostring(TomTom.waypoints[table.getn(TomTom.waypoints)].title))

-- The nearest of several, measured by Astrolabe.
Astrolabe = {
	GetCurrentPlayerPosition = function() return 1, 1, 0.5, 0.5 end,      -- in Dun Morogh
	ComputeDistance = function(_, c1, z1, x1, y1, c2, z2) return z2 == 1 and 300 or 2000, 1, 1 end,
}
AegisPathfinder:ClearWaypoint()
AegisPathfinder:MapNearestNPC({ "Tomas", "Cook Ghilm" }, "Learn Cooking")
check(AegisPathfinder.waypointtarget and AegisPathfinder.waypointtarget.zoneindex == 1,
	"the nearest trainer is chosen -- Cook Ghilm in Dun Morogh, 300 yd, over Tomas")

check(not AegisPathfinder:MapNearestNPC({ "Nobody Atall" }, "Train"),
	"a name pfQuest does not know sends nothing")

-- A step's NPCs are mapped when its note has no coordinates.
AegisPathfinder:ClearWaypoint()
AegisPathfinder:ParseAndMapCoords(nil, "TRAIN", "Needs skill 125.", "Train Expert Enchanting",
	nil, { "Kitta Firewind" })
check(AegisPathfinder.waypointtarget and AegisPathfinder.waypointtarget.x == 64.5,
	"a training step with no coordinates gets its trainer's")

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
