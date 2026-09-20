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
--   { zone, continent, zoneindex, x, y, title, description, onArrival }
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
		local opts = { title = wp.title, crazy = true, silent = true }

		-- Arrival callback for travel objectives
		if wp.onArrival then
			opts.callbacks = {
				distance = {
					[15] = function(event, uid, dist, lastdist)
						AegisPathfinder:Debug("TomTom arrival callback triggered")
						wp.onArrival()
					end
				}
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
			arrow = true,
		})

		-- Aim the pfQuest arrow at this node rather than at whichever quest
		-- objective happens to be nearest.
		pfquesttitle = wp.title
		pfQuest.route.SetTarget({ title = wp.title, texture = texture, layer = PFQUEST_LAYER })

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
		title = "[TG] " .. desc,
		description = desc,
		onArrival = onArrival,
	})

	if created then AegisPathfinder.lastwaypoint = true end
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
	self:ParseAndMapCoords(qid, action, note, quest, zonename)

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

-- Parse coordinates from note text and create waypoints
function AegisPathfinder:ParseAndMapCoords(qid, action, note, desc, zone)
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

