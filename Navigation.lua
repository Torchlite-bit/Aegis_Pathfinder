-- Navigation.lua
-- Waypoint routing for AegisPathfinder.
--
-- Guides describe locations as a zone name plus map coordinates in 0-100 space.
-- Each supported waypoint addon is wrapped in a provider that translates those
-- into its own format, so nothing outside this file talks to TomTom (or any
-- other waypoint addon) directly.

local L = AegisPathfinder.Locale

local function HasMetaMap()
	return IsAddOnLoaded("MetaMap") and MetaMap_NameToZoneID and MetaMap_GetCurrentMapInfo
end

local function HasMetaMapNotes()
	return HasMetaMap() and MetaMapNotes_AddNewNote
end

local function HasMetaMapBWP()
	return HasMetaMap() and BWP_ClearDest and BWP_DisplayFrame and BWPDistanceText and BWPDestText
end

local function EnsureMetaMapBWP()
	if not HasMetaMap() then return false end
	if not IsAddOnLoaded("MetaMapBWP") then
		LoadAddOn("MetaMapBWP")
	end
	if IsAddOnLoaded("MetaMapBWP") and MetaMap_LoadBWP then
		MetaMap_LoadBWP(0, 3)
	end
	return HasMetaMapBWP()
end

local zonei, zonec, zonenames = {}, {}, {}
for ci, c in pairs{GetMapContinents()} do
	zonenames[ci] = {GetMapZones(ci)}
	for zi, z in pairs(zonenames[ci]) do
		zonei[z], zonec[z] = zi, ci
	end
end

--------------------------------------------------------------------------------
--                            Waypoint providers                              --
--------------------------------------------------------------------------------

-- A provider is { label, IsAvailable(), Add(wp), Clear() }, where wp is
--   { zone, continent, zoneindex, x, y, title, description, onArrival, arrow }
-- `arrow` says whether the provider's own arrow should point at this
-- waypoint (see GetArrowMode). A provider whose waypoint *is* its arrow --
-- Cartographer, MetaMap BWP -- marks itself `arrowIsWaypoint` and ignores it.
-- x and y are map coordinates in 0-100 space. Add() returns true when it
-- actually created a waypoint. Clear() removes everything that provider created
-- and must be safe to call when it holds nothing.
local providers = {}

-- Preference order for "auto". TomTom leads because it is the only backend here
-- that can point at a target outside the zone the player is standing in.
local providerorder = { "tomtom", "pfquest", "cartographer", "metamapbwp", "metamap" }

-- TomTom ----------------------------------------------------------------------

local tomtomuids = {}

providers.tomtom = {
	label = "TomTom",

	IsAvailable = function()
		return TomTom and TomTom.AddMFWaypoint and true or nil
	end,

	Add = function(wp)
		-- `crazy` is TomTom's arrow. Left nil, TomTom falls back to its own
		-- "autoqueue" setting, so it is always said outright.
		local opts = { title = wp.title, crazy = wp.arrow and true or false, silent = true }

		--[[ Arrival callback for travel objectives.

			A waypoint's callbacks replace TomTom's defaults rather than add
			to them (TomTom-TWOW's LoadWayPoint only fills them in when there
			are none), and the defaults are what give its map and minimap
			pins their tooltip and click menu. So start from the defaults. ]]
		if wp.onArrival then
			opts.callbacks = TomTom.DefaultCallbacks and TomTom:DefaultCallbacks() or {}
			opts.callbacks.distance = {
				[15] = function(event, uid, dist, lastdist)
					AegisPathfinder:Debug("TomTom arrival callback triggered")
					wp.onArrival()
				end
			}
		end

		AegisPathfinder:Debug(string.format("TomTom waypoint: c=%d z=%d x=%.2f y=%.2f title=%s",
			wp.continent, wp.zoneindex, wp.x / 100, wp.y / 100, wp.title))

		local uid = TomTom:AddMFWaypoint(wp.continent, wp.zoneindex, wp.x / 100, wp.y / 100, opts)
		if not uid then return end

		table.insert(tomtomuids, uid)
		return true
	end,

	Clear = function()
		for i = table.getn(tomtomuids), 1, -1 do
			if TomTom.RemoveWaypoint then
				TomTom:RemoveWaypoint(tomtomuids[i])
			end
			table.remove(tomtomuids, i)
		end
	end,
}

