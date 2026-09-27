--[[ GearFrame.lua -- the Gear window: the stat weights behind the item score.

	Zygor's Item Score page, in this addon's language: the spec you are
	scored as (Auto follows your talents), a line saying where that came from
	and whether the weights are the defaults or yours, and every weight, two
	columns of them, each one editable. Only the stats your spec weighs are
	listed until "Show all stats" is on. Under them, the weights as a string,
	in OctoPawn's format, to export or import, and a reset.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

-- Layout, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local L = {
	WIDTH = 380, PAD = 12, ROW_H = 24, BOX_W = 52, COL_GAP = 14, ROWS = 12,
	BUTTON_H = 22, SCROLL_W = 10, CHROME_TOP = 30 + 18,
}
L.SPEC_TOP = L.CHROME_TOP + 10
L.NOTE_TOP = L.SPEC_TOP + 30 + 6
L.SWITCH_TOP = L.NOTE_TOP + 30
L.LIST_TOP = L.SWITCH_TOP + 22 + 10
L.LIST_H = L.ROWS * L.ROW_H
L.SHARE_TOP = L.LIST_TOP + L.LIST_H + 12
L.FOOT_TOP = L.SHARE_TOP + 24 + 8
L.HEIGHT = L.FOOT_TOP + L.BUTTON_H + L.PAD
L.BODY_W = L.WIDTH - L.PAD * 2 - L.SCROLL_W - 6
L.COL_W = math.floor((L.BODY_W - L.COL_GAP) / 2)

--- "SPELL POWER" -> "Spell Power", "WEAPON DPS" -> "Weapon DPS".
function AegisPathfinder.StatLabel(stat)
	local Data = AegisPathfinder.ItemScoreData
	local text = string.lower(Data.labels[stat] or stat)
	text = string.gsub(text, "(%a)([%w']*)", function(a, b) return string.upper(a) .. b end)
	text = string.gsub(text, "Dps", "DPS")
	return text
end

local function trimNum(v)
	local s = string.format("%.2f", v or 0)
	s = string.gsub(s, "0+$", "")
	return (string.gsub(s, "%.$", ""))
end

--- A box for one number, in the theme: dark field, light text.
local function NumberBox(parent, width)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetWidth(width)
	box:SetHeight(20)
	box:SetAutoFocus(false)
	box:SetMaxLetters(8)
	box:SetJustifyH("RIGHT")
	box:SetTextInsets(4, 6, 0, 0)
	Theme:SetFont(box, "body", 12)
	box:SetTextColor(1, 1, 1)
	local bg = box:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(Theme.texture.solid)
	bg:SetAllPoints(box)
	bg:SetVertexColor(0, 0, 0, 0.55)
	box.bg = bg
	return box
end

--- Put the box's number into effect, or put back the one it had.
local function Commit(box)
	local v = tonumber(box:GetText())
	if v then
		AegisPathfinder.ItemScore:SetWeight(box.stat, v)
	else
		box:SetText(trimNum(box.shown))
	end
end

function AegisPathfinder:CreateGearPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderGear", UIParent)
	self.gearframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(L.WIDTH)
	frame:SetHeight(L.HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	Theme:Panel(frame, "panel")
	frame:Hide()
	Theme:Chrome(frame, "Gear: item score", Theme:PositionSaver("gearframe"))

	local spec = Theme:Dropdown(frame, 200, function(value)
		AegisPathfinder.ItemScore:SetSpec(value ~= "auto" and value or nil)
	end)
	spec:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.SPEC_TOP)
	frame.spec = spec

	local class = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(class, "display", 12)
	class:SetPoint("LEFT", spec, "RIGHT", 10, 0)
	class:SetPoint("RIGHT", frame, "RIGHT", -L.PAD, 0)
	class:SetJustifyH("RIGHT")
	Theme:TextColor(class, "textDim")
	frame.class = class

	local note = Theme:FinePrint(frame, L.WIDTH - L.PAD * 2)
	note:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.NOTE_TOP)
	frame.note = note

	local showAll = Theme:Switch(frame, "Show all stats", function(on)
		AegisPathfinder.ItemScore.Settings().showall = on
		frame.offset = 0
		AegisPathfinder:UpdateGearPanel()
	end)
	showAll:SetWidth(L.WIDTH - L.PAD * 2)
	showAll:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.SWITCH_TOP)
	frame.showAll = showAll

	-- The weights: a scrolling body, two columns of label and box.
	local scroll = CreateFrame("ScrollFrame", "AegisPathfinderGearScroll", frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.LIST_TOP)
	scroll:SetWidth(L.BODY_W)
	scroll:SetHeight(L.LIST_H)
	local body = CreateFrame("Frame", nil, scroll)
	body:SetWidth(L.BODY_W)
	body:SetHeight(1)
	scroll:SetScrollChild(body)
	local bar = Theme:ScrollBar(frame, L.SCROLL_W)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD + 2, -(L.LIST_TOP + L.SCROLL_W))
	bar:SetHeight(L.LIST_H - L.SCROLL_W * 2)
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	bar:SetScript("OnValueChanged", function() scroll:SetVerticalScroll(arg1 or 0) end)
	bar.up:SetScript("OnClick", function() bar:SetValue(math.max(0, bar:GetValue() - L.ROW_H)) end)
	bar.down:SetScript("OnClick", function()
		local _, hi = bar:GetMinMaxValues()
		bar:SetValue(math.min(hi, bar:GetValue() + L.ROW_H))
	end)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function()
		local _, hi = bar:GetMinMaxValues()
		local v = bar:GetValue() - (arg1 or 0) * L.ROW_H * 2
		if v < 0 then v = 0 elseif v > hi then v = hi end
		bar:SetValue(v)
	end)
	frame.scroll, frame.body, frame.bar = scroll, body, bar
	frame.cells = {}

	-- The weights as a string, and what to do with it.
	local share = CreateFrame("EditBox", nil, frame)
	share:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.SHARE_TOP)
	share:SetWidth(L.WIDTH - L.PAD * 2)
	share:SetHeight(24)
	share:SetAutoFocus(false)
	share:SetMaxLetters(2000)
	share:SetTextInsets(6, 6, 0, 0)
	Theme:SetFont(share, "body", 11)
	share:SetTextColor(1, 1, 1)
	local shareBg = share:CreateTexture(nil, "BACKGROUND")
	shareBg:SetTexture(Theme.texture.solid)
	shareBg:SetAllPoints(share)
	shareBg:SetVertexColor(0, 0, 0, 0.55)
	share:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	share:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	frame.share = share

	local third = math.floor((L.WIDTH - L.PAD * 2 - 12) / 3)
	local reset = Theme:PanelButton(frame, "Reset", third, L.BUTTON_H)
	reset:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.FOOT_TOP)
	reset:SetScript("OnClick", function()
		AegisPathfinder.ItemScore:ResetWeights()
		frame.message = "Back to the defaults."
		AegisPathfinder:UpdateGearPanel()
	end)
	local export = Theme:PanelButton(frame, "Export", third, L.BUTTON_H)
	export:SetPoint("LEFT", reset, "RIGHT", 6, 0)
	export:SetScript("OnClick", function()
		share:SetText(AegisPathfinder.ItemScore:Export())
		share:SetFocus()
		share:HighlightText()
		frame.message = "Copy it with Ctrl+C. OctoPawn reads it too."
		AegisPathfinder:UpdateGearPanel()
	end)
	local import = Theme:PanelButton(frame, "Import", third, L.BUTTON_H)
	import:SetPoint("LEFT", export, "RIGHT", 6, 0)
	import:SetScript("OnClick", function()
		local ok, why = AegisPathfinder.ItemScore:Import(share:GetText())
		frame.message = ok and "Imported." or why
		share:ClearFocus()
		AegisPathfinder:UpdateGearPanel()
	end)
	frame.reset, frame.export, frame.import = reset, export, import

	frame:SetScript("OnShow", function()
		this.offset = 0
		this.message = nil
		local guide = AegisPathfinder.objectiveframe
		if not Theme:RestorePosition(this, "gearframe") and guide and AegisPathfinder.GetQuadrant then
			local _, _, hhalf = AegisPathfinder.GetQuadrant(guide)
			this:ClearAllPoints()
			if hhalf == "LEFT" then
				this:SetPoint("TOPLEFT", guide, "TOPRIGHT", 8, 0)
			else
				this:SetPoint("TOPRIGHT", guide, "TOPLEFT", -8, 0)
			end
		end
		AegisPathfinder:UpdateGearPanel()
	end)
	frame:SetScript("OnHide", function() spec.list:Hide() end)

	AegisPathfinder.ItemScore:OnChange(function()
		if frame:IsShown() then AegisPathfinder:UpdateGearPanel() end
	end)
	table.insert(UISpecialFrames, "AegisPathfinderGear")
