# Aegis: Pathfinder — features in full

Everything the addon does, in detail. The [README](../README.md) is the short
version.

## Commands

| Command | |
|---|---|
| `/apg` | Open the objectives panel |
| `/apg next` / `prev` | Step forward or back |
| `/apg goto <n>` | Jump to a step |
| `/apg reset` | Reset progress in the current guide |
| `/apg resetpanels` | Put every window back where it opens by default |
| `/apg materials` | The shopping list: reagents for this craft, or the rest of the guide |
| `/apg exchange` | Send the guide's remaining crafts to Aegis: Exchange, or take them back out |
| `/apg craft` | The crafting route window: the cheapest way to level a profession at today's prices |
| `/apg share` | Share the guide you are on with your party, or stop sharing (beta) |
| `/apg gear` | The options at **Item Score**: the stat weights behind the item score |
| `/apg finder` | The Gear finder: upgrades that drop in the dungeons you run |
| `/apg ssf` | Solo Self-Found on or off |
| `/apg setup` | Run the first-time setup again: your guide, its features and your dungeons |
| `/apg target` | Target and mark the step's next active target (put it in a macro) |
| `/apg useitem` | Use the first active item |

`/pathfinder` and `/vg` do the same thing. There is deliberately no `/aegis` —
that belongs to another addon in the Aegis suite.

The objectives panel is the addon's main window, so a bare `/apg` opens it, and
it opens with the client. The Aegis shield on the edge of the minimap does the
same on a click; right-click it for the options window, and drag it to move it
round the minimap. The options window's **Behaviour** page can hide it, as can
`/apg minimapbutton`.
FuBar is no longer supported: the button is the addon's own now.

The options window can be resized from its bottom-right corner, wider or
taller, and keeps the size; `/apg resetpanels` puts it back. It lists its
pages down the left: **Route** (race and route
pack), **Dungeons**, **Filters**, **Appearance** (server theme), **Gear** and
under it **Item Score** (the stat weights), **Behaviour**, **Navigation** (waypoints and arrow), **Maintenance** (rescan,
error log, setup) and **About** (version and credits).

## What it does

**Routes.** Pick a route pack on the options window's **Route** page: Optimized (Joana's
routes), RestedXP, or RXP Hardcore. (Kamisayo Speedrun, a Horde Warrior pack, is
hidden until its guides are added; a character that had it moves to RestedXP.)
A preview underneath shows the route your race takes under it. Your race's
starting zone is selected for you, and all races merge into a shared route
after level 12.

**Tabs.** Up to eight guides open at once, one per tab. The bar shows up to
four at a time — fewer on a narrow panel — and arrows either side (or the
mouse wheel over the bar) scroll through the rest; the tab you are on is
always brought into view. The first is your main route — what the addon
advances along on its own. Left-click a guide in the list to open it beside
what you are reading, or right-click to load it into the tab you are on; each
tab remembers its own place. Every tab can be closed; close them all and the
panel waits, empty, for you to pick one.

**Dungeons.** Toggle which of 15 dungeons you intend to run. Opting in promotes
their setup and prerequisite steps to mandatory; opting out hides them. A blue
dot marks the dungeons the guide you are currently on actually has steps for.

**Filters.** Solo or group mode, and whether Auction House steps appear.
Defaults follow the route pack you chose. They act on every route pack: in
Solo mode the Optimized and zone guides leave out elite and group quests, and
the quests that follow on from them; with Auction House steps off they leave
out quests that need an item most players buy there.

**Solo Self-Found.** For a character that plays alone, never trades and never
uses the Auction House: group quests, dungeon quests and every step that trades
or uses the Auction House are left out. While it is on, the group mode and
Auction House switches and the dungeon chips are held off and can't be clicked
-- in the options and in the first-time setup -- and the Gear finder looks in
no dungeons. What they were set to is kept, and comes back when it goes off.
It is a switch under **Filters**, a choice in the first-time setup, and
`/apg ssf`.

**First-time setup.** The first time the addon loads on a character, a short
setup asks three things, as RestedXP does:

1. **Your guide**: Optimized (quest-optimized 1-60, every race), RestedXP
   Speedrun, or Hardcore Survival. Only guides with a route for your race are
   offered.
2. **Features**: Auction House steps, Solo Self-Found, group quests, dungeons.
3. **Dungeons** (when dungeons are on): the dungeons your faction can run, with
   level ranges and how many quests each adds to your route, plus
   **Recommended**, **All** and **None**. A quest counts only if the guide you
   picked takes you all the way through it on your race's route: sends you to
   pick it up, has you do first whatever the server wants done before it, and
   sends you to hand it in. A quest whose chain runs through another dungeon
   counts once that one is ticked too -- "1 quest (+4 with Deadmines)" for the
   Stockade until the Deadmines is. **Recommended** picks the dungeons that add
   five quests or more, for the guide you picked: RestedXP and RXP Hardcore
   take you through many, the Optimized guides through few, so each has its
   own.