-- pfQuest ---------------------------------------------------------------------

-- pfQuest draws map/minimap pins from pfMap.nodes and feeds its route planner
-- and on-screen arrow from any node whose meta carries arrow = true.
--
-- The texture is one of pfQuest's own icons so that the node layer pfMap derives
-- from it is a known value (map.lua `layers`: img\fav is 6). pfQuest.route
-- identifies its arrow target by title + texture + layer + cluster, so the layer
-- passed to SetTarget has to match the one pfMap:UpdateNode() computes.
local PFQUEST_ADDON = "AEGISPATHFINDER"
local PFQUEST_LAYER = 6
local pfquesttitle

local function PfQuestTexture()
	return ((pfQuestConfig and pfQuestConfig.path) or "Interface\\AddOns\\pfQuest") .. "\\img\\fav"
end

providers.pfquest = {
	label = "pfQuest",

	IsAvailable = function()
		return pfMap and pfMap.AddNode and pfQuest and pfQuest.route and true or nil
	end,

	Add = function(wp)
		-- pfQuest keys nodes by area id, not by the world map's zone index
		local map = pfMap:GetMapIDByName(wp.zone)
		if not map then
			AegisPathfinder:Debug("pfQuest has no map id for zone " .. (wp.zone or "nil"))
			return
		end

		local texture = PfQuestTexture()
		AegisPathfinder:Debug(string.format("pfQuest node: map=%d x=%.2f y=%.2f title=%s",
			map, wp.x, wp.y, wp.title))

		pfMap:AddNode({
			addon = PFQUEST_ADDON,
			zone = map,
			x = wp.x,
			y = wp.y,
			title = wp.title,
			-- pfMap:UpdateNode() only copies meta onto a pin when spawn is set
			spawn = wp.title,
			spawntype = "Waypoint",
			description = wp.description,
			texture = texture,
			arrow = wp.arrow and true or false,
		})

		-- Aim the pfQuest arrow at this node rather than at whichever quest
		-- objective happens to be nearest -- when its arrow is wanted at all.
		pfquesttitle = wp.title
		if wp.arrow then
			pfQuest.route.SetTarget({ title = wp.title, texture = texture, layer = PFQUEST_LAYER })
		end

		-- Re-stamp the refresh request: SetTarget clobbers queue_update, and
		-- older pfQuest builds put a boolean there, which breaks pfMap's
		-- timestamp debounce. This is what pfMap:NodeClick() does as well.
		pfMap.queue_update = GetTime()
		return true
	end,

	Clear = function()
		if not pfquesttitle then return end

		pfMap:DeleteNode(PFQUEST_ADDON)

		-- Only drop the arrow target if it is still ours; the player may have
		-- clicked a pfQuest node in the meantime.
		if pfQuest.route.IsTarget({ title = pfquesttitle, texture = PfQuestTexture(), layer = PFQUEST_LAYER }) then
			pfQuest.route.SetTarget(nil)
		end
		pfquesttitle = nil
	end,
}

-- Cartographer ----------------------------------------------------------------

local cartographerids = {}

providers.cartographer = {
	label = "Cartographer",
	arrowIsWaypoint = true,

	IsAvailable = function()
		return Cartographer_Waypoints and true or nil
	end,

	Add = function(wp)
		local pt = NotePoint:new(wp.zone, wp.x / 100, wp.y / 100, wp.title)
		Cartographer_Waypoints:AddWaypoint(pt)
		table.insert(cartographerids, pt.WaypointID)
		return true
	end,

	Clear = function()
		for i = table.getn(cartographerids), 1, -1 do
			Cartographer_Waypoints:CancelWaypoint(table.remove(cartographerids, i))
		end
	end,
}

-- MetaMap ---------------------------------------------------------------------

local metamapnotes = {}

providers.metamapbwp = {
	label = "MetaMap BWP",
	arrowIsWaypoint = true,

	IsAvailable = function()
		return HasMetaMap() and (HasMetaMapBWP() or MetaMap_LoadBWP) and true or nil
	end,

	Add = function(wp)
		if not EnsureMetaMapBWP() then return end
		local zid = MetaMap_NameToZoneID(wp.zone) or MetaMap_GetCurrentMapInfo()
		BWP_ClearDest()
		BWP_AddDestination(wp.title, zid, wp.x / 100, wp.y / 100, true, true)
		return true
	end,

	Clear = function()
		if HasMetaMapBWP() then BWP_ClearDest() end
	end,
}

