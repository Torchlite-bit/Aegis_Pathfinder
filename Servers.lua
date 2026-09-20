--[[
	Servers.lua -- which server a guide's data was written for.

	Turtle WoW is offline. The servers that continued it each rebuilt content
	past roughly patch 1.17 independently, from a leak capped around 1.17, so
	two servers can run the same client version and still disagree about a
	quest's id, an NPC's coordinates, or whether a custom zone exists at all.

	For a QID-driven guide addon that is the single largest source of wrong
	waypoints, and it fails quietly: the guide simply points somewhere nothing
	is. Core.lua already notices the symptom -- it stops auto-advancing after
	20 guides complete themselves and asks whether the guide is meant for a
	different server. This module names the cause instead of guessing at it.

	What it does NOT do is ship per-server guide data. Only one dataset exists
	(OctoWoW). This records that fact, surfaces it, and leaves room for more.
]]

local AegisPathfinder = AegisPathfinder

--[[ Registry.

	`dataset` says whether this repository carries guide data verified against
	that server -- not whether the server works. Only OctoWoW is "native"; the
	others are marked "untested" because the guides have not been checked
	against them, which is a statement about our data, not about them.
]]
local SERVERS = {
	{
		key = "octowow",
		label = "OctoWoW",
		database = "octowow.st/db",
		pfquest = "pfQuest-octo",
		dataset = "native",
	},
	{
		key = "capybara",
		label = "Capybara Paradise",
		database = nil,
		-- No dedicated pack found; the community uses the original Turtle
		-- pack. Correct this if a Capybara-specific one appears.
		pfquest = "pfQuest-turtle",
		dataset = "untested",
	},
	{
		key = "ravencraft",
		label = "RavenCraft",
		database = nil,
		pfquest = nil,   -- none confirmed
		dataset = "untested",
	},
}

AegisPathfinder.servers = SERVERS

-- Guide data in this repository was authored against OctoWoW. A guide may
-- override this by setting `dataSource` on its QuestShell+ table.
local DEFAULT_DATA_SOURCE = "octowow"
AegisPathfinder.defaultDataSource = DEFAULT_DATA_SOURCE

function AegisPathfinder:GetServerInfo(key)
	if not key then return nil end
	for _, s in ipairs(SERVERS) do
		if s.key == key then return s end
	end

	return nil
end

--- The server the player says they are on.
-- Detection is deliberately not attempted from the realm name: these servers
-- rename realms, and guessing wrong is worse than not guessing, because a
-- wrong guess suppresses the very warning this module exists to raise.
function AegisPathfinder:GetCurrentServer()
	return self.db.profile.server or DEFAULT_DATA_SOURCE
end

function AegisPathfinder:SetCurrentServer(key)
	local info = self:GetServerInfo(key)
	if not info then return false end

	self.db.profile.server = key
	self:Print(string.format("Server set to %s.", info.label))

	if info.dataset ~= "native" then
		self:Print("|cffff9900Guide data here was authored against "
			.. self:GetServerInfo(DEFAULT_DATA_SOURCE).label
			.. " and has not been verified on this server. Quest ids and "
			.. "coordinates may differ.|r")
	end
	self:UpdateStatusFrame()

	return true
end

--- Which server a guide's data came from.
function AegisPathfinder:GetGuideDataSource(guideName)
	guideName = guideName or self.db.char.currentguide
	local guide = self.qsplusguides and self.qsplusguides[guideName]
	if guide and guide.dataSource then return guide.dataSource end

	return DEFAULT_DATA_SOURCE
end

--- True when the loaded guide's data was not authored for the player's server.
-- Returns the two labels so callers can say which is which.
function AegisPathfinder:HasDataSourceMismatch(guideName)
	local source = self:GetGuideDataSource(guideName)
	local current = self:GetCurrentServer()
	if source == current then return false end

	local sourceInfo, currentInfo = self:GetServerInfo(source), self:GetServerInfo(current)

	return true, sourceInfo and sourceInfo.label or source,
		currentInfo and currentInfo.label or current
end

--- One line for the UI, or nil when there is nothing worth saying.
function AegisPathfinder:GetDataSourceWarning(guideName)
	local mismatch, sourceLabel, currentLabel = self:HasDataSourceMismatch(guideName)
	if not mismatch then return nil end

	return string.format("Guide data: %s (you are on %s)", sourceLabel, currentLabel)
end

function AegisPathfinder:PrintServerStatus()
	local current = self:GetCurrentServer()
	self:Print("|cff52c722Servers|r")
	for _, s in ipairs(SERVERS) do
		local marks = {}
		if s.key == current then table.insert(marks, "|cff52c722selected|r") end
		if s.dataset == "native" then
			table.insert(marks, "guide data verified")
		else
			table.insert(marks, "|cffff9900guide data not verified|r")
		end
		if s.pfquest then
			table.insert(marks, "pfQuest: " .. s.pfquest)
		else
			table.insert(marks, "|cffff9900no pfQuest pack known|r")
		end
		self:Print(string.format("  %-18s %s", s.label, table.concat(marks, " - ")))
	end
	self:Print("Only one guide dataset exists. Switching servers does not swap"
		.. " guide data; it records which server you are on so mismatches can"
		.. " be flagged.")
end

--- Cycle through the servers, for the options panel.
function AegisPathfinder:CycleServer()
	local current = self:GetCurrentServer()
	for i, s in ipairs(SERVERS) do
		if s.key == current then
			local nextServer = SERVERS[i + 1] or SERVERS[1]
			self:SetCurrentServer(nextServer.key)
			return
		end
	end
	self:SetCurrentServer(SERVERS[1].key)
end