It starts from what the character already has, so an existing character can
finish it without changing anything, and it keeps your place in your guide
unless you pick a different one. Where the chosen guides do not mark a kind of
step yet, it says so. Closing it keeps your current settings. Run it again with
`/apg setup` or **Run setup** on the options window's **Maintenance** page.

**Your route decides what comes next.** Finish a guide on your route and the
next is the route's next leg for your guide pack and race -- RestedXP, for
one, sends the Eastern Kingdoms races through Redridge at 19 and Night Elves
through Darkshore. A guide you picked off the route goes on where its own
next guide says.

**Custom zones between guides.** When you finish a guide and a custom zone
fits your level, a small **Where next?** window asks whether to carry on with
the route or take the custom zone. Finish Redridge Mountains (27-28) at 28, for
example, and it offers the next Optimized guide or Northwind (28-34). A custom
zone opens in a tab beside the route, with the route's next guide waiting in the
first tab. Finish the custom zone and it asks again: back to the route, at the
guide for the level you are by then, or on to the next custom zone that fits. A
zone fits when you are inside its level range or one short of it, below its top,
and have not finished it; with none that fit, nothing is asked. Closing the
window carries on with the route. The options window can switch it off (*Offer
custom zones between guides*, under **Behaviour**). The custom zones are also under the guide
list's **Custom** tab at any time.

**Moonwhisper Coast (52-60)**, which came with patch 1.18.1, has a guide for
each side: the draenei of Moro'gai Village for both, Sunsworn Camp and Narvalis
Point for the Alliance, Moonhoof Village and Moonhoof Retreat for the Horde,
with the Horde's trips to Azshara and Mulgore and back where its stories go.
It is written from quest data players have gathered, not from a server's
database, and that data is still growing: quests nobody is on record as giving,
and the ones that start elsewhere, show only once they are in your log. Its
bosses, Price of Betrayal and Draenethyst Recovery are group quests: in Solo
mode they are left out, with what follows them -- for the Horde, the Moonhoof
story from Shade Mother on.

**Professions.** Ten 1–300 routes with trainers, craft counts, reagents and
recipe sources, tracked against your actual skill level. See below.

**Shopping list.** On a guide with reagents the panel's footer carries a
**Shopping list** button (or `/apg materials`). It pops out beside the guide
with what you need and what your bags already hold — `12/40 Peacebloom` —
short lines in gold, covered ones dimmed, updating as your bags change. The tab
at the top switches between **This step** (the craft you are on or coming up
to) and **Whole route** (everything still ahead, counted from where you
actually are rather than from step one, so it is the number you want at the
auction house).

