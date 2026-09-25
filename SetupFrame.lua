--[[
	SetupFrame.lua -- first-time setup, in three steps.

	RestedXP greets a new character with a few questions instead of a page of
	settings: which kind of guide, which features, which dungeons. This does
	the same, over the settings the options panel already has -- nothing here
	is a new setting, only a friendlier way in.

	  1. Your guide     the route pack: Optimized, RestedXP Speedrun, Hardcore
	                    Survival (and Kamisayo for a Horde Warrior). Packs with
	                    no route for your race are not offered.
	  2. Features       Auction House steps, group quests, dungeons.
	  3. Dungeons       which ones, with their level ranges, and quick picks
	                    for the recommended ones, all, or none. Only asked when
	                    dungeons are on.

	It opens once per character, the first time the addon loads on it, with
	whatever that character already has filled in -- so on an existing
	character, Finish without changing anything changes nothing. Closing it
	keeps the current settings. /apg setup and the options panel's Run setup
	open it again.

	Where the chosen guides do not mark a kind of step, the page says so: the
	Optimized guides do not tag auction house, group or dungeon steps yet,
	and a switch that cannot change anything should not look as if it will.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local WIDTH = 420
local PAD = 16
local CHROME_TOP = 30 + 18
local CARD_H = 60
local ROW_H = 22
local FOOT_H = 26 + PAD * 2

--[[ The dungeons the options panel has switches for, with the level ranges
	RestedXP gives them. Ragefire Chasm is Horde-only and the Stockade
	Alliance-only; the rest are for both.

	Recommended: the dungeons whose quests the guides use most -- counted
	from the RestedXP guides' dungeon steps for each faction, the ones with
	55 or more. ]]
local DUNGEONS = {
	{ code = "RFC",       name = "Ragefire Chasm",    lo = 13, hi = 18, faction = "Horde" },
	{ code = "WC",        name = "Wailing Caverns",   lo = 18, hi = 25 },
	{ code = "DM",        name = "The Deadmines",     lo = 18, hi = 25 },
	{ code = "SFK",       name = "Shadowfang Keep",   lo = 23, hi = 29 },
	{ code = "STOCKADES", name = "The Stockade",      lo = 24, hi = 32, faction = "Alliance" },
	{ code = "BFD",       name = "Blackfathom Deeps", lo = 25, hi = 31 },
	{ code = "GNOMER",    name = "Gnomeregan",        lo = 30, hi = 36 },
	{ code = "RFK",       name = "Razorfen Kraul",    lo = 30, hi = 36 },
	{ code = "SM",        name = "Scarlet Monastery", lo = 35, hi = 45 },
	{ code = "RFD",       name = "Razorfen Downs",    lo = 38, hi = 46 },
	{ code = "ULDA",      name = "Uldaman",           lo = 44, hi = 50 },
	{ code = "ZF",        name = "Zul'Farrak",        lo = 45, hi = 53 },
	{ code = "MARA",      name = "Maraudon",          lo = 48, hi = 55 },
	{ code = "ST",        name = "Sunken Temple",     lo = 52, hi = 60 },
	{ code = "BRD",       name = "Blackrock Depths",  lo = 52, hi = 60 },
}
AegisPathfinder.DUNGEON_INFO = DUNGEONS

local RECOMMENDED = {
	Alliance = { DM = true, WC = true, GNOMER = true, ULDA = true, ZF = true, MARA = true, ST = true, BRD = true },
	Horde = { RFC = true, WC = true, BFD = true, ULDA = true, MARA = true, ST = true, BRD = true },
}

-- What each route pack is, in the words the first page uses.
local PACK_TEXT = {
	VanillaGuide = { title = "Optimized",
		text = "Quest-optimized 1-60 for every race, High Elf and Goblin included, with the custom zones offered along the way." },
	RestedXP = { title = "RestedXP Speedrun",
		text = "The fastest routes, from the RestedXP speedrun guides." },
	["RXP Hardcore"] = { title = "Hardcore Survival",
		text = "Routes chosen to keep a hardcore character alive: safer quests in a safer order." },
	["Kamisayo Speedrun"] = { title = "Kamisayo Speedrun",
		text = "A Horde Warrior speedrun, 1-60." },
}
-- The order the first page offers them in.
local PACK_ORDER = { "VanillaGuide", "RestedXP", "RXP Hardcore", "Kamisayo Speedrun" }

-- The features a pack starts with, as SelectRoutePack sets them.
local PACK_DEFAULTS = {
	RestedXP = { ah = true, group = true },
	["Kamisayo Speedrun"] = { ah = true, group = true },
	["RXP Hardcore"] = { ah = false, group = false },
	VanillaGuide = { ah = false, group = false },
}

--[[ The data. ]]

local function Faction()
	return UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
end

--- The dungeons this character's faction can do, in level order.
function AegisPathfinder:GetSetupDungeons()
	local out, faction = {}, Faction()
	for _, d in ipairs(DUNGEONS) do
		if not d.faction or d.faction == faction then table.insert(out, d) end
	end
	return out
end

--- The route packs to offer: the ones this character may use that have a
--- route for its race.
function AegisPathfinder:GetSetupPacks()
	local route = self:GetRouteForRace()
	local usable = {}
	for _, pack in ipairs(self:GetAvailableRoutePacks() or {}) do
		if pack.routes and route and pack.routes[route] then usable[pack.name] = pack end
	end
	local out = {}
	for _, name in ipairs(PACK_ORDER) do
		if usable[name] then table.insert(out, usable[name]); usable[name] = nil end
	end
	for _, pack in pairs(usable) do table.insert(out, pack) end
	return out
end

--[[ What a pack's guides actually mark, for this race's route: whether any
	step is tagged for the Auction House or for groups, and how many steps
	each dungeon adds. Read from the guide text once per pack. ]]
local tagCache = {}
function AegisPathfinder:GetPackTags(packName)
	local route = self:GetRouteForRace()
	local key = tostring(packName) .. "/" .. tostring(route)
	if tagCache[key] then return tagCache[key] end
	local tags = { ah = false, group = false, dungeons = {} }
	local pack = self.routepacks and self.routepacks[packName]
	local seen = {}
	for _, leg in ipairs(pack and pack.routes and pack.routes[route] or {}) do
		local loader = leg.guide and not seen[leg.guide] and self.guides[leg.guide]
		seen[leg.guide or ""] = true
		local ok, text = false, nil
		if type(loader) == "function" then ok, text = pcall(loader) end
		if ok and type(text) == "string" then
			if string.find(text, "|AH|", 1, true) then tags.ah = true end
			if string.find(text, "|P|GROUP|", 1, true) then tags.group = true end
			for list in string.gfind(text, "|D|([^|]+)|") do
				for code in string.gfind(list, "[^/]+") do
					if string.sub(code, 1, 1) ~= "!" then
						code = string.upper(code)
						tags.dungeons[code] = (tags.dungeons[code] or 0) + 1
					end
				end
			end
		end
	end
	tagCache[key] = tags
	return tags
end

--- What the setup starts with: this character's settings as they are now.
function AegisPathfinder:CurrentSetupChoice()
	local db = self.db.char
	local picked, any = {}, false
	for _, d in ipairs(self:GetSetupDungeons()) do
		if db.Dungeons and db.Dungeons[d.code] then picked[d.code] = true; any = true end
	end
	local pack = db.routepack
	if not pack or not self.routepacks[pack] then pack = "VanillaGuide" end
	return {
		pack = pack,
		ah = db.UseAH and true or false,
		group = db.PlayStyle == "GROUP",
		dungeons = any,
		picked = picked,
	}
end

--- Put the choices into effect. The route pack changes only if a different
--- one was chosen: choosing the one you are on keeps your place in it.
function AegisPathfinder:ApplySetup(c)
	local db = self.db.char
	if c.pack and c.pack ~= db.routepack and self.routepacks[c.pack] then
		self:SelectRoutePack(c.pack)
	end
	db.UseAH = c.ah and true or false
	db.PlayStyle = c.group and "GROUP" or "SOLO"
	db.Dungeons = db.Dungeons or {}
	for _, d in ipairs(DUNGEONS) do
		db.Dungeons[d.code] = (c.dungeons and c.picked[d.code]) and true or false
	end
	db.setupdone = true

	-- Re-read the guide on screen with the new filters.
	if not self:HasNoGuide() then
		self:LoadGuide(db.currentguide)
		self:UpdateStatusFrame()
	end
	if self.optionsframe and self.RefreshConfigPanel then self:RefreshConfigPanel() end

	local n = 0
	for _ in pairs(c.dungeons and c.picked or {}) do n = n + 1 end
	local pack = self.routepacks[c.pack]
	self:Print(string.format("Set up: %s, %s, Auction House steps %s, %s.",
		PACK_TEXT[c.pack] and PACK_TEXT[c.pack].title or (pack and pack.displayName) or tostring(c.pack),
		c.group and "group quests" or "solo",
		c.ah and "on" or "off",
		n == 0 and "no dungeons" or (n .. " dungeon" .. (n == 1 and "" or "s"))))
end

--[[ The window. ]]

local frame
local choice
local page = 1

local function Title(parent)
	local t = parent:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(t, "display", 18)
	t:SetJustifyH("LEFT")
	Theme:TextColor(t, "text")
	return t
end

local function Body(parent, width)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, "body", 11)
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	Theme:TextColor(fs, "textDim")
	return fs
end

-- A FontString's wrapped height, counted when the client will not say.
local function TextHeight(fs, width, line)
	local h = fs:GetHeight() or 0
	if h < 1 then h = math.ceil(fs:GetStringWidth() / width) * (line or 13) end
	return h
end

-- A route pack's card: its name over what it is. Selected, it takes the
-- accent.
local function PackCard(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(WIDTH - PAD * 2)
	b:SetHeight(CARD_H)
	b.fill = Theme:NineSlice(b, Theme.texture.tabFill, "BACKGROUND", "panel3")
	b.border = Theme:NineSlice(b, Theme.texture.tabBorder, "BORDER", "border")
	b.title = b:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(b.title, "display", 15)
	b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -9)
	b.title:SetJustifyH("LEFT")
	b.text = Body(b, WIDTH - PAD * 2 - 24)
	b.text:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -3)
	function b:SetSelected(on)
		self.selected = on
		if on then
			self.fill:SetTint("accent", 0.14)
			self.border:SetTint("accent")
			Theme:TextColor(self.title, "accent")
		else
			self.fill:SetTint("panel3")
			self.border:SetTint("border")
			Theme:TextColor(self.title, "text")
		end
	end
	b:SetScript("OnClick", function() AegisPathfinder:ChooseSetupPack(this.pack) end)
	b:SetScript("OnEnter", function() if not this.selected then this.border:SetTint("subtle") end end)
	b:SetScript("OnLeave", function() if not this.selected then this.border:SetTint("border") end end)
	return b
