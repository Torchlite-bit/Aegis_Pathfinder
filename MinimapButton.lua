--[[
	MinimapButton.lua -- the button on the minimap's edge.

	It used to be FuBarPlugin's: Blizzard's quest-log book in the stock round
	minimap border, with a right-click that opened a Dewdrop menu of every
	setting -- the same settings the options panel now shows properly. This is
	the addon's own, drawn like the rest of it: the Aegis shield in accent on a
	dark disc with a hairline ring.

	Click shows or hides the guide, right-click opens the options panel, and
	dragging walks it round the minimap's edge. The Guide behaviour section of
	the options panel (or /apg minimapbutton) hides it.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local SIZE = 28
local RADIUS = 80           -- from the minimap's centre, where its buttons sit
local DEFAULT_ANGLE = 215   -- degrees anticlockwise from east: lower left

local button = CreateFrame("Button", "AegisPathfinderMinimapButton", Minimap)
AegisPathfinder.minimapbutton = button
button:SetWidth(SIZE)
button:SetHeight(SIZE)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:Hide()

local disc = button:CreateTexture(nil, "BACKGROUND")
disc:SetTexture(Theme.texture.circleFill)
disc:SetAllPoints(button)
Theme:Tint(disc, "panel2")

local ring = button:CreateTexture(nil, "BORDER")
ring:SetTexture(Theme.texture.circleBorder)
ring:SetAllPoints(button)
Theme:Tint(ring, "subtle")

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(Theme.texture.logo)
icon:SetWidth(16)
icon:SetHeight(16)
icon:SetPoint("CENTER", button, "CENTER", 0, 0)
Theme:Tint(icon, "accent")

button.disc, button.ring, button.icon = disc, ring, icon

--- Put the button at `angle` degrees round the minimap's edge.
local function Place(angle)
	local r = math.rad(angle)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(r) * RADIUS, math.sin(r) * RADIUS)
end

-- While dragging: the angle from the minimap's centre to the cursor.
local function Dragging()
	local mx, my = Minimap:GetCenter()
	if not mx then return end
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	AegisPathfinder.db.profile.minimapangle = angle
	Place(angle)
end

button:SetScript("OnDragStart", function()
	Theme:HideTip(this)
	this:SetScript("OnUpdate", Dragging)
end)
button:SetScript("OnDragStop", function()
	this:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function()
	if arg1 == "RightButton" then
		AegisPathfinder:ToggleConfigPanel()
	else
		AegisPathfinder:ToggleObjectivePanel()
	end
end)

-- Pressed: the shield sinks a pixel, as a button face would.
button:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", button, "CENTER", 1, -1) end)
button:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", button, "CENTER", 0, 0) end)

button:SetScript("OnEnter", function()
	Theme:Tint(ring, "accent")
	Theme:Tint(icon, "accentGlow")
	Theme:ShowTip(this, "LEFT", "Aegis: Pathfinder", {
		"Click to show or hide the guide",
		"Right-click for settings",
		"Drag to move this button",
	})
end)
button:SetScript("OnLeave", function()
	Theme:Tint(ring, "subtle")
	Theme:Tint(icon, "accent")
	Theme:HideTip(this)
end)

--- Show or hide the button to match the setting, where it was left.
function AegisPathfinder:UpdateMinimapButton()
	Place(self.db.profile.minimapangle or DEFAULT_ANGLE)
	if self.db.char.showminimapbutton == false then
		button:Hide()
	else
		button:Show()
	end
end

function AegisPathfinder:ToggleMinimapButton()
	self.db.char.showminimapbutton = self.db.char.showminimapbutton == false
	self:UpdateMinimapButton()
	if self.RefreshConfigPanel and self.optionsframe then self:RefreshConfigPanel() end
end
