--[[
	Credits.lua -- the in-game credits roll.

	Mirrors CONTRIBUTORS.md. Credit that only exists in a file on GitHub is not
	visible to the people actually using the addon, so it lives here too.

	Keep the two in step: if you add someone to CONTRIBUTORS.md, add them here.
]]

local AegisPathfinder = AegisPathfinder

-- { heading, { line, ... } }
local CREDITS = {
	{ "Addon lineage", {
		"Tekkub -- TourGuide, the original guide framework",
		"isalcedo -- VanillaGuide, the 1.12 addon structure",
		"NostalgiaGeek -- VanillaGuide-Plus",
		"brues-code (Brues) -- VanillaGuide-Plus, ClassicAPI edition",
		"DonutsDelivery -- VanillaGuide-Plus",
		"brues-code -- ClassicAPI, the client DLL this addon is built on",
		"Torchlite -- AEGIS: Pathfinder",
	} },
	{ "Guide content", {
		"Joana (Mancow) -- the optimized leveling routes",
		"mrmr -- optimized quest ordering",
		"RestedXP Guides (Tactics, Zeroji) -- RXP speedrun routes",
		"The Turtle WoW team and the servers continuing it",
	} },
	{ "Libraries and data", {
		"The Ace Development Team -- Ace2",
		"ckknight -- Dewdrop, Tablet, FuBarPlugin",
		"shagu -- pfQuest",
		"Cladhaire, sweetgiorni -- TomTom",
	} },
	{ "Fonts", {
		"Rajdhani -- (c) 2014 Indian Type Foundry, SIL OFL 1.1",
		"Inter -- (c) 2016 The Inter Project Authors, SIL OFL 1.1",
	} },
	{ "Not affiliated", {
		"A fan project. Not affiliated with or endorsed by Blizzard",
		"Entertainment, Zygor Guides LLC, RestedXP, or any server team.",
		"The interface follows conventions set by Zygor and RestedXP;",
		"no art or code from either is used.",
	} },
}

function AegisPathfinder:PrintCredits()
	self:Print("|cff52c722AEGIS: Pathfinder|r -- credits")
	for _, section in ipairs(CREDITS) do
		self:Print("|cffffed71" .. section[1] .. "|r")
		for _, line in ipairs(section[2]) do
			self:Print("  " .. line)
		end
	end
	self:Print("Full list: CONTRIBUTORS.md")
end

AegisPathfinder.creditsData = CREDITS