end

--- One stat's label and box, made the first time it is needed.
function AegisPathfinder:GearCell(stat)
	local frame = self.gearframe
	local cell = frame.cells[stat]
	if cell then return cell end
	cell = CreateFrame("Frame", nil, frame.body)
	cell:SetWidth(L.COL_W)
	cell:SetHeight(L.ROW_H)
	local label = cell:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(label, "body", 12)
	label:SetPoint("LEFT", cell, "LEFT", 0, 0)
	label:SetWidth(L.COL_W - L.BOX_W - 4)
	label:SetJustifyH("LEFT")
	Theme:TextColor(label, "text")
	label:SetText(AegisPathfinder.StatLabel(stat))
	local box = NumberBox(cell, L.BOX_W)
	box:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
	box.stat = stat
	box:SetScript("OnEnterPressed", function() Commit(this); this:ClearFocus() end)
	box:SetScript("OnEditFocusLost", function() Commit(this) end)
	box:SetScript("OnEscapePressed", function()
		this:SetText(trimNum(this.shown))
		this:ClearFocus()
	end)
	cell.label, cell.box = label, box
	frame.cells[stat] = cell
	return cell
end

--- The stats listed: those the spec weighs, or all of them.
function AegisPathfinder:GearStats(weights)
	local IS, Data = self.ItemScore, self.ItemScoreData
	local out = {}
	for _, stat in ipairs(Data.stats) do
		if IS.Settings().showall or (weights[stat] or 0) ~= 0 then table.insert(out, stat) end
	end
	return out