end

-- A dungeon's row: a tick, the name, the level range, how much of the route
-- it adds.
local function DungeonRow(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(WIDTH - PAD * 2)
	b:SetHeight(ROW_H)
	b.check = Theme:StepCheck(b, 14)
	b.check:SetPoint("LEFT", b, "LEFT", 2, 0)
	b.check:EnableMouse(false)
	b.name = b:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(b.name, "body", 12)
	b.name:SetPoint("LEFT", b.check, "RIGHT", 8, 0)
	b.range = b:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(b.range, "body2", 11)
	b.range:SetPoint("LEFT", b.name, "RIGHT", 6, 0)
	b.steps = b:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(b.steps, "body", 10)
	b.steps:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	b.steps:SetJustifyH("RIGHT")
	Theme:TextColor(b.steps, "textDim")
	b:SetScript("OnClick", function()
		choice.picked[this.code] = not choice.picked[this.code] or nil
		AegisPathfinder:PaintSetup()
	end)
	return b
end

local function Build()
	frame = CreateFrame("Frame", "AegisPathfinderSetup", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(WIDTH)
	frame:SetHeight(400)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	Theme:Panel(frame, "panel")
	frame:Hide()
	local _, sub = Theme:Chrome(frame, "Set up your guide")
	AegisPathfinder.setupframe = frame

	-- Which step, at the right of the subhead.
	frame.stepText = sub:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(frame.stepText, "display", 10)
	frame.stepText:SetPoint("RIGHT", sub, "RIGHT", -14, 0)
	Theme:TextColor(frame.stepText, "textDim")

	frame.title = Title(frame)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(CHROME_TOP + 14))
	frame.intro = Body(frame, WIDTH - PAD * 2)
	frame.intro:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)

	-- Step 1: the packs.
	frame.cards = {}

	-- Step 2: the features.
	frame.features = {}
	local function feature(key, label, text)
		local sw = Theme:Switch(frame, label, function(on)
			choice[key] = on
			AegisPathfinder:PaintSetup()
		end)
		sw:SetWidth(WIDTH - PAD * 2)
		sw.desc = Body(frame, WIDTH - PAD * 2 - 45)
		sw.desc:SetText(text)
		sw.key = key
		frame.features[key] = sw
		return sw
	end
	feature("ah", "Auction House", "Includes steps that buy what a quest needs from the auction house instead of farming it.")
	feature("group", "Group quests", "Includes elite and group quests, which are hard alone. Leave off to level solo.")
	feature("dungeons", "Dungeons", "Adds dungeon quests to your route. Choose which on the next step.")
	frame.featureNote = Body(frame, WIDTH - PAD * 2)
	Theme:TextColor(frame.featureNote, "gold")

	-- Step 3: the dungeons.
	frame.quick = {}
	for i, q in ipairs({ { "recommended", "Recommended" }, { "all", "All" }, { "none", "None" } }) do
		local b = Theme:PanelButton(frame, q[2], 110, 24)
		b.which = q[1]
		b:SetScript("OnClick", function() AegisPathfinder:PickSetupDungeons(this.which) end)
		frame.quick[i] = b
	end
	frame.rows = {}
	frame.dungeonNote = Body(frame, WIDTH - PAD * 2)
	Theme:TextColor(frame.dungeonNote, "gold")

	-- Footer.
	frame.back = Theme:PanelButton(frame, "Back", 100, 26)
	frame.back:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
	frame.back:SetScript("OnClick", function() AegisPathfinder:SetupStep(-1) end)
	frame.next = Theme:PanelButton(frame, "Continue", 150, 26)
	frame.next:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
	frame.next:SetScript("OnClick", function() AegisPathfinder:SetupStep(1) end)

	-- Closing keeps the settings as they are; it only stops asking.
	frame:SetScript("OnHide", function()
		AegisPathfinder.db.char.setupdone = true
	end)
	table.insert(UISpecialFrames, "AegisPathfinderSetup")
