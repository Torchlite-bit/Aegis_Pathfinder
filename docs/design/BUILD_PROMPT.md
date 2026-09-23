# Build prompt — concept round 2

## Goal

Make AEGIS: Pathfinder look and behave exactly like
`docs/design/aegis-pathfinder-concept.html`. That file is the source of truth.
Where the 1.12 client cannot do what the concept does, build the closest thing
that reads the same and say what was substituted and why. Generate whatever
assets that needs — there is a generator at `Tools/make_assets.py` and nothing
in `media/` is hand-drawn.

## What changed in this revision of the concept

The build currently in the repository was made from the previous revision.
Six things moved; the first two reverse earlier decisions, so read them before
touching anything.

### 1. The compact status bar is deleted

Every `.sb-*` rule and the whole `#statusbar` block are gone from the concept.
`renderStatusBar()` is now `renderNavCallout()`. The objectives panel no longer
carries the `hidden` attribute — it is the only window, and it is open.

The addon still has `StatusFrame.lua`: the card, its layout code, its tests and
the `/apg statusbar` command that shows it. **Decide before building**: delete
the surface outright, or keep it as an opt-in that is off by default (what it
is today). The concept cannot answer this — it only shows the default state.
Do not do it twice.

Note that a good deal of the addon hangs off that frame regardless of whether
it is drawn: `PositionStatusFrame`, `GetQuadrant` anchoring for every other
panel, the FuBar/minimap plugin, and `UpdateStatusFrame`, which is the function
that actually walks the guide and auto-completes steps. Removing the *surface*
must not remove the *engine*.

### 2. The navigation callout is back, with no chrome

It was removed last round, along with `nav-arrow.tga` and its generator
function, on the instruction to "lose the arrow and minimalistic box". The
concept now separates those: the box is gone for good, the arrow returns.

It is no longer a panel. `background` and `box-shadow` are removed; the block
floats directly on the game world:

| | |
|---|---|
| Arrow | The same three-stop gradient SVG, `drop-shadow(0 3px 4px rgba(0,0,0,.65))` |
| Instruction | Inter 600 14px `#f6f2e8` |
| Distance | Inter 600 13px `#e79a52` (was `#df8b4a`) |
| ETA | Inter 600 13px `#ece6d8` |
| All three text lines | `text-shadow: 0 1px 3px rgba(0,0,0,.9), 0 1px 8px rgba(0,0,0,.7)` |
| Whole block | `cursor:grab`, draggable |

Legibility over arbitrary terrain is the entire reason for those shadows, so
they are not optional detail. 1.12 font strings have `SetShadowOffset` and
`SetShadowColor`, which should cover it.

The arrow rotates to bearing (`rotate(Ndeg)` in the concept). 1.12 has no
`SetRotation`; the usual vanilla technique is the eight-argument form of
`SetTexCoord`, which maps the texture onto an arbitrary quad. Verify that form
works on this client before building the rest on top of it.

`nav-arrow.tga` and its generator both need restoring — see the deletion in
commit `970ec6a` rather than rewriting them.

### 3. New: focus mode and overview mode

A third header chip (`#obj-expand-btn`, between ☰ and ✕) toggles them, and it
takes a new `.chip-btn.active` style: accent fill, `#0d1a06` text.

| Mode | Step list shows |
|---|---|
| **Focus** (default) | Only the current step, plus the objective meter below it |
| **Overview** | Every visible step |

The addon only has overview today — it always renders the whole list. Focus
mode is new behaviour, not a restyle, and the tooltip flips with the state
("Show all steps" / "Show one step at a time").

`#objectives.overview-mode .steps-list{flex:1 1 auto;}` — in focus mode the
list shrinks to its content instead of filling the panel.

### 4. New: the objective meter

`.zobjective`, shown under the single step in focus mode only:

- Label left, `3 / 8` right in mono accent, 12px
- A 6px gradient track beneath, `--accent-deep` → `--accent-glow`
- Rounded 8px, `rgba(255,255,255,.04)` fill, 1px border, lighter on hover
- Clickable

This is quest-log objective progress. The addon already reads it —
`GetNumQuestLeaderBoards` / `GetQuestLogLeaderBoard` in `UpdateOHPanel` — but
currently flattens it into the row's note line. In overview mode the concept
does exactly that (`if(step.objTarget && state.overviewMode)`); in focus mode
it gets the meter.

No new texture: `progress-fill`, `solid` and `tab-fill` cover it.

