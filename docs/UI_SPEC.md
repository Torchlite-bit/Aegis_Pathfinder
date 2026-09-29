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

**Tooltips.** The concept's hints are the browser's `title` attribute; the
client's equivalent, `GameTooltip`, is Blizzard's bevelled card in FrizQuadrata
-- and shared with the whole UI, so restyling it would restyle every other
addon's tooltips too. `Theme:ShowTip(owner, side, text, detail, color)` is the
addon's own: a `panel-2` card in the body face, the hint in `--text` over dimmer
detail lines, as wide as its longest line up to 260px, in the `TOOLTIP` strata,
hiding itself if its owner disappears under the cursor. Only the Active Items
buttons still open `GameTooltip`, since only it can show a game item, and
`Tools/verify.py` fails any other file that does. Those buttons are the theme's
rounded tile around the item's icon, not `ItemButtonTemplate`'s square
action-button border.

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

With Astrolabe loaded -- TomTom-TWOW and pfQuest both bring it -- the bearing
and distance come from it: it measures in yards across the zones of a
continent, as TomTom's own arrow does, and copes with the hidden world map
being left on the continent view. Astrolabe does that itself when it cannot
place the player in a zone, and the same-zone path used to read it as "not in
the waypoint's zone" and hide, while TomTom's arrow kept pointing. Without
Astrolabe it falls back to that path (re-centring a continent-view map first).
With no provider, no waypoint, or no way to measure, the callout hides; an
arrow that is confidently wrong is worse than no arrow. `/apg diagnav` says
which of those it is.

**Which arrows.** Out of the box there were two: ours, and the waypoint
addon's, aimed at the same waypoint. Ours reads the waypoint the addon records
for itself, not the provider's arrow, so they are independent, and the options
panel's **Arrows** section has a switch for each of Pathfinder's, TomTom's and
pfQuest's, any combination (`IsArrowOn` / `SetArrow` in `Navigation.lua`). An
arrow that is on gets the step's waypoint even when its addon is not the one
taking them, so TomTom's and pfQuest's can both point. pfQuest's switch reads
and writes pfQuest's own `pfQuest_config.arrow` (what `/db arrow` flips), and
hides `pfQuest.route.arrow` when turned off. An addon not loaded has its switch
held off. The default is ours alone; a character who had turned ours off keeps
TomTom's. TomTom is told `crazy = false` outright -- TomTom-TWOW fills a nil `crazy`
from its own autoqueue setting, which is on -- and pfQuest's route target is
simply not set. That is not enough for TomTom on its own: its
`GoToNextWayPoint`, run when its arrow's target is reached or cleared, hands
the arrow to the last waypoint in its list, usually ours. So the arrow's
driver takes TomTom's arrow back off any of *our* waypoints each tick while
the setting says so (`EnforceArrowMode`); the player's own TomTom waypoints
are never touched. Cartographer and MetaMap BWP have no waypoint but their arrow,
so they point whatever is switched, and the section's note says so.

### The status card -- deleted

The concept removed it: every `.sb-*` rule and the whole `#statusbar` block are
gone, and `renderStatusBar()` became `renderNavCallout()`. `StatusFrame.lua`
went with it.

Almost nothing in that file was the card, though. `UpdateStatusFrame` is the
scan that walks the step list, decides which step you are on, auto-completes
what ClassicAPI can resolve, drives the waypoint and loads the next guide when
one runs out. That is now `GuideEngine.lua`. The use-item button for `|U|`
steps lived there too until it became the Active Items window
(`ActiveFrames.lua`, below).

What the card's meta row used to paint is now `GetStepMeta`, which returns the
quest id, a profession step's live skill range, coordinates buried in the note,
and any warning, and lets the caller decide how to show them.

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

**Escape does not close it.** It is not in `UISpecialFrames`: it stays on
screen while you play, as the quest tracker does, and Escape is what clears a
target or cancels a spell in a fight, so it kept closing the guide in combat.
Its close chip closes it. The windows opened from it (options, guide list,
Gear finder, Where next?) still close on Escape.

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
meter rather than an empty one. **Substitution:** the concept draws one
objective; a quest with more has a line each (`PaintMeter`), label, count and
bar stacked 8px apart, and the meter grows a line at a time from the
concept's 38px -- Crocolisk Hunting's meat and skins are two bars. A finished
objective stays, its bar full. A bar is a StatusBar (`Theme:ProgressBar`):
the client fills it to the value, where a texture sized from the bar's
reported width drew 4 of 5 about half full in game. The step's accent bar and
wash reach down beside the meter to the footer (`ReachActiveRow`), so the
objectives read as part of the step.
Overview mode folds the same text into the step's note line instead, as the
concept does.