providers.metamap = {
	label = "MetaMap",

	IsAvailable = function()
		return HasMetaMapNotes() and true or nil
	end,

	Add = function(wp)
		local zid = MetaMap_NameToZoneID(wp.zone) or MetaMap_GetCurrentMapInfo()
		local note = { zoneid = zid, xPos = wp.x / 100, yPos = wp.y / 100, name = wp.title, color = 0 }
		MetaMapNotes_AddNewNote(note)
		table.insert(metamapnotes, note)
		return true
	end,

	Clear = function()
		for i = table.getn(metamapnotes), 1, -1 do
			local note = table.remove(metamapnotes, i)
			MetaMapNotes_DeleteNote(note.zoneid, note.xPos, note.yPos)
		end
	end,
}

-- Provider selection ----------------------------------------------------------

-- The provider that should receive waypoints, or nil when no supported waypoint
-- addon is loaded. A configured provider that is not currently usable falls back
-- to the "auto" order rather than silently dropping waypoints.
function AegisPathfinder:GetWaypointProvider()
	local choice = self.db.char.waypointprovider
	if choice and choice ~= "auto" and providers[choice] and providers[choice].IsAvailable() then
		return providers[choice]
	end

	for _, name in ipairs(providerorder) do
		if providers[name].IsAvailable() then return providers[name] end
	end
end

-- Ordered { name, label } list of the providers that are usable right now.
function AegisPathfinder:GetWaypointProviders()
	local list = {}
	for _, name in ipairs(providerorder) do
		if providers[name].IsAvailable() then
			table.insert(list, { name = name, label = providers[name].label })
		end
	end
	return list
end

function AegisPathfinder:GetWaypointProviderLabel()
	local choice = self.db.char.waypointprovider or "auto"
	if choice ~= "auto" and providers[choice] then
		return providers[choice].label
	end

	local active = self:GetWaypointProvider()
	return "Auto (" .. (active and active.label or "none") .. ")"
end

-- Step to the next selectable provider ("auto", then every usable provider) and
-- re-point the current waypoint at it.
function AegisPathfinder:CycleWaypointProvider()
	local choices = { "auto" }
	for _, provider in ipairs(self:GetWaypointProviders()) do
		table.insert(choices, provider.name)
	end

	local current, index = self.db.char.waypointprovider or "auto", 1
	for i, name in ipairs(choices) do
		if name == current then
			index = i
			break
		end
	end

	self:ClearWaypoint()
	self.db.char.waypointprovider = choices[math.mod(index, table.getn(choices)) + 1]
	self:Debug("Waypoint provider set to " .. self.db.char.waypointprovider)
	self:ForceWaypointUpdate()
end

--- Pick a provider by name ("auto" for the preference order), as the options
--- panel's dropdown does. Cycling is still there for the slash command.
function AegisPathfinder:SetWaypointProvider(name)
	self:ClearWaypoint()
	self.db.char.waypointprovider = name or "auto"
	self:Debug("Waypoint provider set to " .. self.db.char.waypointprovider)
	self:ForceWaypointUpdate()
end

--[[ Whose arrow points at the current step.

	The addon draws its own arrow (NavCallout.lua), and the waypoint addon
	usually has one too -- TomTom's, pfQuest's -- so out of the box there were
	two, pointing at the same place. Ours reads the waypoint the addon keeps
	for itself, not the provider's arrow, so the two are independent: either,
	both or neither can point.

	Two settings underneath: `shownavcallout` for ours (which predates this),
	and `providerarrow` for theirs. A character from before `providerarrow`
	existed had the provider's arrow on regardless; they keep it only if they
	had turned ours off, and otherwise get ours alone.
]]
AegisPathfinder.ARROW_MODES = {
	{ value = "pathfinder", label = "Pathfinder's arrow" },
	{ value = "provider",   label = "The waypoint addon's arrow" },
	{ value = "both",       label = "Both arrows" },
	{ value = "none",       label = "No arrow" },
}

