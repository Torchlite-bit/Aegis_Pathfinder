# UI specification

How the design concept maps onto 1.12 frames. The concept is a web page; this
records what each part of it becomes in an addon that has no CSS, no rounded
rectangles, no web fonts and no emoji.

The concept itself is kept in `docs/design/` for reference. It is a design
artifact — it is not referenced from the `.toc` and does not ship.

## Design tokens

Every value below lives in `Theme.lua` and nowhere else. The hex strings are
the concept's CSS custom properties, kept verbatim so they can be diffed
against it.

| Concept | `Theme.color` | Hex | Used for |
|---|---|---|---|
| `--panel` | `panel` | `202020` | Window bodies |
| `--panel-2` | `panel2` | `111111` | Headers, footers |
| `--panel-3` | `panel3` | `1a1a1a` | In-town steps, inactive pills |
| `--tabbg` | `tabbg` | `3b3b3b` | Tab strips, nav rows |
| `--accent` | `accent` | `52c722` | Progress, active states, meta text |
| `--accent-deep` | `accentDeep` | `2e850e` | Gradient start, branch pill |
| `--accent-glow` | `accentGlow` | `8fe066` | Gradient end, pill text |
| `--gold` / `--gold-deep` | `gold` / `goldDeep` | `ffed71` / `e8b93a` | Branch tag |
| `--band-green` / `--band-red` | `bandGreen` / `bandRed` | `2e850e` / `7c1820` | Step bands |
| `--danger` | `danger` | `e8636b` | Errors |
| `--blue` | `blue` | `5b9fd6` | Wired-dungeon marker |
| `--text` / `--text-dim` | `text` / `textDim` | `ffffff` / `c7c7bd` | Text |
| `--border` | `border` | `050505` | 1px borders |
| — | `subtle` | `545454` | Unchecked control rings |

Fonts: Rajdhani (display) and Inter (body), bundled under `media/fonts/`.
`Theme:SetFont` falls back to the client font if a face is rejected, so a bad
TTF degrades to readable text rather than an empty UI.

## Techniques

**Rounded corners.** The client has no rounded-rect primitive. `Theme:NineSlice`
builds one from a 32×32 mask: four 10px corners at fixed size, four edges that
stretch along one axis, and a stretched centre, positioned with `SetTexCoord`.
`Theme.CORNER` and the slice constants must stay in step with the radius in
`Tools/make_assets.py`.

**Colour.** Shapes are white masks tinted with `SetVertexColor`, so one
rounded-rect serves every panel, tab, pill and band, and a palette change is a
Lua edit rather than a re-render.

**Shadows.** `box-shadow` becomes `shadow.tga`, nine-sliced 7px outside the
frame (`Theme.SHADOW_GEOM`: 18px corners, no middle piece). It is a ring:
darkest at the panel's edge, gone 7px out, and transparent inside. That last
part matters. The shadow shares the fill's `BACKGROUND` layer, and 1.12 does
not order two textures within a layer, so the first version -- a stretched
blob, darkest in its middle -- drew a dark square straight through the guide
panel. `Tools/verify.py` fails a shadow that is not clear in the middle.

**Icons.** The concept uses emoji, which the 1.12 font cannot render. Each of
the 17 action codes gets a generated 32×32 glyph instead. They are silhouettes,
not line art, because they render at roughly 14px where thin strokes vanish.

The frames index these by parsed action name (`ACCEPT`, `SETHEARTH`), not by
DSL letter, so `Theme.actionIconByName` is the table `AegisPathfinder.icons`
actually resolves through. Before that existed the panels were still drawing
stock quest-log art -- bevelled, bordered, a different palette -- on top of
the themed background.

**Chrome glyphs.** The concept draws its own chrome with characters the client
font has no glyph for: `☰ ✕ + ← → ‹ › ✓ ! 📍`. Each is generated the same way
and lives in `Theme.glyph`.

**Gradients.** Baked into the texture (`progress-fill.tga`) — there is no
runtime gradient.

## Surfaces

### Navigation callout -- `NavCallout.lua`

