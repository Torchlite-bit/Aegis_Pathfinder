--[[
	Loads StatusFrame.lua under the stub API and exercises the reskinned card.

	The status bar is the addon's always-visible surface and the file is heavy
	with layout, so it is the code most likely to break silently off-client.
	This runs the real file and drives the functions the reskin added.

	Run:  lua5.1 Tools/test_statusframe.lua
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
function AegisPathfinder:GetSkillProgress() return nil end
function AegisPathfinder:FindBagSlot() return nil end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end

dofile("WidgetWarlock.lua")
dofile("Theme.lua")
dofile("Parser.lua")      -- provides GetObjectiveTag
dofile("Servers.lua")     -- provides GetDataSourceWarning
dofile("StatusFrame.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- Construction ---------------------------------------------------------------

local f = AegisPathfinder.statusframe
check(f ~= nil, "status frame was not created")
check(f:GetWidth() == 352, "the card should be 352px wide per the concept, got %s",
	tostring(f:GetWidth()))
check(AegisPathfinder.statusskin ~= nil, "the status frame was not skinned")
check(AegisPathfinder.statuscard ~= nil, "the status card rows were not built")
check(AegisPathfinder.navcallout == nil,
	"the navigation callout was removed; nothing should rebuild it")
check(not f:IsShown(),
	"the card starts hidden -- the objectives panel is the default surface")

-- Auto-detection -------------------------------------------------------------

check(AegisPathfinder:IsAutoDetectable("ACCEPT"), "ACCEPT is auto-detectable via ClassicAPI")
check(AegisPathfinder:IsAutoDetectable("TURNIN"), "TURNIN is auto-detectable")
check(AegisPathfinder:IsAutoDetectable("COMPLETE"), "COMPLETE is auto-detectable")
check(AegisPathfinder:IsAutoDetectable("SETHEARTH"), "SETHEARTH is auto-detectable")
check(not AegisPathfinder:IsAutoDetectable("NOTE"), "a NOTE can only be read by the player")
check(not AegisPathfinder:IsAutoDetectable("BUY"), "a BUY step cannot be detected")
check(not AegisPathfinder:IsAutoDetectable("GRIND"), "a GRIND step cannot be detected")
check(not AegisPathfinder:IsAutoDetectable(nil), "a nil action is not auto-detectable")

-- Travel depends on a waypoint provider being active.
AegisPathfinder.__provider = nil
check(not AegisPathfinder:IsAutoDetectable("RUN"),
	"travel cannot self-complete with no waypoint provider")
AegisPathfinder.__provider = "TomTom"
check(AegisPathfinder:IsAutoDetectable("RUN"),
	"travel completes on arrival once a provider is active")

-- Profession steps are detectable through skill events.
AegisPathfinder.tags = { [1] = "|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion|" }
check(AegisPathfinder:IsAutoDetectable("USE", 1),
	"a craft step with a SKILL target is auto-detectable")
AegisPathfinder.tags = { [1] = "|N|Read this|" }
check(not AegisPathfinder:IsAutoDetectable("USE", 1),
	"a USE step with no skill target is not auto-detectable")

-- Card population ------------------------------------------------------------

local card = AegisPathfinder.statuscard

AegisPathfinder.actions = { "ACCEPT", "TURNIN" }
AegisPathfinder.quests = { "Refugees no More@1@", "Refugees no More@2@" }
AegisPathfinder.tags = {
	"|QID|41187| |N|Aerthand Skyshield in Brinthilien (48.3, 84.3)|",
	"|QID|41187| |N|Commander Anarileth|",
}
AegisPathfinder.turnedin = {}
AegisPathfinder.db.char.isbranching = false

AegisPathfinder:UpdateStatusCard(1, "ACCEPT",
	"Aerthand Skyshield in Brinthilien (48.3, 84.3)", 2)

check(card.desc:IsShown(), "a step with a note should show the description row")
check(card.desc:GetText() == "Aerthand Skyshield in Brinthilien",
	"coordinates belong on the meta row, not in the prose -- got '%s'",
	tostring(card.desc:GetText()))
check(card.meta:IsShown(), "a step with a quest id should show the meta row")
check(string.find(card.meta:GetText(), "QID 41187", 1, true) ~= nil,
	"the meta row should carry the quest id, got '%s'", tostring(card.meta:GetText()))
check(string.find(card.meta:GetText(), "48.3, 84.3", 1, true) ~= nil,
	"the meta row should carry the coordinates, got '%s'", tostring(card.meta:GetText()))
check(card.progressText:GetText() == "0 of 2",
	"progress should read 0 of 2, got '%s'", tostring(card.progressText:GetText()))
check(not card.branchTag:IsShown(), "the branch tag is hidden on the main route")

-- Completing a step moves the progress bar.
AegisPathfinder.turnedin["Refugees no More@1@"] = true
AegisPathfinder:UpdateStatusCard(2, "TURNIN", "Commander Anarileth", 2)
check(card.progressText:GetText() == "1 of 2",
	"progress should read 1 of 2 after a completion, got '%s'",
	tostring(card.progressText:GetText()))
check(card.progress.fill:GetWidth() == card.progress:GetWidth() / 2,
	"the progress fill should be half the track at 1 of 2")

-- A step with no note and no id collapses its rows.
AegisPathfinder.tags = { [3] = "" }
AegisPathfinder:UpdateStatusCard(3, "NOTE", nil, 2)
check(not card.desc:IsShown(), "a step with no note hides the description row")
check(not card.meta:IsShown(), "a step with no id or coords hides the meta row")

-- Branching shows the tag.
AegisPathfinder.db.char.isbranching = true
AegisPathfinder:UpdateStatusCard(1, "ACCEPT", "somewhere", 2)
check(card.branchTag:IsShown(), "the branch tag shows while off the main route")
AegisPathfinder.db.char.isbranching = false

-- A profession step puts its skill range on the meta row.
AegisPathfinder.actions = { "USE" }
AegisPathfinder.quests = { "Craft 40x Minor Healing Potion@1@" }
AegisPathfinder.tags = { "|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion|" }
AegisPathfinder:UpdateStatusCard(1, "USE", "Takes you from 1 to 63.", 1)
check(string.find(card.meta:GetText(), "Alchemy 1-63", 1, true) ~= nil,
	"a profession step should show its skill range, got '%s'",
	tostring(card.meta:GetText()))

-- Card layout ----------------------------------------------------------------

-- The card must grow and shrink with the rows it is showing, and a hidden
-- description must not leave a gap behind it.
AegisPathfinder.db.profile.server = "octowow"
AegisPathfinder.actions = { "NOTE" }
AegisPathfinder.quests = { "Bare step@1@" }
AegisPathfinder.tags = { "" }
AegisPathfinder:UpdateStatusCard(1, "NOTE", nil, 1)
local bareHeight = f:GetHeight()
local bareProgressY = card.progress.__points[table.getn(card.progress.__points)][5]

AegisPathfinder.tags = { "|QID|41187| |N|A reasonably long note about where to go and what to do there|" }
AegisPathfinder:UpdateStatusCard(1, "ACCEPT",
	"A reasonably long note about where to go and what to do there", 1)
local fullHeight = f:GetHeight()
check(fullHeight > bareHeight,
	"the card should grow when it gains a description and meta row (%s vs %s)",
	tostring(fullHeight), tostring(bareHeight))

local fullProgressY = card.progress.__points[table.getn(card.progress.__points)][5]
check(fullProgressY < bareProgressY,
	"the progress bar should sit lower when rows are added (%s vs %s)",
	tostring(fullProgressY), tostring(bareProgressY))

-- Back to a bare step: the layout must return to where it started rather than
-- keeping the gap the hidden description used to occupy.
AegisPathfinder.tags = { "" }
AegisPathfinder:UpdateStatusCard(1, "NOTE", nil, 1)
check(f:GetHeight() == bareHeight,
	"the card should shrink back to its bare height, got %s expected %s",
	tostring(f:GetHeight()), tostring(bareHeight))
check(card.progress.__points[table.getn(card.progress.__points)][5] == bareProgressY,
	"the progress bar should return to its bare position, not sit below a hidden row")

-- Data-source provenance -----------------------------------------------------

-- On the native server the meta row carries the step's own data.
AegisPathfinder.db.profile.server = "octowow"
AegisPathfinder.actions = { "ACCEPT" }
AegisPathfinder.quests = { "Refugees no More@1@" }
AegisPathfinder.tags = { "|QID|41187| |N|Aerthand Skyshield (48.3, 84.3)|" }
AegisPathfinder:UpdateStatusCard(1, "ACCEPT", "Aerthand Skyshield (48.3, 84.3)", 1)
check(string.find(card.meta:GetText(), "QID 41187", 1, true) ~= nil,
	"no warning on the native server, got '%s'", tostring(card.meta:GetText()))

-- On another server the row becomes the mismatch warning, because a guide
-- pointing at the wrong coordinates is worth more than the quest id.
AegisPathfinder.db.profile.server = "ravencraft"
AegisPathfinder:UpdateStatusCard(1, "ACCEPT", "Aerthand Skyshield (48.3, 84.3)", 1)
check(card.meta:IsShown(), "a data mismatch must be visible")
check(string.find(card.meta:GetText(), "RavenCraft", 1, true) ~= nil,
	"the mismatch warning should name the player's server, got '%s'",
	tostring(card.meta:GetText()))
AegisPathfinder.db.profile.server = "octowow"

-- Title row anchoring --------------------------------------------------------

-- The title row and everything on it must be pinned to the TOP of the card.
-- Anchoring the checkbox, arrows, icon and title straight to the card with
-- LEFT/RIGHT also pins their vertical centre, so once the card grew past one
-- line they slid into the middle of it and printed over the description.
local titleRow = card.titleRow
check(titleRow ~= nil, "the title row was not built")

local function anchorsOf(region)
	local seen = {}
	for _, p in ipairs(region.__points) do seen[p[1]] = p end
	return seen
end

local rowAnchors = anchorsOf(titleRow)
check(rowAnchors.TOPLEFT ~= nil and rowAnchors.TOPRIGHT ~= nil,
	"the title row must be pinned TOPLEFT and TOPRIGHT to the card")
check(rowAnchors.TOPLEFT[3] == "TOPLEFT" and rowAnchors.TOPLEFT[4] == 0
	and rowAnchors.TOPLEFT[5] == 0,
	"the title row must sit flush against the top of the card")
check(titleRow:GetHeight() == 24,
	"the title row is one 24px line, got %s", tostring(titleRow:GetHeight()))

-- Nothing on the title row may be parented to the card, or it will drift as
-- the card grows.
for _, name in ipairs({ "title" }) do
	check(card[name]:GetParent() == titleRow,
		"the %s must be parented to the title row, not the card", name)
end

-- The regression itself: grow the card with a long description and check the
-- title is still above it rather than sitting on top of it.
AegisPathfinder.actions = { "ACCEPT" }
AegisPathfinder.quests = { "A quest@1@" }
AegisPathfinder.tags = { "|QID|41187| |N|A note long enough that the card has to grow several lines to fit it, which is what used to push the title down into it|" }
AegisPathfinder:UpdateStatusCard(1, "ACCEPT",
	"A note long enough that the card has to grow several lines to fit it, which is what used to push the title down into it", 1)
check(f:GetHeight() > 24, "the card should have grown past one line for this test")
check(anchorsOf(card.title).RIGHT[2] == titleRow,
	"the title is anchored to the title row, so it cannot drift as the card grows")

-- Visibility -----------------------------------------------------------------

-- The panels the card anchors are siblings, not children: a hidden card must
-- not be able to take the guide list down with it.
AegisPathfinder.objectiveframe = CreateFrame("Frame")
AegisPathfinder.optionsframe = CreateFrame("Frame")
AegisPathfinder.guidelistframe = CreateFrame("Frame")
AegisPathfinder.objectiveframe:Hide()

AegisPathfinder:ToggleObjectivePanel()
check(AegisPathfinder.objectiveframe:IsShown(),
	"a bare command opens the objectives panel")
AegisPathfinder:ToggleObjectivePanel()
check(not AegisPathfinder.objectiveframe:IsShown(), "and closes it again")

-- The card is remembered per character, so toggling it records the choice.
AegisPathfinder.db.char.showstatusframe = false
AegisPathfinder:ToggleStatusFrame()
check(f:IsShown(), "toggling brings the card back")
check(AegisPathfinder.db.char.showstatusframe == true,
	"and the choice is saved, so it survives a reload")

-- Hiding it must take its panels with it rather than leave them orphaned.
AegisPathfinder.objectiveframe:Show()
AegisPathfinder.guidelistframe:Show()
AegisPathfinder:ToggleStatusFrame()
check(not f:IsShown(), "toggling hides the card again")
check(AegisPathfinder.db.char.showstatusframe == false, "and saves that too")
check(not AegisPathfinder.objectiveframe:IsShown(),
	"hiding the card closes the panels anchored to it")
check(not AegisPathfinder.guidelistframe:IsShown(),
	"including the guide list")

-- PositionStatusFrame restores the saved choice on login.
AegisPathfinder.db.char.showstatusframe = true
AegisPathfinder:PositionStatusFrame()
check(f:IsShown(), "the saved choice is restored at login")
AegisPathfinder.db.char.showstatusframe = false
AegisPathfinder:PositionStatusFrame()
check(not f:IsShown(), "and stays hidden when that was the choice")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("StatusFrame: %d checks", checks))
if table.getn(failures) == 0 then
	print("All status frame checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
