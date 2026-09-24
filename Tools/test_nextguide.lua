--[[
	Tests for "Where next?" -- offering the custom zones between guides.

	The walk-through the design came from: finish Redridge Mountains (27-28)
	on the route at 28, take Northwind (28-34), finish it at 34, take the
	next custom zone that fits, then go back to the route at the guide for
	the level you are by then -- not the one you left.

	Run:  lua5.1 Tools/test_nextguide.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local level = 28
UnitLevel = function() return level end

local printed = {}
AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {}, qsplusguides = {},
	routes = {}, routepacks = {},
	db = { char = { completion = {}, currentguide = "Optimized/Redridge (27-28)" }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:UpdateGuideListPanel() end
function AegisPathfinder:UpdateObjectiveTabs() end
function AegisPathfinder:UpdateOHPanel() end
function AegisPathfinder:UnloadGuide() end
function AegisPathfinder:GetRouteForRace() return "Human" end
function AegisPathfinder.GetQuadrant() return "TOPRIGHT", "TOP", "RIGHT" end
-- Loading a guide moves currentguide, and, finishing one, records it done.
local loads = {}
function AegisPathfinder:LoadGuide(name, complete)
	local outgoing = self.db.char.currentguide
	if complete and outgoing then self.db.char.completion[outgoing] = 1 end
	self.db.char.currentguide = name
	self.current = 1
	table.insert(loads, name)
end

-- The guides: a stretch of the Optimized route and the custom zones.
local function guide(name, nextzone)
	AegisPathfinder.guides[name] = function() return "" end
	AegisPathfinder.nextzones[name] = nextzone
	table.insert(AegisPathfinder.guidelist, name)
end
guide("Optimized/Redridge (27-28)", "Optimized/Duskwood (28-29)")
guide("Optimized/Duskwood (28-29)", "Optimized/Ashenvale (29-30)")
guide("Optimized/Ashenvale (29-30)", "Optimized/Stranglethorn (33-34)")
guide("Optimized/Stranglethorn (33-34)", "Optimized/Arathi (37-38)")
guide("Optimized/Arathi (37-38)", "Optimized/Dustwallow (38-39)")
guide("Optimized/Dustwallow (38-39)", nil)
guide("Thalassian Highlands (1-10)")
guide("Northwind (28-34)")
guide("Balor (29-34)")
guide("Grim Reaches (33-38)")
guide("Gilneas (39-46)")
guide("Hyjal (58-60)")
guide("Westfall (12-17)")
AegisPathfinder.routes.Human = {
	{ levels = "27-28", guide = "Optimized/Redridge (27-28)" },
	{ levels = "28-29", guide = "Optimized/Duskwood (28-29)" },
	{ levels = "29-30", guide = "Optimized/Ashenvale (29-30)" },
	{ levels = "33-34", guide = "Optimized/Stranglethorn (33-34)" },
	{ levels = "37-38", guide = "Optimized/Arathi (37-38)" },
	{ levels = "38-39", guide = "Optimized/Dustwallow (38-39)" },
}

-- Core.lua is far too large to load under the stub; lift the tab, branch,
-- category and next-guide code out of it, as the tab tests do.
local core = io.open("Core.lua"):read("*a")
local function lift(from, to)
	local a = string.find(core, from, 1, true)
	local b = string.find(core, to, a or 1, true)
	assert(a and b, "could not find " .. from .. " in Core.lua")
	assert(loadstring(string.sub(core, a, b - 1)))()
end
lift("AegisPathfinder.NO_GUIDE =", "---------------------------------\n--      Branching Functions")
lift("function AegisPathfinder:BranchToGuide", "-- Check if current guide is complete and handle branch return")
lift("-- Turtle WoW custom zones for categorization", "---------------------------------\n--      Route Functions")
lift("function AegisPathfinder:LoadNextGuide()", "function AegisPathfinder:IsProfessionLearned")

dofile("Theme.lua")
dofile("WidgetWarlock.lua")
dofile("NextGuideFrame.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local function names(list)
	local out = {}
	for _, z in ipairs(list) do table.insert(out, z.guide) end
	return table.concat(out, ", ")
end
local function tabs()
	local out = {}
	for _, t in ipairs(AegisPathfinder.db.char.tabs or {}) do table.insert(out, t.guide) end
	return table.concat(out, " | ")
end

-- Which custom zones fit ------------------------------------------------------------

check(names(AegisPathfinder:GetCustomZoneChoices(28)) == "Northwind (28-34), Balor (29-34)",
	"at 28: Northwind, and Balor one level early; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(28)))
check(names(AegisPathfinder:GetCustomZoneChoices(34)) == "Grim Reaches (33-38)",
	"at 34 Northwind and Balor are done with; got '%s'", names(AegisPathfinder:GetCustomZoneChoices(34)))
check(names(AegisPathfinder:GetCustomZoneChoices(28, "Northwind (28-34)")) == "Balor (29-34)",
	"the zone just finished is not offered again")
AegisPathfinder.db.char.completion["Balor (29-34)"] = 1
check(names(AegisPathfinder:GetCustomZoneChoices(28)) == "Northwind (28-34)", "nor one finished before")
AegisPathfinder.db.char.completion["Balor (29-34)"] = nil
check(table.getn(AegisPathfinder:GetCustomZoneChoices(20)) == 0, "a level with none fitting offers none")

-- Finishing a route guide ------------------------------------------------------------

AegisPathfinder:EnsureTabs()
check(tabs() == "Optimized/Redridge (27-28)", "the route in its tab, got %s", tabs())

check(AegisPathfinder:OfferNextGuide() == true, "finishing Redridge at 28 asks")
local f = AegisPathfinder.nextguideframe
check(f and f:IsShown(), "in a window")
check(string.find(f.done:GetText(), "Redridge (27-28)", 1, true) ~= nil,
	"naming what was finished, got '%s'", tostring(f.done:GetText()))
check(f.route:IsShown() and f.route:GetText() == "CONTINUE TO DUSKWOOD (28-29)",
	"the route's next guide first, got '%s'", f.route:GetText())
check(f.zones[1]:IsShown() and f.zones[1]:GetText() == "NORTHWIND (28-34)"
	and f.zones[2]:GetText() == "BALOR (29-34)" and not f.zones[3]:IsShown(),
	"then the custom zones that fit")
check(f:GetHeight() > 150, "sized to its rows, got %s", f:GetHeight())
local _, rel = f:GetPoint()
check(rel == nil or rel == AegisPathfinder.objectiveframe or rel == UIParent, "placed")
check(AegisPathfinder:OfferNextGuide() == true and table.getn(loads) == 0,
	"asked again while it is open, it keeps waiting and loads nothing")

-- Take Northwind.
this = f.zones[1]
f.zones[1]:GetScript("OnClick")()
check(not f:IsShown(), "choosing closes the window")
check(AegisPathfinder.db.char.currentguide == "Northwind (28-34)", "Northwind is loaded")
check(tabs() == "Optimized/Duskwood (28-29) | Northwind (28-34)",
	"in a tab beside the route, which waits at its next guide; got %s", tabs())
check(AegisPathfinder.db.char.activetab == 2 and AegisPathfinder.db.char.isbranching, "on the custom zone's tab")
check(AegisPathfinder.db.char.completion["Optimized/Redridge (27-28)"] == 1, "Redridge counts as done")

-- Finishing a custom zone ------------------------------------------------------------

level = 34
check(AegisPathfinder:OfferNextGuide() == true, "finishing Northwind at 34 asks again")
check(f.route:GetText() == "BACK TO STRANGLETHORN (33-34)",
	"back to the route at the guide for level 34, not the one left; got '%s'", f.route:GetText())
check(f.zones[1]:GetText() == "GRIM REACHES (33-38)" and not f.zones[2]:IsShown(),
	"or the next custom zone that fits")

this = f.zones[1]
f.zones[1]:GetScript("OnClick")()
check(tabs() == "Optimized/Duskwood (28-29) | Grim Reaches (33-38)",
	"a custom zone after a custom zone takes its tab; got %s", tabs())
check(AegisPathfinder.db.char.currentguide == "Grim Reaches (33-38)", "and is loaded")
check(AegisPathfinder.db.char.completion["Northwind (28-34)"] == 1, "Northwind counts as done")

-- Finish Grim Reaches at 38 and go back.
level = 38
check(AegisPathfinder:OfferNextGuide() == true, "finishing Grim Reaches asks")
check(f.zones[1]:GetText() == "GILNEAS (39-46)", "offering Gilneas one level early")
this = f.route
f.route:GetScript("OnClick")()
check(tabs() == "Optimized/Arathi (37-38)" and not AegisPathfinder.db.char.isbranching,
	"back on the route, at the guide for 38; got %s", tabs())
check(AegisPathfinder.db.char.currentguide == "Optimized/Arathi (37-38)", "and it is loaded")
check(AegisPathfinder.db.char.completion["Grim Reaches (33-38)"] == 1, "Grim Reaches counts as done")

-- Closing it --------------------------------------------------------------------------

-- Closing without a choice carries on with the route, as it always did.
level = 38
AegisPathfinder.db.char.completion["Gilneas (39-46)"] = nil
check(AegisPathfinder:OfferNextGuide() == true, "finishing Arathi at 38 offers Gilneas")
loads = {}
f:Hide()
this = f
f:GetScript("OnHide")()
check(AegisPathfinder.db.char.currentguide == "Optimized/Dustwallow (38-39)",
	"closing it carries on with the route, got %s", tostring(AegisPathfinder.db.char.currentguide))
check(table.getn(loads) == 1, "once")
check(AegisPathfinder:OfferNextGuide("Optimized/Arathi (37-38)") == false,
	"and a guide is only asked about once")

-- Nothing to ask ----------------------------------------------------------------------

level = 20
AegisPathfinder.db.char.currentguide = "Westfall (12-17)"
check(AegisPathfinder:OfferNextGuide() == false and not f:IsShown(),
	"with no custom zone at your level, nothing is asked")
level = 38
AegisPathfinder.db.char.currentguide = "Optimized/Dustwallow (38-39)"
AegisPathfinder.db.char.offercustomzones = false
check(AegisPathfinder:OfferNextGuide() == false and not f:IsShown(), "switched off, nothing is asked")
AegisPathfinder.db.char.offercustomzones = nil

-- The end of the route: only the custom zones.
check(AegisPathfinder:OfferNextGuide() == true, "the last route guide still offers custom zones")
check(not f.route:IsShown() and not f.routeHeader:IsShown(), "with no route row, having nowhere to continue")
f.chosen = true
f:Hide()

-- Report ----------------------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("NextGuide: %d checks", checks))
if table.getn(failures) == 0 then
	print("All next guide checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