The concept's signature element, and the only surface with no window around it:
`background` and `box-shadow` were dropped, so the arrow, the instruction and
the distance float directly on the game world.

That is what makes the text shadows load-bearing rather than decorative. The
concept sets `text-shadow: 0 1px 3px rgba(0,0,0,.9), 0 1px 8px rgba(0,0,0,.7)`;
1.12 offers one hard offset copy through `SetShadowOffset` / `SetShadowColor`,
so it is drawn at full opacity to carry the same weight. Without it the
instruction disappears over snow.

**Rotation.** 1.12 has no `SetRotation`. The eight-argument form of
`SetTexCoord` maps a texture onto an arbitrary quad, which is how vanilla
addons turned minimap arrows, so `AegisPathfinder.RotateTexture` rotates the
four corners about (0.5, 0.5). The arrow art is centred in its square for the
same reason -- a rotation samples outside 0..1 at the corners, and off-centre
art wobbles as it turns.

**Bearing** comes from `AegisPathfinder:GetWaypointBearing` in
`Navigation.lua`, which is a compass bearing to the stored waypoint minus the
player's facing. Distance needs Astrolabe's zone dimension tables to turn map
percentages into yards; Astrolabe ships with both TomTom and pfQuest, so in
practice it is there whenever a provider is. When it is not, the arrow still
points and the distance stays blank -- an invented number would be worse.

With no provider, no waypoint, or the waypoint in another zone, the callout
hides. An arrow that is confidently wrong is worse than no arrow.

### The status card -- deleted

The concept removed it: every `.sb-*` rule and the whole `#statusbar` block are
gone, and `renderStatusBar()` became `renderNavCallout()`. `StatusFrame.lua`
went with it.

Almost nothing in that file was the card, though. `UpdateStatusFrame` is the
scan that walks the step list, decides which step you are on, auto-completes
what ClassicAPI can resolve, drives the waypoint and loads the next guide when
one runs out. That is now `GuideEngine.lua`, along with the use-item button --
a surface of its own, for `|U|` steps, which the concept does not show and
which had no business being deleted with the card.

What the card's meta row used to paint is now `GetStepMeta`, which returns the
quest id, a profession step's live skill range, coordinates buried in the note,
and any data-source warning, and lets the caller decide how to show them.

### Window chrome -- `Theme:Chrome`

Every floating window in the concept is the same `.chrome-frame`, so one call
builds all of it:

| Concept element | Implementation |
|---|---|
| `.panel-header` | `Theme:Header` -- a `panel-2` strip, the wordmark centred, a 1px rule beneath |
| `.panel-wordmark` | `wordmark.tga`, not a font string: the concept sets `.18em` letter-spacing, which 1.12 font strings cannot do |
| `.chip-btn` | `Theme:ChipButton` -- a 20px rounded square carrying one glyph |
| `.subhead` | `Theme:Subhead` -- a `tabbg` strip naming the window in small uppercase |
| `cursor:grab` on the header | `MakeDragHandle`: `SetMovable` + `RegisterForDrag`, with the drop position saved per profile |

The header's corners are a problem the concept does not have. It clips its
strips to the window radius with `overflow:hidden`; 1.12 cannot clip, so a
flat strip across the top of a rounded panel pokes square corners out past it.
`Theme:CapStrip` nine-slices `cap-top.tga` / `cap-bottom.tga` instead --
rounded on the edge that meets the panel, square on the edge that meets the
body.

A window that has been dragged stays where it was put: `Theme:PositionSaver`
records the drop, `Theme:RestorePosition` re-applies it, and the "snap beside
the status card" logic in each panel's `OnShow` only runs when nothing was
saved.

**Stacking.** The concept's windows are DOM elements, and one simply paints
over another. 1.12 draws a whole strata in frame-level order, across every
window at once, and a frame starts one level above its parent -- so two
windows built at the same level have their headers at the same level, their
chips at the same level, and so on down. Overlap them and they interleave:
one window's close chip and scrollbar drawn through the other's body.

