--[[
	MaterialsFrame.lua -- what you still need to buy or gather.

	The reference document the profession guides came from prints one shopping
	list per profession, totalled from skill 1. That is the wrong number for
	anyone who is already part-way through: it counts reagents for crafts you
	have done.

	This totals the reagents the *remaining* steps call for, from wherever you
	currently are, which is the number you actually want standing at the
	auction house. AegisPathfinder:GetRemainingMaterials does the arithmetic;
	this shows it.

	It works for any guide carrying |MATS| tags, not only profession guides --
	there is nothing profession-specific in the panel itself.
]]

local AegisPathfinder = AegisPathfinder
local ww = WidgetWarlock
local Theme = AegisPathfinder.Theme

local ROWS = 18
local ROW_H = 16
local PAD = 12
local WIDTH = 260

-- Header plus subhead, the concept's chrome on every window.
local CHROME_TOP = 30 + 18

local rows = {}
local offset = 0

function AegisPathfinder:CreateMaterialsPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderMaterials", UIParent)
	self.materialsframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(WIDTH)
	frame:SetHeight(CHROME_TOP + PAD * 2 + 26 + ROWS * ROW_H)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	Theme:Panel(frame, "panel")
	frame:Hide()

	-- The whole window drags by its header now, like every other panel, rather
	-- than by any pixel of its body.
	Theme:Chrome(frame, "Materials", Theme:PositionSaver("materialsframe"))

	local subtitle = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(subtitle, "body", 10)
	subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(CHROME_TOP + 5))
	subtitle:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	subtitle:SetJustifyH("LEFT")
	Theme:TextColor(subtitle, "textDim")
	frame.subtitle = subtitle

	Theme:Divider(frame, subtitle, "BOTTOMLEFT", 0, -6)

	for i = 1, ROWS do
		local row = CreateFrame("Frame", nil, frame)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(CHROME_TOP + 26 + (i - 1) * ROW_H))
		row:SetPoint("RIGHT", frame, "RIGHT", -PAD - 18, 0)

		local qty = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(qty, "display", 11)
		qty:SetPoint("LEFT", row, "LEFT", 0, 0)
		qty:SetWidth(38)
		qty:SetJustifyH("RIGHT")
		Theme:TextColor(qty, "accent")

		local name = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(name, "body", 11)
		name:SetPoint("LEFT", qty, "RIGHT", 8, 0)
		name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		name:SetJustifyH("LEFT")
		Theme:TextColor(name, "text")

		row.qty, row.name = qty, name
		rows[i] = row
	end

	local slider = CreateFrame("Slider", "AegisPathfinderMaterialsSlider", frame,
		"UIPanelScrollBarTemplate")
	slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -(CHROME_TOP + 26))
	slider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 12)
	slider:SetMinMaxValues(0, 0)
	slider:SetValueStep(1)
	slider:SetWidth(16)
	slider:SetValue(0)
	slider:SetScript("OnValueChanged", function()
		if slider.updating then return end
		offset = math.floor(arg1 or slider:GetValue() or 0)
		AegisPathfinder:UpdateMaterialsPanel()
	end)
	frame.slider = slider

	frame:SetScript("OnShow", function()
		offset = 0
		AegisPathfinder:UpdateMaterialsPanel()
	end)

	table.insert(UISpecialFrames, "AegisPathfinderMaterials")
end

--- Alphabetical: this is a list you read while looking for one item, not a
--- ranking. Quantity-ordered would bury Peacebloom under Dreamfoil.
local function ByName(a, b)
	return a.item < b.item
end

function AegisPathfinder:UpdateMaterialsPanel()
	local frame = self.materialsframe
	if not frame or not frame:IsVisible() then return end

	local list = self:GetRemainingMaterials()

	if not list then
		frame.subtitle:SetText("This guide lists no materials.")
		for _, row in ipairs(rows) do
			row.qty:SetText("")
			row.name:SetText("")
		end
		frame.slider:Hide()
		return
	end

	table.sort(list, ByName)

	local total = table.getn(list)
	local guide = self.db.char.currentguide or "guide"
	frame.subtitle:SetText(string.format("%d still needed for %s", total, guide))

	local maxOffset = math.max(0, total - ROWS)
	if offset > maxOffset then offset = maxOffset end
	if offset < 0 then offset = 0 end

	if maxOffset > 0 then
		frame.slider:Show()
		frame.slider.updating = true
		frame.slider:SetMinMaxValues(0, maxOffset)
		frame.slider:SetValue(offset)
		frame.slider.updating = nil
	else
		frame.slider:Hide()
	end

	for i, row in ipairs(rows) do
		local entry = list[i + offset]
		if entry then
			row.qty:SetText(entry.need .. "x")
			row.name:SetText(entry.item)
		else
			row.qty:SetText("")
			row.name:SetText("")
		end
	end
end

function AegisPathfinder:ToggleMaterialsPanel()
	if not self.materialsframe then
		self:CreateMaterialsPanel()
	end

	if self.materialsframe:IsShown() then
		self.materialsframe:Hide()
	else
		self.materialsframe:Show()
	end
end
