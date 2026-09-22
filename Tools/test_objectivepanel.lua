--[[
	Tests for the objectives panel's structure and step rows.

	The panel is the addon's main surface and the one the concept specifies in
	most detail, so this drives the real file against the stub API and checks
	the things that are invisible until someone loads a client: that the header
	exists and is wired as the drag handle, that the nav row counts the guide
	correctly, and that quest hand-offs become coloured bands while ordinary
	steps stay rows.

	Run:  lua5.1 Tools/test_objectivepanel.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
PlaySound = function() end
GetNumQuestLeaderBoards = function() return 0 end
GetQuestLogLeaderBoard = function() return nil end

local L = setmetatable({ PART_FIND = "^(.-)@", PART_GSUB = "@.*$" },
	{ __index = function(_, k) return k end })

AegisPathfinder = {
	Locale = L,
	guides = {}, guidelist = {}, qsplusguides = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance",
	db = { char = { currentguide = "Elwynn Forest (1-12)" }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:IsTemplateGuide() return false end
function AegisPathfinder:ReturnFromBranch() end
function AegisPathfinder:GoToObjective(i) self.__wentTo = i end
function AegisPathfinder:GoToPreviousObjective() end
function AegisPathfinder:SkipToNextObjective() end
function AegisPathfinder:SetTurnedIn() end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:ToggleMaterialsPanel() end
function AegisPathfinder:OnObjectiveFrameResized2() end
function AegisPathfinder:IsAutoDetectable() return false end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end
function AegisPathfinder:GetObjectiveStatus(i) return self.turnedin[i] end
function AegisPathfinder:GetObjectiveTag(tag, i)
	local t = self.tags[i or self.current]
	if not t then return nil end
	return t[tag]
end

AegisPathfinder.statusframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.optionsframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.guidelistframe = CreateFrame("Frame", nil, UIParent)

dofile("Theme.lua")
dofile("WidgetWarlock.lua")
dofile("ObjectivesFrame.lua")

local Theme = AegisPathfinder.Theme

-- The real Core.lua publishes the generated glyphs under this name; the panel
-- reads it per row, so the test needs the same mapping rather than a stub.
AegisPathfinder.icons = setmetatable({}, {
	__index = function(_, action)
		return Theme.actionIconByName[action] or Theme.actionIcon.N
	end,
})

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local frame = AegisPathfinder.objectiveframe
AegisPathfinder:UpdateObjectivePanel()

-- Header ---------------------------------------------------------------------

check(frame.header ~= nil, "the panel has no header")
check(frame.header.wordmark ~= nil, "the header is missing the PATHFINDER wordmark")
check(frame.header.wordmark:GetTexture() == Theme.texture.wordmark,
	"the wordmark should be the pre-rendered texture, not a font string")

-- The bug the user hit: no header meant nothing to drag the window by.
check(frame:IsMovable(), "the panel must be movable")
check(frame.header.__dragButton == "LeftButton",
	"the header must be registered for left-button drag, got %s",
	tostring(frame.header.__dragButton))
local dragStart = frame.header:GetScript("OnDragStart")
local dragStop = frame.header:GetScript("OnDragStop")
check(dragStart ~= nil, "the header has no OnDragStart")
check(dragStop ~= nil, "the header has no OnDragStop")

if dragStart and dragStop then
	dragStart()
	check(frame.__moving == true, "dragging the header should move the panel")
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
	dragStop()
	check(frame.__moving == false, "releasing should stop the move")
	check(AegisPathfinder.db.profile.objframepoint == "TOPLEFT"
		and AegisPathfinder.db.profile.objframex == 120
		and AegisPathfinder.db.profile.objframey == -80,
		"where the panel was dropped must be saved, got %s %s,%s",
		tostring(AegisPathfinder.db.profile.objframepoint),
		tostring(AegisPathfinder.db.profile.objframex),
		tostring(AegisPathfinder.db.profile.objframey))
end

-- Chrome ---------------------------------------------------------------------

check(frame.navrow ~= nil, "the nav row was not built")
check(frame.guideProgress ~= nil, "the guide progress bar was not built")
check(frame.footer ~= nil, "the footer was not built")

-- Steps ----------------------------------------------------------------------

AegisPathfinder.actions = { "NOTE", "ACCEPT", "RUN", "TURNIN", "COMPLETE" }
AegisPathfinder.quests = {
	"Welcome to Elwynn@1@", "Down in the Ridge@1@", "Goldshire@1@",
	"Down in the Ridge@2@", "Kill the boars@1@",
}
AegisPathfinder.tags = {
	[1] = { N = "Read this first" },
	[2] = { N = "Marshal McBride in Northshire Abbey", QID = "26" },
	[3] = { N = "Travel to Goldshire" },
	[4] = { N = "Marshal Dughan in Goldshire", QID = "26" },
	[5] = { N = "Kill 8 boars" },
}
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 3
frame:Show()
AegisPathfinder:UpdateOHPanel(0)

-- Rows are fixed slots: slot n shows step n + offset, and offset is 0 here.
-- They are reachable as the panel's children that carry a band.
local built = {}
for _, child in ipairs(frame.__children) do
	if child.band then table.insert(built, child) end
end
check(table.getn(built) == 30, "expected 30 row slots, got %d", table.getn(built))

-- A NOTE step is an ordinary row, never a band.
local r1 = built[1]
check(not r1.band:IsShown(), "a NOTE step is a row, not a band")
check(r1.text:GetText() == "[1] Welcome to Elwynn@1@",
	"the row title carries the step number, got '%s'", tostring(r1.text:GetText()))
check(r1.detail:GetText() == "Read this first",
	"the note sits under the title, got '%s'", tostring(r1.detail:GetText()))
check(r1.icon:GetTexture() == Theme.actionIcon.N,
	"a NOTE row should draw the generated note glyph, got '%s'",
	tostring(r1.icon:GetTexture()))

-- An ACCEPT that is neither current nor done stays an ordinary row, so the
-- list does not become a wall of colour.
local r2 = built[2]
check(not r2.band:IsShown(),
	"an ACCEPT that is not the current step and not done stays a row")

-- The current step gets the wash and the left accent bar.
local r3 = built[3]
check(r3.bg:IsShown() and r3.activebar:IsShown(),
	"the current step should show the wash and the accent bar")

-- A TURNIN that IS the current step becomes a red band.
AegisPathfinder.current = 4
AegisPathfinder:UpdateOHPanel(0)
local r4 = built[4]
check(r4.band:IsShown(), "the current TURNIN step should render as a band")
check(not r4.text:IsShown(), "the band replaces the row, it does not overlap it")
check(r4.band.label:GetText() == "[4] Turn in 'Down in the Ridge@2@'",
	"the band reads as an instruction, got '%s'", tostring(r4.band.label:GetText()))
check(r4.band.icon:GetTexture() == Theme.glyph.bang,
	"an outstanding band carries the bang glyph")

-- Once done it turns green and the verb goes past tense.
AegisPathfinder.turnedin[4] = true
AegisPathfinder:UpdateOHPanel(0)
check(r4.band:IsShown(), "a completed TURNIN stays a band")
check(r4.band.label:GetText() == "[4] Turned in 'Down in the Ridge@2@'",
	"a satisfied band reads in the past tense, got '%s'",
	tostring(r4.band.label:GetText()))
check(r4.band.icon:GetTexture() == Theme.glyph.tick,
	"a satisfied band carries the tick glyph")

-- Moving off it leaves it a band, because it is done.
AegisPathfinder.current = 5
AegisPathfinder:UpdateOHPanel(0)
check(r4.band:IsShown(), "a done hand-off stays a band after you move past it")

-- Switching a slot from band back to row must restore every piece of the row.
AegisPathfinder.turnedin[4] = nil
AegisPathfinder:UpdateOHPanel(0)
check(not r4.band:IsShown(), "an untouched TURNIN two steps back is a row again")
check(r4.text:IsShown() and r4.icon:IsShown() and r4.check:IsShown(),
	"coming back from a band must restore the row's own parts")

-- No Blizzard art anywhere in the rows -----------------------------------------

for i, row in ipairs(built) do
	if row.icon:IsShown() and row.icon:GetTexture() then
		check(string.find(row.icon:GetTexture(), "Aegis_Pathfinder", 1, true) ~= nil,
			"row %d draws a texture from outside the addon: %s",
			i, tostring(row.icon:GetTexture()))
	end
end

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ObjectivePanel: %d checks", checks))
if table.getn(failures) == 0 then
	print("All objective panel checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