`Theme:RegisterWindow` (which `Theme:Chrome` calls, and the objectives panel
calls itself) keeps the windows in bands instead. Showing a window, or
grabbing its header, moves its whole frame tree above every other open
window's, preserving each frame's height within its own window, and packs the
rest back down beneath it from a fixed base -- so levels are rebuilt rather
than raised, and never climb toward the client's ceiling. `SetToplevel` covers
clicks on a window's rows and buttons, where the client raises the window
itself; the order it leaves is read back from the roots' levels on the next
restack. `Tools/verify.py` fails a file that puts more windows in `DIALOG`
than it registers.

### Objectives panel -- `ObjectivesFrame.lua`

The concept's `#objectives`, and now the addon's only window: header, tab bar,
nav row, a 4px progress rule, the step list, and the footer.

**Panels open beside the guide, not instead of it.** The ☰ chip used to hide
the panel before showing Config, so opening settings closed what you were
reading; the concept has `#options` at `right:456px` and `#objectives` at
`right:40px`, both on screen. Same for the `+` and the guide list.

**Two modes**, behind the header's third chip. Focus -- the default -- shows
the one step you are on and nothing else, which is how you follow a guide;
overview shows the whole list, which is how you look ahead. The chip takes
`.chip-btn.active` (accent fill, dark glyph) while overview is on, so the panel
says which of the two you are looking at.

**The objective meter** (`.zobjective`) sits under the single step in focus
mode: what the quest wants, how much of it you have, and a bar. It is quest-log
leaderboard text -- "Kobold Vermin slain: 3/8" -- parsed into its three parts.
An objective with nothing countable in it ("Speak to Marshal Dughan") gets no
meter rather than an empty one. Overview mode folds the same text into the
step's note line instead, as the concept does.

**Width.** The concept's 396px (`.panel{width:396px}`). It used to open at
630px, and every earlier version saved the width on any resize, the first
layout included -- so a stored 630 is read as "never chosen" and dropped. Only
the grip saves a width now. At 396 a data-source warning in the footer does
not fit beside the step count, so it stops short of the count on one line and
the footer's tooltip carries the whole of it.

**Height follows the content.** The concept's panel is `height:auto` under
`max-height: min(70vh, 600px)`, with `.steps-list` `flex:0 0 auto` in focus
mode and `flex:1 1 auto` in overview. So `LayoutPanelHeight` makes the panel
exactly as tall as what it shows, up to a cap: in focus mode, the one step
(with its note in full) and the meter; in overview, the list, which for any
real guide means the cap. The height is never saved -- only the width and the
cap are the player's.

The resize grip is the concept's `makeResizable`: sideways sets the width
(320px minimum), down or up sets the cap (260px minimum), never the height.
It does its own sizing from `GetCursorPosition` rather than `StartSizing`. The
client's sizing re-anchors the frame as it sees fit, and a panel left anchored
by its top and its bottom ignores `SetHeight`, which is how the panel once got
stuck at a dragged size, unable to follow the step or be moved. A height
saved by that older version becomes the cap.

Every window is pinned by its top-left corner after a drag (`Theme:AnchorTopLeft`),
so it grows downward and has one anchor to save, and `PositionSaver` keeps the
relative point as well as the offsets. Windows are clamped to the screen.
`/apg resetpanels` forgets every saved position and size.

**The footer** carries live state rather than the slash-command hint it used
to: the current step's quest id on the left in accent, how far through the
guide you are on the right. A data-source warning outranks the id and turns the
slot red -- it is the most likely reason a waypoint points at nothing, and it
otherwise fails silently.

Rows are 44px slots holding either of the concept's two row models:

| Concept | Implementation |
|---|---|
| `.zrow` | Dot, action glyph, title, and the note beneath it in `#8f8f86` |
| `.zrow.active` | A faint wash plus the left accent bar |
| `.zrow.done` | Dimmed |
| `.zband.red` / `.zband.green` | `Theme:Band` laid over the whole slot |

A step becomes a band only when it is an `ACCEPT` or `TURNIN` **and** is either
the current step or already satisfied -- the same rule as the concept's
`bandable && (st.done || idx === state.stepIndex)`. Any other quest hand-off
further down the list stays an ordinary row, so the list does not turn into a
wall of colour.

