--[[
	Theme.lua -- the shared visual language for AEGIS: Pathfinder.

	Every colour, font and texture the UI uses is declared here and nowhere
	else, so a palette change is one edit in one file. Values come straight
	from the design concept's CSS custom properties; the hex strings are kept
	verbatim so they can be diffed against it.

	Textures are white masks tinted at runtime with SetVertexColor (see
	Tools/make_assets.py), which is why one 32x32 rounded-rect serves every
	panel, band, pill and tab in the addon.
]]

local MEDIA = "Interface\\AddOns\\AegisPathfinder\\media\\"

AegisPathfinder.Theme = {}
local Theme = AegisPathfinder.Theme

Theme.media = MEDIA

-- "52c722" -> 0.322, 0.780, 0.133
local function hex(s)
	return {
		tonumber(string.sub(s, 1, 2), 16) / 255,
		tonumber(string.sub(s, 3, 4), 16) / 255,
		tonumber(string.sub(s, 5, 6), 16) / 255,
	}
end

Theme.color = {
	bg1        = hex("12160f"),
	bg2        = hex("0a0d09"),
	panel      = hex("202020"),   -- --panel:      body of a floating window
	panel2     = hex("111111"),   -- --panel-2:    header / footer strips
	panel3     = hex("1a1a1a"),   -- --panel-3
	tabbg      = hex("3b3b3b"),   -- --tabbg:      tab strip and nav rows
	accent     = hex("52c722"),
	accentDeep = hex("2e850e"),
	accentGlow = hex("8fe066"),
	gold       = hex("ffed71"),
	goldDeep   = hex("e8b93a"),
	danger     = hex("e8636b"),
	bandGreen  = hex("2e850e"),   -- step satisfied
	bandRed    = hex("7c1820"),   -- step outstanding
	blue       = hex("5b9fd6"),
	text       = hex("ffffff"),
	textDim    = hex("c7c7bd"),
	border     = hex("050505"),
	subtle     = hex("545454"),   -- unchecked control outlines
}

Theme.texture = {
	solid       = MEDIA .. "solid",
	panelFill   = MEDIA .. "panel-fill",
	panelBorder = MEDIA .. "panel-border",
	pillFill    = MEDIA .. "pill-fill",
	pillBorder  = MEDIA .. "pill-border",
	tabFill     = MEDIA .. "tab-fill",
	circleFill  = MEDIA .. "circle-fill",
	circleBorder= MEDIA .. "circle-border",
	glow        = MEDIA .. "glow",
	shadow      = MEDIA .. "shadow",
	progress    = MEDIA .. "progress-fill",
	navArrow    = MEDIA .. "nav-arrow",
	logo        = MEDIA .. "logo",
	wordmark    = MEDIA .. "wordmark",
}

Theme.font = {
	display  = MEDIA .. "fonts\\Rajdhani-Bold.ttf",
	display2 = MEDIA .. "fonts\\Rajdhani-SemiBold.ttf",
	body     = MEDIA .. "fonts\\Inter-Regular.ttf",
	body2    = MEDIA .. "fonts\\Inter-SemiBold.ttf",
}

-- Action code -> icon texture. Codes are the guide DSL's (see
-- docs/GUIDE_AUTHORING.md). ACCEPT and TURNIN deliberately share a glyph, as
-- they do in the concept -- the coloured band tells them apart. KILL and GRIND
-- share one too; DIE gets crossbones so it is never mistaken for a kill step.
Theme.actionIcon = {
	A = MEDIA .. "icons\\accept",
	T = MEDIA .. "icons\\turnin",
	C = MEDIA .. "icons\\complete",
	N = MEDIA .. "icons\\note",
	R = MEDIA .. "icons\\run",
	H = MEDIA .. "icons\\hearth",
	h = MEDIA .. "icons\\sethearth",
	F = MEDIA .. "icons\\fly",
	f = MEDIA .. "icons\\getflightpoint",
	B = MEDIA .. "icons\\buy",
	b = MEDIA .. "icons\\boat",
	K = MEDIA .. "icons\\kill",
	G = MEDIA .. "icons\\grind",
	U = MEDIA .. "icons\\use",
	t = MEDIA .. "icons\\train",
	D = MEDIA .. "icons\\die",
	P = MEDIA .. "icons\\pet",
}

Theme.CORNER = 10        -- --radius:10px

