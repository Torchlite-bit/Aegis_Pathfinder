--[[
	NextGuideFrame.lua -- "Where next?" between guides.

	The routes run through the classic zones; the custom zones (Northwind,
	Balor, Grim Reaches, Gilneas and the rest) sit beside them, reachable from
	the guide list's Custom tab but never offered. This offers them at the
	moment they are worth taking: when a guide finishes.

	Finishing a route guide -- say Redridge Mountains (27-28) at level 28 --
	asks whether to carry on with the route or take a custom zone that fits
	your level, such as Northwind (28-34). A custom zone opens in a tab beside
	the route, with the route's next guide waiting in the first tab.

	Finishing a custom zone asks again: back to the route, at the guide for
	the level you are now rather than the one you left, or on to the next
	custom zone that fits.

	A custom zone fits when you are inside its level range or one level short
	of it, are not already at its top, and have not finished it. With none
	that fit, nothing is asked and the guide moves on as it always has.
	Closing the window without choosing carries on with the route. The
	options panel can switch the question off.

	Dungeons along the way: with that switched on (the options window's
	Dungeons page), the dungeons you have ticked there are offered the same
	way, when one fits your level by the same rule -- its dungeon guide
	(Guides/Dungeons/) opens beside the route, picks up its quests, takes you
	in, and when it is done asks where next, the route first.

	And, at the end of the file, a ticked dungeon offered on its own when you
	reach the middle of its levels -- not waiting for a guide to finish.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local WIDTH = 300
local PAD = 14
local ROW_H = 26
local ROW_GAP = 6
local MAX_ZONES = 5
local MAX_DUNGEONS = 4
local CHROME_TOP = 30 + 18

-- "Optimized/Duskwood (28-29)" reads as "Duskwood (28-29)".
local function DisplayName(guide)
	return (string.gsub(guide or "", "^[%w_]+/", ""))
end
AegisPathfinder.GuideDisplayName = DisplayName

--- Custom-zone guides worth taking at `level`, lowest first. `except` is the
--- guide just finished.
function AegisPathfinder:GetCustomZoneChoices(level, except)
	local out = {}
	local completion = self.db.char.completion or {}
	for _, name in ipairs(self.guidelist or {}) do
		if name ~= except and self.guides[name] and self:GetGuideCategory(name) == "turtle" then
			local lo, hi = self:ParseGuideLevelRange(name)
			local done = (completion[name] or 0) >= 1
			if lo and hi and not done and level >= lo - 1 and level < hi then
				table.insert(out, { guide = name, lo = lo, hi = hi })
			end
		end
	end
	table.sort(out, function(a, b)
		if a.lo ~= b.lo then return a.lo < b.lo end
		return a.guide < b.guide
	end)
	while table.getn(out) > MAX_ZONES do table.remove(out) end
	return out
end

--- The dungeon guides to offer at `level`, lowest first: the ticked
--- dungeons', for this side, that fit as a custom zone does. None with
--- dungeons along the way off, or in Solo Self-Found. `except` is the guide
--- just finished.
function AegisPathfinder:GetDungeonGuideChoices(level, except)
	local db = self.db.char
	local out = {}
	if not db.offerdungeons or db.SelfFound then return out end
	local ticked = db.Dungeons or {}
	local completion = db.completion or {}
	local function consider(list)
		for _, d in ipairs(list or {}) do
			if ticked[d.code] then
				local prefix = "Dungeons/" .. d.name .. " ("
				for _, name in ipairs(self.guidelist or {}) do
					if name ~= except and self.guides[name] and string.sub(name, 1, string.len(prefix)) == prefix then
						local lo, hi = self:ParseGuideLevelRange(name)
						if lo and hi and (completion[name] or 0) < 1 and level >= lo - 1 and level < hi then
							table.insert(out, { guide = name, lo = lo, hi = hi, code = d.code })
						end
					end
				end
			end
		end
	end
	consider(self.DUNGEON_INFO)
	consider(self.TURTLE_DUNGEON_INFO)
	table.sort(out, function(a, b)
		if a.lo ~= b.lo then return a.lo < b.lo end
		return a.guide < b.guide
	end)
	while table.getn(out) > MAX_DUNGEONS do table.remove(out) end
	return out
end

--- Where the route goes after `finished`: the next leg of your route (or,
--- off it, the guide's own next link), or, coming back from a custom zone,
--- the route's guide for your level now.
function AegisPathfinder:GetRouteContinuation(finished)
	if self.db.char.isbranching then
		local tabs = self:EnsureTabs()
		local guide = self:GetOptimizedGuideForLevel(UnitLevel("player")) or (tabs[1] and tabs[1].guide)
		return self.guides[guide] and guide or nil
	end
	local nextname = self:GetRouteSuccessor(finished) or (self.nextzones and self.nextzones[finished])
	return self.guides[nextname] and nextname or nil
end

--[[ The window. ]]

local frame

local function Build()
	frame = CreateFrame("Frame", "AegisPathfinderNextGuide", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(WIDTH)
	frame:SetHeight(200)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	Theme:Panel(frame, "panel")
	frame:Hide()
	Theme:Chrome(frame, "Where next?")
	AegisPathfinder.nextguideframe = frame

	local done = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(done, "body", 11)
	done:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(CHROME_TOP + 10))
	done:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	done:SetJustifyH("LEFT")
	Theme:TextColor(done, "textDim")
	frame.done = done

	frame.routeHeader = Theme:SectionHeader(frame, "The route", WIDTH - PAD * 2)
	frame.zoneHeader = Theme:SectionHeader(frame, "Custom zones", WIDTH - PAD * 2)
	frame.dungeonHeader = Theme:SectionHeader(frame, "Dungeons", WIDTH - PAD * 2)

	frame.route = Theme:PanelButton(frame, "", WIDTH - PAD * 2, ROW_H)
	frame.route:SetScript("OnClick", function() AegisPathfinder:ContinueRoute() end)

	frame.zones = {}
	for i = 1, MAX_ZONES do
		local b = Theme:PanelButton(frame, "", WIDTH - PAD * 2, ROW_H)
		b:SetScript("OnClick", function() AegisPathfinder:TakeCustomZone(this.guide) end)
		frame.zones[i] = b
	end
	-- A dungeon guide opens beside the route as a custom zone does.
	frame.dungeons = {}
	for i = 1, MAX_DUNGEONS do
		local b = Theme:PanelButton(frame, "", WIDTH - PAD * 2, ROW_H)
		b:SetScript("OnClick", function() AegisPathfinder:TakeCustomZone(this.guide) end)
		frame.dungeons[i] = b
	end

	-- Closing without a choice carries on, as finishing a guide always did.
	frame:SetScript("OnHide", function()
		if this.finished and not this.chosen then
			this.chosen = true
			AegisPathfinder:ContinueRoute()
		end
	end)
	table.insert(UISpecialFrames, "AegisPathfinderNextGuide")
end

-- Stack the window's rows under `y`; returns where the next goes.
local function Put(widget, y, h)
	widget:ClearAllPoints()
	widget:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
	widget:Show()
	return y + h
end

--- Ask where to go after `finished`. True when the window is up and the
--- guide should wait for the answer; false when there is nothing to ask.
function AegisPathfinder:OfferNextGuide(finished)
	finished = finished or self.db.char.currentguide
	if not finished then return false end
	if frame and frame:IsShown() and frame.finished == finished then return true end
	-- Asked once per finished guide: a closed window has had its answer.
	self.offered = self.offered or {}
	if self.offered[finished] then return false end

	local level = UnitLevel("player")
	local zones = self.db.char.offercustomzones ~= false and self:GetCustomZoneChoices(level, finished) or {}
	local dungeons = self:GetDungeonGuideChoices(level, finished)
	if table.getn(zones) == 0 and table.getn(dungeons) == 0 then return false end
	local route = self:GetRouteContinuation(finished)

	if not frame then Build() end
	self.offered[finished] = true
	frame.finished, frame.chosen, frame.routeGuide = finished, nil, route

	local other = table.getn(zones) > 0 and table.getn(dungeons) > 0 and "take a custom zone or a dungeon"
		or table.getn(zones) > 0 and "take a custom zone" or "run a dungeon"
	frame.done:SetText(string.format("You finished %s. Carry on with the route, or %s at your level?",
		DisplayName(finished), other))
	-- However many lines that wrapped to; a client that will not measure
	-- wrapped text is answered by counting them.
	local textH = frame.done:GetHeight() or 0
	if textH < 1 then
		textH = math.ceil(frame.done:GetStringWidth() / (WIDTH - PAD * 2)) * 13
	end
	local y = CHROME_TOP + 10 + textH + 12

	if route then
		y = Put(frame.routeHeader, y, 20 + 6)
		frame.route:SetText((self.db.char.isbranching and "Back to " or "Continue to ") .. DisplayName(route))
		y = Put(frame.route, y, ROW_H) + 12
	else
		frame.routeHeader:Hide()
		frame.route:Hide()
	end

	-- A heading and a button per choice; nothing at all where there is none.
	local function list(header, buttons, choices)
		if table.getn(choices) == 0 then
			header:Hide()
		else
			y = Put(header, y, 20 + 6)
		end
		for i, b in ipairs(buttons) do
			local c = choices[i]
			if c then
				b.guide = c.guide
				b:SetText(DisplayName(c.guide))
				y = Put(b, y, ROW_H + (choices[i + 1] and ROW_GAP or 0))
			else
				b.guide = nil
				b:Hide()
			end
		end
		if table.getn(choices) > 0 then y = y + 12 end
	end
	list(frame.zoneHeader, frame.zones, zones)
	list(frame.dungeonHeader, frame.dungeons, dungeons)
	frame:SetHeight(y - 12 + PAD)

	-- Beside the guide, like every window that opens from it.
	local guide = self.objectiveframe
	if guide and self.GetQuadrant then
		local _, _, hhalf = self.GetQuadrant(guide)
		frame:ClearAllPoints()
		if hhalf == "LEFT" then
			frame:SetPoint("TOPLEFT", guide, "TOPRIGHT", 8, 0)
		else
			frame:SetPoint("TOPRIGHT", guide, "TOPLEFT", -8, 0)
		end
	end
	frame:Show()
	return true
end

local function Close()
	if frame then
		frame.chosen = true
		frame:Hide()
	end
end

--- Carry on with the route: its next guide, or back to it from a custom zone.
function AegisPathfinder:ContinueRoute()
	local finished = frame and frame.finished or self.db.char.currentguide
	Close()
	if finished then self.db.char.completion[finished] = 1 end
	if self.db.char.isbranching then
		self:ReturnFromBranch()
	elseif self:LoadNextGuide() then
		self:UpdateStatusFrame()
	end
end

--- Take custom zone `guide`: beside the route in a tab of its own, or in
--- place of the custom zone just finished.
function AegisPathfinder:TakeCustomZone(guide)
	if not guide or not self.guides[guide] then return end
	local finished = frame and frame.finished or self.db.char.currentguide
	local route = frame and frame.routeGuide
	Close()
	if finished then self.db.char.completion[finished] = 1 end

	if self.db.char.isbranching then
		self:LoadGuideInTab(guide)
		return
	end

	self:OpenGuideTab(guide)
	-- The route's next guide waits in the first tab, so going back resumes
	-- the route rather than the zone just finished.
	local tabs = self:EnsureTabs()
	if route and tabs[1] and self:FindTab(guide) ~= 1 then
		tabs[1].guide, tabs[1].step = route, 1
		self:SyncBranchState()
		self:UpdateObjectiveTabs()
	end
end

--[[ A ticked dungeon, at the middle of its levels.

	Ticking a dungeon in the setup puts its quests in the route. This puts
	its dungeon guide in front of you when you are ready for it: on reaching
	the middle of the level range its dungeon guide gives -- The Deadmines
	(17-24) at 21 -- a small window offers the guide, to open in a tab of its
	own or not now. Each dungeon is offered once.

	Only the dungeons the setup asks about count (DUNGEON_INFO): Turtle WoW's
	own are ticked until you untick them, so they would all be offered
	whether chosen or not; they stay with "Dungeons along the way". Nothing is
	offered before the setup is done, in Solo Self-Found, past a dungeon's top
	level, for a dungeon guide finished or already open in a tab, or with the
	options window's switch off. It looks on each level up, once after login
	and when the setup is finished. ]]

local MAX_MIDLEVEL = 4

--- The middle of `lo`-`hi`, a half rounded up: 17-24 is 21.
function AegisPathfinder.DungeonMidLevel(lo, hi)
	return math.floor((lo + hi + 1) / 2)
end

--- The ticked dungeons whose guide's middle level `level` has reached and
--- that are yet to be offered, lowest first: { guide, code, lo, hi, mid }.
function AegisPathfinder:GetMidLevelDungeons(level)
	local db = self.db.char
	local out = {}
	if not db.setupdone or db.SelfFound or db.middungeons == false or not level then return out end
	local ticked, offered = db.Dungeons or {}, db.middungeonsoffered or {}
	local completion = db.completion or {}
	for _, d in ipairs(self.DUNGEON_INFO or {}) do
		if ticked[d.code] and not offered[d.code] then
			local prefix = "Dungeons/" .. d.name .. " ("
			for _, name in ipairs(self.guidelist or {}) do
				if self.guides[name] and string.sub(name, 1, string.len(prefix)) == prefix
					and (completion[name] or 0) < 1 and not (self.FindTab and self:FindTab(name)) then
					local lo, hi = self:ParseGuideLevelRange(name)
					local mid = lo and hi and self.DungeonMidLevel(lo, hi)
					if mid and level >= mid and level <= hi then
						table.insert(out, { guide = name, code = d.code, lo = lo, hi = hi, mid = mid })
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.mid ~= b.mid then return a.mid < b.mid end
		return a.guide < b.guide
	end)
	while table.getn(out) > MAX_MIDLEVEL do table.remove(out) end
	return out
end

local mid

local function BuildMid()
	mid = CreateFrame("Frame", "AegisPathfinderMidDungeon", UIParent)
	mid:SetFrameStrata("DIALOG")
	mid:SetWidth(WIDTH)
	mid:SetHeight(160)
	mid:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	Theme:Panel(mid, "panel")
	mid:Hide()
	Theme:Chrome(mid, "A dungeon at your level")
	AegisPathfinder.middungeonframe = mid

	local text = mid:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(text, "body", 11)
	text:SetPoint("TOPLEFT", mid, "TOPLEFT", PAD, -(CHROME_TOP + 10))
	text:SetPoint("RIGHT", mid, "RIGHT", -PAD, 0)
	text:SetJustifyH("LEFT")
	Theme:TextColor(text, "textDim")
	mid.text = text

	mid.dungeons = {}
	for i = 1, MAX_MIDLEVEL do
		local b = Theme:PanelButton(mid, "", WIDTH - PAD * 2, ROW_H)
		b:SetScript("OnClick", function() AegisPathfinder:OpenMidLevelDungeon(this.guide) end)
		mid.dungeons[i] = b
	end
	mid.later = Theme:PanelButton(mid, "Not now", WIDTH - PAD * 2, ROW_H)
	mid.later:SetScript("OnClick", function() mid:Hide() end)
	table.insert(UISpecialFrames, "AegisPathfinderMidDungeon")
end

-- Lay the window out for `choices` at `level`.
local function PaintMid(choices, level)
	local one = table.getn(choices) == 1 and choices[1]
	if one then
		mid.text:SetText(string.format("You're level %d, the middle of %s, which you ticked. Open its dungeon guide beside the route? It picks up the quests, then takes you in.",
			level, DisplayName(one.guide)))
	else
		mid.text:SetText(string.format("You're level %d, the middle of these dungeons you ticked. Open one's dungeon guide beside the route? It picks up the quests, then takes you in.",
			level))
	end
	local textH = mid.text:GetHeight() or 0
	if textH < 1 then
		textH = math.ceil(mid.text:GetStringWidth() / (WIDTH - PAD * 2)) * 13
	end
	local y = CHROME_TOP + 10 + textH + 12
	for i, b in ipairs(mid.dungeons) do
		local c = choices[i]
		if c then
			b.guide = c.guide
			b:SetText((one and "Open " or "") .. DisplayName(c.guide))
			y = Put(b, y, ROW_H + ROW_GAP)
		else
			b.guide = nil
			b:Hide()
		end
	end
	y = Put(mid.later, y + 6, ROW_H)
	mid:SetHeight(y + PAD)
end

--- Offer the ticked dungeons whose middle level `level` (yours, when nil)
--- has reached. True when the window is up. Each is offered once: showing
--- it is the offer, whatever the answer.
function AegisPathfinder:OfferMidLevelDungeons(level)
	if not self.db then return false end
	level = level or UnitLevel("player")
	local choices = self:GetMidLevelDungeons(level)
	if table.getn(choices) == 0 then return false end
	-- One window at a time: "Where next?" goes first; the next level up or
	-- login asks again.
	if frame and frame:IsShown() then return false end
	if self.setupframe and self.setupframe:IsShown() then return false end

	if not mid then BuildMid() end
	local db = self.db.char
	db.middungeonsoffered = db.middungeonsoffered or {}
	for _, c in ipairs(choices) do db.middungeonsoffered[c.code] = true end
	mid.choices, mid.level = choices, level
	PaintMid(choices, level)

	local guide = self.objectiveframe
	if guide and self.GetQuadrant then
		local _, _, hhalf = self.GetQuadrant(guide)
		mid:ClearAllPoints()
		if hhalf == "LEFT" then
			mid:SetPoint("TOPLEFT", guide, "TOPRIGHT", 8, 0)
		else
			mid:SetPoint("TOPRIGHT", guide, "TOPLEFT", -8, 0)
		end
	end
	mid:Show()
	return true
end

--- Open dungeon guide `guide` from the window in a tab of its own; the
--- window stays for any others it offered.
function AegisPathfinder:OpenMidLevelDungeon(guide)
	if not guide or not self.guides[guide] then return end
	self:OpenGuideTab(guide)
	if not mid then return end
	local rest = {}
	for _, c in ipairs(mid.choices or {}) do
		if c.guide ~= guide then table.insert(rest, c) end
	end
	mid.choices = rest
	if table.getn(rest) == 0 then
		mid:Hide()
	else
		PaintMid(rest, mid.level)
	end
end

-- The level up. PLAYER_LEVEL_UP's arg1 is the new level: UnitLevel can
-- still say the old one while it fires.
local levels = CreateFrame("Frame")
levels:RegisterEvent("PLAYER_LEVEL_UP")
levels:SetScript("OnEvent", function()
	if AegisPathfinder.db and AegisPathfinder.enableDone then
		AegisPathfinder:OfferMidLevelDungeons(tonumber(arg1))
	end
end)
AegisPathfinder.midLevelEvents = levels
