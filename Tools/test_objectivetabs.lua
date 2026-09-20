--[[
	Tests for the objectives panel tab bar.

	The tab bar is how the branch system reads now: the guide you are on is a
	tab, branching opens a second beside it, closing that tab returns you. Two
	things are easy to get wrong and invisible off-client -- which guide the
	main tab names while you are branched (it is NOT currentguide), and where
	the + button sits once the branch tab is hidden again.

	Run:  lua5.1 Tools/test_objectivetabs.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
PlaySound = function() end
GetNumQuestLeaderBoards = function() return 0 end
GetQuestLogLeaderBoard = function() return "" end

-- ObjectivesFrame takes a Locale reference at file scope; keys fall through
-- to themselves, which is what the real locale metatable does for a miss.
local L = setmetatable({}, { __index = function(_, k) return k end })

AegisPathfinder = {
	Locale = L,
	guides = {}, guidelist = {}, qsplusguides = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance", icons = {},
	db = { char = { currentguide = "Elwynn Forest (1-12)" }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:IsTemplateGuide(name)
	local qsp = self.qsplusguides and self.qsplusguides[name]
	return (qsp and qsp.template) and true or false
end
function AegisPathfinder:ReturnFromBranch() self.__returned = true end
function AegisPathfinder:GetObjectiveStatus() return nil end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end
function AegisPathfinder:GetObjectiveTag() return nil end
function AegisPathfinder:IsAutoDetectable() return false end
function AegisPathfinder:ParseGuideLevelRange() return nil, nil end
function AegisPathfinder:OnObjectiveFrameResized() end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:GetGuideCategory() return "zone" end

-- ObjectivesFrame anchors itself to the status frame.
AegisPathfinder.statusframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.optionsframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.guidelistframe = CreateFrame("Frame", nil, UIParent)

dofile("Theme.lua")
dofile("WidgetWarlock.lua")
dofile("ObjectivesFrame.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local frame = AegisPathfinder.objectiveframe
check(frame ~= nil, "the objectives frame was not created")

-- The tab bar is built lazily with the rest of the panel.
AegisPathfinder:UpdateObjectivePanel()
check(frame.tabbar ~= nil, "the tab bar was not built")
check(frame.mainTab ~= nil and frame.branchTab ~= nil and frame.addTab ~= nil,
	"the tab bar is missing one of its three parts")
check(not frame.branchTab:IsShown(),
	"the branch tab starts hidden -- there is no branch until you make one")

-- Unbranched ------------------------------------------------------------------

AegisPathfinder:UpdateObjectiveTabs()
check(frame.mainTab.label:GetText() == "Elwynn Forest (1-12)",
	"the main tab names the loaded guide, got '%s'", tostring(frame.mainTab.label:GetText()))
check(frame.mainTab.badge.label:GetText() == "XP",
	"an authored guide gets the XP badge, got '%s'",
	tostring(frame.mainTab.badge.label:GetText()))
check(not frame.branchTab:IsShown(), "no branch tab while on the main route")

-- Clicking the main tab when not branched must do nothing; there is nowhere
-- to return to.
AegisPathfinder.__returned = nil
frame.mainTab:GetScript("OnClick")()
check(AegisPathfinder.__returned == nil,
	"clicking the main tab while already on it must not trigger a return")

-- Branched --------------------------------------------------------------------

AegisPathfinder.db.char.isbranching = true
AegisPathfinder.db.char.branchsavedguide = "Elwynn Forest (1-12)"
AegisPathfinder.db.char.currentguide = "Alchemy (1-300)"
AegisPathfinder:UpdateObjectiveTabs()

check(frame.branchTab:IsShown(), "branching should open a second tab")
check(frame.branchTab.label:GetText() == "Alchemy (1-300)",
	"the branch tab names the guide you branched TO, got '%s'",
	tostring(frame.branchTab.label:GetText()))
-- The subtle one: while branched, currentguide is the branch, so the main tab
-- has to read branchsavedguide or it will name the wrong guide.
check(frame.mainTab.label:GetText() == "Elwynn Forest (1-12)",
	"the main tab must still name the guide you left, got '%s'",
	tostring(frame.mainTab.label:GetText()))

-- Both routes back.
AegisPathfinder.__returned = nil
frame.mainTab:GetScript("OnClick")()
check(AegisPathfinder.__returned == true,
	"clicking the guide you left should return you to it")

AegisPathfinder.__returned = nil
local closeBtn
for _, child in ipairs(frame.branchTab.__children) do
	if child.__scripts and child.__scripts.OnClick then closeBtn = child end
end
check(closeBtn ~= nil, "the branch tab has no close button")
if closeBtn then
	closeBtn:GetScript("OnClick")()
	check(AegisPathfinder.__returned == true, "closing the branch tab should return you")
end

-- Badges track the guide, not the branch state.
AegisPathfinder.qsplusguides["Fishing (1-300)"] = { template = true, steps = {} }
AegisPathfinder.db.char.isbranching = false
AegisPathfinder.db.char.currentguide = "Fishing (1-300)"
AegisPathfinder:UpdateObjectiveTabs()
check(frame.mainTab.badge.label:GetText() == "TPL",
	"an unauthored guide gets the TPL badge, got '%s'",
	tostring(frame.mainTab.badge.label:GetText()))

-- The + button must follow whichever tab is last, or it floats where the
-- hidden branch tab used to be.
local function lastAnchorTarget(f)
	local pts = f.__points
	return pts[table.getn(pts)][2]
end
check(lastAnchorTarget(frame.addTab) == frame.mainTab,
	"with no branch tab, + should sit beside the main tab")

AegisPathfinder.db.char.isbranching = true
AegisPathfinder.db.char.currentguide = "Alchemy (1-300)"
AegisPathfinder:UpdateObjectiveTabs()
check(lastAnchorTarget(frame.addTab) == frame.branchTab,
	"with a branch tab open, + should sit beside that instead")

-- Degenerate state: branching with nothing saved must not blank the tab.
AegisPathfinder.db.char.branchsavedguide = nil
AegisPathfinder:UpdateObjectiveTabs()
check(frame.mainTab.label:GetText() ~= nil and frame.mainTab.label:GetText() ~= "",
	"the main tab should never render empty, got '%s'",
	tostring(frame.mainTab.label:GetText()))

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ObjectiveTabs: %d checks", checks))
if table.getn(failures) == 0 then
	print("All objective tab checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