**Width.** The concept's 396px (`.panel{width:396px}`). It used to open at
630px, and every earlier version saved the width on any resize, the first
layout included -- so a stored 630 is read as "never chosen" and dropped. Only
the grip saves a width now. At 396 a warning in the footer does
not fit beside the step count, so it stops short of the count on one line and
the footer's tooltip carries the whole of it.

**Height follows the content.** The concept's panel is `height:auto` under
`max-height: min(70vh, 600px)`, with `.steps-list` `flex:0 0 auto` in focus
mode and `flex:1 1 auto` in overview. So `LayoutPanelHeight` makes the panel
exactly as tall as what it shows, up to a cap: in focus mode, the one step
(its title and its note in full, both wrapped to the width) and the meter;
in overview, the list, one line of title a step, which for any
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
guide you are on the right. A warning from `GetStepMeta` outranks the id and
turns the slot red; nothing raises one at present (the per-server guide-data
warning is gone).

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

The concept's `#options`: header and `Config` subhead over a body of sections —
Race, Route pack, Dungeons, Filters, Server theme — each an accent uppercase
`h3` over its controls. It used to be a column of pill buttons that opened the
dungeons, the filters and the route picker as three more windows; all of that
is sections now.

**Substitution: pages.** With the gear, behaviour, navigation and maintenance
sections added, one scrolling body grew too long to find anything in, so the
sections are grouped into pages with a category list down the left, as Zygor's
options have it: Route (Race, Route pack), Dungeons (Dungeons, Turtle WoW's
own, Along the way -- with the middle-of-its-levels switch), Filters, Appearance (Server theme, Window scale), Gear and, set in under it, Item Score, Behaviour, Navigation
(Waypoints, Arrow), Maintenance, About. The concept's 396px pane is unchanged, with the 150px list beside it
(546px in all). The list is a quieter column than the pane — a 3% text tint and
a hairline on its right edge — and the page shown is marked with a 3px accent
bar, a brighter row and white text. The subhead names the page (`CONFIG ·
GEAR`). A page scrolls only when it is taller than the window, and every page
opens at its top; changing page closes any dropdown list left open.

A grip in the bottom-right corner (the guide's `grip.tga`) resizes the window:
wider or taller, never narrower than it opens, never shorter than 360px, never
bigger than the screen, and the size is kept. The pane's contents are laid out
for its width once, and each widget that spans it -- section rules, switches,
fine print, dropdowns and their lists, the route preview, the Item Score
page's share column -- is registered with how to take a new width, so a wider
window reflows them; a taller one shows more of the page before it scrolls.
Every row on a page is placed through one helper that remembers it, so a new
width lays the page out again: a label that no longer wraps gives its line
back, and the rows under it move up.

A switch's label wraps under itself when it is too long for the row, and the
row grows to hold it (`Switch:Fit`): the lines are counted from the label's
unwrapped width, since a wrapped font string's own height is not reliable on
1.12. Labels used to run under the scroll bar and be cut off.

**Item Score** (`GearFrame.lua`) is Zygor's page of the same name: the spec
picker and your class, a note on where the spec came from and whether the
weights are the defaults or yours, *Show all stats*, then the weights one to a
row down the left — label (134px, so the longest stat names stay on one line),
then a 58px field (black, with a hairline edge) —
and beside them a *Share weights* column: the OctoPawn string's field with
**Import** and **Export** under it, and what they did. **Reset** sits under the
longer column. The list's length follows the spec and *Show all stats*, so the
page sets its own height as it is drawn and the window keeps your place while
it changes. It used to be a window of its own. Zygor's has a many-line box for
the string; here the field is one line that scrolls sideways, so the page
needs no second scroll frame inside its own.

| Concept | Implementation |
|---|---|
| `.options-body h3` | `Theme:SectionHeader` — 12px display, accent, 1px rule under it |
| `<select>` | `Theme:Dropdown` — a button with a caret, and a list at `FULLSCREEN_DIALOG` strata so the scrolling body cannot draw over it |
| `.pill-group` | `Theme:Pill`, sized to its label and wrapping |
| `.route-preview` | Level range in accent, zone in dim, one row per leg of the route this race takes under the selected pack; scrolls on the wheel. **Substitution:** the concept's seven rows are the least; the preview takes the rest of the page's height, a row per 20px, so a taller window shows more legs (`FitRoutePreview`) |
| `.dchip` grid | `Theme:Chip`, four across |
| `.toggle-row` + `.switch` | `Theme:Switch` — `switch-track.tga` (a stadium) and a circle knob that slides from left to right. Off: a faint track (`text` at 10%) and a white knob. On: the theme's `switchOn` (its accent deep; RavenCraft's a near white, where grey on grey did not say which it was) and a near-black knob. **Red and green switches** on the Appearance page (`Theme:SetSwitchColours("redgreen")`, saved as `switchcolours`) makes every switch green when on and red when off whatever the theme (`Theme.SWITCH_ON` / `SWITCH_OFF`), repainting those already drawn |
| `.fine-print` | `Theme:FinePrint` |
| `overflow-y:auto` | A ScrollFrame, the theme's scroll bar, and the wheel anywhere on the panel; the bar hides on a page that fits |