In overview the slots are a fixed height rather than the concept's
content-height rows: these guides run to a few hundred steps and the list
scrolls by step, which needs a row height known in advance, so title and note
are clipped to one line each and the full note is in the row's tooltip. Focus
mode shows one step and has the room, so its row grows to show the whole note
(a second, wrapping font string, measured after it is set), and runs to the
panel's edge since there is no scrollbar beside it.

### Shared widgets -- `WidgetWarlock.lua`

Rather than edit every call site, the two shared widget helpers build themed
widgets:

| Helper | Now returns |
|---|---|
| `SummonCheckBox` | `Theme:StepCheck` -- a CheckButton, so `SetChecked`/`GetChecked`/`OnClick` are unchanged |
| `SummonFontString` | A font string mapped from the Blizzard font object name onto a theme face and colour |

`Theme.lua` therefore loads before `WidgetWarlock.lua`.

`Theme:PanelButton` and `Theme:CloseChip` do the same job for
`UIPanelButtonTemplate` and `UIPanelCloseButton`, which is what every
secondary panel and all three `Core.lua` dialogs were still built from.

### Options panel -- `OptionsFrame.lua`

The concept's `#options`: one 396px window, header and `Config` subhead, and a
scrolling body of sections — Race, Route pack, Dungeons, Filters, Server — each
an accent uppercase `h3` over its controls. It used to be a column of pill
buttons that opened the dungeons, the filters and the route picker as three
more windows; all of that is sections now.

| Concept | Implementation |
|---|---|
| `.options-body h3` | `Theme:SectionHeader` — 12px display, accent, 1px rule under it |
| `<select>` | `Theme:Dropdown` — a button with a caret, and a list at `FULLSCREEN_DIALOG` strata so the scrolling body cannot draw over it |
| `.pill-group` | `Theme:Pill`, sized to its label and wrapping |
| `.route-preview` | Level range in accent, zone in dim, one row per leg of the route this race takes under the selected pack; scrolls on the wheel |
| `.dchip` grid | `Theme:Chip`, four across |
| `.toggle-row` + `.switch` | `Theme:Switch` — `switch-track.tga` (a stadium) and a circle knob that slides from left to right |
| `.fine-print` | `Theme:FinePrint` |
| `overflow-y:auto` | A ScrollFrame, the theme's scroll bar, and the wheel anywhere on the panel |

**Substitutions.** The concept has no home for the addon's own behaviour
settings, the waypoint provider or the Rescan / Error log actions, so they
follow as three more sections in the same language. Last comes **About**, with
a **Credits** button that opens the credits as a window of their own -- the
same chrome and section layout as this panel, beside it on the side away from
the guide, closing when the options panel does. Credits used to be a slash
command that printed into chat. The concept's route pills
include a "Zone Completion" pack that the addon does not have; the pills are
the packs this character can actually use. The pack stored as `VanillaGuide`
is shown as "Optimized", the concept's name for it — only the display name
changed, since the key is saved on every character.

**The dungeon grid's blue dot is not decorative.** `AegisPathfinder:GetGuideDungeons` scans the
**raw** guide text for `|D|` tags and marks the dungeons the loaded guide
actually has steps for, so the grid distinguishes "I could run this" from
"this guide knows about it". It has to read raw text because the `|D|` filter
runs at parse time -- a step for a dungeon you have not opted into is gone
from `self.actions` entirely, so the parsed guide cannot answer the question.
A negated tag (`|D|!DM|`) still counts as a reference: the step is
conditional, the relevance is not. Results are cached per guide, since the
scan walks guides that run to hundreds of steps.

### Guide list -- `GuideListFrame.lua`

The concept's tab bar, replacing five independent category checkboxes with
`Theme:Tab`. Single-select on its own would have lost the ability to see
several categories at once, so **All** leads the bar and is the default: the
concept's layout, none of the old capability removed. An active tab takes the
panel colour so it reads as continuous with the list below it.

Profession guides get their own tab and their own category. They are named
"Alchemy (1-300)", which matches none of the name prefixes `GetGuideCategory`
keys on, so they would otherwise land in with the zone guides — the category
comes off the guide table instead.