-- Slice boundaries inside the 32px rounded-rect masks: the first and last
-- 10px are corners, the middle 12px stretches.
local S0, S1 = 10 / 32, 22 / 32

--[[ Colour helpers ]]

function Theme:Tint(tex, name, alpha)
	local c = self.color[name] or name
	tex:SetVertexColor(c[1], c[2], c[3], alpha or 1)
	return tex
end

function Theme:TextColor(fs, name)
	local c = self.color[name] or name
	fs:SetTextColor(c[1], c[2], c[3])
	return fs
end

--[[ Typography ]]

-- Applies a bundled face, falling back to the client font if it is rejected.
-- SetFont returns false when the file cannot be loaded, which is the only way
-- to detect a bad font on 1.12.
function Theme:SetFont(fs, role, size, flags)
	local path = self.font[role]
	if not path or not fs:SetFont(path, size, flags) then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
		return false
	end
	return true
end

--[[ Nine-slice panels ]]

-- Builds a rounded panel out of a 32x32 mask: four fixed corners, four edges
-- that stretch along one axis, and a stretched centre. The 1.12 client has no
-- rounded-rectangle primitive, so this is how the concept's --radius survives.
function Theme:NineSlice(frame, file, layer, colorName, alpha)
	local parts, t = {}, nil
	local C = self.CORNER

	local function piece(name, coords)
		t = frame:CreateTexture(nil, layer or "BACKGROUND")
		t:SetTexture(file)
		t:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		self:Tint(t, colorName, alpha)
		parts[name] = t
		return t
	end

	local tl, tr = piece("tl", { 0, S0, 0, S0 }), piece("tr", { S1, 1, 0, S0 })
	local bl, br = piece("bl", { 0, S0, S1, 1 }), piece("br", { S1, 1, S1, 1 })
	for _, c in pairs({ tl, tr, bl, br }) do
		c:SetWidth(C); c:SetHeight(C)
	end
	tl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

	local top = piece("top", { S0, S1, 0, S0 })
	top:SetHeight(C)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
	top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)

	local bottom = piece("bottom", { S0, S1, S1, 1 })
	bottom:SetHeight(C)
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)

	local left = piece("left", { 0, S0, S0, S1 })
	left:SetWidth(C)
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)

	local right = piece("right", { S1, 1, S0, S1 })
	right:SetWidth(C)
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)

	local center = piece("center", { S0, S1, S0, S1 })
	center:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT", 0, 0)
	center:SetPoint("BOTTOMRIGHT", br, "TOPLEFT", 0, 0)

	function parts:SetTint(name, a)
		for _, tex in pairs(self) do
			if type(tex) == "table" and tex.SetVertexColor then
				Theme:Tint(tex, name, a)
			end
		end
	end

	return parts
end

--[[ Composite widgets ]]

-- A floating window: tinted fill, 1px border in the concept's near-black, and
-- a soft drop shadow standing in for CSS box-shadow.
function Theme:Panel(frame, colorName, withShadow)
	local skin = {}
	if withShadow ~= false then
		local shadow = frame:CreateTexture(nil, "BACKGROUND")
		shadow:SetTexture(self.texture.shadow)
		shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 7)
		shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 7, -9)
		shadow:SetVertexColor(0, 0, 0, 0.62)
		skin.shadow = shadow
	end
	skin.fill = self:NineSlice(frame, self.texture.panelFill, "BACKGROUND", colorName or "panel")
	skin.border = self:NineSlice(frame, self.texture.panelBorder, "BORDER", "border")
	return skin
end

-- Flat strip used for headers, footers, tab bars and nav rows.
function Theme:Strip(frame, colorName, alpha)
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetTexture(self.texture.solid)
	t:SetAllPoints(frame)
	self:Tint(t, colorName or "panel2", alpha)
	return t
end

-- 1px rule in the concept's border colour.
function Theme:Divider(parent, anchor, relPoint, x, y, width)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetTexture(self.texture.solid)
	t:SetHeight(1)
	if width then t:SetWidth(width) end
	t:SetPoint("TOPLEFT", anchor, relPoint or "BOTTOMLEFT", x or 0, y or 0)
	if not width then t:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, y or 0) end
	self:Tint(t, "border")
	return t
end