end

--- Open the setup. On a character that has been through it, only when asked.
function AegisPathfinder:ShowSetup()
	if not frame then Build() end
	choice = self:CurrentSetupChoice()
	page = 1
	self:PaintSetup()
	frame:Show()
end

--- The first time the addon loads on a character.
function AegisPathfinder:MaybeShowSetup()
	if self.db.char.setupdone then return false end
	self:ShowSetup()
	return true
end

function AegisPathfinder:ChooseSetupPack(name)
	if not choice or choice.pack == name then return end
	choice.pack = name
	-- A new pack brings its own starting features, as the options panel's
	-- pack pills do.
	local d = PACK_DEFAULTS[name]
	if d then choice.ah, choice.group = d.ah, d.group end
	self:PaintSetup()
end

function AegisPathfinder:PickSetupDungeons(which)
	choice.picked = {}
	for _, d in ipairs(self:GetSetupDungeons()) do
		if which == "all" or (which == "recommended" and RECOMMENDED[Faction()][d.code]) then
			choice.picked[d.code] = true
		end
	end
	self:PaintSetup()
end

--- Forward or back a step; forward from the last one finishes.
function AegisPathfinder:SetupStep(delta)
	local last = choice.dungeons and 3 or 2
	local nextPage = page + delta
	if nextPage < 1 then return end
	if nextPage > last then
		self:ApplySetup(choice)
		frame:Hide()
		return
	end
	-- Turning dungeons on with none picked starts from the recommended ones.
	if nextPage == 3 and not next(choice.picked) then self:PickSetupDungeons("recommended") end
	page = nextPage
	self:PaintSetup()