function AegisPathfinder:GetArrowMode()
	local db = self.db.char
	local ours = db.shownavcallout ~= false
	local theirs = db.providerarrow
	if theirs == nil then theirs = not ours end
	if ours and theirs then return "both" end
	if ours then return "pathfinder" end
	if theirs then return "provider" end
	return "none"
end

--- Whether the waypoint addon's own arrow should be aimed at our waypoints.
function AegisPathfinder:WantsProviderArrow()
	local mode = self:GetArrowMode()
	return mode == "provider" or mode == "both"
end

--- True when the active provider has no waypoint but its arrow, so the
--- arrow setting cannot take it away.
function AegisPathfinder:ProviderArrowIsWaypoint()
	local provider = self:GetWaypointProvider()
	return provider and provider.arrowIsWaypoint and true or false
end

function AegisPathfinder:SetArrowMode(mode)
	local db = self.db.char
	db.shownavcallout = (mode == "pathfinder" or mode == "both")
	db.providerarrow = (mode == "provider" or mode == "both")
	-- Re-send the step's waypoint so the provider's arrow takes it, or lets
	-- it go -- removing a TomTom waypoint also clears its arrow.
	self:ClearWaypoint()
	self:ForceWaypointUpdate()
	if self.UpdateNavCallout then self:UpdateNavCallout() end
end

-- Helper to get valid zone data (ensures map is set to player location)
local function GetPlayerZoneData()
	-- Save current map state
	local wasShown = WorldMapFrame:IsShown()
	local oldContinent, oldZone
	if wasShown then
		oldContinent = GetCurrentMapContinent()
		oldZone = GetCurrentMapZone()
	end

	-- Briefly set map to player's zone to get valid data
	SetMapToCurrentZone()
	local c = GetCurrentMapContinent()
	local z = GetCurrentMapZone()

	-- Restore map state
	if wasShown and oldContinent and oldZone then
		SetMapZoom(oldContinent, oldZone)
	elseif not wasShown and WorldMapFrame:IsShown() then
		HideUIPanel(WorldMapFrame)
	end

	return c, z
end

-- Hand one waypoint to the active provider
local function MapPoint(zone, x, y, desc, onArrival)
	desc = desc or "Waypoint"
	AegisPathfinder:Debug(string.format("Mapping %q - %s (%.2f, %.2f)", desc, zone or "nil", x or 0, y or 0))
	local zi, zc = zone and zonei[zone], zone and zonec[zone]
	if not zi or zi == 0 then
		if zone then AegisPathfinder:Print(string.format(L["Cannot find zone %q, using current zone."], zone))
		else AegisPathfinder:Print(L["No zone provided, using current zone."]) end

		zc, zi = GetPlayerZoneData()
		zone = zonenames[zc] and zonenames[zc][zi]
	end

	-- Skip if still no valid zone
	if not zc or zc == 0 or not zi or zi == 0 then
		AegisPathfinder:Debug("Could not determine zone for waypoint")
		return
	end

	local provider = AegisPathfinder:GetWaypointProvider()
	if not provider then return end

	local created = provider.Add({
		zone = zone,
		continent = zc,
		zoneindex = zi,
		x = x,
		y = y,
		title = "Pathfinder: " .. desc,
		description = desc,
		onArrival = onArrival,
		arrow = AegisPathfinder:WantsProviderArrow(),
	})

	if created then
		AegisPathfinder.lastwaypoint = true
		-- Remember where it went. The providers take a waypoint and give
		-- nothing back, so this is the only record of what the arrow is
		-- supposed to be pointing at.
		AegisPathfinder.waypointtarget = { continent = zc, zoneindex = zi, x = x, y = y }
	end
end

