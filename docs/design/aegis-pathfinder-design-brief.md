# AEGIS: Pathfinder — Research & Interactive HTML Concept Brief

> **Scope check before you start:** this brief asks for UX research and an interactive HTML/CSS/JS concept prototype — a clickable design mockup to review before committing to Lua. It does **not** ask for Lua, XML, or any WoW API code. If you find yourself writing a `.toc` file or a `RegisterEvent` call, you've gone past the brief.

## 1. What you're doing and why

You're designing the interaction and visual concept for **Aegis: Pathfinder**, a new member of the **Aegis** addon suite — a Classic+ leveling guide for the Turtle WoW-lineage 1.12 client family (OctoWoW, Capybara Paradise, and RavenCraft — see §2), aiming for the in-game experience of Zygor Guides or RestedXP Guides: an always-visible current objective, a waypoint pointing at it, automatic step advancement as quests are accepted/completed/turned in, and a full guide browser for switching paths.

This is a **new addon**, not a reskin of the attached repo. VanillaGuide-Plus / TurtleGuide is your reference for what's already proven to work on this client — treat its structure, vocabulary, and feature set as ground truth to design from, not just loose inspiration.

The deliverable is a **single self-contained HTML file** — real, working, clickable — that shows how Pathfinder would look and behave in-game. It's a design artifact, not shippable code: it exists so the interaction design can be reviewed before any Lua/XML work starts, the same way Aegis: Exchange went through a phase-mapped design brief with exported screens before its build phases.

Use a current frontier-tier model with extended thinking and web search for this. The source repo's own task files (see §3) specify a top-tier model for research-heavy guide work; this brief carries a comparable research load.

## 2. Platform note — read before researching

**Turtle WoW itself is no longer live.** Blizzard sued its operators in mid-2025 over copyright and trademark claims; a federal judge sided with Blizzard, and the original server went permanently offline in mid-May 2026 under an injunction that also barred handing its code to a successor project.

**A family of independent "1.18.1" successor servers filled the gap**, all tracing back to a September 2024 leak of Turtle WoW's server- and client-side code (capped around version 1.17). That leak is what let separate teams each build their own continuation — so "runs the 1.18.1 Turtle client" is true of all of them at the client-version level, but the content built on top of that leak past ~1.17 was reconstructed independently by each team. Treat quest IDs, coordinates, and custom-zone content as **potentially different per server** until verified, even where the addon-compatible client version matches.

*The three currently in scope for Pathfinder:*

| Server | Status (as of Aug 19, 2026) | Pedigree | Notes |
|---|---|---|---|
| **OctoWoW** (octowow.st) | Live since ~May 2026 | Community-built; deliberately anonymous "zero-trust" team | Own quest database at `octowow.st/db`; `pfQuest-octo` database pack available |
| **Capybara Paradise** / "CapyCraft" | Live since May 2026; very high population (reported 11,000+ concurrent at peak) | Founded by Turtle WoW's former Asian/SEA-realm administrator | Chinese-primary community with a growing English one (VPN + translation add-ons commonly used); claims to run inherited, not reconstructed, 1.18.1 code |
| **RavenCraft** (ravencraft.io) | **Not yet live** — official launch Aug 22, 2026 | Claims former contributors from the original 1.18.1-era Turtle WoW team | Publicly disputes other clones' 1.18.1 authenticity, calling their post-leak content reconstruction unreliable — treat that as one side of a rivalry, not settled fact |

**The attached repo currently reflects only the OctoWoW branch of this.** Its README badges the project for `Octo WoW-1.18.1` (via a required ClassicAPI dependency), even though the prose throughout still says "Turtle WoW." Guide content built from this repo (QIDs, coordinates) should be assumed OctoWoW-specific until checked against RavenCraft's and Capybara Paradise's own data.

**Practical implications:**
- Use "Turtle WoW-lineage" or name the specific server when precision matters; "Turtle WoW" alone is fine for in-universe flavor text since that's still how the community talks.
- `database.turtle-wow.org` and `turtle-wow.fandom.com` — cited repeatedly inside the repo's own `docs/GUIDE_AUTHORING.md` — may be stale or unreachable now that the original server is dark. Verify before relying on either; prefer each server's own current database (`octowow.st/db` for OctoWoW) instead.
- For quest-database addon support, `pfQuest-octo` covers OctoWoW; equivalent Capybara Paradise and RavenCraft database packs weren't confirmed in this brief's research and should be tracked down (or their absence flagged) before assuming guide data ports cleanly between servers.
- RavenCraft hasn't launched as of this brief — there's no live server to verify content against yet. Treat it as a near-term target, not a current one.
- Don't assume a single guide dataset serves all three servers without checking — this is the single biggest open risk for a QID-driven addon like Pathfinder.