With [Aegis: Exchange](https://github.com/Torchlite-bit/Aegis_Exchange)
loaded, **Send to Exchange** at the bottom of the list (or `/apg exchange`)
puts each craft still ahead on Exchange's Crafting tab, where its shopping
list prices every line at the auction house. It stays in step: finish a craft
and it leaves Exchange too; finish the route and the list is gone. **Remove
from Exchange** takes it all back out. Recipes you captured in Exchange
yourself are never touched — if one shares a name with a craft on the route,
it is set aside while the route's stands in for it and put back afterwards.
Exchange's demo mode has to be off.

**Cheapest crafting route.** **Cheapest route** on the shopping list (or
`/apg craft`) opens a window that works out the cheapest way from your skill to
300 in a profession at today's prices, as
[CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute) does — without
needing CraftRoute. It shows the total, what it is made of (reagents, recipes,
what you get back selling leftovers to a merchant), and a row per recipe: the
skill band, how many crafts, the reagents and what the step costs. Hover a row
for how the recipe is learned, what to buy and what gets made first.

- **Prices** come from merchants (built in) and the auction house: press **Scan
  prices** with the auction house open and it searches for each reagent and
  recipe the profession could use, the route's own first, keeping every
  listing so forty of something is priced as forty. With Aegis: Exchange
  loaded its prices are used too. A reagent nobody has a price for is never
  counted as free: the route avoids it, or says it has no price.
- **Your recipes**: open your profession window once and the recipes you know
  cost nothing to learn; drop and reputation recipes are only used once you
  know them.
- **Load as guide** turns the route into a guide, *Alchemy (cheapest route)*
  and so on, in the Professions list: the authored guide's trainers, level and
  rank steps (and the Expert cookbook and Artisan quest for Cooking) placed
  where your skill cap runs out, with the planned crafts in between. It is kept
  between sessions and replaced when you plan again.

It plans Alchemy, Blacksmithing, Cooking, Enchanting, Engineering,
Jewelcrafting, Leatherworking, Survival and Tailoring, from 1,095 recipes whose
thresholds, reagents and sources come from CraftRoute's data (with its
author's permission); the planner itself is this addon's own.

**Active items and targets.** Two small windows, as RestedXP has, hang under
the guide. **Active Items** has a button for every item the guide wants you to
use — the current step's, and those for any quest in your log that is not done
yet. **Active Targets** has a button for whoever the step wants you to find: the
quest's giver or hand-in, what it wants killed, what drops what it wants
collected, the trainer a profession step sends you to. Click one to target it
and mark it for what the quest wants with them (see **Quest icons**).
`/apg target` does the same for the next one each time you press it, so a macro
with just that line works like RestedXP's; both also have key bindings under
*Aegis: Pathfinder* in the key bindings menu. Targets come from pfQuest's
database, so quest steps need pfQuest; profession steps name their trainers
themselves. Either window can be dragged anywhere, or switched off under
**Behaviour** in the options.

**Quest icons.** Mouse over or target anyone a quest wants and the right raid
marker goes on them by itself, as RestedXP's Quest Icons do:

| Marker | Means | Who |
|---|---|---|
| Star | Talk | Gives or takes the quest; the trainer or vendor a profession step names |
| Square | Interact | A friendly NPC the quest's objectives involve |
| Skull | Kill | An enemy the quest wants killed |
| Cross | Loot | An enemy that drops what the quest wants collected |

It covers the current step and every quest in your log: what an unfinished
quest wants killed or looted, and who takes a finished one. It never replaces a
marker already there (a party member's, say), skips players and corpses, and
stays out of raids, where markers belong to the leaders. Someone marked for
killing who turns out not to be attackable gets a square instead. Quest-log
marks need pfQuest and ClassicAPI (which gives the log's quest ids); without
ClassicAPI only the current step is marked. The options window can switch it
off, under **Behaviour**.

**Macros.** A third small window, **Macros**, holds two real macros the addon
writes into your character's macro book and keeps up to date: **AegisTarget**,
with a `/target` line for each of the step's targets and a line that marks
whoever it found, and **AegisItem**, which uses the quest item the step needs
and wears that item's icon. Drag either tile onto an action bar once; from then
on the macro follows the guide by itself, step after step. Clicking a tile does
what its macro does. They are made the first time there is something for them
to do, use two of your 18 character macro slots (the window says so if none are
free), and are never rewritten while the macro window is open. The options
window can switch it off, under **Behaviour**, which also stops the macros
being made or updated.

**Sharing a guide with your party (beta).** Playing a guide with someone else
is awkward when neither of you can see which step the other is on. In a party,
click the party icon at the right of the guide panel's step row (or
`/apg share`) and confirm; everyone in the party running Aegis: Pathfinder gets
a popup, and accepting opens the guide in a new tab. From then on:

- Under the step, each member sharing it is listed with their progress on it —
  `Ghanndraine [3/6]`, `[done]` — or which step they are on, if another.
- A step you have finished waits until everyone sharing has finished it too,
  then the guide moves on for all of you. Nobody is pulled back to someone who
  is behind: you wait where you are. The skip arrow still moves you on alone.
- The icon is gold while nobody has accepted yet, lit once someone has, and a
  second click stops sharing. Leaving the group leaves the share.

Steps are matched by what they are (the quest, or the step's title), not by
number, so characters whose guides differ by a class or race step still line
up; a partner on a step you do not have is shown but cannot hold you. The
confirmation has a "Don't warn me again" box.

**Server themes.** **Server theme**, on the options window's **Appearance**
page, recolours the addon:
Turtle WoW is the original green, OctoWoW purple, RavenCraft grey, Capybara
Paradise tan, Aegis red, and Day (amber, lighter panels) and Night (moonlight
blue, deeper panels). It applies at once, arrow and progress bars included, with
no reload. Themes are colours only. Every theme is checked for readability:
accents and text keep a WCAG contrast of at least 4.5:1 against the panels.

**Automatic advancement.** Accepting, completing and turning in quests, binding
a hearthstone, and collecting tagged items all resolve themselves. So do travel
steps, once a waypoint provider is active. The checkbox wears a halo on steps
the addon can finish for you, so you know when not to reach for it.

**One step, or all of them.** The panel opens on the step you are on and
nothing else, with its note in full and a meter underneath counting whatever
the quest wants killed or collected. The expand button in the header swaps
that for the whole guide when you want to look ahead. The panel sizes itself
to what it shows; the grip in its corner sets the width, and how tall it may
grow.

**Your place in the guide.** The arrows beside the step number move a step
back or skip one, and they change what is ticked as they go. Right-click them
to get back: after clicking round, a right-click on the arrow that points at
where you were takes you there and puts back every tick (and quest completion)
the arrows changed on the way -- a quest you finished in the meantime stays
finished. Without clicking round, a right-click takes you to where the guide
would open: the quest your log shows work at, else the first step not done.
If your place is the other way, it says which arrow to right-click.

**A navigation arrow.** It points at the current objective and says how far and
how long, floating on the world with no window around it. It needs a waypoint
provider; with none, or with no waypoint for this step, it hides rather than
pointing somewhere arbitrary. The **Arrow** setting picks whose arrow points at
the step: this one, the waypoint addon's (TomTom's, pfQuest's), both, or
neither. By default it is this one alone, and the waypoint addon keeps its map
pins either way.

## Gear

**Item score.** Every item's tooltip gets a line: what the item is worth to
your spec, and how it compares with what you wear in that slot — green and
`+12%` for an upgrade, red for worse, *empty slot* where you wear nothing, *not
for you* for armour, weapons or classes you cannot use. An item you are too
low for says the level it becomes an upgrade at.

- **The score** is the item's stats — read off its tooltip, as a 1.12 client
  gives nothing else — weighted for your class and spec, with soft caps on hit,
  crit, defence and the like so that stacking one stat does not run away.
- **Your spec** is the talent tree you have put most points into, or the one
  you pick; with no talents yet, your class's usual levelling spec.
- **Comparing:** a ring or trinket is weighed against the weaker of the two you
  wear, a one-hander against either hand once you can dual wield, a two-hander
  against both hands together. Enchants are left out on both sides.
- **The weights** are OctoPawn's defaults for every class and spec. The
  options window's **Item Score** page, under **Gear** (`/apg gear`, or **Stat
  weights** on the Gear page), lists them down the left with a box each, as
  Zygor's does. Change any of them, pick another spec, reset, or import and
  export them as a string OctoPawn reads too.

**Gear Advisor.** It watches for upgrades, as Zygor's does, and is switched
under **Gear** in the options:

- **Upgrades as you pick them up.** When something in your bags beats what you
  wear and you can wear it now, a window says so: the item, how much better,
  what it replaces, and **Equip** or **Decline**. Declined items are not offered
  again until you **Clear declined items**. In a fight, Equip waits for the
  fight to end.
- **Equip upgrades for me** puts them on without asking — never one that binds
  when equipped; that one still asks. Off until you turn it on.
- **Quest rewards.** When a quest offers a choice, the best one is marked: the
  biggest upgrade, or, with none, the one a vendor pays most for. With **pick it
  for me** on, and quests turning in by themselves, it is taken.
- **Your bags.** Upgrades get a border in the default bag frames.
- It can be switched off, or off at level 60.

**Gear finder.** Upgrades waiting in the dungeons you run (`/apg finder`, or
**Gear finder** in the options): for each slot, the best few drops that beat
what you wear, with who drops them, where, and how often.

- It looks in the dungeons that start no more than three levels above you, on
  your side, and ticked under **Dungeons** — and in raids, at 60, if you switch
  them on. Items up to three levels above you count, marked with their level.
- Each drop is weighed with the item score, for your spec, as tooltips are.
- Walking into a dungeon names its upgrades in chat.
- The loot tables are the CMaNGOS database's for every vanilla dungeon and
  raid, and pfQuest-turtle's for Turtle WoW's own: Dragonmaw Retreat,
  Crescent Grove, Stormwrought Ruins, Gilneas City, Hateforge Quarry, Karazhan
  Crypt, The Black Morass, Stormwind Vault, and the Emerald Sanctum and Tower
  of Karazhan raids. Their levels are read off their creatures. pfQuest-turtle
  does not say what Turtle's own items are, so the game is asked the first
  time -- a list may fill in over a few seconds, once.
- The vanilla dungeons and raids are as Turtle WoW has them: pfQuest-turtle's
  changes are laid over the CMaNGOS loot -- bosses Turtle added (Molten
  Core's Incindis and Basalthar, among others), loot moved between bosses,
  new items, and drops taken out. Where Turtle only changed a shared loot
  table, the CMaNGOS chance stands.
- Not only drops -- at 60 much of the best gear is not one. Each switched in
  the options, on to start with:
  - **Quest rewards** from quests you have still to do, on your side and for
    your class, that you can take within three levels: *Quest: Title*, with
    the reputation it needs where it needs one (*Honored, Argent Dawn*).
  - **Reputation gear** a vendor sells at a rank: *Revered with Stormpike
    Guard · the quartermaster*.
  - **Crafted gear**: *Blacksmithing 300*, and *made by a crafter* when you
    are not one. Crafted gear that binds on pickup counts only if you have the
    profession -- and under Solo Self-Found, all of it does.
  These are looked at near your level only, up to ten levels under it: there
  are thousands, each loaded to be weighed. They are vanilla's, from the
  CMaNGOS database; Turtle's own quests and recipes are not in it.
- Turning raids on says the first look takes a minute or two: hundreds more
  items to load, once.

## Professions

| Authored | |
|---|---|
| Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Jewelcrafting, Leatherworking, Mining, Survival, Tailoring | Full 1–300 crafting routes |
| Herbalism, Skinning, Fishing | 1–300 by where to go — see **Gathering** below |

Each authored guide is a fixed route, chosen once. For one planned from today's
prices instead, see **Cheapest crafting route** above — it keeps the authored
guide's trainer and rank steps and replaces only the crafts.

Each authored guide says what to craft in each skill band and roughly how many,
the reagents (the shopping list totals what the rest of the route still
needs, and can send it to Aegis: Exchange), where the recipe comes from, and equally viable alternatives.

Every rank is a step of its own: your faction's trainers, what the rank needs
and what it costs. Primary crafts wait for the character level a rank needs
(Apprentice 5, Journeyman 10, Expert 20, Artisan 35) with a "Reach level N"
step that clears itself once you are there. With pfQuest installed the step
points the arrow at the nearest of its trainers. Cooking and First Aid do not
train Expert or Artisan: the guide sends you to buy the Expert tome, and at
skill 225 — the point the route cannot pass without it — walks you through
the Artisan quest, level 40 and what to bring included.

Engineering is not in the reference the other guides were converted from. Its
route is CraftRoute's (a craft-by-craft 1–300 route checked against its recipe
data), with reagents and recipe sources from the same recipe data the cheapest
route uses. Its trainers come from the CMaNGOS 1.12 database: every NPC whose
trainer list teaches that rank, in the zone pfQuest puts them in. Artisan is
Buzzek Bracketswing in Gadgetzan (Tanaris) for both factions. Trainers the
Turtle-lineage servers added in their own new zones are not in those databases,
so are not listed.

Steps complete themselves on the numbers the game reports: a craft or
gathering step when your skill reaches its target, a rank when your skill cap
does. Open a guide part-way through and it goes straight to where you are.

### Gathering

Herbalism, Skinning and Fishing level by going somewhere, not by making
something, so each skill band is one step naming the best places for it — for
your faction, with the levels this addon's own zone guides spend there, so you
can pick one your character suits:

- **Herbalism** — the zones with most of the herbs that can still raise your
  skill in that band, counted from pfQuest's node database (Turtle WoW's new
  zones included), and which herbs to look for there.
- **Skinning** — the levels of beast worth skinning in the band, and the zones
  with most of them (normal creatures, no elites), from the CMaNGOS database.
- **Fishing** — the zones where nothing gets away at your skill (every catch
  can raise it, wherever you fish). Expert is a book, *Expert Fishing - The
  Bass and You*, from Old Man Heming in Booty Bay; Artisan is Nat Pagle's quest
  in Dustwallow Marsh, with where each of the four fish is caught — or, for
  the Horde, Katoom the Angler in The Hinterlands trains it.

Each rank is a step with your faction's trainers, capital cities first; with
pfQuest the arrow points at the nearest. Gathering ranks mostly need no
character level; where the trainer data says one does — Artisan Skinning at
35, Fishing at 5 to start and 35 for Artisan — a "Reach level N" step waits
for it.

Where the reference had no recipe for a skill range, the guide says so rather
than inventing one. Mining's mid-range gaps are real, and it tells you to go
mine nodes — and where: for your faction, the zones with most of the veins
that can still raise your skill. Each of its smelting steps says where to
mine the ore it uses, too.

## Servers

Turtle WoW, OctoWoW, Capybara Paradise and RavenCraft share the quests and
places these guides use, so the same guides work on all of them. The **Server
theme** option is colours only. For quest-giver lookups, use the
pfQuest pack for your server: `pfQuest-octo` on OctoWoW, `pfQuest-turtle`
elsewhere.