--[[ Which way the player is facing, in radians counter-clockwise from north.

	GetPlayerFacing arrived in a much later client than 1.12, so it is only
	here if ClassicAPI backports it. The vanilla-era way is the player arrow on
	the minimap: an unnamed Model child of Minimap whose model file is
	MinimapArrow, and whose GetFacing is the player's heading. Found once and
	remembered. With neither, there is no heading, and an arrow that ignores
	which way you are facing would point somewhere wrong -- so it returns nil.
]]
local minimapArrow
function AegisPathfinder:GetPlayerFacing()
	if GetPlayerFacing then
		local ok, f = pcall(GetPlayerFacing)
		if ok and f then return f end
	end

	if not minimapArrow and Minimap and Minimap.GetChildren then
		for _, child in ipairs({ Minimap:GetChildren() }) do
			if child.IsObjectType and child:IsObjectType("Model") and not child:GetName() then
				local ok, model = pcall(child.GetModel, child)
				if ok and type(model) == "string"
					and string.find(string.lower(model), "minimaparrow", 1, true) then
					minimapArrow = child
					break
				end
			end
		end
	end
	if minimapArrow then
		local ok, f = pcall(minimapArrow.GetFacing, minimapArrow)
		if ok and f then return f end
	end
	return nil
end

--[[ Where the current waypoint is, relative to the player.

	Returns the bearing in radians -- clockwise, relative to the way the player
	is facing, so zero means "straight ahead" -- and the distance in yards.
	With no bearing it returns nil, nil and a reason, which /apg diagnav shows.

	Astrolabe first, when it is loaded -- TomTom-TWOW and pfQuest both bring
	it. It measures in yards across zones on a continent, the way TomTom's own
	arrow does, and it copes with the hidden world map being left on the
	continent view: which it does itself, when it cannot place the player in
	a zone, and which the same-zone path below took for "not in the
	waypoint's zone" -- so our arrow hid while TomTom's went on pointing.

	Without Astrolabe: map coordinates, same zone only, and no distance. An
	arrow that says "that way" without claiming a range beats inventing one.
]]
local function AstrolabeDelta(wp)
	if not (Astrolabe and Astrolabe.GetCurrentPlayerPosition and Astrolabe.ComputeDistance) then return end
	local ok, pc, pz, px, py = pcall(Astrolabe.GetCurrentPlayerPosition, Astrolabe)
	if not ok or not pc or pc == 0 or not px then return end
	local ok2, d, dx, dy = pcall(Astrolabe.ComputeDistance, Astrolabe,
		pc, pz, px, py, wp.continent, wp.zoneindex, wp.x / 100, wp.y / 100)
	if not ok2 or not d or not dx or not dy then return end
	-- Astrolabe answers 0, 0, 0 for a zone it has no dimensions for; that is
	-- "unknown", not "you are standing on it".
	if d == 0 and (pc ~= wp.continent or pz ~= wp.zoneindex
		or math.abs(px - wp.x / 100) > 0.001 or math.abs(py - wp.y / 100) > 0.001) then
		return
	end
	return dx, dy, d
end

function AegisPathfinder:GetWaypointBearing()
	local wp = self.waypointtarget
	if not wp then return nil, nil, "no waypoint for this step" end
	if not self:GetWaypointProvider() then return nil, nil, "no waypoint addon" end
	if WorldMapFrame:IsShown() then return nil, nil, "the world map is open" end

	local facing = AegisPathfinder:GetPlayerFacing()
	if not facing then return nil, nil, "no heading from the client" end

	-- East and south of the player, and how far.
	local east, south, yards = AstrolabeDelta(wp)
	if not east then
		-- The map has to be on the player's own zone to read a position in
		-- it: reset it when it reports none, or a continent (zone 0).
		local px, py = GetPlayerMapPosition("player")
		if not px or (px == 0 and py == 0) or GetCurrentMapZone() == 0 then
			SetMapToCurrentZone()
			px, py = GetPlayerMapPosition("player")
		end
		if not px or (px == 0 and py == 0) then return nil, nil, "no player position" end
		local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
		if c ~= wp.continent or z ~= wp.zoneindex then
			return nil, nil, "the waypoint is in another zone (install TomTom-TWOW or pfQuest to point across zones)"
		end
		east, south = wp.x / 100 - px, wp.y / 100 - py
	end
	if east == 0 and south == 0 then return 0, yards or 0 end

	-- atan2(east, north) is the compass bearing, clockwise from north.
	local bearing = math.atan2(east, -south)
	-- GetPlayerFacing grows counter-clockwise from north, so adding it turns a
	-- compass bearing into one relative to the player.
	return bearing + facing, yards
end

