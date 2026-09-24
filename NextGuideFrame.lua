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
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local WIDTH = 300
local PAD = 14
local ROW_H = 26
local ROW_GAP = 6
local MAX_ZONES = 5
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

--- Where the route goes after `finished`: the next guide in its chain, or,
--- coming back from a custom zone, the route's guide for your level now.
function AegisPathfinder:GetRouteContinuation(finished)
	if self.db.char.isbranching then
		local tabs = self:EnsureTabs()
		local guide = self:GetOptimizedGuideForLevel(UnitLevel("player")) or (tabs[1] and tabs[1].guide)
		return self.guides[guide] and guide or nil
	end
	local nextname = self.nextzones and self.nextzones[finished]
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

	frame.route = Theme:PanelButton(frame, "", WIDTH - PAD * 2, ROW_H)
	frame.route:SetScript("OnClick", function() AegisPathfinder:ContinueRoute() end)

	frame.zones = {}
	for i = 1, MAX_ZONES do
		local b = Theme:PanelButton(frame, "", WIDTH - PAD * 2, ROW_H)
		b:SetScript("OnClick", function() AegisPathfinder:TakeCustomZone(this.guide) end)
		frame.zones[i] = b
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
	if not finished or self.db.char.offercustomzones == false then return false end
	if frame and frame:IsShown() and frame.finished == finished then return true end
	-- Asked once per finished guide: a closed window has had its answer.
	self.offered = self.offered or {}
	if self.offered[finished] then return false end

	local zones = self:GetCustomZoneChoices(UnitLevel("player"), finished)
	if table.getn(zones) == 0 then return false end
	local route = self:GetRouteContinuation(finished)

	if not frame then Build() end
	self.offered[finished] = true
	frame.finished, frame.chosen, frame.routeGuide = finished, nil, route

	frame.done:SetText(string.format("You finished %s. Carry on with the route, or take a custom zone at your level?",
		DisplayName(finished)))
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

	y = Put(frame.zoneHeader, y, 20 + 6)
	for i, b in ipairs(frame.zones) do
		local z = zones[i]
		if z then
			b.guide = z.guide
			b:SetText(DisplayName(z.guide))
			y = Put(b, y, ROW_H + (zones[i + 1] and ROW_GAP or 0))
		else
			b.guide = nil
			b:Hide()
		end
	end
	frame:SetHeight(y + PAD)

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