**Substitutions.** The concept has no home for the addon's own behaviour
settings, the item score and gear, the waypoint provider or the Rescan / Error
log actions, so they follow as more sections in the same language. Last comes
**About**, with
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

### Sharing a guide -- `PartySync.lua`

Not in the concept. Zygor's Share Mode, in this addon's language:

- **The party icon** (`Theme:GlyphButton` with the generated `party` glyph)
  sits at the right end of the objectives panel's step row, and the step count
  moves left of it. Dim while not sharing, gold while waiting for anyone to
  accept, the accent once someone has. Its tooltip says what sharing does, or
  who you are sharing with.
- **Confirmation** and **invitation** share one themed popup (header, `GUIDE
  SHARING (BETA)` subhead, centred lines, two half-width buttons). The
  confirmation names the guide, notes that the party needs Aegis: Pathfinder,
  and has a "Don't warn me again" box (`char.sharenowarn`). The invitation names
  who and which guide, and says accepting opens it in a new tab. Closing an
  invitation any way but Accept declines it.
- **Members under the step**: in focus mode, a block under the meter (or the
  step, with no meter), counted into the panel's height: a line per member,
  name left and status right — `[3/6]` (gold) or `[done]` (accent) on your step,
  `step N, behind` (gold), `step N` or `step N, waiting` ahead, `on a step you do
  not have`, `joining...`. A held step adds a first line, "Done. Waiting for your
  party to finish this step."
- **Holding**: `UpdateStatusFrame` asks `ShareHold` after finding the next
  step. A member on step p allows up to p, or p + 1 once they have finished p;
  past the smallest such limit you stay on the step you were on (never going
  back). The skip arrow on a held step bypasses it until the party passes it.
- **Messages**: over `PARTY` or `RAID`, prefix `AegisPF`, fields joined by `^`:
  `INV`, `ACC`, `DEC`, `NOG`, `ST` (step, done, have, need), `REQ`, `BYE`. A
  step is `action:questid-or-title#occurrence`, so class and race filtering do
  not misalign it. Our status is looked at twice a second and sent on change
  (at most once a second) or every 15 seconds; incoming news sets a dirty flag
  flushed once a frame, so a burst of messages is one engine run.

### Server themes -- `Theme.lua`

Not in the concept, which is green. The options panel's **Server theme**
(which replaced the Server dropdown) picks one of `Theme.THEMES`: Day, Night,
Turtle WoW (the concept, the default), OctoWoW, RavenCraft, Capybara Paradise,
Aegis. A theme names only the colours it changes: the accent family (`accent`,
`accentDeep`, `accentGlow`), and for Day, Night and RavenCraft the panel shades.
Text, gold, danger and the green/red step bands keep their meaning everywhere.

- **Live**: `Theme:ApplyTheme` changes the colour tables in place and re-tints
  every texture and font string `Tint`/`TextColor` last coloured by a name that
  some theme changes (a weak-keyed record, so nothing is kept alive by it).
  `SetTheme` then repaints the open windows, so colours chosen by state catch
  up. The saved theme is applied in `OnInitialize`, before the first paint.
- **Baked art**: the navigation arrow and progress fill are gradients drawn in
  green. `Theme:Skin` keeps them exactly as drawn under Turtle WoW, and under
  any other theme swaps in the same shape in grey (`nav-arrow-mask`,
  `progress-mask`), tinted with the theme's accent glow.
- **Readable**: `test_theme.lua` requires, in every theme, a WCAG contrast of
  4.5:1 for the accent on the panel and for dark text on an accent pill, and
  7:1 for dim text on the panel. RavenCraft's "dark grey" is its panels; its
  accent is a lighter grey, since dark grey on a dark panel cannot be read.
- **Colours only**: a theme says nothing about which server you play on. The
  servers share the quests and places the guides use, so the old per-server
  guide-data warnings (`Servers.lua`, `/apg server`) are gone; the note under
  the dropdown says what the theme looks like.

### Minimap button -- `MinimapButton.lua`

Not in the concept, which has no minimap. It used to be FuBarPlugin's:
Blizzard's quest-log book in the stock round minimap border, and a right-click
that opened a Dewdrop menu of every setting in Blizzard tooltip chrome. Now it
is drawn like the rest of the addon -- `logo.tga`, the Aegis shield, in accent
on a `panel-2` disc (`circle-fill.tga`) with a `subtle` hairline ring
(`circle-border.tga`) that takes the accent on hover.