--[[ Keep the waypoint addon's arrow off our waypoint when it is not wanted.

	Telling TomTom `crazy = false` keeps it from taking the waypoint when it
	is added, but not later: TomTom-TWOW's GoToNextWayPoint -- run whenever
	its arrow's target is reached or cleared, or the player is resurrected --
	hands the arrow to the last waypoint in its list, which is usually ours.
	So this runs with the arrow's ticks and takes it back off. Only ever off
	one of our own waypoints: the player's own TomTom waypoints are theirs.
]]
function AegisPathfinder:EnforceArrowMode()
	if self:WantsProviderArrow() then return end
	if not (TomTom and TomTom.active_waypoint and TomTom.ClearCrazyArrow) then return end
	for _, uid in ipairs(tomtomuids) do
		if TomTom.active_waypoint == uid then
			TomTom:ClearCrazyArrow()
			return true
		end
	end
end

-- Set waypoint from coordinates
function AegisPathfinder:SetWaypoint(x, y, zone, description)
	self:ClearWaypoint()
	MapPoint(zone, x, y, description or "AegisPathfinder Waypoint")
end

-- Clear all AegisPathfinder waypoints. Every provider is cleared, not just the
-- active one, so switching providers does not leave stale waypoints behind.
function AegisPathfinder:ClearWaypoint()
	for _, name in ipairs(providerorder) do
		if providers[name].IsAvailable() then providers[name].Clear() end
	end
	self.lastwaypoint = nil
	self.waypointtarget = nil
end

-- Force waypoint update - directly creates waypoint for current objective
function AegisPathfinder:ForceWaypointUpdate()
	if not self.current then return end

	local action, quest = self:GetObjectiveInfo(self.current)
	if not action then return end

	local note = self:GetObjectiveTag("N", self.current)
	local qid = self:GetObjectiveTag("QID", self.current)
	local zonename = self:GetObjectiveTag("Z", self.current) or self.zonename

	self:Debug(string.format("ForceWaypointUpdate: step=%d action=%s quest=%s note=%s zone=%s",
		self.current, action or "nil", quest or "nil", note or "nil", zonename or "nil"))

	-- Clear and recreate waypoint
	self:ParseAndMapCoords(qid, action, note, quest, zonename,
		self:GetObjectiveTag("NPC", self.current))

	-- Signal to StatusFrame that waypoint was updated
	self.waypointForced = true
end

-- Map NPC location using pfQuest database
function AegisPathfinder:MapPfQuestNPC(qid, action)
	if not self.db.char.mapquestgivers then return end
	if not qid then return false end
	if not pfDB then return false end

	local unitId, objectId = "UNKNOWN", "UNKNOWN"
	local loc, qid = GetLocale(), tonumber(qid)

	local qLookup = pfDB["quests"]["data"]
	if not qLookup or not qLookup[qid] then return false end

	local title = pfDB.quests.loc[qid] and pfDB.quests.loc[qid]["T"] or "Unknown Quest"

	if action == "ACCEPT" then
		if qLookup[qid]["start"] then
			if qLookup[qid]["start"]["U"] then
				for _, uid in pairs(qLookup[qid]["start"]["U"]) do
					unitId = uid
				end
			elseif qLookup[qid]["start"]["O"] then
				for _, oid in pairs(qLookup[qid]["start"]["O"]) do
					objectId = oid
				end
			end
		end
	else
		if qLookup[qid]["end"] then
			if qLookup[qid]["end"]["U"] then
				for _, uid in pairs(qLookup[qid]["end"]["U"]) do
					unitId = uid
				end
			elseif qLookup[qid]["end"]["O"] then
				for _, oid in pairs(qLookup[qid]["end"]["O"]) do
					objectId = oid
				end
			end
		end
	end
	self:Debug(string.format("pfQuest lookup A:%s U:%s O:%s", action, unitId, objectId))

	if unitId ~= "UNKNOWN" then
		local unitLookup = pfDB["units"]["data"]
		if unitLookup[unitId] and unitLookup[unitId]["coords"] then
			for _, data in pairs(unitLookup[unitId]["coords"]) do
				local x, y, zone, _ = unpack(data)
				local zoneName = pfDB.zones.loc and pfDB.zones.loc[zone] or nil
				local unitName = pfDB.units.loc and pfDB.units.loc[unitId] or "NPC"
				MapPoint(zoneName, x, y, title .. " (" .. unitName .. ")")
				return true
			end
		end
	elseif objectId ~= "UNKNOWN" then
		local objectLookup = pfDB["objects"]["data"]
		if objectLookup[objectId] and objectLookup[objectId]["coords"] then
			for _, data in pairs(objectLookup[objectId]["coords"]) do
				local x, y, zone, _ = unpack(data)
				local zoneName = pfDB.zones.loc and pfDB.zones.loc[zone] or nil
				local objName = pfDB.objects.loc and pfDB.objects.loc[objectId] or "Object"
				MapPoint(zoneName, x, y, title .. " (" .. objName .. ")")
				return true
			end
		end
	end
	self:Debug(string.format("%s: No NPC or Object information found for %s!", action, title))
	return false
