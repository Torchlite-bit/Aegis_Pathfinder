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

local MEDIA = "Interface\\AddOns\\Aegis_Pathfinder\\media\\"

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
	capTop      = MEDIA .. "cap-top",
	capBottom   = MEDIA .. "cap-bottom",
	tabFill     = MEDIA .. "tab-fill",
	tabBorder   = MEDIA .. "tab-border",
	circleFill  = MEDIA .. "circle-fill",
	circleBorder= MEDIA .. "circle-border",
	glow        = MEDIA .. "glow",
	shadow      = MEDIA .. "shadow",
	progress    = MEDIA .. "progress-fill",
	logo        = MEDIA .. "logo",
	wordmark    = MEDIA .. "wordmark",
	grip        = MEDIA .. "grip",
}

--[[ Chrome glyphs.

	The concept draws its own chrome with characters -- a hamburger, a close
	cross, arrows, chevrons, a tick, a map pin. The 1.12 font renders none of
	them, so each is a generated mask like every other shape here.
]]
Theme.glyph = {
	menu         = MEDIA .. "icons\\menu",
	close        = MEDIA .. "icons\\close",
	plus         = MEDIA .. "icons\\plus",
	arrowLeft    = MEDIA .. "icons\\arrow-left",
	arrowRight   = MEDIA .. "icons\\arrow-right",
	chevronLeft  = MEDIA .. "icons\\chevron-left",
	chevronRight = MEDIA .. "icons\\chevron-right",
	tick         = MEDIA .. "icons\\tick",
	bang         = MEDIA .. "icons\\bang",
	pin          = MEDIA .. "icons\\pin",
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

--[[ The same glyphs, keyed by action name rather than DSL letter.

	The frames read `AegisPathfinder.icons[action]` where action is the parsed
	name ("ACCEPT", "SETHEARTH"), so this is the table Core.lua publishes as
	that field. Before the reskin it held Blizzard icon paths, which is why the
	panels were still drawing stock quest-log art on a themed background.
]]
Theme.actionIconByName = {
	ACCEPT         = Theme.actionIcon.A,
	TURNIN         = Theme.actionIcon.T,
	COMPLETE       = Theme.actionIcon.C,
	NOTE           = Theme.actionIcon.N,
	RUN            = Theme.actionIcon.R,
	MAP            = Theme.actionIcon.R,
	HEARTH         = Theme.actionIcon.H,
	SETHEARTH      = Theme.actionIcon.h,
	FLY            = Theme.actionIcon.F,
	GETFLIGHTPOINT = Theme.actionIcon.f,
	BUY            = Theme.actionIcon.B,
	BOAT           = Theme.actionIcon.b,
	KILL           = Theme.actionIcon.K,
	GRIND          = Theme.actionIcon.G,
	USE            = Theme.actionIcon.U,
	TRAIN          = Theme.actionIcon.t,
	DIE            = Theme.actionIcon.D,
	PET            = Theme.actionIcon.P,
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

--[[ Strip that meets a panel edge.

	The concept clips its header and footer to the window's corner radius with
	overflow:hidden. 1.12 cannot clip, so a flat Strip laid across the top of a
	panel pokes square corners out past the rounded ones. This nine-slices a
	mask that is rounded on the edge it touches and square on the edge that
	meets the body. `edge` is "top" or "bottom".
]]
function Theme:CapStrip(frame, colorName, edge, alpha)
	return self:NineSlice(frame,
		edge == "bottom" and self.texture.capBottom or self.texture.capTop,
		"BACKGROUND", colorName or "panel2", alpha)
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
-- Built as a CheckButton, not a Button, so it keeps the widget API the old
-- Blizzard checkbox exposed (SetChecked, SetButtonState, Enable/Disable) and
-- existing call sites keep working. Only the artwork is ours.
function Theme:StepCheck(parent, size)
	local b = CreateFrame("CheckButton", nil, parent)
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

	-- Shadows the widget method so the artwork follows the checked state.
	function b:SetChecked(done)
		self.__checked = done and true or false
		if self.__checked then self.fill:Show() else self.fill:Hide() end
		Theme:Tint(self.ring, self.__checked and "accent" or "subtle")
	end
	function b:GetChecked() return self.__checked end

	--[[ Auto-detected completion reads differently from a manual tick.

		ClassicAPI's ID-keyed events are what make Zygor-style advancement
		possible on this client, and the UI says so: a step the addon can
		complete on its own wears a halo, so the player knows not to bother
		ticking it. A step only they can confirm has none.
	]]
	function b:SetAutoEligible(eligible)
		if eligible and not self.__checked then self.halo:Show() else self.halo:Hide() end
	end

	b:SetChecked(false)
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

--[[ Panel button.

	The concept has no plain button -- every action in it is a pill -- so this
	is `.pill` sized for a panel row. It shadows SetText/GetText so it drops
	straight into call sites that were built around UIPanelButtonTemplate, and
	uppercases like the concept does in CSS.
]]
function Theme:PanelButton(parent, label, width, height)
	local b = self:Pill(parent, label, width or 150, height or 22)

	function b:SetText(t) self.label:SetText(string.upper(t or "")) end
	function b:GetText() return self.label:GetText() end

	b:SetScript("OnEnter", function()
		if this.__active then return end
		this.fill:SetTint("tabbg")
		Theme:TextColor(this.label, "text")
	end)
	b:SetScript("OnLeave", function()
		if this.__active then return end
		this.fill:SetTint("panel3")
		Theme:TextColor(this.label, "textDim")
	end)

	return b
end

--[[ Close chip.

	The concept's header ✕. Replaces UIPanelCloseButton, whose art is Blizzard
	dialog chrome and whose built-in handler hides its own parent -- so the
	frame to hide is passed explicitly here rather than inferred.
]]
function Theme:CloseChip(parent, target)
	local b = self:ChipButton(parent, "close")
	b:SetScript("OnClick", function() (target or parent):Hide() end)
	return b
end

--[[ Category tab.

	The concept's branch-modal tab: uppercase display face, transparent until
	selected, and accent-on-panel when it is. Tabs sit directly on top of the
	list they filter, so the active one reads as continuous with it.
]]
function Theme:Tab(parent, label, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width or 88)
	b:SetHeight(height or 22)

	local fill = self:NineSlice(b, self.texture.tabFill, "BACKGROUND", "panel")
	fill:SetTint("tabbg")

	local fs = b:CreateFontString(nil, "OVERLAY")
	self:SetFont(fs, "display", 11)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	fs:SetText(string.upper(label or ""))
	self:TextColor(fs, "textDim")

	b.fill, b.label = fill, fs

	function b:SetActive(active)
		self.__active = active and true or false
		if self.__active then
			self.fill:SetTint("panel")
			Theme:TextColor(self.label, "accent")
		else
			self.fill:SetTint("tabbg")
			Theme:TextColor(self.label, "textDim")
		end
	end
	function b:IsActive() return self.__active end

	b:SetActive(false)
	return b
end

--[[ Badge.

	The small gold `XP` / grey `TPL` pill from the concept's tab bar. It marks
	whether a guide is authored content or a placeholder, which matters most in
	a list where the two sit side by side and otherwise look identical.
]]
function Theme:Badge(parent, text, kind)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(12)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(self.texture.tabFill)
	bg:SetAllPoints(f)

	local fs = f:CreateFontString(nil, "OVERLAY")
	self:SetFont(fs, "display", 9)
	fs:SetPoint("CENTER", f, "CENTER", 0, 0)

	f.bg, f.label = bg, fs

	function f:SetKind(kind, text)
		self.label:SetText(string.upper(text or kind or ""))
		if kind == "tpl" then
			Theme:Tint(self.bg, "subtle")
			self.label:SetTextColor(0.93, 0.93, 0.93)
		else
			Theme:Tint(self.bg, "goldDeep")
			self.label:SetTextColor(0.08, 0.07, 0.06)
		end
		self:SetWidth(math.max(22, self.label:GetStringWidth() + 10))
	end

	f:SetKind(kind, text)
	return f
end

--[[ Dungeon chip.

	Two stacked lines -- the short code above its full name -- which is how the
	concept fits fifteen dungeons into a panel without a scrollbar. A small
	blue dot marks a dungeon the loaded guide actually has steps for, so the
	grid distinguishes "I could run this" from "this guide knows about it".
]]
function Theme:Chip(parent, code, name, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width or 78)
	b:SetHeight(height or 34)

	local fill = self:NineSlice(b, self.texture.tabFill, "BACKGROUND", "panel3")
	local border = self:NineSlice(b, self.texture.tabBorder, "BORDER", "border")

	local codeText = b:CreateFontString(nil, "OVERLAY")
	self:SetFont(codeText, "display", 11)
	codeText:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -4)
	codeText:SetText(code)
	self:TextColor(codeText, "text")

	local nameText = b:CreateFontString(nil, "OVERLAY")
	self:SetFont(nameText, "body", 9)
	nameText:SetPoint("TOPLEFT", codeText, "BOTTOMLEFT", 0, -1)
	nameText:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	nameText:SetJustifyH("LEFT")
	nameText:SetText(name)
	self:TextColor(nameText, "textDim")

	local dot = b:CreateTexture(nil, "OVERLAY")
	dot:SetTexture(self.texture.circleFill)
	dot:SetWidth(5); dot:SetHeight(5)
	dot:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -4)
	self:Tint(dot, "blue")
	dot:Hide()

	b.fill, b.border, b.codeText, b.nameText, b.dot = fill, border, codeText, nameText, dot

	function b:SetActive(active)
		self.__active = active and true or false
		if self.__active then
			self.fill:SetTint("accent")
			-- Dark text on the accent fill, as the concept has it.
			self.codeText:SetTextColor(0.05, 0.10, 0.02)
			self.nameText:SetTextColor(0.05, 0.10, 0.02)
			Theme:Tint(self.dot, "border")
		else
			self.fill:SetTint("panel3")
			Theme:TextColor(self.codeText, "text")
			Theme:TextColor(self.nameText, "textDim")
			Theme:Tint(self.dot, "blue")
		end
	end
	function b:IsActive() return self.__active end

	--- Mark that the loaded guide has steps referencing this dungeon.
	function b:SetWired(wired)
		if wired then self.dot:Show() else self.dot:Hide() end
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