Click toggles the guide, right-click toggles the options panel (every setting
the Dewdrop menu held is there), and dragging walks it round the minimap's edge
at 80px from its centre; the angle is saved per profile. "Minimap button" in
the options panel's Guide behaviour section, or `/apg minimapbutton`, hides it.

Dewdrop-2.0, Tablet-2.0 and FuBarPlugin-2.0 were only there for the old
button, so they are gone from `libs/` and the `.toc`; AceConsole and AceDB use
Dewdrop only when it is present. `Tools/verify.py` fails on Blizzard quest-log
or minimap art, in either backslash form.

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
is the only thing distinguishing them. Every profession has a guide now, so
none ships with it; the badge stays for the next placeholder.

Custom-zone guides are the **Custom** tab: `GetGuideCategory` matches a
guide's name against `TURTLE_ZONES` in `Core.lua`, which has to name every
custom zone -- Scarlet Enclave and Hyjal were once missing and filed under
Zones. `Tools/test_guidelist.lua` reads that list out of `Core.lua` and checks
every custom-zone guide against it.

Dungeon guides (`Guides/Dungeons/`, named `Dungeons/<dungeon> (lo-hi)`) are
the **Dungeons** tab, between Zones and Professions: `GetGuideCategory` takes
the `Dungeons/` prefix before it looks for a custom zone's name, so Gilneas
City's guide is not filed under Custom. With eight tabs the strip's tabs are
78 wide, to fit the 660-wide panel.

### First-time setup -- `SetupFrame.lua`

Not in the concept: RestedXP's first-run questions, over settings the options
panel already has (`routepack`, `UseAH`, `PlayStyle`, `Dungeons`); nothing in
it is a new setting. Opened once per character from the end of
`InitializeRoute` (`MaybeShowSetup`, `db.char.setupdone`), and again from
`/apg setup` or the options panel's **Run setup** pill.

A 420px Chrome window, `SET UP YOUR GUIDE`, with `STEP n OF m` at the right of
the subhead (two steps with dungeons off, three with them on), a display-face
title and a line of intro per step, Back and Continue/Finish at the foot.

1. **Your guide**: a card per route pack this character may use
   (`GetAvailableRoutePacks`) that has a route for its race -- so no RestedXP
   or Hardcore card for a High Elf or Goblin. Name in the display face over a
   line of what it is; the chosen card takes the accent. Picking a pack
   brings its starting features, as the pack pills do.
2. **Features**: `Theme:Switch` rows with a line each. Under them, in gold,
   which of the three the chosen pack's guides do not mark at all
   (`GetPackTags` reads the route's guide text once per pack) -- the
   Optimized guides mark none yet.
3. **Dungeons**: the faction's dungeons (`DUNGEON_INFO`: Ragefire Chasm is
   Horde-only, the Stockade Alliance-only) in level order, each a
   `Theme:StepCheck`, the name, the level range (accent while it is your
   level, gold ahead, dim once past) and how many quests it adds to the route
   (`GetDungeonQuestCount`, from DungeonQuests.lua: "12 quests", "1 quest (+4
   with Deadmines)" while a quest's chain waits on another dungeon, "none in
   this route"), in the accent colour when recommended. Recommended / All /
   None above. Reaching the step with none ticked starts from the recommended
   ones (`GetRecommendedDungeons`): for the pack picked and your race, each
   that adds five quests or more, counting the ones it shares with the others
   recommended. With no quests for any dungeon, a note says the guides take
   you through none yet.

Finish (`ApplySetup`) switches pack only when a different one was chosen --
`SelectRoutePack` re-routes, which would lose your place -- writes the three
filters, re-reads the guide on screen, and prints what was set up. Closing
the window keeps everything and marks setup done.

### Where next? -- `NextGuideFrame.lua`

Not in the concept. Asked when a guide finishes, before the engine moves on:
`UpdateStatusFrame` calls `OfferNextGuide` first, and when it returns true the
guide waits for the answer instead of `LoadNextGuide` or `ReturnFromBranch`.

It is asked only when a custom zone fits (`GetCustomZoneChoices`): a guide in
the `turtle` category, not the one just finished, not finished before
(`db.char.completion`), with the player at least one level short of its bottom
and below its top. Up to five, lowest first. With `offerdungeons` on (the
Dungeons page's *Offer dungeon guides along the way*, off by default, held off
by Solo Self-Found) it is also asked when a dungeon guide fits
(`GetDungeonGuideChoices`): the guide under `Dungeons/` of a ticked dungeon,
vanilla or Turtle WoW's own, fitting the level the same way, up to four,
lowest first. Nothing fits, nothing is asked, and the old path runs. Each
finished guide is asked about once a session.

