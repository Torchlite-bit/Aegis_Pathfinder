--[[
	Tests for GuideEngine.lua -- what survived the status card's deletion.

	The card is gone, but almost nothing that lived in that file was the card:
	the auto-detection table, the step metadata the objectives panel renders,
	and the use-item button are all still here. This checks that the surface
	really did go and that none of the engine went with it.

	Run:  lua5.1 Tools/test_guideengine.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

GameTooltip_Hide = function() end
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
SetItemButtonTexture = function() end
C_Timer = { After = function() end, NewTicker = function() end }
C_Item = { GetItemCount = function() return 0 end }

AegisPathfinder = {
	qsplusguides = {},
	guides = {}, guidelist = {}, nextzones = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance",
	icons = {},
	db = { char = {}, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder.GetQuadrant() return nil, nil, "RIGHT" end
function AegisPathfinder:GetWaypointProvider() return self.__provider end
function AegisPathfinder:IsSkillObjective(i)
	return self:GetObjectiveTag("SKILL", i) ~= nil
end
function AegisPathfinder:GetSkillProgress() return nil, self.__rank end
function AegisPathfinder:FindBagSlot() return nil end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end

dofile("WidgetWarlock.lua")
dofile("Theme.lua")
dofile("Parser.lua")      -- provides GetObjectiveTag
dofile("Servers.lua")     -- provides GetDataSourceWarning
dofile("GuideEngine.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- The card is gone -----------------------------------------------------------

check(AegisPathfinder.statusframe == nil,
	"the status card was deleted; nothing should rebuild it")
check(AegisPathfinder.statuscard == nil, "the status card rows should be gone")
check(AegisPathfinder.statusskin == nil, "the status card skin should be gone")
check(AegisPathfinder.UpdateStatusCard == nil,
	"UpdateStatusCard painted the card and should not have survived it")
check(AegisPathfinder.LayoutStatusCard == nil, "LayoutStatusCard should be gone")
check(AegisPathfinder.ToggleStatusFrame == nil,
	"there is no card left to toggle")

-- The engine is not ----------------------------------------------------------

for _, fn in ipairs({ "UpdateStatusFrame", "ScheduleStatusUpdate", "SetStatusText",
		"IsAutoDetectable", "GetStepMeta", "GetStepProse", "ToggleObjectivePanel",
		"PositionItemButton", "PLAYER_REGEN_ENABLED" }) do
	check(type(AegisPathfinder[fn]) == "function",
		"%s is engine, not card, and must survive", fn)
end

-- The use-item button is its own surface and stays.
check(getglobal("AegisPathfinderItemButton") ~= nil,
	"the |U| use-item button should still exist")
local itemButton = getglobal("AegisPathfinderItemButton")
check(itemButton.border and itemButton.icon,
	"drawn as the theme's tile around the item's icon, not ItemButtonTemplate")
check(itemButton.icon.__texcoord and itemButton.icon.__texcoord[1] > 0,
	"with the game's bevel cropped off the icon")

-- Auto-detection -------------------------------------------------------------

check(AegisPathfinder:IsAutoDetectable("ACCEPT"), "ACCEPT is auto-detectable via ClassicAPI")
check(AegisPathfinder:IsAutoDetectable("TURNIN"), "TURNIN is auto-detectable")
check(AegisPathfinder:IsAutoDetectable("COMPLETE"), "COMPLETE is auto-detectable")
check(AegisPathfinder:IsAutoDetectable("SETHEARTH"), "SETHEARTH is auto-detectable")
check(not AegisPathfinder:IsAutoDetectable("NOTE"), "a NOTE can only be read by the player")
check(not AegisPathfinder:IsAutoDetectable("BUY"), "a BUY step cannot be detected")
check(not AegisPathfinder:IsAutoDetectable("GRIND"), "a GRIND step cannot be detected")
check(not AegisPathfinder:IsAutoDetectable(nil), "a nil action is not auto-detectable")

AegisPathfinder.__provider = nil
check(not AegisPathfinder:IsAutoDetectable("RUN"),
	"travel cannot self-complete with no waypoint provider")
AegisPathfinder.__provider = "TomTom"
check(AegisPathfinder:IsAutoDetectable("RUN"),
	"travel completes on arrival once a provider is active")

AegisPathfinder.tags = { [1] = "|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion|" }
check(AegisPathfinder:IsAutoDetectable("USE", 1),
	"a craft step with a SKILL target is auto-detectable")
AegisPathfinder.tags = { [1] = "|N|Read this|" }
check(not AegisPathfinder:IsAutoDetectable("USE", 1),
	"a USE step with no skill target is not auto-detectable")

-- Step metadata --------------------------------------------------------------

-- What the card's meta row used to paint is now data the panel renders.
AegisPathfinder.db.profile.server = "octowow"
AegisPathfinder.tags = { [1] = "|QID|41187| |N|Aerthand Skyshield in Brinthilien (48.3, 84.3)|" }

local qid, meta, warn = AegisPathfinder:GetStepMeta(1)
check(qid == "41187", "the quest id should come back on its own, got '%s'", tostring(qid))
check(not warn, "no warning on the native server")
check(string.find(meta, "QID 41187", 1, true) ~= nil,
	"the meta string should carry the quest id, got '%s'", tostring(meta))
check(string.find(meta, "48.3, 84.3", 1, true) ~= nil,
	"coordinates buried in the note should be pulled out, got '%s'", tostring(meta))

-- Prose is the note without the coordinates, which are reported separately.
local prose = AegisPathfinder:GetStepProse("Aerthand Skyshield in Brinthilien (48.3, 84.3)")
check(prose == "Aerthand Skyshield in Brinthilien",
	"coordinates belong on the meta row, not in the prose -- got '%s'", tostring(prose))
check(AegisPathfinder:GetStepProse(nil) == nil, "no note means no prose")
check(AegisPathfinder:GetStepProse("  (12.3, 45.6)  ") == nil,
	"a note that is only coordinates leaves no prose behind")

-- A profession step reports its live skill range.
AegisPathfinder.tags = { [1] = "|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion|" }
AegisPathfinder.__rank = 27
local _, skillMeta = AegisPathfinder:GetStepMeta(1)
check(string.find(skillMeta, "Alchemy 27/63", 1, true) ~= nil,
	"a profession step should show progress against its target, got '%s'",
	tostring(skillMeta))
AegisPathfinder.__rank = nil
local _, bandMeta = AegisPathfinder:GetStepMeta(1)
check(string.find(bandMeta, "Alchemy 1-63", 1, true) ~= nil,
	"with no rank yet it should show the band, got '%s'", tostring(bandMeta))

-- Nothing to say.
AegisPathfinder.tags = { [1] = "" }
local noQid, noMeta = AegisPathfinder:GetStepMeta(1)
check(noQid == nil and noMeta == nil,
	"a step with no id, skill or coordinates reports nothing rather than an empty string")

-- A data-source mismatch outranks everything else the row could carry.
AegisPathfinder.db.profile.server = "ravencraft"
AegisPathfinder.tags = { [1] = "|QID|41187| |N|Aerthand Skyshield (48.3, 84.3)|" }
local _, warnMeta, isWarn = AegisPathfinder:GetStepMeta(1)
check(isWarn == true, "a data mismatch must be flagged as a warning, not as metadata")
check(string.find(warnMeta, "RavenCraft", 1, true) ~= nil,
	"the warning should name the player's server, got '%s'", tostring(warnMeta))
AegisPathfinder.db.profile.server = "octowow"

-- Before any guide is loaded ------------------------------------------------

--[[ At login the guide loads only after every guide file has registered, and
	events arrive in between -- SKILL_LINES_CHANGED always does. It reached
	the engine with no step list and failed on ipairs(nil). ]]
do
	local a, q, t, c = AegisPathfinder.actions, AegisPathfinder.quests,
		AegisPathfinder.turnedin, AegisPathfinder.current
	AegisPathfinder.actions, AegisPathfinder.quests = nil, nil
	AegisPathfinder.turnedin, AegisPathfinder.current = nil, nil
	local ok, err = pcall(function() AegisPathfinder:UpdateStatusFrame() end)
	check(ok, "an event before the guide loads must not error: %s", tostring(err))
	AegisPathfinder.actions, AegisPathfinder.quests = a, q
	AegisPathfinder.turnedin, AegisPathfinder.current = t, c
end

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("GuideEngine: %d checks", checks))
if table.getn(failures) == 0 then
	print("All guide engine checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
