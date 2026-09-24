--[[
	Tests for the options panel -- the concept's #options.

	It used to be a column of buttons that opened the dungeons, the filters and
	the route picker as three more windows. It is one scrolling panel now, with
	the concept's sections in the concept's order, so this checks the layout
	and that every control actually drives the setting it shows.

	Run:  lua5.1 Tools/test_options.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
ShowUIPanel = function(f) if f and f.Show then f:Show() end end
GameTooltip_Hide = function() end
UnitRaceBase = function() return "Human" end

AegisPathfinder = {
	myfaction = "Alliance",
	db = {
		char = {
			routepack = "VanillaGuide", currentroute = "Human",
			PlayStyle = "SOLO", UseAH = false, Dungeons = {},
			autoquest = true, trackquests = false, skipfollowups = true,
			autobranch = false, shownavcallout = true, showminimapbutton = true,
			waypointprovider = "auto", currentguide = "Elwynn Forest (1-12)",
		},
		profile = {},
	},
	routepacks = {
		VanillaGuide = {
			name = "VanillaGuide", displayName = "Optimized", description = "Quest-optimized",
			routes = { Human = {
				{ zone = "Elwynn Forest", levels = "1-10", guide = "E" },
				{ zone = "Westfall", levels = "10-12", guide = "W" },
			} },
		},
		RestedXP = {
			name = "RestedXP", displayName = "RestedXP", description = "Speedrun",
			routes = { Human = {} },
		},
	},
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.GetQuadrant() return "TOPRIGHT", "TOP", "RIGHT" end
function AegisPathfinder:GetRouteForRace() return "Human" end
function AegisPathfinder:GetAvailableRoutePacks()
	return { self.routepacks.RestedXP, self.routepacks.VanillaGuide }
end
function AegisPathfinder:SelectRoutePack(name) self.db.char.routepack = name end
function AegisPathfinder:SelectRoute(route) self.db.char.currentroute = route end
function AegisPathfinder:GetWaypointProviders()
	return { { name = "TomTom", label = "TomTom" } }
end
function AegisPathfinder:SetWaypointProvider(n) self.db.char.waypointprovider = n end
function AegisPathfinder:GetGuideDungeons() return { DM = true } end
function AegisPathfinder:HasNoGuide() return false end
function AegisPathfinder:LoadGuide() self.__reloaded = (self.__reloaded or 0) + 1 end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:UpdateNavCallout() self.__arrowRefreshed = true end
function AegisPathfinder:UpdateMinimapButton() self.__minimapRefreshed = true end
function AegisPathfinder:RefreshActiveFrames() self.__activeRefreshed = (self.__activeRefreshed or 0) + 1 end
function AegisPathfinder:QueryServerCompletedQuests() self.__rescanned = true end
function AegisPathfinder:ShowErrorLog() self.__errorlog = true end

AegisPathfinder.objectiveframe = CreateFrame("Frame", nil, UIParent)

-- The arrow setting lives in Navigation.lua, which enumerates the world map
-- as it loads; lift just the block under test.
do
	local nav = io.open("Navigation.lua"):read("*a")
	local from = string.find(nav, "--[[ Whose arrow points", 1, true)
	local to = string.find(nav, "-- Helper to get valid zone data", 1, true)
	assert(from and to, "could not find the arrow block in Navigation.lua")
	assert(loadstring(string.sub(nav, from, to - 1)))()
end
AegisPathfinder.__provider = { label = "TomTom" }
function AegisPathfinder:GetWaypointProvider() return self.__provider end
function AegisPathfinder:ClearWaypoint() self.__cleared = true end
function AegisPathfinder:ForceWaypointUpdate() self.__resent = true end

dofile("Theme.lua")
dofile("WidgetWarlock.lua")
dofile("Servers.lua")
dofile("Credits.lua")
dofile("OptionsFrame.lua")

-- Fire a script the way the client does: with `this` set to its frame.
local function fire(f, script)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local old = this
	this = f
	h()
	this = old
end
local function click(f) fire(f, "OnClick") end

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

AegisPathfinder:CreateConfigPanel()
local frame = AegisPathfinder.optionsframe
frame:Show()
fire(frame, "OnShow")
local db = AegisPathfinder.db.char

-- One panel, the concept's sections, in its order --------------------------------

check(frame:GetWidth() == 396, "the concept's panel is 396px wide, got %s", frame:GetWidth())
check(frame.header ~= nil and frame.subhead ~= nil, "it wears the concept's chrome")
check(frame.subhead.label:GetText() == "CONFIG", "and names itself Config")

local order = {}
for _, h in ipairs(frame.sections) do table.insert(order, h.label:GetText()) end
local want = { "RACE", "ROUTE PACK", "DUNGEONS", "FILTERS", "SERVER" }
for i, name in ipairs(want) do
	check(order[i] == name, "section %d should be %s, got %s", i, name, tostring(order[i]))
end

-- Nothing opens a window of its own any more.
check(AegisPathfinder.dungeonframe == nil, "dungeons are a section, not a window")
check(AegisPathfinder.filtersframe == nil, "filters are a section, not a window")
check(AegisPathfinder.ToggleDungeonPanel == nil and AegisPathfinder.ToggleFiltersPanel == nil,
	"the functions that opened those windows are gone")

-- Sections run top to bottom without overlapping.
local lastY = 1
for _, h in ipairs(frame.sections) do
	local _, _, _, _, yoff = h:GetPoint()
	check(yoff < lastY, "section %s should sit below the one before it", h.label:GetText())
	lastY = yoff
end

-- It scrolls ----------------------------------------------------------------------

local _, range = frame.scrollbar:GetMinMaxValues()
check(range > 0, "seven sections do not fit 560px, so the body must scroll (range %s)", range)
arg1 = -1; fire(frame, "OnMouseWheel")
check(frame.scroll:GetVerticalScroll() > 0, "the mouse wheel scrolls the body")
arg1 = 1; fire(frame, "OnMouseWheel")
check(frame.scroll:GetVerticalScroll() == 0, "and back up, without going past the top")

-- Race -------------------------------------------------------------------------------

check(frame.race.label:GetText() == "Human (Alliance) - yours",
	"the race dropdown shows the current race, marked as yours, got '%s'",
	tostring(frame.race.label:GetText()))
check(table.getn(frame.race.items) == 5, "one entry per Alliance race, got %d",
	table.getn(frame.race.items))
click(frame.race)
check(frame.race.list:IsShown(), "clicking the dropdown opens its list")
click(frame.race.rows[2])
check(db.currentroute == "Dwarf", "picking a race selects its route, got %s", tostring(db.currentroute))
check(not frame.race.list:IsShown(), "and closes the list")

-- Route pack --------------------------------------------------------------------------

db.currentroute = "Human"
AegisPathfinder:RefreshConfigPanel()
local optimized, rested
for _, p in ipairs(frame.packPills) do
	if p.packName == "VanillaGuide" then optimized = p end
	if p.packName == "RestedXP" then rested = p end
end
check(optimized and optimized.label:GetText() == "OPTIMIZED",
	"the default pack is shown as the concept names it")
check(optimized and optimized.fill.center.__color[2] > 0.7, "and it is the active pill")
click(rested)
check(db.routepack == "RestedXP", "clicking a pill switches pack, got %s", tostring(db.routepack))

-- The preview is the route this race takes under the selected pack.
click(optimized)
check(frame.preview.rows[1].lvl:GetText() == "1-10"
	and frame.preview.rows[1].zone:GetText() == "Elwynn Forest",
	"the preview lists the route's first leg, got '%s %s'",
	tostring(frame.preview.rows[1].lvl:GetText()), tostring(frame.preview.rows[1].zone:GetText()))
check(frame.preview.rows[2].zone:GetText() == "Westfall", "and its second")
check(not frame.preview.rows[3]:IsShown(), "and nothing past the end of it")

-- Dungeons ------------------------------------------------------------------------------

check(table.getn(frame.chips) == 15, "fifteen dungeon chips, got %d", table.getn(frame.chips))
local dm
for _, c in ipairs(frame.chips) do if c.dungeonCode == "DM" then dm = c end end
check(dm.dot:IsShown(), "the dungeon this guide has steps for carries the blue dot")
local reloads = AegisPathfinder.__reloaded or 0
click(dm)
check(db.Dungeons.DM == true, "clicking a chip opts in")
check((AegisPathfinder.__reloaded or 0) > reloads, "and reloads the guide so it takes effect")

-- Filters -------------------------------------------------------------------------------

check(not frame.groupSwitch:IsOn(), "solo by default, so group mode is off")
check(frame.filterNote:GetText() == "Solo mode \194\183 Auction House steps hidden",
	"the summary reads as the concept's does, got '%s'", tostring(frame.filterNote:GetText()))
click(frame.groupSwitch)
check(db.PlayStyle == "GROUP", "the switch sets group mode, got %s", tostring(db.PlayStyle))
check(frame.groupSwitch:IsOn(), "and shows it")
click(frame.ahSwitch)
check(db.UseAH == true, "the Auction House switch turns those steps on")
check(frame.filterNote:GetText() == "Group mode \194\183 Auction House steps shown",
	"and the summary follows, got '%s'", tostring(frame.filterNote:GetText()))

-- The knob slides: left when off, right when on.
local _, _, _, onX = frame.groupSwitch.knob:GetPoint()
click(frame.groupSwitch)
local _, _, _, offX = frame.groupSwitch.knob:GetPoint()
check(onX > offX, "the knob sits right when on (%s) and left when off (%s)", onX, offX)

-- Server ---------------------------------------------------------------------------------

check(frame.server.label:GetText() == "OctoWoW", "the server defaults to OctoWoW, got '%s'",
	tostring(frame.server.label:GetText()))
check(string.find(frame.serverNote:GetText(), "authored against OctoWoW", 1, true) ~= nil,
	"on the native server the note says so, got '%s'", tostring(frame.serverNote:GetText()))
click(frame.server.rows[3])
check(AegisPathfinder.db.profile.server == "ravencraft", "picking a server sets it")
check(string.find(frame.serverNote:GetText(), "not been checked on RavenCraft", 1, true) ~= nil,
	"and the note warns that the data is unverified there, got '%s'",
	tostring(frame.serverNote:GetText()))

-- The addon's own settings ---------------------------------------------------------------

check(frame.switches.autoquest:IsOn(), "switches start from the saved settings")
check(not frame.switches.trackquests:IsOn(), "off ones included")
click(frame.switches.trackquests)
check(db.trackquests == true, "and write back to them")
check(frame.switches.shownavcallout == nil,
	"the arrow is not a switch any more; the Arrow section says whose")
check(frame.switches.showminimapbutton ~= nil and frame.switches.showminimapbutton:IsOn(),
	"the minimap button has a switch, on by default")
click(frame.switches.showminimapbutton)
check(db.showminimapbutton == false and AegisPathfinder.__minimapRefreshed,
	"which hides the button at once")

-- The Active Items, Active Targets and Macros windows: a switch each, on unless the
-- saved setting says otherwise, repainting as they change.
for _, key in ipairs({ "showactiveitems", "showactivetargets", "showmacros", "questicons" }) do
	local sw = frame.switches[key]
	check(sw ~= nil, "%s has a switch", key)
	if sw then
		local before = AegisPathfinder.__activeRefreshed or 0
		click(sw)
		check(db[key] == sw:IsOn(), "%s writes back", key)
		check((AegisPathfinder.__activeRefreshed or 0) == before + 1, "and repaints the windows at once")
	end
end

click(frame.waypoints.rows[2])
check(db.waypointprovider == "TomTom", "the waypoint dropdown picks a provider, got %s",
	tostring(db.waypointprovider))

-- Arrow ------------------------------------------------------------------------

--[[ Whose arrow points at the step. A character from before the setting had
	ours on and the waypoint addon's too -- two arrows -- and gets ours alone. ]]
check(frame.arrow.label:GetText() == "Pathfinder's arrow",
	"ours alone by default, got '%s'", tostring(frame.arrow.label:GetText()))
check(not AegisPathfinder:WantsProviderArrow(), "so the waypoint addon's arrow is not aimed")
click(frame.arrow)
local modes = {}
for i, row in ipairs(frame.arrow.rows) do if row:IsShown() then modes[i] = row.value end end
check(table.getn(modes) == 4, "four choices: ours, theirs, both, neither, got %d", table.getn(modes))
AegisPathfinder.__cleared, AegisPathfinder.__resent, AegisPathfinder.__arrowRefreshed = nil, nil, nil
click(frame.arrow.rows[3])               -- Both
check(db.shownavcallout == true and db.providerarrow == true and AegisPathfinder:WantsProviderArrow(),
	"Both keeps ours and aims the waypoint addon's")
check(AegisPathfinder.__cleared and AegisPathfinder.__resent,
	"re-sending the waypoint so the change takes at once")
check(AegisPathfinder.__arrowRefreshed, "and ours is refreshed too")
click(frame.arrow)
click(frame.arrow.rows[2])               -- theirs
check(db.shownavcallout == false and AegisPathfinder:GetArrowMode() == "provider",
	"the waypoint addon's alone turns ours off")
check(string.find(frame.arrowNote:GetText(), "map pins", 1, true) ~= nil,
	"the note says the pins stay whichever arrow, got '%s'", tostring(frame.arrowNote:GetText()))

-- A provider whose waypoint is its arrow cannot have the arrow taken away.
AegisPathfinder.__provider = { label = "Cartographer", arrowIsWaypoint = true }
AegisPathfinder:RefreshConfigPanel()
check(string.find(frame.arrowNote:GetText(), "Cartographer's waypoint is its arrow", 1, true) ~= nil,
	"and says so for Cartographer, got '%s'", tostring(frame.arrowNote:GetText()))
AegisPathfinder.__provider = { label = "TomTom" }

-- Someone who had turned ours off before the setting existed kept the
-- waypoint addon's arrow, and still does.
db.shownavcallout, db.providerarrow = false, nil
check(AegisPathfinder:GetArrowMode() == "provider", "an old 'arrow off' keeps the waypoint addon's")
db.shownavcallout, db.providerarrow = true, false

click(frame.rescan)
check(AegisPathfinder.__rescanned, "Rescan progress asks the server")
click(frame.errorlog)
check(AegisPathfinder.__errorlog, "Error log opens the log")

-- Credits ---------------------------------------------------------------------

--[[ Credits are a button at the bottom of the panel, not a slash command that
	printed into chat. ]]
local last = frame.sections[table.getn(frame.sections)]
check(last.label:GetText() == "ABOUT", "the last section is About, got %s",
	tostring(last.label:GetText()))
check(frame.credits ~= nil and frame.credits.label:GetText() == "CREDITS",
	"with a Credits button in it")
local _, _, _, _, lastY = last:GetPoint()
local _, _, _, _, buttonY = frame.credits:GetPoint()
check(buttonY < lastY, "under the About header, at the bottom of the panel")
check(AegisPathfinder.PrintCredits == nil, "the chat printout is gone")

check(AegisPathfinder.creditsframe == nil, "the credits window is built on first use")
frame:ClearAllPoints()
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -100)
AegisPathfinder.objectiveframe:ClearAllPoints()
AegisPathfinder.objectiveframe:SetWidth(400)
AegisPathfinder.objectiveframe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 704, -100)
click(frame.credits)
local credits = AegisPathfinder.creditsframe
check(credits ~= nil and credits:IsShown(), "clicking the button opens the credits")
check(AegisPathfinder.Theme:IsWindow(credits), "a stacked window like every other")
check(credits.subhead.label:GetText() == "CREDITS", "wearing the same chrome")
fire(credits, "OnShow")
check(credits:GetRight() == frame:GetLeft() - 8,
	"opening beside the options panel, away from the guide (right %s, options left %s)",
	tostring(credits:GetRight()), tostring(frame:GetLeft()))

check(table.getn(credits.sections) == table.getn(AegisPathfinder.creditsData),
	"one section per heading in Credits.lua, got %d", table.getn(credits.sections))
for i, section in ipairs(AegisPathfinder.creditsData) do
	check(credits.sections[i].label:GetText() == string.upper(section[1]),
		"section %d is %s, got %s", i, section[1], tostring(credits.sections[i].label:GetText()))
end
local found = false
for _, r in ipairs(credits.body.__regions) do
	local t = r.GetText and r:GetText()
	if t and string.find(t, "Tekkub", 1, true) and string.find(t, "TourGuide", 1, true) then
		found = string.find(t, "|cffffffffTekkub|r", 1, true) ~= nil
	end
end
check(found, "each credit names its person in white, then what they did")

click(frame.credits)
check(not credits:IsShown(), "the button closes them again")
click(frame.credits)
fire(frame, "OnHide")
check(not credits:IsShown(), "and they close with the options panel")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Options: %d checks", checks))
if table.getn(failures) == 0 then
	print("All options checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