### 5. The footer carries live state, not slash commands

Was a centred hint reading `/vg next · /vg prev · /vg goto <n>`. Now a flex
row:

- `QID nnnnn` on the left, in accent, hidden when the step has no quest id
- `N of M steps completed` pushed right with `margin-left:auto`

The slash-command hint disappears with it. If `/apg goto <n>` has nowhere else
to be discovered, put it in a tooltip rather than keeping the old footer.

### 6. Panel geometry

`#objectives` moves from `top:30px` to `top:180px`, and its cap drops from
`min(78vh, 660px)` to `min(70vh, 600px)` — it sits below the callout now
rather than beside the status bar.

## Already done — do not redo

The previous round landed all of this; it is in the concept's current revision
too, so treat it as built unless something below contradicts it:

- Window chrome on every panel: `panel-2` header, centred wordmark texture,
  ☰ and ✕ chips, subhead strip, 1px rules, rounded caps
- Drag by the header, with the drop position saved per profile and reopening
  respecting it
- Tab bar with the XP/TPL badge, a ✕ on every tab, `+`, and ‹ › scrolling
  once more guides are open than fit (four at most in view)
- Nav row, the 4px progress rule, and the red/green bands for `ACCEPT` and
  `TURNIN` that are current or satisfied
- Rows with the note stacked under the title in `#8f8f86`
- Generated glyphs throughout — no Blizzard icon, button or close-box art
  survives anywhere, and `Tools/verify.py` fails the build if any returns

## Known gap beyond the diff

The **options panel** is the concept surface furthest from the build, and the
diff does not mention it because it did not change. The concept's `#options` is
one scrolling body with accent uppercase `h3` section headers:

| Section | Concept |
|---|---|
| Race | `<select>` |
| Route pack | `.pill-group` of four pills, plus a scrolling `.route-preview` of level → zone |
| Dungeons | The `.dchip` grid |
| Filters | `.toggle-row` with sliding `.switch` toggles |
| Server | `<select>` |

The build instead has a menu of pill buttons that open Dungeons and Filters as
separate windows, and round check dots where the concept has sliding switches.
The route preview does not exist at all.

1.12 has no `<select>`; a cycling button or a small dropdown is the usual
substitute. The `.switch` is a rounded track with a circle that moves — two
generated masks and an anchor change.

## Constraints

- **Lua 5.0**, Interface 11200: `table.getn` not `#`, `string.gfind` not
  `gmatch`, `math.mod` not `%`. `Tools/verify.py` enforces this.
- **No clipping.** Anything the concept does with `overflow:hidden` needs a
  mask that is already the right shape — see `cap-top.tga`.
- **No runtime gradients, no rounded-rect primitive, no CSS letter-spacing.**
  Nine-slice from a mask, bake gradients into the texture, pre-render
  letter-spaced text as a texture.
- **Textures are white masks tinted with `SetVertexColor`** unless they are
  genuinely multi-colour. The palette lives in `Theme.lua` and nowhere else,
  with the concept's hex values kept verbatim so they can be diffed.
- **TGA**: 32-bit RLE truecolor, bottom-left origin, power-of-two dimensions.
  `Tools/make_assets.py` already writes this correctly — add to it rather than
  hand-producing files.
- Absolute texture paths mean the addon folder must stay `Aegis_Pathfinder`.

## Assets this needs

| File | For |
|---|---|
| `icons/expand.tga` | The overview chip — diagonal double arrow, per the concept's inline SVG |
| `nav-arrow.tga` | Restore; three-stop vertical gradient, 64×64, colour baked in |
| `switch-track.tga`, `switch-knob.tga` | If the options panel gets the concept's sliding toggles |

Everything else the concept needs already exists in `media/`.

## Done means

1. `sh Tools/run_tests.sh` green, with new suites covering the new behaviour —
   mode toggling, the meter's arithmetic and its focus-mode-only rule, and the
   footer's two fields. Assertions must fail when the behaviour is broken;
   check that by breaking it deliberately.
2. Each surface matched against the concept element by element, with any
   substitution named and justified.
3. A client pass. Nothing offline proves a texture is the right way up, that
   the bundled fonts render, that the arrow's texcoord rotation works, or that
   the callout is readable over snow. Those are the things most likely to be
   wrong, and they need eyes on a running client.

Report what was substituted and what is still unverified. Do not describe
anything as matching the concept on the strength of the test suite alone.
