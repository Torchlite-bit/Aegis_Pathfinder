# Contributing to AEGIS: Pathfinder

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
| `Tools/verify.py` | Lua syntax, Lua 5.0 compatibility for shipped files, `.toc` paths, `Guides.xml` completeness, TGA validity, no Blizzard chrome |
| `Tools/convert_professions.py --check` | The profession source document still parses and is internally consistent |
| `Tools/test_theme.lua` | The theme layer against a stubbed 1.12 API |
| `Tools/test_professions.lua` | Generated guides through the real parsers |
| `Tools/test_statusframe.lua` | The status card's layout and population |
| `Tools/test_servers.lua` | Guide data provenance and mismatch detection |
| `Tools/test_dungeons.lua` | Dungeon chips and the guide-reference scan |
| `Tools/test_guidelist.lua` | Guide categorisation, tabs and badges |
| `Tools/test_activeframes.lua` | Active Items and Active Targets: which items and targets each step offers, targeting and raid marks, placement, the key bindings |
| `Tools/test_materials.lua` | Shopping list arithmetic, checked against the source document's own shopping list; bag counts, the scope tabs, and sending to Aegis: Exchange |
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
document in `Tools/data/`, then regenerate:

```sh
python3 Tools/convert_professions.py
```

## Guide data and servers

Guide content in this repository was authored against **OctoWoW**. The
Turtle WoW-lineage servers each reconstructed content past roughly patch 1.17
independently, so quest ids and coordinates are not guaranteed to match on
Capybara Paradise or RavenCraft.

If you author or verify guide data, say which server you checked it against.
Guides that silently assume one server's data is the most likely source of
wrong waypoints in this addon.
