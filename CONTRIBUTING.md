# Contributing to Aegis: Pathfinder

## Getting credited

Add yourself to [CONTRIBUTORS.md](CONTRIBUTORS.md) in the same pull request as
your change. Put yourself in the table your work belongs to, or start a new row
if none fits. Nobody will do this for you, and a contribution that goes
uncredited because the list was not updated is a bug in our process, not yours
— so if you forget and notice later, send a PR that just adds you.

The in-game credits window (the **Credits** button at the bottom of the
options panel) reads from `Credits.lua`, which mirrors `CONTRIBUTORS.md`.
Update both.

## Branching

Work on a branch and open a pull request against `main`. Do not push a `v*`
tag unless you mean to cut a release — that tag triggers the release packager.

## Running the checks

```sh
sh Tools/run_tests.sh
```

That runs everything that can run without a WoW client:

| Check | What it covers |
|---|---|
| `Tools/verify.py` | Lua syntax, Lua 5.0 compatibility for shipped files, `.toc` paths, `Guides.xml` completeness, TGA validity, no Blizzard chrome, the 32-upvalue ceiling |
| `Tools/convert_professions.py --check` | The profession source document still parses and is internally consistent |
| `Tools/test_theme.lua` | The theme layer against a stubbed 1.12 API |
| `Tools/test_professions.lua` | Generated guides through the real parsers |
| `Tools/test_statusframe.lua` | The status card's layout and population |
| `Tools/test_servers.lua` | Guide data provenance and mismatch detection |
| `Tools/test_dungeons.lua` | Dungeon chips and the guide-reference scan |
| `Tools/test_guidelist.lua` | Guide categorisation, tabs and badges |
| `Tools/test_activeframes.lua` | Active Items, Active Targets and Macros: which items and targets each step offers, targeting and raid marks, the generated AegisTarget/AegisItem macros, placement, the key bindings |
| `Tools/test_setup.lua` | First-time setup: when it opens, which guides and dungeons it offers, and what Finish writes |
| `Tools/test_nextguide.lua` | Where next?: which custom zones fit a level, and the walk from a route guide to a custom zone and back to the route |
| `Tools/test_materials.lua` | Shopping list arithmetic, checked against the source document's own shopping list; bag counts, the scope tabs, and sending to Aegis: Exchange |
| `Tools/test_craftplanner.lua` | The crafting route planner: reading the recipe data, the skill-up chance, the route against brute force, learning fees, make-or-buy, pricing at depth, stock carried between steps, selling back, unpriced reagents; the auction scan against the suite's auction house rules; every profession planned from the real data |
| `Tools/test_craftroute.lua` | The crafting route window and planned guides: rank steps placed where the skill cap runs out, crafts contiguous and parsed as skill steps, saving and restoring, the window's totals, rows, status line, re-planning only on change, and the scan button |
| `Tools/test_objectivetabs.lua` | The objectives tab bar and branch state |

Everything must pass before you open a PR. **None of it proves the UI looks
right** — that still needs someone to load the addon on a 1.12 client and look
at it. Say in your PR whether you did.

## Code rules

**The client runs Lua 5.0.** No `#` length operator (`table.getn`), no
`string.gmatch` (`string.gfind`), no `select()` on varargs — the addon has its
own `AegisPathfinder.select` shim. `Tools/verify.py` enforces this for shipped
files; files excluded by `.pkgmeta` run on desktop Lua and are exempt.

**Match the surrounding code.** This is a long-lived fork with an established
idiom. Do not modernise code you are only passing through.

**No function may read more than 32 file-scope locals.** Lua 5.0 refuses to
load a file that breaks this ("too many upvalues"), taking the whole addon
with it, and the Lua 5.1 the tests run on allows 60, so nothing else notices.
Group constants into a table rather than adding another local beside a large
function. `Tools/verify.py` checks it with `luac -l`; the guide panel's builder
in `ObjectivesFrame.lua` is over the line already and is held at its current
count until that is resolved.

**Colours, fonts and textures live in `Theme.lua`**, and nowhere else. If you
need a colour that is not there, add it there.

**Textures are generated.** Do not hand-edit anything in `media/` — change
`Tools/make_assets.py` and re-run it. See [media/README.md](media/README.md).

## Writing guides

See [docs/GUIDE_AUTHORING.md](docs/GUIDE_AUTHORING.md) for the step and tag
reference.

Two formats are supported. Hand-written guides use the pipe-delimited DSL.
Generated guides use QuestShell+ structured tables, because a generated corpus
diffs and validates far better that way.

**Profession guides in `Guides/Professions/` are generated.** Editing them by
hand will be overwritten. Change `Tools/convert_professions.py` or the source
document in `Tools/data/`, then regenerate. Engineering, which the document
does not cover, comes from CraftRoute's fixed route
(`Tools/data/craftroute_routes.json`, exported by `Tools/import_recipes.py`)
with its trainers in `Tools/data/profession_training.json`:

```sh
python3 Tools/convert_professions.py
```

**Recipe data in `Crafting/` is generated** from
[CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute)'s data files, with
its author's permission, by `Tools/import_recipes.py`. To pick up a newer
CraftRoute, check it out and run:

```sh
python3 Tools/import_recipes.py <path to CraftRoute>
```

Only the data is taken, rewritten into this addon's own one-line-per-recipe
format (documented at the top of each generated file); the planner in
`CraftPlanner.lua` is written separately. Reagents CraftRoute gives only by
item id are named from pfQuest's item database, cached in
`Tools/data/recipe_item_names.json`; pass `--pfquest <dir>` to refresh it.

**Filter tags.** The Auction House, Group and Dungeon switches act on `|AH|`,
`|P|GROUP|` and `|D|<code>|` tags. The RestedXP and RXP Hardcore guides carry
them; the Optimized and zone guides mostly do not, so on those the switches
change little. `Tools/find_filter_candidates.py` lists the steps there that
probably should be tagged -- by quest, from the RestedXP guides' own tags and
from the guides' notes -- into `docs/review/filter_candidates.json`, for a
person to review before any tag is added.

## Guide data and servers

Guide content in this repository was authored against **OctoWoW**. The
Turtle WoW-lineage servers each reconstructed content past roughly patch 1.17
independently, so quest ids and coordinates are not guaranteed to match on
Capybara Paradise or RavenCraft.

If you author or verify guide data, say which server you checked it against.
Guides that silently assume one server's data is the most likely source of
wrong waypoints in this addon.