## 3. Source material: VanillaGuide-Plus / TurtleGuide (attached)

**Lineage:** Tekkub's original TourGuide → isalcedo's VanillaGuide → this fork, "TurtleGuide - ClassicAPI Edition" (repo `VanillaGuide-Plus`, github.com/brues-code/VanillaGuide-Plus). Route content is credited to Joana's Vanilla WoW speedrun guides, plus a full RestedXP (RXP) route conversion.

**Read these files first** — they carry the most design-relevant information:
- `README.md` — feature list, full 1–60 zone path tables for both factions, the status-bar UI diagram, action-icon table, slash commands
- `docs/GUIDE_AUTHORING.md` — the complete step/tag DSL specification, with a full worked example
- `Tools/QuestShellPlus.md` — a structured (table-based, not text-DSL) alternate format — the closest thing to a ready-made JSON schema
- `TurtleGuide.toc` — confirms Interface 11200 (1.12.1 client), optional deps (TomTom, pfQuest, MetaMap, MetaMapBWP), and load order
- `ObjectivesFrame.lua`, `Navigation.lua`, `StatusFrame.lua`, `GuideListFrame.lua`, `OptionsFrame.lua` — skim for any concrete layout/behavior detail not already captured below

**Technical foundation — why this matters for the concept:** the addon depends on a companion project, **ClassicAPI** (also by brues-code; the addon refuses to run below v1.5.9), which backports modern retail-style WoW API to the 1.12 client. Instead of the old vanilla-addon trick of parsing chat system messages and matching quest names as strings, this addon gets real, ID-keyed events — `QUEST_ACCEPTED(questLogIndex, questID)`, `QUEST_TURNED_IN(questID, xpReward, moneyReward)`, `QUEST_REMOVED(questID)` — plus `C_QuestLog`, `C_GossipInfo`, `C_Item`, `C_Container`, and `C_Timer` namespaces for lookups, gossip automation, and bag/item tracking. A quest removed without a turn-in confirmation is treated as an abandon and rewinds the guide to that quest's accept step.

Practically: this is *why* Zygor-quality automatic advancement is plausible on a 1.12 client at all, and the concept should visually communicate that confidence — e.g., distinguish an auto-detected completion from a manually-checked one, rather than treating all "done" states identically.

**The guide data model.** Guides register like this:

```lua
TurtleGuide:RegisterGuide("Zone Name (Level-Range)", "Next Zone (Level-Range)", "Faction", function()
  return [[ ...steps... ]]
end)
```

Each line is one step: a single-letter action code, a title, then zero or more `|TAG|value|` metadata tags.

*Action codes (17 total):*

| Code | Action | Code | Action |
|---|---|---|---|
| A | Accept a quest | B | Buy an item |
| C | Complete quest objectives | b | Take a boat |
| T | Turn in a quest | K | Kill mobs (non-quest) |
| N | Note / instruction | G | Grind mobs for XP |
| R | Travel to a location | U | Use an item |
| H | Use hearthstone | t | Train at a trainer |
| h | Set hearthstone location | D | Die (spirit rez) |
| F | Take a flight path | P | Pet-related action |
| f | Discover a flight point | | |

*Tags worth modeling in the prototype:* `QID` (quest ID — enables smart-skip and tracking), `OIDX` (objective index within a multi-objective quest), `N` (note text, often carrying coordinates as `(45.5, 32.8)`), `Z` (zone override), `C`/`R` (class/race restriction — supports OR-lists like `Mage/Warlock` and negation like `!Hunter`), `O` (optional step), `L` (loot item + quantity), `PRE` (prerequisite). Dungeon-conditional steps use a separate tag, `|D|DUNGEONCODE|` (and negated `!DUNGEONCODE`), gating visibility on which of the 15 supported dungeons (RFC, WC, DM, SFK, BFD, Stockades, Gnomer, RFK, SM, RFD, Ulda, ZF, Mara, ST, BRD) the player has toggled on.