-- Progress track + gradient fill. SetWidth on the returned fill drives it.
function Theme:ProgressBar(parent, height)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(height or 5)

	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(self.texture.solid)
	track:SetAllPoints(bar)
	track:SetVertexColor(0, 0, 0, 0.4)

	local fill = bar:CreateTexture(nil, "ARTWORK")
	fill:SetTexture(self.texture.progress)
	fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	fill:SetWidth(1)

	bar.track, bar.fill = track, fill

	-- ratio in 0..1
	function bar:SetProgress(ratio)
		if not ratio or ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
		local w = self:GetWidth()
		if not w or w <= 0 then w = 1 end
		if ratio <= 0 then
			self.fill:Hide()
		else
			self.fill:Show()
			self.fill:SetWidth(w * ratio)
		end
	end

	return bar
end

-- The step checkbox: a ring that fills with accent when complete. Distinct
-- states for auto-detected vs manually ticked completion are handled by
-- SetAutoEligible / the glow, not by the check itself.
function Theme:StepCheck(parent, size)
	local b = CreateFrame("Button", nil, parent)
	size = size or 15
	b:SetWidth(size); b:SetHeight(size)

	local ring = b:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(self.texture.circleBorder)
	ring:SetAllPoints(b)
	self:Tint(ring, "subtle")

	local fill = b:CreateTexture(nil, "ARTWORK")
	fill:SetTexture(self.texture.circleFill)
	fill:SetAllPoints(b)
	self:Tint(fill, "accent")
	fill:Hide()

	-- Ring shown behind the check while ClassicAPI can complete this step for
	-- the player. The concept uses it to say "you do not have to tick this".
	local halo = b:CreateTexture(nil, "BACKGROUND")
	halo:SetTexture(self.texture.glow)
	halo:SetPoint("CENTER", b, "CENTER", 0, 0)
	halo:SetWidth(size * 2.6); halo:SetHeight(size * 2.6)
	self:Tint(halo, "accent", 0.32)
	halo:Hide()

	b.ring, b.fill, b.halo = ring, fill, halo

	function b:SetChecked2(done)
		if done then self.fill:Show() else self.fill:Hide() end
		Theme:Tint(self.ring, done and "accent" or "subtle")
	end

	function b:SetAutoEligible(eligible)
		if eligible then self.halo:Show() else self.halo:Hide() end
	end

	return b
end

-- Uppercase display-face pill used by the route-pack selector.
function Theme:Pill(parent, label, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width or 90); b:SetHeight(height or 22)

	local fill = self:NineSlice(b, self.texture.pillFill, "BACKGROUND", "panel3")
	local border = self:NineSlice(b, self.texture.pillBorder, "BORDER", "border")

	local fs = b:CreateFontString(nil, "OVERLAY")
	self:SetFont(fs, "display", 11)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	fs:SetText(string.upper(label or ""))
	self:TextColor(fs, "textDim")

	b.label, b.fill, b.border = fs, fill, border

	function b:SetActive(active)
		if active then
			self.fill:SetTint("accent")
			self.label:SetTextColor(0.05, 0.10, 0.02)
		else
			self.fill:SetTint("panel3")
			Theme:TextColor(self.label, "textDim")
		end
	end

	b:SetActive(false)
	return b
end

-- Coloured full-width band for ACCEPT / TURNIN steps: red while outstanding,
-- green once satisfied, exactly as the concept renders them.
function Theme:Band(parent, height)
	local f = CreateFrame("Button", nil, parent)
	f:SetHeight(height or 26)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(self.texture.solid)
	bg:SetAllPoints(f)
	self:Tint(bg, "bandRed")

	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(13); icon:SetHeight(13)
	icon:SetPoint("LEFT", f, "LEFT", 10, 0)

	local fs = f:CreateFontString(nil, "OVERLAY")
	self:SetFont(fs, "body", 12)
	fs:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	fs:SetPoint("RIGHT", f, "RIGHT", -8, 0)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1)

	f.bg, f.icon, f.label = bg, icon, fs

	function f:SetDone(done)
		Theme:Tint(self.bg, done and "bandGreen" or "bandRed")
	end

	return f
end

-- Action-type icon. Falls back to the note glyph for an unknown code so a
-- malformed guide line still renders something.
function Theme:SetActionIcon(tex, code)
	tex:SetTexture(self.actionIcon[code] or self.actionIcon.N)
	self:Tint(tex, "textDim")
	return tex
end
