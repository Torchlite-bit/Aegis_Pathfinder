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
| `--panel-2` | `panel2` | `111111` | Headers, footers, callout |
| `--panel-3` | `panel3` | `1a1a1a` | In-town steps, inactive pills |
| `--tabbg` | `tabbg` | `3b3b3b` | Tab strips, nav rows |
| `--accent` | `accent` | `52c722` | Progress, active states, meta text |
| `--accent-deep` | `accentDeep` | `2e850e` | Gradient start, branch pill |
| `--accent-glow` | `accentGlow` | `8fe066` | Gradient end, pill text |
| `--gold` / `--gold-deep` | `gold` / `goldDeep` | `ffed71` / `e8b93a` | Branch tag, callout distance |
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

**Shadows.** `box-shadow` becomes a `shadow.tga` texture inset behind the
frame.

**Icons.** The concept uses emoji, which the 1.12 font cannot render. Each of
the 17 action codes gets a generated 32×32 glyph instead. They are silhouettes,
not line art, because they render at roughly 14px where thin strokes vanish.

**Gradients.** Baked into the texture (`progress-fill.tga`, `nav-arrow.tga`) —
there is no runtime gradient.

## Surfaces

### Status card — `StatusFrame.lua`

352px wide, matching the concept. Grows vertically to fit whichever rows are
showing; `AegisPathfinder:LayoutStatusCard()` sizes it.

| Concept element | Implementation |
|---|---|
| Card background | `Theme:Panel(f, "panel")` |
| `.sb-check` | `Theme:StepCheck` — a CheckButton with ring/fill artwork, so it keeps the widget API the Blizzard checkbox had |
| `.sb-check.auto-eligible` | The halo texture, shown via `SetAutoEligible` |
| `‹` / `›` | Display-face chevrons, replacing the spellbook page arrows |
| `.sb-icon` | Generated action glyph, `Theme:SetActionIcon` |
| `.sb-title` | Display face, 13px |
| `.sb-branch-tag` | Gold `[BRANCH]`, shown while branching |
| `.sb-desc` | The `\|N\|` note, with inline coordinates stripped out |
| `.sb-meta` | Quest id, coordinates, and for profession steps the live skill range |
| `.sb-progress` | `Theme:ProgressBar` with the baked gradient |
| `.sb-top.band-red/green` | `Theme:Band` |

**Auto-detected vs. manual completion.** The concept distinguishes them and so
does the addon: `AegisPathfinder:IsAutoDetectable` decides whether the checkbox
wears its halo. Quest steps and hearthstone binds qualify because ClassicAPI
reports them by id; travel steps qualify only while a waypoint provider is
active; profession steps qualify because they resolve off skill events.
Everything else — a note to read, a vendor to visit, a mob to grind — only the
player can confirm.

### Navigation callout — `StatusFrame.lua`

The concept's signature element: arrow, instruction, distance. The arrow is a
texture because 1.12 can only rotate a texture, and only about its own centre.

Phrasing follows the concept per action type ("Head to the quest giver",
"Head to the dock", …). When no waypoint provider reports a distance, the line
is blank — an invented number would be worse than none.

### Objectives panel, options panels, guide list -- `ObjectivesFrame.lua`, `OptionsFrame.lua`, `GuideListFrame.lua`

All on the theme. Rather than edit every call site, the two shared widget
helpers in `WidgetWarlock.lua` build themed widgets:

| Helper | Now returns |
|---|---|
| `SummonCheckBox` | `Theme:StepCheck` -- a CheckButton, so `SetChecked`/`GetChecked`/`OnClick` are unchanged |
| `SummonFontString` | A font string mapped from the Blizzard font object name onto a theme face and colour |

`Theme.lua` therefore loads before `WidgetWarlock.lua`.

Objectives rows follow the concept's model: a faint wash plus a left accent bar
on the active step, dimmed text when complete, a hint of accent on `|T|`
in-town steps, and the auto-detect halo on row checkboxes, so that signal
appears wherever a step is shown. Panel buttons are display-face pills.

The three dialog frames in `Core.lua` (route selector, starting-zone selector,
error log) use `Theme:Panel` in place of Blizzard's dialog art.

### Dungeon chips -- `OptionsFrame.lua`

A wrapping grid of `Theme:Chip`, three across, replacing the vertical checkbox
list. Each chip stacks the short code over the full name, which is how the
concept fits fifteen dungeons into a panel without a scrollbar. Active chips
take the accent fill with dark text.

The blue dot is not decorative. `AegisPathfinder:GetGuideDungeons` scans the
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

### Objectives panel tab bar -- `ObjectivesFrame.lua`

The concept's model for the branch system: the guide you are on is a tab,
branching opens a second beside it, and closing that tab is how you come back.
The addon expressed the same thing as a button plus a status tag, which says
less about where you are.

| Concept element | Implementation |
|---|---|
| `.tab` with `.tab-badge` | Main tab, naming the guide, with `Theme:Badge` marking it `XP` (authored) or `TPL` (placeholder) |
| `.tab.branch-tab` with `.tab-close` | Branch tab, shown only while branching; its `x` returns you |
| `.tab-add` | `+`, opening the guide list to branch from |

Two things here are subtle enough to be worth stating. While branching,
`db.char.currentguide` is the **branch** — the guide you left is in
`db.char.branchsavedguide` — so the main tab reads that one or it names the
wrong guide. And the `+` button re-anchors when the branch tab hides, or it
floats in the gap the hidden tab used to occupy.

`TABBAR_H` also feeds `HEADER_HEIGHT`, which drives the visible-row maths in
`OnObjectiveFrameResized`; the two have to move together.

The bottom button row keeps its **Guides** and **Return Main** buttons, which
now duplicate `+` and the tab affordances. That is deliberate: they are
familiar, `Return Main` only appears while branching anyway, and removing a
working control is a worse surprise than a redundant one.

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
