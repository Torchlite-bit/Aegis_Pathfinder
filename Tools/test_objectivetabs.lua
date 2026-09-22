--[[
	Tests for the guide tab model and the bar that draws it.

	The panel used to hold one guide plus at most one branch off it. It now
	holds as many as the concept's tab bar implies, so this covers the list
	itself -- opening, switching, closing, and where each tab's step goes --
	as well as the bar: which tab is active, where the + sits once tabs come
	and go, and that the main route can never be closed out from under the
	addon.

	Run:  lua5.1 Tools/test_objectivetabs.lua
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
UnitLevel = function() return 12 end

local L = setmetatable({ PART_FIND = "^(.-)@", PART_GSUB = "@.*$" },
	{ __index = function(_, k) return k end })

AegisPathfinder = {
	Locale = L,
	guidelist = {}, qsplusguides = {},
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1, myfaction = "Alliance", icons = {},
	db = { char = { currentguide = "Elwynn Forest (1-12)" }, profile = {} },
	-- Every guide the tests open has to exist as far as Core is concerned.
	guides = setmetatable({}, { __index = function() return function() return "" end end }),
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() self.__printed = true end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:IsTemplateGuide(name)
	local qsp = self.qsplusguides and self.qsplusguides[name]
	return (qsp and qsp.template) and true or false
end
function AegisPathfinder:GetObjectiveStatus() return nil end
function AegisPathfinder:GetObjectiveInfo(i)
	return self.actions[i], self.quests[i], self.quests[i]
end
function AegisPathfinder:GetObjectiveTag() return nil end
function AegisPathfinder:GetStepMeta() return nil, nil, false end
function AegisPathfinder:IsAutoDetectable() return false end
function AegisPathfinder:ParseGuideLevelRange() return nil, nil end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:UpdateGuideListPanel() end
function AegisPathfinder:GetGuideCategory() return "zone" end
function AegisPathfinder:GetOptimizedGuideForLevel() return nil end
function AegisPathfinder:ToggleMaterialsPanel() end
function AegisPathfinder:GoToObjective() end
function AegisPathfinder:GoToPreviousObjective() end
function AegisPathfinder:SkipToNextObjective() end
function AegisPathfinder:SetTurnedIn() end
-- Loading a guide only has to move currentguide for these tests.
function AegisPathfinder:LoadGuide(name)
	self.db.char.currentguide = name
	self.current = 1
end

AegisPathfinder.optionsframe = CreateFrame("Frame", nil, UIParent)
AegisPathfinder.guidelistframe = CreateFrame("Frame", nil, UIParent)

dofile("Theme.lua")
dofile("WidgetWarlock.lua")
dofile("ObjectivesFrame.lua")

-- The tab model lives in Core.lua, which is far too large to load under the
-- stub; lift just the functions under test out of it.
local core = io.open("Core.lua"):read("*a")
local from = string.find(core, "function AegisPathfinder:EnsureTabs", 1, true)
local to = string.find(core, "---------------------------------\n--      Branching Functions", 1, true)
assert(from and to, "could not find the tab block in Core.lua")
assert(loadstring(string.sub(core, from, to - 1)))()

-- Plus the two branch entry points, which are now tab operations.
local bfrom = string.find(core, "function AegisPathfinder:BranchToGuide", 1, true)
local bto = string.find(core, "-- Get the optimized guide for a given level", 1, true)
assert(bfrom and bto, "could not find the branch block in Core.lua")
assert(loadstring(string.sub(core, bfrom, bto - 1)))()

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local frame = AegisPathfinder.objectiveframe
AegisPathfinder:UpdateObjectivePanel()

local function names()
	local out = {}
	for _, t in ipairs(AegisPathfinder.db.char.tabs or {}) do table.insert(out, t.guide) end
	return table.concat(out, ", ")
end

-- One guide, one tab ----------------------------------------------------------

AegisPathfinder:UpdateObjectiveTabs()
check(frame.guideTabs[1]:IsShown(), "the guide you are on gets a tab")
check(frame.guideTabs[1].label:GetText() == "Elwynn Forest (1-12)",
	"the first tab names the loaded guide, got '%s'",
	tostring(frame.guideTabs[1].label:GetText()))
check(not frame.guideTabs[2]:IsShown(), "and no others until you open one")
check(not frame.guideTabs[1].close:IsShown(),
	"the main route has no close button -- there is nothing to fall back to")
check(frame.guideTabs[1].badge.label:GetText() == "XP",
	"an authored guide gets the XP badge, got '%s'",
	tostring(frame.guideTabs[1].badge.label:GetText()))

-- Opening keeps what you were reading ------------------------------------------

AegisPathfinder.current = 14
AegisPathfinder:OpenGuideTab("Alchemy (1-300)")
AegisPathfinder:UpdateObjectiveTabs()

check(table.getn(AegisPathfinder.db.char.tabs) == 2,
	"opening a guide adds a tab, got: %s", names())
check(AegisPathfinder.db.char.tabs[1].guide == "Elwynn Forest (1-12)",
	"the guide you were on keeps its tab, got: %s", names())
check(AegisPathfinder.db.char.tabs[1] and AegisPathfinder.db.char.tabs[1].step == 14,
	"and its place in it, got %s",
	tostring(AegisPathfinder.db.char.tabs[1] and AegisPathfinder.db.char.tabs[1].step))
check(AegisPathfinder.db.char.activetab == 2, "the new tab is the active one")
check(frame.guideTabs[2]:IsShown(), "the second tab is drawn")
check(frame.guideTabs[2].close:IsShown(), "and it can be closed")

-- The old branch flags are answered from the tabs, so everything that reads
-- them keeps working.
check(AegisPathfinder.db.char.isbranching == true,
	"an active tab other than the first is a branch")
check(AegisPathfinder.db.char.branchsavedguide == "Elwynn Forest (1-12)",
	"and the main route is what tab 1 holds, got '%s'",
	tostring(AegisPathfinder.db.char.branchsavedguide))

-- A third, and a fourth.
AegisPathfinder:OpenGuideTab("Westfall (12-17)")
AegisPathfinder:OpenGuideTab("Mining (1-300)")
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(AegisPathfinder.db.char.tabs) == 4,
	"four guides open at once, got: %s", names())
check(frame.guideTabs[4]:IsShown(), "all four are drawn")

-- Opening one that is already open switches to it rather than duplicating.
AegisPathfinder:OpenGuideTab("Alchemy (1-300)")
check(table.getn(AegisPathfinder.db.char.tabs) == 4,
	"opening an open guide must not duplicate its tab, got: %s", names())
check(AegisPathfinder.db.char.activetab == 2,
	"it switches to the tab that already has it, got %s",
	tostring(AegisPathfinder.db.char.activetab))

-- Switching resumes where you left off ------------------------------------------

AegisPathfinder.current = 7
AegisPathfinder:SwitchToTab(1)
check(AegisPathfinder.db.char.tabs[2] and AegisPathfinder.db.char.tabs[2].step == 7,
	"leaving a tab remembers where you were in it, got %s",
	tostring(AegisPathfinder.db.char.tabs[2] and AegisPathfinder.db.char.tabs[2].step))
check(AegisPathfinder.current == 14,
	"and returning to one resumes there, got %s", tostring(AegisPathfinder.current))
check(AegisPathfinder.db.char.currentguide == "Elwynn Forest (1-12)",
	"switching loads that tab's guide, got '%s'",
	tostring(AegisPathfinder.db.char.currentguide))
check(AegisPathfinder.db.char.isbranching == false,
	"back on tab 1 is not branching")

AegisPathfinder:UpdateObjectiveTabs()
check(frame.guideTabs[1].fill.center.__color[1] < 0.2,
	"the active tab takes the panel fill so it reads as continuous with the list")

-- Closing ------------------------------------------------------------------------

AegisPathfinder:SwitchToTab(3)      -- Westfall
AegisPathfinder:CloseTab(3)
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(AegisPathfinder.db.char.tabs) == 3,
	"closing removes the tab, got: %s", names())
check(AegisPathfinder.db.char.activetab == 1,
	"closing the tab you are on returns you to the main route, got %s",
	tostring(AegisPathfinder.db.char.activetab))

-- Closing a tab to the left of the active one keeps you on the same guide.
AegisPathfinder:SwitchToTab(3)      -- Mining
local before = AegisPathfinder.db.char.currentguide
AegisPathfinder:CloseTab(2)         -- Alchemy, to its left
check(AegisPathfinder.db.char.currentguide == before,
	"closing a tab beside you must not move you, got '%s'",
	tostring(AegisPathfinder.db.char.currentguide))
check(AegisPathfinder.db.char.activetab == 2,
	"the active index follows the tab, got %s",
	tostring(AegisPathfinder.db.char.activetab))

-- The main route is not closable, by button or by call.
AegisPathfinder:CloseTab(1)
check(table.getn(AegisPathfinder.db.char.tabs) == 2,
	"tab 1 is the main route and cannot be closed, got: %s", names())

-- Returning from a branch closes it and goes back to tab 1.
AegisPathfinder:SwitchToTab(2)
AegisPathfinder:ReturnFromBranch()
check(table.getn(AegisPathfinder.db.char.tabs) == 1,
	"returning closes the branch tab, got: %s", names())
check(AegisPathfinder.db.char.activetab == 1, "and lands on the main route")
check(AegisPathfinder.db.char.isbranching == false, "which is not a branch")

-- The + button --------------------------------------------------------------------

AegisPathfinder:UpdateObjectiveTabs()
local function lastAnchorTarget(f)
	local pts = f.__points
	return pts[table.getn(pts)][2]
end
check(lastAnchorTarget(frame.addTab) == frame.guideTabs[1],
	"with one tab, + sits beside it")

AegisPathfinder:OpenGuideTab("Alchemy (1-300)")
AegisPathfinder:UpdateObjectiveTabs()
check(lastAnchorTarget(frame.addTab) == frame.guideTabs[2],
	"with two, + follows the last one rather than floating where a closed tab was")

-- Past the bar's capacity there is nowhere to put another tab.
for _, name in ipairs({ "A (1-2)", "B (1-2)", "C (1-2)", "D (1-2)" }) do
	AegisPathfinder:OpenGuideTab(name)
end
AegisPathfinder:UpdateObjectiveTabs()
check(table.getn(AegisPathfinder.db.char.tabs) == 6, "six tabs open, got: %s", names())
check(not frame.addTab:IsShown(),
	"at capacity the + stops offering what it cannot do")

-- Migration -------------------------------------------------------------------------

-- A character saved by the old one-deep branch model.
AegisPathfinder.db.char.tabs = nil
AegisPathfinder.db.char.activetab = nil
AegisPathfinder.db.char.isbranching = true
AegisPathfinder.db.char.branchsavedguide = "Elwynn Forest (1-12)"
AegisPathfinder.db.char.branchsavedstep = 22
AegisPathfinder.db.char.currentguide = "Alchemy (1-300)"
AegisPathfinder.current = 5

local migrated = AegisPathfinder:EnsureTabs()
check(table.getn(migrated) == 2,
	"an old branch becomes two tabs, got: %s", names())
check(migrated[1] and migrated[1].guide == "Elwynn Forest (1-12)" and migrated[1].step == 22,
	"the guide that was set aside becomes tab 1, at the step it was left")
check(migrated[2] and migrated[2].guide == "Alchemy (1-300)",
	"and the branch becomes tab 2, got '%s'",
	tostring(migrated[2] and migrated[2].guide))
check(AegisPathfinder.db.char.activetab == 2, "with the branch active")

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
