# Contributing to Aegis: Pathfinder

## Getting credited

Add yourself to [CONTRIBUTORS.md](CONTRIBUTORS.md) in the same pull request as
your change. Put yourself in the table your work belongs to, or start a new row
if none fits. Nobody will do this for you, and a contribution that goes
uncredited because the list was not updated is a bug in our process, not yours
— so if you forget and notice later, send a PR that just adds you.

The in-game credits window (the **Credits** button on the options window's
**About** page) reads from `Credits.lua`, which mirrors `CONTRIBUTORS.md`.
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
| `Tools/convert_professions.py --check` | The profession source document still parses and is internally consistent; the gathering guides cover 1–300 for each faction with somewhere named in every band; the committed guides are what the generator writes |
| `Tools/test_theme.lua` | The theme layer against a stubbed 1.12 API |
| `Tools/test_smartskip.lua` | Where a guide opens: a new character at the top, a quest in progress or ready to hand in at its step, otherwise the first step not done |
| `Tools/test_yourplace.lua` | Right-clicking the step arrows: back or on to your place after clicking round, every mark and completion the arrows changed put back (a completion earned meanwhile kept), only in the arrow's direction, and with no clicking round, to where the guide would open |
| `Tools/test_filtertags.lua` | The filter tags in the Optimized and zone guides through the real parser: group quests and their follow-ups hide in Solo mode, Auction House steps with Auction House steps off, dungeon quests with the dungeon unticked, and all three -- with trading -- under Solo Self-Found; and every approved tag is still in place |
| `Tools/test_professions.lua` | Generated guides through the real parsers: skill bands tile 1–300 for each faction, every rank is reached, and a gathering guide never sends a faction into the other side's starting zones or capitals |
| `Tools/test_statusframe.lua` | The status card's layout and population |
| `Tools/test_dungeons.lua` | Dungeon chips and the guide-reference scan |
| `Tools/test_guidelist.lua` | Guide categorisation, tabs and badges |
| `Tools/test_activeframes.lua` | Active Items, Active Targets and Macros: which items and targets each step offers, targeting and raid marks, the generated AegisTarget/AegisItem macros, placement, the key bindings |
| `Tools/test_setup.lua` | First-time setup: when it opens, which guides and dungeons it offers, Solo Self-Found holding the other features off, and what Finish writes |
| `Tools/test_nextguide.lua` | Where next?: which custom zones fit a level, and the walk from a route guide to a custom zone and back to the route |
| `Tools/test_materials.lua` | Shopping list arithmetic, checked against the source document's own shopping list; bag counts, the scope tabs, and sending to Aegis: Exchange |
| `Tools/test_craftplanner.lua` | The crafting route planner: reading the recipe data, the skill-up chance, the route against brute force, learning fees, make-or-buy, pricing at depth, stock carried between steps, selling back, unpriced reagents; the auction scan against the suite's auction house rules; every profession planned from the real data |
| `Tools/test_itemscore.lua` | The item score: reading 1.12 tooltips (stats, weapon DPS, school spell damage, set bonuses and procs ignored, red lines meaning unusable or later), soft caps, the spec from your talents, your own weights and sharing them in OctoPawn's string, comparing by slot (rings, two-handers, dual wield), and the tooltip line |
| `Tools/test_gearadvisor.lua` | The Gear Advisor: upgrades found in the bags, offered biggest first and once a session, Equip into the right slot (waiting out a fight, finding an item that moved), Decline remembered across reloads, equip-for-me never binding an item, off at 60; the best quest reward (upgrade, else sell price, waiting for items to load) marked and picked; upgrades bordered in the bags |
| `Tools/test_gearfinder.lua` | The Gear finder: the dungeons it looks in (level, side, your ticks, raids), the drops it weighs (level, class), Turtle WoW's own items described by the client (and badges, greys and items above you never weighed), quest rewards (not done, your side and class, within reach), reputation gear and crafted gear (bind-on-pickup and Solo Self-Found only with the profession), loading the ones not cached, the best three a slot in the character sheet's order, the window, and naming upgrades on walking into a dungeon; and that the real loot data is there |
| `Tools/test_gearframe.lua` | The Item Score page: the spec picker, the weights listed down the left and edited, show all growing the page, export, import and reset beside and under them |
| `Tools/test_craftroute.lua` | The crafting route window and planned guides: rank steps placed where the skill cap runs out, crafts contiguous and parsed as skill steps, saving and restoring, the window's totals, rows, status line, re-planning only on change, and the scan button |
| `Tools/test_partysync.lua` | Sharing a guide with the party: step names that survive different step numbering, holding a finished step for the slowest partner without pulling anyone back, skipping out of a hold, the messages both ways, the throttle and heartbeat, the popups, the members under the step, and the group changing |
| `Tools/test_objectivetabs.lua` | The objectives tab bar and branch state |