*A real worked example* (from the repo's own authoring doc — use this shape, not generic placeholder quests, when populating the prototype):

```
N Welcome to Thalassian Highlands |N|This is the High Elf starting zone.|

A Refugees no More |QID|41187| |N|Aerthand Skyshield in Brinthilien (48.3, 84.3)| |Z|Thalassian Highlands|
T Refugees no More |QID|41187| |N|Commander Anarileth in Brinthilien (48.6, 83.6)| |Z|Thalassian Highlands|
A Provisions for Refugees |QID|41188| |N|Commander Anarileth in Brinthilien (48.6, 83.6)| |Z|Thalassian Highlands|

A Plain Letter |QID|41230| |N|Brinthilien trainer area| |C|Warrior| |Z|Thalassian Highlands|
A Feathered Letter |QID|41231| |N|Brinthilien trainer area| |C|Hunter| |Z|Thalassian Highlands|

C Provisions for Refugees |QID|41188| |N|Kill Young Thalassian Boars (46, 82) (50, 78)| |Z|Thalassian Highlands|
T Provisions for Refugees |QID|41188| |N|Commander Anarileth (48.6, 83.6)| |Z|Thalassian Highlands|

H Alah'Thalas |N|Set your hearthstone at Tiriel's inn| |Z|Thalassian Highlands|
R Alah'Thalas Docks |N|Travel to the docks (62, 17.9)| |Z|Thalassian Highlands|
B Boat to Auberdine |N|Take the boat to Darkshore|

N Guide Complete |N|Continue to Darkshore (12-17).|
```

Note the two class-gated steps sitting side by side (Warrior gets one letter quest, Hunter gets another) — a real example of the class-branching behavior the concept should show, not just describe.

**A second, structured format exists too** — `QuestShell+`, documented in `Tools/QuestShellPlus.md`. It's Lua tables rather than a pipe-delimited string DSL, and it maps almost directly onto JSON:

```lua
{ type="ACCEPT", title="Your Place In The World", questId=4641,
  coords={x=43.29, y=68.61}, npc={name="Kaltunk"},
  note="Kaltunk in Valley of Trials" },
{ type="ACCEPT", title="Vile Familiars", questId=1485,
  coords={x=42.61, y=68.79}, npc={name="Ruzan"},
  class="Warlock", note="Ruzan in Valley of Trials" },
```

**Use this shape (as JSON) as the prototype's underlying sample data model** rather than trying to parse the pipe-delimited text DSL in JavaScript — it's already the addon maintainers' own answer to "how do we make this format tooling-friendly."

**Feature set to represent** (all present in the attached addon — don't invent features it doesn't have, and don't drop ones it does):
- Race-based starting-zone routing that auto-selects your path, merging into one shared optimized route after level 12
- A choice of route packs: the original zone-completion guides, an "Optimized" reordered path (Joana's routes), and full RestedXP speedrun routes for both factions (plus an RXP Hardcore variant with different solo/no-grouping defaults)
- Dungeon selection: toggle which of 15 dungeons you're running; opting in forces their setup/prereq steps to mandatory, opting out hides them (RXP guides only)
- Play-style filters: Solo/Group mode and an Auction House step toggle, with different defaults depending on which route pack is active
- A **branch system**: jump to any zone guide from the main path, do as much as you want, then "Return to Main" resumes the optimized path at the step matching your current level — with a visible `[Branch]` indicator while off-path
- Smart quest-log scanning on load, so re-logging or switching guides mid-zone finds the right step instead of restarting
- TomTom-style waypoint arrow to the current objective; pfQuest-style prerequisite/chain awareness
- Manual prev/next/checkbox controls alongside the automatic tracking, and slash commands (`/vg`, `/vg next`, `/vg prev`, `/vg goto <n>`, `/vg reset`)

**Reference content to actually use** (real Turtle/OctoWoW data, not placeholders):

*Starting zone per race:*

| Alliance | Zone | Levels | Horde | Zone | Levels |
|---|---|---|---|---|---|
| Human | Elwynn Forest → Westfall | 1–10 → 10–12 | Orc/Troll | Durotar | 1–12 |
| Dwarf/Gnome | Dun Morogh | 1–12 | Tauren | Mulgore | 1–12 |
| Night Elf | Teldrassil | 1–12 | Undead | Tirisfal Glades | 1–12 |
| High Elf | Thalassian Highlands | 1–10 | Goblin | Blackstone Island | 1–10 |

*Custom zones available via branching (all Turtle/OctoWoW-original, not in retail vanilla):*

| Zone | Levels | Faction |
|---|---|---|
| Thalassian Highlands | 1–10 | Alliance |
| Blackstone Island | 1–10 | Horde |
| Balor | 29–34 | Both |
| Grim Reaches | 33–38 | Both |
| Gilneas | 39–46 | Both |
| Icepoint Rock | 40–50 | Both |
| Lapidis Isle | 48–53 | Alliance |
| Gillijim's Isle | 48–53 | Horde |
| Tel'Abim | 54–60 | Both |

*Shape of the Alliance optimized path* (opening stretch — the full 1–60 tables for both factions are in the attached `README.md`; pull from there rather than inventing zone order):

| Levels | Zone |
|---|---|
| 12–14 | Darkshore |
| 14–17 | Darkshore |
| 17–18 | Loch Modan |
| 18–20 | Redridge Mountains |
| 20–21 | Darkshore |
| 21–22 | Ashenvale |
| 22–23 | Stonetalon Mountains |
| 23–24 | Darkshore |

...continuing the same way through 59–60 Winterspring.

**Companion addons the concept should acknowledge** (shown as detected/recommended, not built from scratch): TomTom (waypoint arrow) and a pfQuest database pack matched to the active server (`pfQuest-octo` for OctoWoW; see §2 for the other two) — the real addon hard-depends on TomTom's API for its arrow and gets prerequisite warnings from pfQuest when installed.

## 4. UX inspiration: Zygor Guides & RestedXP Guides

**Zygor Guides** — the "GPS for WoW" reference point. What's worth borrowing:
- A moveable, always-on-top guide window with the current step at top and a directional indicator toward the objective
- Contextual markers over NPCs and objects — a small star/square/skull-style icon depending on whether you need to talk, click, or kill something there
- Automatic advancement the moment an objective completes, with the guide visibly "catching up" to where you actually are
- A guide/step list you can scrub through, not just a single-step view
- Comprehensive scope (professions, dungeons, achievements) — but Pathfinder's concept should stay leveling-focused; don't scope-creep into profession or achievement guides unless asked

**RestedXP Guides** — the efficiency-first reference point, built by speedrunners (Tactics and Zeroji) and already deeply integrated into the attached addon (full RXP and RXP Hardcore route packs, a dedicated `RXPConverter.lua` and `convert_rxp.py`). Its ethos is a leaner UI and routes optimized purely for /played time — worth noting this inspiration is *already partly satisfied by the source material itself*, so the concept doesn't need to invent RXP-style routing from scratch, just present it well.

**Synthesis for Pathfinder:** aim for Zygor's visual clarity and polish on top of the attached addon's actual feature set (which already leans RXP-efficient by default). The concept should read as "a clean, modern execution of what TurtleGuide/VanillaGuide-Plus already does," not a reinvention.

## 5. What to build: the interactive HTML concept

**Format:** one self-contained HTML file (inline CSS and JS, no build step). Light use of an external font or a small utility library via a CDN is fine if it improves authenticity; keep the core interaction logic in plain JS so the file stays portable. Assume a fixed desktop viewport — this mimics an in-game addon frame, not a responsive website.

**Visual direction:** it should read as a believable WoW 1.12-era addon window, not a generic web dashboard with WoW words on it. Think parchment/beaten-metal frame borders, a WoW-appropriate serif/display typeface for headers, gold and deep-red/blue accent colors, and small icon glyphs for each action type (accept/complete/turn-in/travel/etc.) — evocative of the game's own UI skin, executed with clean, modern front-end code underneath.

**Surfaces to mock** (mirror the real addon's two-tier structure):
1. **Compact status bar** — always visible, one line, matching this information density from the real addon:
   ```
   [✓] [<] [icon] [15/120] Kill 8 Grell Earring [?] [>]
   ```
   checkbox • prev • action-type icon • step counter (current/total) • objective text • note indicator (hover for detail) • next
2. **Full Objectives Panel** — opens on click, scrollable step list around the current position, with the Branch button and progress indication
3. **Options Panel** — route pack selector (Zone Completion / Optimized / RestedXP / RXP Hardcore), dungeon toggles, Solo/Group and AH filters
4. **Branch selector** — categorized list (Optimized Path / RestedXP Speedrun / Turtle-lineage Custom Zones / Zone Guides)

**Interaction flows the prototype must actually demonstrate** (clickable, not just described in a caption):
- Normal progression through a few real steps (use the Thalassian Highlands excerpt from §3), including at least one auto-advance moment and one manual next/checkbox use
- Branching from the main path to a custom zone guide, then "Return to Main" — showing the `[Branch]` indicator while off-path and the resume-at-correct-level behavior on return
- Toggling a dungeon on in Options and seeing its steps appear/reflow in the Objectives Panel
- Switching route packs and seeing the guide list change accordingly

**Out of scope:** no Lua, XML, or WoW API calls; no claim that this is installable in-game; no backend/network logic. This is a front-end illustration of the interaction design, full stop.

## 6. Design & technical consistency notes

- The eventual build target is Lua 5.0 on the 1.12.1 client (Interface 11200) via Ace2 (`AceAddon-2.0`, `AceEvent-2.0`, `AceDB-2.0`, etc. — the same stack the attached addon already uses) plus ClassicAPI for QID-based tracking. The HTML concept isn't bound by any of that, but avoid designing interactions with no plausible path to a WoW frame later — e.g., don't lean on hover-only reveals with no click equivalent, since WoW's UI is mouse-and-click-first.
- Pathfinder doesn't need to visually match Aegis: Exchange's clean Auctionator-style look — that aesthetic was chosen for an auction house tool. Pathfinder's reference point is Zygor/RestedXP/the source addon's own in-game window, a different (and for this addon, more appropriate) visual lineage. Keep naming and spirit consistent with the suite; don't force a shared skin that doesn't fit.
- Following the Aegis: Exchange precedent, treat this HTML concept as a design-phase artifact — something to review before Lua work starts, not something that ships in the `.toc`.
- If §7's research confirms quest IDs/coordinates diverge between OctoWoW, Capybara Paradise, and RavenCraft, the concept should at least gesture at a server selector (even a simple label or dropdown) rather than silently assuming one dataset fits all three — but don't over-build this until that question is actually answered.

## 7. Before you design: research checklist

- [ ] Confirm whether OctoWoW, Capybara Paradise, and (once live) RavenCraft actually share quest IDs/coordinates, or whether each needs its own guide dataset
- [ ] Check RavenCraft's launch status (targeting Aug 22, 2026) before treating it as a live reference platform
- [ ] Confirm each server's current patch/version number and whether anything past 1.18.1 has shipped
- [ ] Confirm whether `database.turtle-wow.org` / `turtle-wow.fandom.com` still resolve; use each server's own current database instead where possible
- [ ] Pull a few current Zygor Guides and RestedXP Guides screenshots or clips for visual reference — the addon landscape moves, and it's worth confirming these still look/behave as described in §4

## 8. Process

1. Read the source material in §3's file list and skim the UI-related Lua files
2. Do the research checklist in §7
3. Sketch the information architecture — what lives in the status bar vs. the full panel vs. options — before writing any HTML
4. Build the single-file interactive HTML concept
5. Self-check against §9 before calling it done
6. Present it with a short rationale for the key UX calls made — not a full design document, just enough to explain "why this and not the obvious alternative" where it isn't self-evident

## 9. Output requirements

- [ ] A veteran of the Turtle WoW-lineage servers (OctoWoW, Capybara Paradise, RavenCraft) who's used Zygor or RestedXP should recognize this immediately — not read it as a generic web app with WoW vocabulary bolted on
- [ ] Every feature listed in §3's "Feature set to represent" appears somewhere in the concept, interactively
- [ ] Sample content is real/representative (per §3 and §5), not Lorem Ipsum or invented quest names
- [ ] Single HTML file, self-contained, actually clickable end to end
- [ ] Terminology matches §2 (Turtle WoW / OctoWoW, not "Turtle WoW" presented as still-current)
- [ ] Ships with a short rationale, not a full write-up