end

local function HideAll()
	for _, c in ipairs(frame.cards) do c:Hide() end
	for _, sw in pairs(frame.features) do sw:Hide(); sw.desc:Hide() end
	frame.featureNote:Hide()
	for _, b in ipairs(frame.quick) do b:Hide() end
	for _, r in ipairs(frame.rows) do r:Hide() end
	frame.dungeonNote:Hide()
end

function AegisPathfinder:PaintSetup()
	if not frame then return end
	HideAll()
	local last = choice.dungeons and 3 or 2
	frame.stepText:SetText(string.format("STEP %d OF %d", page, last))
	frame.back:SetText("Back")
	if page == 1 then frame.back:Hide() else frame.back:Show() end
	frame.next:SetText(page == last and "Finish" or "Continue")

	local y = CHROME_TOP + 14
	local width = WIDTH - PAD * 2

	local function intro(title, text)
		frame.title:SetText(title)
		frame.intro:SetText(text)
		y = y + 22 + 4 + TextHeight(frame.intro, width) + 14
	end

	if page == 1 then
		intro("Choose your guide", "Pick how you want to level. You can change this later in the options.")
		for i, pack in ipairs(self:GetSetupPacks()) do
			local c = frame.cards[i]
			if not c then c = PackCard(frame); frame.cards[i] = c end
			local t = PACK_TEXT[pack.name] or { title = pack.displayName, text = pack.description }
			c.pack = pack.name
			c.title:SetText(t.title)
			c.text:SetText(t.text)
			c:SetSelected(choice.pack == pack.name)
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
			c:Show()
			y = y + CARD_H + 8
		end
	elseif page == 2 then
		intro("Choose your features", "Turn on what you want the guide to include.")
		local tags = self:GetPackTags(choice.pack)
		for _, key in ipairs({ "ah", "group", "dungeons" }) do
			local sw = frame.features[key]
			sw:SetOn(choice[key])
			sw:ClearAllPoints()
			sw:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
			sw:Show()
			sw.desc:ClearAllPoints()
			sw.desc:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 45, -(y + 22))
			sw.desc:Show()
			y = y + 22 + TextHeight(sw.desc, width - 45) + 12
		end
		-- Say which switches these guides cannot act on.
		local missing = {}
		if not tags.ah then table.insert(missing, "auction house") end
		if not tags.group then table.insert(missing, "group") end
		if not next(tags.dungeons) then table.insert(missing, "dungeon") end
		if table.getn(missing) > 0 then
			local title = PACK_TEXT[choice.pack] and PACK_TEXT[choice.pack].title or choice.pack
			frame.featureNote:SetText(string.format("The %s guides do not mark %s steps yet, so %s nothing in them for now.",
				title, table.concat(missing, ", "), table.getn(missing) == 1 and "that switch changes" or "those switches change"))
			frame.featureNote:ClearAllPoints()
			frame.featureNote:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
			frame.featureNote:Show()
			y = y + TextHeight(frame.featureNote, width) + 10
		end
	else
		intro("Choose your dungeons", "Add the dungeons you want to run. The guide adds their quests to your route.")
		for i, b in ipairs(frame.quick) do
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (i - 1) * 116, -y)
			b:Show()
		end
		y = y + 24 + 10
		local tags = self:GetPackTags(choice.pack)
		local level = UnitLevel("player") or 1
		for i, d in ipairs(self:GetSetupDungeons()) do
			local r = frame.rows[i]
			if not r then r = DungeonRow(frame); frame.rows[i] = r end
			r.code = d.code
			r.check:SetChecked(choice.picked[d.code] and true or false)
			r.name:SetText(d.name)
			r.range:SetText(string.format("%d-%d", d.lo, d.hi))
			-- Green while it is your level, gold ahead of you, dim once past.
			Theme:TextColor(r.range, level > d.hi and "textDim" or level >= d.lo and "accent" or "gold")
			local n = tags.dungeons[d.code]
			r.steps:SetText(n and (n .. " step" .. (n == 1 and "" or "s")) or "not in this route")
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
			r:Show()
			y = y + ROW_H
		end
		if not next(tags.dungeons) then
			frame.dungeonNote:SetText("These guides do not mark dungeon quests yet, so this list changes nothing in them for now.")
			frame.dungeonNote:ClearAllPoints()
			frame.dungeonNote:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(y + 8))
			frame.dungeonNote:Show()
			y = y + 8 + TextHeight(frame.dungeonNote, width)
		end
		y = y + 6
	end

	frame:SetHeight(y + FOOT_H)
end