Everything must pass before you open a PR. **None of it proves the UI looks
right** — that still needs someone to load the addon on a 1.12 client and look
at it. Say in your PR whether you did.

## Versions

Numbered as every Aegis addon is: `MAJOR.MINOR.PATCH`, and `0.x` until the
public release, when MAJOR becomes 1.

- **MINOR** for a new capability — something the addon could not do before.
  **PATCH** for a fix, wording, colour, layout, or a corrected calculation.
  **MAJOR** only for a change that breaks an existing setup with no migration.
- **One push, one MINOR**: a body of work that lands in one merge takes a single
  MINOR bump, and each change inside it is a PATCH under that.
- A bump touches **five places**: `Core.lua` (`AegisPathfinder.version`), the
  `.toc`'s `## Version`, the README's H1 and its "Something broken?" line, and a
  new [`CHANGELOG.md`](CHANGELOG.md) entry with its link reference at the
  bottom. `Tools/verify.py` checks they agree.
- Mark a release **restart** in the changelog when it adds or removes a `.lua`
  file in the `.toc`, or a texture in `media/`.
- Nothing under `Tools/` or `docs/` ships, so a change there alone is not a
  release and takes no bump.

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
function -- `ObjectivesFrame.lua` keeps its layout in `G` for this reason.
`Tools/verify.py` checks it with `luac -l`.

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
with its trainers in `Tools/data/profession_training.json`. Herbalism, Skinning
and Fishing are built by `Tools/gathering_guides.py` from
`Tools/data/gathering.json`, which also gives each step of the Mining route,
per faction, where to mine its ore. They only send players to zones this addon
has a zone guide for:

```sh
python3 Tools/convert_professions.py
```

`Tools/data/gathering.json` is extracted from pfQuest (herb and ore nodes,
spawn points, zone names) and the CMaNGOS classic-db dump (the ore each vein
yields, skinnable creatures, fishing skill by zone, trainers, the Expert
fishing book, Nat Pagle's quest).
To refresh it, check both out and run:

```sh
python3 Tools/build_gathering.py --pfquest <pfQuest> <pfQuest-turtle> --cmangos <classic-db full dump .sql[.gz]>
```

**`ItemScoreData.lua` is generated** from
[OctoPawn](https://github.com/iGreed1993/OctoPawn)'s defaults (MIT; its notice
is carried in the file) by `Tools/import_octopawn.py`: the stat weights for every
class and spec, the tooltip patterns, the soft caps. To pick up a newer OctoPawn,
check it out and run:

```sh
python3 Tools/import_octopawn.py <path to OctoPawn>
```

**`GearData.lua` is generated** from the CMaNGOS classic-db dump and a
pfQuest-turtle checkout by
`Tools/build_gear_data.py --cmangos <dump> --pfquest-turtle <pfQuest-turtle>`:
what each quest reward sells for, which the Gear Advisor falls back on when no
reward is an upgrade; and for the Gear finder, what drops in each dungeon and
raid, which quests reward gear, what reputation vendors sell, and what the
professions make (`other_sources`) -- Turtle WoW's own from pfQuest-turtle, whose zones for them are listed
in `TURTLE_INSTANCES`, and Turtle's changes to the vanilla ones laid over the
CMaNGOS loot (`turtle_vanilla`).

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
`|P|GROUP|` and `|D|<code>|` tags. The RestedXP and RXP Hardcore guides always
carried them. The Optimized and zone guides carry the ones the owner approved:
`Tools/find_filter_candidates.py` listed the steps that probably wanted one
(`docs/review/filter_candidates.json`), the answers are in
`docs/review/filter_decisions.json`, and `Tools/apply_filter_tags.py` applies
them. A "yes" on a quest's own step tags every step of that quest; a "yes" on
a note or buy step that merely carries a quest id tags only that step; an
answer changed to "no" takes the tag off again. An Auction House tag belongs on
the step that sends you to the Auction House, not on a quest you can also do by
fishing, farming a drop or finding a vendor -- those are answered "steps", which
tags only the buy steps. Only a quest that needs an item a crafting profession
makes keeps the tag on the quest itself. Quests
you can only reach through a tagged one inherit its tag (worked out from
pfQuest's prerequisites with `--pfquest`, and kept in the decisions file).
When you add a step for a tagged quest, give it the same tag --
`Tools/test_filtertags.lua` runs `apply_filter_tags.py --check`, which fails
if an approved tag has gone missing.

## Guide data and servers

Turtle WoW, OctoWoW, Capybara Paradise and RavenCraft share the quests and
places these guides use, so one set of guides serves all of them. If you find a
quest id or a location that differs on one server, report it with the server
and the step.