end

--[[ Where NPCs are, by name, from pfQuest's database.

	Profession steps name who to go to -- trainers, a tome's vendor, an
	Artisan quest's giver -- but carry no coordinates: the reference they were
	generated from gives names and zones only, and coordinates typed in from
	memory would be wrong often enough to send people to empty ground.
	pfQuest's unit database has every NPC's spawn points, Turtle-lineage
	custom zones included (pfQuest-turtle, pfQuest-octo), so the names are
	looked up there. One pass over the database per set of names, cached.

	Only places the world map can show are kept: a trainer inside a dungeon
	has no waypoint, and the step's other trainers are the better direction.
]]
local npcspots = {}      -- name -> { { zone, x, y }, ... }, or false

local function NPCSpots(names)
	local wanted = {}
	for _, name in ipairs(names) do
		if npcspots[name] == nil then wanted[name] = true end
	end
	local units = pfDB and pfDB.units
	if next(wanted) and units and units.loc and units.data then
		local zoneloc = pfDB.zones and pfDB.zones.loc or {}
		for id, uname in pairs(units.loc) do
			if wanted[uname] then
				local data = units.data[id]
				for _, c in pairs(data and data.coords or {}) do
					local zoneName = zoneloc[c[3]]
					if zoneName and zonei[zoneName] then
						npcspots[uname] = npcspots[uname] or {}
						table.insert(npcspots[uname], { zone = zoneName, x = c[1], y = c[2] })
					end
				end
			end
		end
	end
	-- Only remember "not found" once there was a database to look in.
	if units and units.loc then
		for name in pairs(wanted) do
			if npcspots[name] == nil then npcspots[name] = false end
		end
	end
	return npcspots
end

--- Send a waypoint to the nearest of `names`. True when one was sent.
function AegisPathfinder:MapNearestNPC(names, desc)
	if not names or table.getn(names) == 0 then return false end
	local spots = NPCSpots(names)

	-- Where the player is, if Astrolabe can say; otherwise their zone's name.
	local pc, pz, px, py
	if Astrolabe and Astrolabe.GetCurrentPlayerPosition then
		local ok, c, z, x, y = pcall(Astrolabe.GetCurrentPlayerPosition, Astrolabe)
		if ok and c and c > 0 then pc, pz, px, py = c, z, x, y end
	end
	local here = GetRealZoneText and GetRealZoneText()

	local best, bestScore
	for _, name in ipairs(names) do
		for _, spot in ipairs(spots[name] or {}) do
			local c, z = zonec[spot.zone], zonei[spot.zone]
			-- Yards when they can be measured; failing that, the same zone
			-- beats the same continent beats anywhere.
			local score
			if pc and Astrolabe.ComputeDistance then
				local ok, d = pcall(Astrolabe.ComputeDistance, Astrolabe,
					pc, pz, px, py, c, z, spot.x / 100, spot.y / 100)
				if ok and d and (d > 0 or (c == pc and z == pz)) then score = d end
			end
			if not score then
				if spot.zone == here then score = 1e6
				elseif pc and c == pc then score = 1e7
				else score = 1e8 end
			end
			if not bestScore or score < bestScore then
				best, bestScore = { name = name, zone = spot.zone, x = spot.x, y = spot.y }, score
			end
		end
	end
	if not best then return false end

	MapPoint(best.zone, best.x, best.y, (desc or "Go to") .. " (" .. best.name .. ")")
	return self.waypointtarget ~= nil
end