--[[ Bare glyph button.

	A clickable mask with no chrome of its own -- the concept's `.nav-btn` and
	`.navrow-arrow`, which are transparent until hovered and then take the
	accent. `size` is the glyph, `box` the click target around it.
]]
function Theme:GlyphButton(parent, glyphName, size, box)
	local b = CreateFrame("Button", nil, parent)
	size = size or 12
	b:SetWidth(box or (size + 8))
	b:SetHeight(box or (size + 8))

	local g = b:CreateTexture(nil, "ARTWORK")
	g:SetTexture(self.glyph[glyphName] or glyphName)
	g:SetWidth(size); g:SetHeight(size)
	g:SetPoint("CENTER", b, "CENTER", 0, 0)
	self:Tint(g, "textDim")

	b.glyph = g
	b.__idle, b.__hover = "textDim", "accent"

	--- Recolour for a button whose resting and hover tints differ from the
	--- nav-row default (the header chips sit on panel2 and go white).
	function b:SetTints(idle, hover)
		self.__idle, self.__hover = idle, hover
		Theme:Tint(self.glyph, idle)
	end

	b:SetScript("OnEnter", function() Theme:Tint(this.glyph, this.__hover) end)
	b:SetScript("OnLeave", function() Theme:Tint(this.glyph, this.__idle) end)

	return b