end

function AegisPathfinder:UpdateGearPanel()
	local frame = self.gearframe
	if not frame then return end
	local IS = self.ItemScore
	local class = IS:Class()
	local spec, why = IS:Spec()
	local weights = IS:Weights(class, spec)

	-- The spec picker: Auto, naming what Auto is now, then each spec.
	local detected = IS:DetectSpec(class)
	local items = { { value = "auto", label = "Auto (" .. IS:SpecLabel(detected or spec) .. ")" } }
	for _, s in ipairs(IS:Specs(class)) do table.insert(items, { value = s, label = IS:SpecLabel(s) }) end
	frame.spec:SetItems(items)
	frame.spec:SetValue(IS.Settings().spec or "auto")
	local className = UnitClass("player")
	frame.class:SetText(className or class)

	local whence = (why == "picked" and "the spec you picked")
		or (why == "talents" and "your talents")
		or "your class's usual levelling spec, until you have talents"
	local text = "Scoring as " .. IS:SpecLabel(spec) .. ", from " .. whence .. ". "
		.. (IS:IsCustom(class, spec) and "You are using your own weights." or "These are the default weights.")
	if frame.message then text = text .. "\n" .. frame.message end
	frame.note:SetText(text)
	frame.showAll:SetOn(IS.Settings().showall)

	-- The weights, two columns.
	for _, cell in pairs(frame.cells) do cell:Hide() end
	local stats = self:GearStats(weights)
	for i, stat in ipairs(stats) do
		local cell = self:GearCell(stat)
		local col, row = math.mod(i - 1, 2), math.floor((i - 1) / 2)
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", frame.body, "TOPLEFT", col * (L.COL_W + L.COL_GAP), -row * L.ROW_H)
		cell.box.shown = weights[stat] or 0
		cell.box:SetText(trimNum(cell.box.shown))
		cell:Show()
	end
	local rows = math.ceil(table.getn(stats) / 2)
	frame.body:SetHeight(math.max(1, rows * L.ROW_H))
	local over = math.max(0, rows * L.ROW_H - L.LIST_H)
	frame.bar:SetMinMaxValues(0, over)
	if frame.bar:GetValue() > over then frame.bar:SetValue(over) end
end

function AegisPathfinder:ToggleGearPanel()
	if not self.gearframe then self:CreateGearPanel() end
	if self.gearframe:IsShown() then
		self.gearframe:Hide()
	else
		self.gearframe:Show()
	end
end