-- Parse coordinates from note text and create waypoints
function AegisPathfinder:ParseAndMapCoords(qid, action, note, desc, zone, npcs)
	-- Clear existing waypoints first
	self:ClearWaypoint()

	self:Debug(string.format("ParseAndMapCoords: action=%s note=%s desc=%s zone=%s",
		action or "nil", note or "nil", desc or "nil", zone or "nil"))

	-- Check if this is an objective that should auto-complete on arrival
	local isTravelObjective = (action == "RUN" or action == "FLY" or action == "HEARTH" or action == "BOAT" or action == "GETFLIGHTPOINT")
	local onArrival = nil
	if isTravelObjective then
		onArrival = function()
			AegisPathfinder:Debug("Travel objective arrival - marking complete")
			AegisPathfinder:SetTurnedIn()
		end
	end

	if note and string.find(note, L.COORD_MATCH) then
		self:Debug("Found coordinates in note")
		for x, y in string.gfind(note, L.COORD_MATCH) do
			MapPoint(zone, tonumber(x), tonumber(y), desc, onArrival)
		end
	elseif npcs and self:MapNearestNPC(npcs, desc) then
		self:Debug("Mapped the nearest of the step's NPCs")
	elseif (action == "ACCEPT" or action == "TURNIN") then
		self:Debug("Trying pfQuest lookup for ACCEPT/TURNIN")
		if pfQuest or pfDB then
			if not self:MapPfQuestNPC(qid, action) and not self.lastwaypoint and self:GetWaypointProvider() then
				self:Print("No waypoint data found. Try enabling note coords or install pfQuest.")
			end
		elseif not self.lastwaypoint and self:GetWaypointProvider() then
			self:Print("No waypoint data found. Try enabling note coords or install pfQuest.")
		end
	else
		self:Debug("No coords in note and action=" .. (action or "nil") .. " - no waypoint created")
	end
end

-- Auto-update waypoint when step changes
function AegisPathfinder:UpdateWaypoint()
	if not self:GetWaypointProvider() then return end

	local action, quest, fullquest = self:GetObjectiveInfo()
	if not action then return end

	local note = self:GetObjectiveTag("N")
	local qid = self:GetObjectiveTag("QID")
	local zonename = self:GetObjectiveTag("Z") or self.zonename

	self:ParseAndMapCoords(qid, action, note, quest, zonename)
end

-- Patch Astrolabe/TomTom spelling mismatches and Lua errors at runtime
function AegisPathfinder:PatchAstrolabe()
	if self.astrolabePatched then return end
	self.astrolabePatched = true

	-- 1. Fix Astrolabe spelling mismatches
	if Astrolabe and Astrolabe.ContinentList and WorldMapSize then
		local misspellings = {
			["orgrimmar"] = "Ogrimmar",
			["darnassus"] = "Darnassis",
			["azshara"] = "Aszhara",
			["hillsbrad"] = "Hilsbrad"
		}
		for continent, zones in pairs(Astrolabe.ContinentList) do
			for index, zData in pairs(zones) do
				if zData.mapFile then
					local correctKey = misspellings[string.lower(zData.mapFile)]
					if correctKey and WorldMapSize[continent] and WorldMapSize[continent].zoneData then
						local coords = WorldMapSize[continent].zoneData[correctKey]
						if coords then
							-- Overwrite the zeroData at mapData[index] with the correct coordinates
							WorldMapSize[continent][index] = coords
							coords.mapName = zData.mapName
						end
					end
				end
			end
		end
		self:Debug("Astrolabe spelling mismatch patches applied successfully.")
	end

	-- 2. Fix TomTom texcoords indexing Lua error when NaN or invalid keys are passed
	if TomTom and TomTom.texcoords then
		local mt = getmetatable(TomTom.texcoords)
		if mt and mt.__index then
			local original_index = mt.__index
			mt.__index = function(t, k)
				-- Ensure k is a valid string containing a colon to avoid Lua errors
				if type(k) == "string" and string.find(k, ":") then
					local status, res = pcall(original_index, t, k)
					if status then
						return res
					end
				end
				-- Safe fallback: call original_index with "1:1" to prevent crashes
				local status, res = pcall(original_index, t, "1:1")
				if status then
					return res
				end
				-- Absolute fallback: return hardcoded table to avoid returning nil/crashing
				return {0, 0, 0, 0}
			end
			self:Debug("TomTom texcoords error safety wrapper applied successfully.")
		end
	end
end