end

--[[ Header chip.

	The concept's `.chip-btn`: a 24px rounded square with a 1px border and a
	barely-there fill, carrying one glyph. Used for the hamburger and close
	controls in every panel header.
]]
function Theme:ChipButton(parent, glyphName, size)
	local b = self:GlyphButton(parent, glyphName, 10, size or 20)

	local fill = self:NineSlice(b, self.texture.tabFill, "BACKGROUND", "text", 0.04)
	self:NineSlice(b, self.texture.tabBorder, "BORDER", "border")
	b.fill = fill
	b:SetTints("textDim", "text")

	b:SetScript("OnEnter", function()
		this.fill:SetTint("text", 0.10)
		Theme:Tint(this.glyph, this.__hover)
	end)
	b:SetScript("OnLeave", function()
		this.fill:SetTint("text", 0.04)
		Theme:Tint(this.glyph, this.__idle)
	end)

	return b
end

--[[ Panel header.

	Every floating window in the concept wears the same one: a `--panel-2`
	strip with the PATHFINDER wordmark centred, optional chips either side, a
	1px rule beneath it, and the whole strip as the window's drag handle.

	The wordmark is a pre-rendered texture rather than a font string -- the
	concept sets .18em letter-spacing, which 1.12 font strings cannot do.
]]
function Theme:Header(frame, height)
	local h = CreateFrame("Frame", nil, frame)
	h:SetHeight(height or 30)
	h:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	h:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
	self:CapStrip(h, "panel2", "top")
	self:Divider(h, h, "BOTTOMLEFT", 0, 0)

	local mark = h:CreateTexture(nil, "ARTWORK")
	mark:SetTexture(self.texture.wordmark)
	mark:SetWidth(128); mark:SetHeight(16)
	mark:SetPoint("CENTER", h, "CENTER", 0, 0)
	self:Tint(mark, "text")

	h.wordmark = mark

	--- Make the window follow this header. The position is handed back through
	--- `onMoved` so the caller can persist it.
	function h:MakeDragHandle(target, onMoved)
		target:SetMovable(true)
		target:EnableMouse(true)
		self:EnableMouse(true)
		self:RegisterForDrag("LeftButton")
		self:SetScript("OnDragStart", function() target:StartMoving() end)
		self:SetScript("OnDragStop", function()
			target:StopMovingOrSizing()
			if onMoved then onMoved(target) end
		end)
		return self
	end

	return h