Placeholder guides carry the concept's grey `TPL` badge (`Theme:Badge`). In a
list where an unauthored guide looks exactly like an authored one, that badge
is the only thing distinguishing them.

### Materials panel -- `MaterialsFrame.lua`

Not in the concept, which is leveling-focused. It exists because the
profession guides need it: the reference document prints one shopping list per
profession totalled from skill 1, which is the wrong number for anyone
part-way through, since it counts reagents for crafts already done. The panel
totals what the *remaining* steps call for.

Nothing in it is profession-specific -- any guide carrying `|MATS|` tags gets
a materials list. Sorted alphabetically: it is a list you read while hunting
for one item, not a ranking.

### Scrollbar -- `Theme:ScrollBar`

The last Blizzard art in the addon. `WidgetWarlock.ConjureScrollBar` used the
stock knob plus the character-sheet scroll frame around it, which read as a
foreign object on a flat panel; it now delegates here. A dark track, a stadium
thumb (`scroll-thumb.tga`, radius half its width, so the caps stay circular at
any length) and caret step buttons. It is still a Slider, so
`SetMinMaxValues` / `SetValue` / `OnValueChanged` are unchanged.

The carets move by the bar's `step` -- a row by default, a column of 16 in the
guide list, 40px in the error log -- and stop at the ends of the range. Every
scrolling list uses it: the objectives panel, the options body, the guide
list, the materials panel and the error log. The last three were still on
`UIPanelScrollBarTemplate` / `UIPanelScrollFrameTemplate`, which drew
Blizzard's gold arrows and knob; `Tools/verify.py` now fails on either.

### Objectives panel tab bar -- `ObjectivesFrame.lua`

One tab per open guide, up to eight. Tab 1 is the main route — what
auto-advance follows. Every tab has a ✕, the first included; closing the last
one leaves the panel empty, with "Click here to load a guide" in place of the
steps. Clicking a tab switches to it and resumes where it was left; the `+`
opens the guide list beside the panel; at eight the `+` stops offering what it
cannot do.

The bar does not squeeze every open guide in: at five that reduced each tab to
"Optim…". It shows as many as fit at 100px or more, four at most (three at the
concept's 396px, four once the panel is widened to about 480px), and a `‹` `›` pair appears either side
once there are more. Each arrow, or a notch of the mouse wheel over the bar,
moves the view one tab and dims at its end. The view follows the active tab
when that changes — opening a guide, switching from the guide list, closing
one — and otherwise stays where the arrows left it, so a repaint does not
yank it back. Tab labels drop the pack prefix (`Optimized/`) that every tab
shares; the tooltip keeps the full name. Below 130px a tab drops its XP/TPL
badge so the width goes to the name.

The model is `db.char.tabs` (a list of `{guide, step}`) plus `activetab`, in
`Core.lua`. It replaced a one-deep branch — main plus at most one branch off
it — and the old `isbranching` / `branchsavedguide` / `branchsavedstep` fields
are still written, derived from the tabs by `SyncBranchState`, because a dozen
call sites read them and "am I branching?" is just "is the active tab not the
first one?". A character saved under the old model migrates on first use.

Tabs are a fixed pool of frames, anchored as they come into view, so switching
guides or scrolling the bar never creates a frame.

### Still to do

Every surface in the concept is now built. What remains is verification: none
of it has been loaded in a client.

## Verification

`Tools/verify.py` checks every texture is a 32-bit RLE TGA with power-of-two
dimensions and bottom-left origin — the format matching the two textures the
addon already shipped and which are known to load on this client.

`Tools/verify.py` also fails the build on Blizzard chrome -- `SetBackdrop`,
`TooltipBorderBG`, dialog/checkbox/button art, `GameFont` objects -- across
every shipped file, so a panel drifting off the theme is caught here rather
than in the client.

`Tools/test_theme.lua` and `Tools/test_statusframe.lua` execute the real code
against a stubbed API and assert the geometry and state transitions.

**None of this proves the UI looks like the concept.** Nothing here has been
loaded in a game client. Texture orientation, font rendering, and whether the
nine-slice corners line up are all unverified.