Chrome with a `WHERE NEXT?` subhead, a line naming what was finished, then:

- **The route** (`Theme:SectionHeader` over a full-width `Theme:PanelButton`):
  "Continue to" the route's next guide (`nextzones`), or, finishing a custom
  zone, "Back to" the route guide for the player's level now
  (`GetOptimizedGuideForLevel`). Hidden at the end of the route.
- **Custom zones**: a button each.
- **Dungeons**: a button each, under the custom zones. Taken like a custom
  zone: from the route it opens in a tab beside it.

Taking a custom zone from the route opens it in a tab (`OpenGuideTab`) and
points tab 1 at the route's next guide, so returning resumes the route rather
than the guide just finished. Taking one from a custom zone replaces that tab
(`LoadGuideInTab`). Going back is `ReturnFromBranch`. Either way the finished
guide is recorded as done. Closing the window (its close chip, Escape) is
"carry on with the route" -- what finishing a guide always did.
`offercustomzones`, on by default, switches it off; it replaced
`autobranch`, a switch that nothing read.

**A dungeon at your level** (`AegisPathfinderMidDungeon`, same file). Not in
the concept. `GetMidLevelDungeons(level)` lists the dungeon guides (`Dungeons/`)
of the ticked dungeons in `DUNGEON_INFO` -- the ones the setup asks about;
Turtle WoW's own start ticked, so they are left to *along the way* -- whose
middle level (`DungeonMidLevel`: `floor((lo + hi + 1) / 2)`, from the guide's
title range) the player has reached, without being past its top, finished
(`db.char.completion`), open in a tab (`FindTab`) or offered before
(`db.char.middungeonsoffered[code]`). Nothing before `setupdone`, in Solo
Self-Found, or with `middungeons` false (the Dungeons page's *Offer a dungeon's
guide at the middle of its levels*, on by default). Up to four, lowest middle
first.

`OfferMidLevelDungeons(level)` shows them: chrome with an `A DUNGEON AT YOUR
LEVEL` subhead, a line naming the level and the dungeon, a `Theme:PanelButton`
per dungeon ("Open ..." when there is one) and a **Not now** button. Showing
them is the offer: each is marked offered then, whatever the answer. A button
opens its guide in a tab (`OpenGuideTab`) and the window keeps the rest; Not
now, the close chip or Escape closes it. It waits while Where next? or the setup
is up, without marking anything. It is asked from its own `PLAYER_LEVEL_UP`
frame (`arg1`, the new level: `UnitLevel` can lag), at the end of
`InitializeRoute`, and when the setup is finished (`SetupStep`). Beside the
guide, as Where next? is.

### Shopping list -- `MaterialsFrame.lua`

Not in the concept, which is leveling-focused. It exists because the
profession guides need it: the reference document prints one shopping list per
profession totalled from skill 1, which is the wrong number for anyone
part-way through, since it counts reagents for crafts already done. The panel
totals what the *remaining* steps call for.

Opened by the **Shopping list** button at the left of the objectives panel's
footer -- the buy glyph and the words, shown only on a guide with `|MATS|`
tags (`GuideHasMaterials`). It used to be a bare glyph named `"use"`, which is
not one of the theme's glyphs, so it drew nothing at all. It pops out beside
the guide, on whichever side has room, like the options panel, until dragged;
a dragged position is restored (it used to be saved and never read).

- **Chrome**: the standard header and a `SHOPPING LIST` subhead, 280px wide.
- **Scope tabs** (`Theme:Tab`): *This step* -- the first unfinished step from
  the current one on that lists reagents -- and *Whole route*. Remembered in
  `profile.shoppingscope`; the whole route by default.
- **Summary**: the craft's title or the guide's name, then "4 of 5 still to
  get", or "all 5 in your bags".
- **Rows**: have/need (`display` 11, "20/40", capped at the need) then the
  name. Gold for a line still short, the accent with a dimmed name for one
  covered. Up to 14 rows, never fewer than 3; the window is sized to its list
  and the theme's scroll bar takes over past 14. Sorted alphabetically: it is
  a list you read while hunting for one item, and one sorted by what is short
  would move lines under the cursor as you buy.
- **Bag counts** are by name over bags 0-4. `BAG_UPDATE` only marks the list
  stale; the window repaints from OnUpdate at most every 0.25s, and only while
  open, so a loot or a stack split is one repaint, not one per bag.
- **Send to Exchange** and **Cheapest route** (`Theme:PanelButton`, half the
  width each, at the foot). Exchange is below; Cheapest route opens the
  crafting route window.