end

--[[ Subhead.

	The concept's `.subhead`: a `--tabbg` strip under the header naming what
	this particular window is, in small uppercase. The header carries the
	product, the subhead carries the page.
]]
function Theme:Subhead(frame, anchor, text)
	local s = CreateFrame("Frame", nil, frame)
	s:SetHeight(18)
	s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
	s:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
	self:Strip(s, "tabbg")
	self:Divider(s, s, "BOTTOMLEFT", 0, 0)

	local fs = s:CreateFontString(nil, "OVERLAY")
	self:SetFont(fs, "display", 10)
	fs:SetPoint("LEFT", s, "LEFT", 14, 0)
	fs:SetText(string.upper(text or ""))
	self:TextColor(fs, "textDim")

	s.label = fs
	return s
end

--[[ The whole window chrome in one call.

	Header with the wordmark, a close chip, the drag wiring, and -- when the
	window needs to name itself -- a subhead beneath. Returns both so callers
	can anchor their body to whichever is lowest.

	`onMoved` receives the frame after a drag so the caller can persist where
	it was dropped.
]]
function Theme:Chrome(frame, subtitle, onMoved)
	local header = self:Header(frame)
	header:MakeDragHandle(frame, onMoved)

	local close = self:CloseChip(header, frame)
	close:SetPoint("RIGHT", header, "RIGHT", -8, 0)

	local sub = subtitle and self:Subhead(frame, header, subtitle) or nil

	frame.header, frame.subhead = header, sub
	return header, sub
end

--- Persist a frame's position under `key` in the profile, as a drag callback.
function Theme:PositionSaver(key)
	return function(f)
		local point, _, _, x, y = f:GetPoint()
		local db = AegisPathfinder.db and AegisPathfinder.db.profile
		if not db then return end
		db[key .. "point"], db[key .. "x"], db[key .. "y"] = point, x, y
	end
end

--- Restore what PositionSaver stored. No saved position leaves the frame's
--- own anchors alone.
function Theme:RestorePosition(frame, key)
	local db = AegisPathfinder.db and AegisPathfinder.db.profile
	if not db or not db[key .. "point"] then return false end
	frame:ClearAllPoints()
	frame:SetPoint(db[key .. "point"], db[key .. "x"], db[key .. "y"])
	return true
end

-- Action-type icon. Falls back to the note glyph for an unknown code so a
-- malformed guide line still renders something.
function Theme:SetActionIcon(tex, code)
	tex:SetTexture(self.actionIcon[code] or self.actionIcon.N)
	self:Tint(tex, "textDim")
	return tex
end