Nothing in it is profession-specific -- any guide carrying `|MATS|` tags gets
a shopping list.

#### Aegis: Exchange

Exchange builds its own shopping list from crafting projects, `{ name, itemId,
made, want, reagents = { { name, count, itemId } } }`, priced at the auction
house. The button writes one project per craft still ahead, in route order
with the next craft on top: `want` is the craft count and `made` is 1, so
Exchange's `reagent count x crafts` lands on the same totals as the list here
(`Tools/test_materials.lua` checks this against the reference document's
Alchemy list). The same craft on two steps is one project with both counts.
Item ids come from the bags, then Exchange's own name map, then pfQuest's item
database; anything unmatched is reported in chat, since Exchange's list only
shows reagents it can resolve.

Only Exchange's public calls are used -- `craft.Projects`, `AddProject`,
`DeleteProject` and `ui.RefreshCraft` (pcall-guarded). Sent projects carry
`pathfinder = <guide>`, which is how they are found to update or remove.
Exchange keeps one project per name, so one of the player's own recipes that
shares a name with a craft on the route is kept inside ours as `replaced` and
put back when ours goes; its exact item ids are used meanwhile.

It follows the guide: `UpdateStatusFrame` calls `RefreshShoppingList` when
the step settles, which marks things stale for one OnUpdate, and
`SyncExchange` rewrites Exchange's list only if what is left has changed.
Finishing the route removes it. It only syncs while the guide it was sent
from is the one loaded. Exchange's demo mode shows made-up projects in place
of the saved list, so nothing is sent or removed while it is on.

### Crafting route -- `CraftRouteFrame.lua`

Not in the concept. It does what CraftRoute does, without CraftRoute: plans
the cheapest way from your skill to 300 at today's prices and shows it, and
can turn it into a guide. The planning is `CraftPlanner.lua`, the auction scan
`CraftScan.lua`, the recipe and merchant-price data `Crafting/` (converted from
CraftRoute's data by `Tools/import_recipes.py`).

Opened by **Cheapest route** on the shopping list, or `/apg craft`. It pops out
beside the guide like the shopping list, until dragged (`craftframe`).

- **Chrome**: the standard header and a `CRAFTING ROUTE` subhead, 360px wide.
- **Profession** (`Theme:Dropdown`): every profession with recipe data, with
  your skill beside the ones you have. It opens on the profession of the guide
  you are reading, else the last one planned, else the first you have. At the
  right, `SKILL 41 TO 300` (`display` 12, dim): from your current skill to
  where the route gets.
- **Total** (`display` 18, gold) and the crafts beside it. A route that pays for
  itself by selling back shows `+` and the amount in the accent, and says so.
- **Breakdown** (`body` 10, dim): reagents, recipes, what is sold back, how many
  items have no price, and where the route stops if it stops short.
- **Status line**: where auction prices come from ("your scan 2 h ago and Aegis:
  Exchange"), or gold when there are none or some reagents have no price, or the
  scan's progress while it runs.
- **Rows**, two lines each, 30px, eight visible and the theme's scroll bar past
  that: the skill band (`display` 11, accent), the recipe, the crafts (`x49`,
  gold); under them the reagents of one craft and what the step spends. A step
  with an unpriced reagent is gold. Hovering a row shows the expected crafts,
  the cost of one, how the recipe is learned, what to buy, what is made first,
  and what has no price.
- **Sell what is left over to a merchant** (`Theme:Switch`): whether leftovers
  count against the cost. `char.craftsellback`, on by default.
- **Scan prices** / **Stop scan** and **Load as guide** (`Theme:PanelButton`,
  half width each).

The plan is worked out when the window opens and again only when something it
depends on changes: the profession, your skill, the sell-back switch, a
finished scan, or a recipe newly seen in your profession window. Scan progress
only repaints. Each of those arrives as a dirty flag flushed once on the next
frame.

#### The planner

1. Unit costs: the lower of a merchant's price and the auction house's, or the
   cost of making the item from its own reagents where this profession can and
   that is cheaper.
2. Skill-up chance: certain from orange to yellow, then falling in a straight
   line to nothing at grey.
3. The route: a dynamic program over skill points with the last recipe used as
   the state. Carrying on costs the next point (a craft's cost over its chance);
   switching also costs the new recipe's fee, and one craft as a nudge against
   one-point detours.
4. Depth: the route is priced at the quantities it buys, walking up the
   auction listings, and planned again at those prices until it settles.
5. Accounting: the route is played through in order -- an earlier step's
   products are used by a later one before anything is bought -- and what is
   left is sold back if the switch says so.

A known recipe is free to learn; a drop or reputation recipe is only planned
once known; `skip` recipes (cooldowns, rare drops) never. A reagent with no
price keeps its recipe out, unless the route cannot go on without it, in which
case the route uses it, says which items have no price, and leaves them out of
the total rather than guessing.

#### Auction prices

`CraftScan.lua` searches for each reagent and recipe book the profession could
use that no merchant sells -- the route's own first -- one name at a time, gated
on `CanSendAuctionQuery()`, reading `AUCTION_ITEM_LIST_UPDATE` only while a
reply is awaited, up to four pages an item, and keeping only listings with
exactly the name searched for. Each item's listings are stored cheapest first
per realm (`realm.craftprices`), so forty units are priced as forty. Items
searched in the last half hour are skipped. Aegis: Exchange's unit price is
used where there is no scan of our own, or ours is over a week old.

#### Load as guide

The route becomes a QuestShell+ guide, `<Profession> (cheapest route)`, in the
Professions list. The authored profession guide's non-craft steps -- trainers
per rank, the level each rank needs, the Expert cookbook, the Artisan quest --
are kept, each block placed where the old skill cap runs out (the rank to 150
at 75, and so on); crafts are split there. Craft steps carry `|SKILL|`,
`|CRAFT|` and `|MATS|` like authored ones, so they complete on your skill and
feed the shopping list; a trainer recipe you do not know carries your
faction's trainers. The guide is saved in `char.craftguides` and registered
again at login, and loading a new plan replaces it.

### Active Items, Active Targets and Macros -- `ActiveFrames.lua`

Not in the concept: RestedXP's two small windows, asked for by name. Each is a
`Theme:Panel` with an 18px `Theme:Header` strip carrying its title (`ACTIVE
ITEMS`, `ACTIVE TARGETS`, `display` 11) in place of the wordmark, and a row of
32px tiles -- the theme's rounded square, `panel-2` fill, a hairline border
that takes the accent on hover. The width fits the tiles or the title,
whichever is wider. `MEDIUM` strata, not `DIALOG`: they are part of the HUD,
not windows that stack.

Until dragged, Items hangs under the guide (`TOPRIGHT` to its `BOTTOMRIGHT`,
6px down) and Targets under Items -- or under the guide while Items has
nothing to show. Dragged by the title, each is saved (`activeitems`,
`activetargets`) and stays; Reset Panels forgets both. A window mid-drag is
not re-anchored by a repaint. Each hides when it has nothing to show, and the
options panel can switch either off (`showactiveitems`, `showactivetargets`).

**Items** replaced the single floating use-item button. A tile per item the
guide wants used, up to six, one per item however many steps want it: the
current step's `|U|` item first, then any other step's whose quest is in the
log and not complete. Only what is in the bags -- a tile for an item you do
not carry is a dead button. The icon is the bag's, cropped of its bevel; a
stack shows its count in the corner; hover is `GameTooltip:SetBagItem`. A
click uses it from wherever it is now, and ticks the current step if that is
a USE step for this item.

**Targets**: a tile per NPC or enemy the current step wants found, up to four.
From the step's `|NPC|` tag, and from pfQuest's database by the step's quest
id: an ACCEPT's starters, a TURNIN's enders, a COMPLETE's objective units then
the units that drop its objective items, likeliest drop first. A COMPLETE's
units are narrowed to those with a pfQuest spawn in the first of the step's
`|Z|` zone, the guide's zone, then the player's (`Nearby`) that has any, and
are left whole when none does: by drop chance alone Crocolisk Hunting targeted
Wetlands and Stranglethorn crocolisks, never a Loch Crocolisk. pfQuest's
`fac` string says who is friendly to the player's faction. The tile shows the
step's action glyph (the kill glyph in `danger` for an enemy) and, in its
corner, the raid mark it will apply -- the one piece of Blizzard art here,
because it is the in-game marker itself. A click targets the next one by
that name around you (**Cycling**, below) and `SetRaidTarget`s the entry's
context mark (quest icons, below). An existing mark is not set again (which
would toggle it off). The tile of whoever is targeted takes the accent border,
relit on `PLAYER_TARGET_CHANGED`.

**Cycling.** `TargetByName` -- `/target` -- takes the nearest with the name
but keeps the current target when it has the name already, so pressing it
again never moves on. With ClassicAPI's `TargetNearest`, `UnitGUID` and
`TargetUnit`, a press looks round instead: up to 30 `TargetNearest` calls,
stopping at the first GUID seen twice, keep the living non-player units with
a wanted name, sorted by `UnitDistanceSquared`, and the press takes the one
after the current target's GUID -- the nearest when the target is none of
them -- so presses go nearest, next out, and round again. While it looks,
the `PLAYER_TARGET_CHANGED` handler does nothing (no marks, no border
repaints) for the units it passes. When it finds none of them, the target is
put back (`TargetUnit` of the old GUID, or `ClearTarget`) and it falls back to
`TargetByName`, which also reaches friendly NPCs further out. Without those
ClassicAPI functions it is `TargetByName` alone, as it was.

**Quest icons.** Each target carries a context and the mark that says it,
as RestedXP's Quest Icons do: `talk` star (an ACCEPT's starters, a TURNIN's
enders, `|NPC|` names), `interact` square (a friendly objective unit), `kill`
skull (a hostile objective unit), `loot` cross (a unit that drops an
objective item). pfQuest's `fac` decides friend from enemy; at marking time a
`kill` or `loot` unit that `UnitCanAttack` says cannot be attacked gets the
square. On `UPDATE_MOUSEOVER_UNIT` and `PLAYER_TARGET_CHANGED` the unit
(`mouseover`, `target`) is marked if its name is wanted: the current step's
targets first, then, for each quest in the log (ids from ClassicAPI's
`C_QuestLog.GetQuestIDForLogIndex`, headers skipped), an unfinished quest's
COMPLETE targets or a finished one's TURNIN targets, up to 40 names, rebuilt
on every repaint. Never over an existing mark, on a player or a corpse, or in
a raid. `questicons` switches it off. The step's targets are worked out
whether or not the Targets window is showing: the icons and the macro use
them too.

**Macros**, the third window, under Targets (or whichever is showing above
it), with a tile for each of two character macros the addon writes and keeps
current -- RestedXP's generated targeting macro, plus one for the quest item:

- **AegisTarget**: `/apg target` (`TargetNextActive`), the same on every
  step: each press the next of the step's targets around you, marked
  (**Cycling**). It was a `/target <name>` line per target and `/script
  AegisPathfinder:MarkTarget()`; `/target` stayed on whoever was targeted, so
  presses did not move on. `MarkTarget` stays for a macro saved that way until
  it is next written. With no targets it says there is nobody. Its icon is
  Hunter's Mark's (`Ability_Hunter_SniperShot`).
- **AegisItem**: `/apg useitem` (1.12 has no `/use`), wearing the first active
  item's icon. The stock action bars repaint a button when its slot changes, not
  when the macro in it does, so after an edit the addon repaints any stock
  button holding it (`ActionButton_Update`); other bar addons repaint on
  their own schedule.

**Icons by name.** ClassicAPI's `C_Macro.CreateMacro` / `C_Macro.EditMacro`
take the icon as a texture name, so both macros are written through them when
they are there: no list is involved, and AegisItem gets its item's own icon,
which the stock list lacks. The stock `CreateMacro` / `EditMacro` take a place
in the macro icon list instead, and the client fills that list lazily: read
while it was still empty, and kept, it left AegisTarget with the first place
of an empty list, a blank icon. Without `C_Macro` the list is read again
until it is the one the client reports, and the icon is left alone while it
is empty; the targeting icon is then the first of Hunter's Mark's, the town
watch's or a spyglass the list has, and AegisItem's the item's icon when the
list has it, else the question mark.

Both are made as character macros the first time there is something for them
to do, and rewritten (`EditMacro`, only when the text or icon changed) on
every repaint after that -- including a step with nothing to do, so one on a
bar never aims at a finished step. Never while `MacroFrame` is open: the stock
UI saves its own copy of the text over ours when it closes, so the repaint
waits a second and tries again. With the 18 character slots full nothing is
made; the tile's tooltip and a drag say so. A tile click does what its macro
does (`TargetNextActive`, `UseActiveItem`); a drag is `PickupMacro`, to drop
on a bar. `showmacros` switches the window and the macro writing off.

`/apg target` and a key binding (`Bindings.xml`) do what AegisTarget does:
the nearest of the step's targets, then the next one out on each press --
RestedXP's macro, without a macro. `/apg useitem` and a second binding use the
first item.

Step changes repaint on the next frame (`UpdateStatusFrame` calls
`RefreshActiveFrames`); `BAG_UPDATE` bursts coalesce into one repaint 0.25s
later.

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
list, the shopping list and the error log. The last three were still on
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
shares; the tooltip keeps the full name. Below 130px a tab drops its badge so
the width goes to the name.

**Substitution: the badge says what the guide is** (`GuideBadge`,
`Theme.BADGES`). The concept has the one gold `XP`. Here it's `XP` for a leveling
guide, `PF` (blue) for a profession guide, a crafting route included, `DG`
(violet) for a dungeon guide, `HC` (red, light text) for a hardcore guide, and
the grey `TPL` for a placeholder, whatever else it is. PF, DG and HC keep
their colours in every theme, as the step bands do.

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
