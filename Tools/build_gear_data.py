#!/usr/bin/env python3
"""Extract the data behind the Gear Advisor and Gear Finder into GearData.lua.

    python3 Tools/build_gear_data.py --cmangos FILE --pfquest-turtle DIR

Both need facts a 1.12 client will not give an addon, taken from the CMaNGOS
classic-db dump (FILE, .sql or .sql.gz) and pfQuest-turtle (DIR, a checkout)
and committed, so the addon reads them with no database:

  Sell prices   When no quest reward is an upgrade, the Gear Advisor picks
                the one worth most at a vendor, as Zygor's does. Every item a
                quest offers as a choice, with its SellPrice.
  Dungeon loot  What the Gear Finder looks through: for each dungeon and raid,
                what its creatures drop, with the chance -- groups and shared
                ("reference") loot tables resolved into one chance per item --
                and for each item its slot, quality, required level and the
                classes it is for. Only green and better gear, MIN_CHANCE or
                likelier; a shared table used by more than REF_LIMIT creatures
                is the world's random drops, not a dungeon's, and is left out.

The dungeons are found by map: the creatures spawned there (creature,
creature_spawn_entry). Map ids and names live in the client's Map.dbc, which
the dump does not carry, so INSTANCES names them -- with the level ranges the
first-time setup uses (SetupFrame.lua), and the usual ones for the rest. A
few bosses are summoned by a script rather than spawned, so appear on no map;
SUMMONED names them, and their loot is looked up like any other.

Turtle WoW's own dungeons and raids are not in that database; pfQuest-turtle
has them. TURTLE_INSTANCES names the zones it places their creatures in, and
what those creatures drop comes from its item data, with the chance. Their
levels are read off the creatures: the tenth percentile of the elites'
levels, to the highest, both held at 60 -- a creature above 60 is level-60
content. pfQuest-turtle knows an item's name and where it drops but not its
slot or quality, so Turtle's own items go in with no entry under `items`: the
finder asks the client what they are, as it asks for any item it has not
seen. Items the CMaNGOS database knows are filtered here as for any dungeon.
Only direct drops are taken: the shared tables Turtle's dungeons use are the
world's random drops, or pools of trash drops far under MIN_CHANCE.

Turtle also changed the vanilla instances: bosses added, loot moved, drops
taken out. turtle_vanilla lays those over the CMaNGOS loot, from the same
pfQuest-turtle data (see its docstring for the rule).

Turtle's own quests are not in either. Their rewards have no price, and the
Gear Advisor says so rather than guess.
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_gathering import Dump, lua_names, num  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "GearData.lua")

# map id, code (the options' dungeon chip, where there is one), name, levels,
# kind, faction.
INSTANCES = [
    (389, "RFC", "Ragefire Chasm", 13, 18, "dungeon", "Horde"),
    (43, "WC", "Wailing Caverns", 18, 25, "dungeon", None),
    (36, "DM", "The Deadmines", 18, 25, "dungeon", None),
    (33, "SFK", "Shadowfang Keep", 23, 29, "dungeon", None),
    (34, "STOCKADES", "The Stockade", 24, 32, "dungeon", "Alliance"),
    (48, "BFD", "Blackfathom Deeps", 25, 31, "dungeon", None),
    (90, "GNOMER", "Gnomeregan", 30, 36, "dungeon", None),
    (47, "RFK", "Razorfen Kraul", 30, 36, "dungeon", None),
    (189, "SM", "Scarlet Monastery", 35, 45, "dungeon", None),
    (129, "RFD", "Razorfen Downs", 38, 46, "dungeon", None),
    (70, "ULDA", "Uldaman", 44, 50, "dungeon", None),
    (209, "ZF", "Zul'Farrak", 45, 53, "dungeon", None),
    (349, "MARA", "Maraudon", 48, 55, "dungeon", None),
    (109, "ST", "Sunken Temple", 52, 60, "dungeon", None),
    (230, "BRD", "Blackrock Depths", 52, 60, "dungeon", None),
    (429, "DIREMAUL", "Dire Maul", 56, 60, "dungeon", None),
    (229, "BRS", "Blackrock Spire", 55, 60, "dungeon", None),
    (289, "SCHOLO", "Scholomance", 58, 60, "dungeon", None),
    (329, "STRAT", "Stratholme", 58, 60, "dungeon", None),
    (309, "ZG", "Zul'Gurub", 60, 60, "raid", None),
    (509, "AQ20", "Ruins of Ahn'Qiraj", 60, 60, "raid", None),
    (249, "ONY", "Onyxia's Lair", 60, 60, "raid", None),
    (409, "MC", "Molten Core", 60, 60, "raid", None),
    (469, "BWL", "Blackwing Lair", 60, 60, "raid", None),
    (531, "AQ40", "Temple of Ahn'Qiraj", 60, 60, "raid", None),
    (533, "NAXX", "Naxxramas", 60, 60, "raid", None),
]

# Bosses a script summons, by the instance they appear in. The run fails if a
# name is not a creature with loot, so a typo cannot pass unnoticed.
SUMMONED = {
    "MC": ["Ragnaros"],
    "BWL": ["Nefarian"],
    "SCHOLO": ["Darkmaster Gandling"],
    "ZG": ["Gahz'ranka", "Gri'lek", "Hazza'rah", "Renataki", "Wushoolay"],
}

# The vanilla instances' areas, where pfQuest-turtle places the creatures it
# has for them. Turtle gave some instances areas of its own as well; those are
# found by name (VANILLA_NAME where it differs from INSTANCES').
VANILLA_AREA = {
    "RFC": 2437, "WC": 718, "DM": 1581, "SFK": 209, "STOCKADES": 717, "BFD": 719,
    "GNOMER": 721, "RFK": 491, "SM": 796, "RFD": 722, "ULDA": 1337, "ZF": 1176,
    "MARA": 2100, "ST": 1477, "BRD": 1584, "DIREMAUL": 2557, "BRS": 1583,
    "SCHOLO": 2057, "STRAT": 2017, "ZG": 1977, "AQ20": 3429, "ONY": 2159, "MC": 2717,
    "BWL": 2677, "AQ40": 3428, "NAXX": 3456,
}
VANILLA_NAME = {"ST": "The Temple of Atal'Hakkar", "AQ40": "Ahn'Qiraj"}

# Turtle WoW's own instances: the zone pfQuest-turtle places their creatures
# in, a code, and dungeon or raid. Names are pfQuest-turtle's, which are the
# client's -- what the Gear Finder hears on walking in.
TURTLE_INSTANCES = [
    (5601, "DMR", "dungeon"),     # Dragonmaw Retreat
    (5077, "CG", "dungeon"),      # Crescent Grove
    (5628, "SWR", "dungeon"),     # Stormwrought Ruins
    (5208, "GC", "dungeon"),      # Gilneas City
    (5103, "HQ", "dungeon"),      # Hateforge Quarry
    (5086, "KC", "dungeon"),      # Karazhan Crypt
    (5204, "BM", "dungeon"),      # The Black Morass
    (5087, "SWV", "dungeon"),     # Stormwind Vault
    (5097, "ES", "raid"),         # Emerald Sanctum
    (3457, "KARA", "raid"),       # Tower of Karazhan (Lower Karazhan Halls)
]

INVTYPE = {
    1: "INVTYPE_HEAD", 2: "INVTYPE_NECK", 3: "INVTYPE_SHOULDER", 5: "INVTYPE_CHEST",
    6: "INVTYPE_WAIST", 7: "INVTYPE_LEGS", 8: "INVTYPE_FEET", 9: "INVTYPE_WRIST",
    10: "INVTYPE_HAND", 11: "INVTYPE_FINGER", 12: "INVTYPE_TRINKET", 13: "INVTYPE_WEAPON",
    14: "INVTYPE_SHIELD", 15: "INVTYPE_RANGED", 16: "INVTYPE_CLOAK", 17: "INVTYPE_2HWEAPON",
    20: "INVTYPE_ROBE", 21: "INVTYPE_WEAPONMAINHAND", 22: "INVTYPE_WEAPONOFFHAND",
    23: "INVTYPE_HOLDABLE", 25: "INVTYPE_THROWN", 26: "INVTYPE_RANGEDRIGHT", 28: "INVTYPE_RELIC",
}
MIN_CHANCE = 1.0      # percent
REF_LIMIT = 20        # a shared table used by more creatures than this is a world drop
ALL_CLASSES = 1535    # the nine classes' bits: 1+2+4+8+16+64+128+256+1024


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def reward_prices(db):
    ids = set()
    for r in db.rows("quest_template"):
        for k in range(1, 7):
            i = num(r.get("RewChoiceItemId%d" % k))
            if i:
                ids.add(i)
    return {num(r["entry"]): num(r["SellPrice"]) for r in db.rows("item_template")
            if num(r["entry"]) in ids and num(r["SellPrice"]) > 0}


def instance_creatures(db):
    """map id -> the creature ids spawned there."""
    by_guid, out = {}, {}
    for r in db.rows("creature"):
        m = num(r["map"])
        if num(r["id"]):
            out.setdefault(m, set()).add(num(r["id"]))
        else:
            by_guid[num(r["guid"])] = m
    for r in db.rows("creature_spawn_entry"):
        m = by_guid.get(num(r["guid"]))
        if m is not None:
            out.setdefault(m, set()).add(num(r["entry"]))
    return out


def loot_tables(db):
    tables = {}
    for name in ("creature_loot_template", "reference_loot_template"):
        t = {}
        for r in db.rows(name):
            t.setdefault(num(r["entry"]), []).append(r)
        tables[name] = t
    return tables


def ref_uses(tables):
    """How many creatures' loot each shared table is part of."""
    uses = {}
    for entry, rows in tables["creature_loot_template"].items():
        for r in rows:
            if num(r["mincountOrRef"]) < 0:
                uses.setdefault(-num(r["mincountOrRef"]), set()).add(entry)
    return {ref: len(e) for ref, e in uses.items()}


def chances(tables, uses, table, entry, depth=0):
    """item -> percent chance from one loot table entry. Each group gives one
    item: its explicit chances first, the rest shared evenly among the items
    with none. Items outside a group roll on their own. A shared table's
    chances are scaled by the chance of rolling it."""
    out = {}
    if depth > 4:
        return out
    groups = {}
    for r in tables[table].get(entry, []):
        groups.setdefault(num(r["groupid"]), []).append(r)
    for gid, rows in groups.items():
        explicit = sum(max(0.0, float(r["ChanceOrQuestChance"])) for r in rows)
        even = [r for r in rows if float(r["ChanceOrQuestChance"]) == 0]
        share = (max(0.0, 100.0 - explicit) / len(even)) if (gid and even) else 0.0
        for r in rows:
            c = float(r["ChanceOrQuestChance"])
            if c < 0:
                continue                      # a quest drop
            if c == 0:
                c = share if gid else 100.0
            ref = -num(r["mincountOrRef"])
            if ref > 0:
                if uses.get(ref, 0) > REF_LIMIT:
                    continue                  # the world's random drops
                for item, sub in chances(tables, uses, "reference_loot_template", ref, depth + 1).items():
                    out[item] = max(out.get(item, 0.0), c * sub / 100.0)
            else:
                item = num(r["item"])
                out[item] = max(out.get(item, 0.0), c)
    return out


def dungeon_loot(db):
    creatures = instance_creatures(db)
    tmpl = {num(r["Entry"]): r for r in db.rows("creature_template")}
    items = {num(r["entry"]): r for r in db.rows("item_template")}
    tables = loot_tables(db)
    uses = ref_uses(tables)
    dungeons, gear = [], {}
    by_name = {}
    for e, t in tmpl.items():
        if num(t.get("LootId")):
            by_name.setdefault(t["Name"], e)
    for mapid, code, name, lo, hi, kind, faction in INSTANCES:
        best = {}
        summoned = set()
        for boss in SUMMONED.get(code, []):
            if boss not in by_name:
                sys.exit("SUMMONED names %r, which is no creature with loot" % boss)
            summoned.add(by_name[boss])
        for cid in sorted(creatures.get(mapid, set()) | summoned):
            t = tmpl.get(cid)
            if not t or not num(t.get("LootId")):
                continue
            for item, c in chances(tables, uses, "creature_loot_template", num(t["LootId"])).items():
                it = items.get(item)
                if not it or c < MIN_CHANCE or num(it["Quality"]) < 2:
                    continue
                slot = INVTYPE.get(num(it["InventoryType"]))
                if not slot:
                    continue
                if item not in best or c > best[item][1]:
                    best[item] = (t["Name"], c)
                mask = num(it["AllowableClass"])
                gear[item] = (slot, num(it["Quality"]), num(it["RequiredLevel"]),
                              0 if mask <= 0 or (mask & ALL_CLASSES) == ALL_CLASSES else mask)
        loot = sorted(((item, src, round(c, 1)) for item, (src, c) in best.items()),
                      key=lambda x: (x[1], -x[2], x[0]))
        dungeons.append({"map": mapid, "code": code, "name": name, "lo": lo, "hi": hi,
                         "kind": kind, "faction": faction, "loot": loot,
                         "units": creatures.get(mapid, set()) | summoned})
    return dungeons, gear


# --------------------------------------------------------------------------
# pfQuest-turtle
# --------------------------------------------------------------------------

def lua_entries(path):
    """id -> body of each top-level entry of a pfQuest data table, read line by
    line: entries such as `[2] = {},` and `[19] = "_",` (removed by Turtle) sit
    on one line, which a pattern over the whole file would run together with
    the next entry."""
    out, cur, body = {}, None, []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if cur is None:
                m = re.match(r"  \[(\d+)\] = (.*)$", line)
                if not m:
                    continue
                if m.group(2) == "{":
                    cur, body = int(m.group(1)), []
                elif m.group(2) == "{},":
                    out[int(m.group(1))] = ""
                elif m.group(2) == '"_",':
                    out[int(m.group(1))] = None       # Turtle removed it
            elif line == "  },":
                out[cur] = "\n".join(body)
                cur = None
            else:
                body.append(line)
    return out


def lua_sub(body, key):
    """One keyed sub-table of an entry: id -> number."""
    m = re.search(r'\n?    \["%s"\] = \{\n(.*?)\n    \},' % key, body, re.S)
    if not m:
        return {}
    return {int(a): float(b) for a, b in re.findall(r"\[(\d+)\] = ([\d.]+),", m.group(1))}


def turtle_loot(pf, db):
    """Turtle's own instances, from pfQuest-turtle, shaped as dungeon_loot's."""
    def path(*parts):
        p = os.path.join(pf, "db", *parts)
        if not os.path.exists(p):
            sys.exit("missing pfQuest-turtle file: %s" % p)
        return p
    zone_names = lua_names(path("enUS", "zones-turtle.lua"))
    unit_names = lua_names(path("enUS", "units-turtle.lua"))
    known = {num(r["entry"]): r for r in db.rows("item_template")}
    in_zone, levels = {}, {}
    wanted = set(z for z, _, _ in TURTLE_INSTANCES)
    for uid, body in lua_entries(path("units-turtle.lua")).items():
        body = body or ""                      # a creature Turtle removed
        zones = [int(z) for z in re.findall(r"\{ [\d.]+, [\d.]+, (\d+), \d+ \}", body)]
        lvl = re.search(r'\["lvl"\] = "(\d+)(?:-(\d+))?"', body)
        elite = re.search(r'\["rnk"\] = "[1-9]"', body)
        for z in zones:
            if z in wanted:
                in_zone.setdefault(z, set()).add(uid)
                if lvl and elite:
                    levels.setdefault(z, []).append(int(lvl.group(2) or lvl.group(1)))
    drops = {}
    for iid, body in lua_entries(path("items-turtle.lua")).items():
        for uid, c in lua_sub(body or "", "U").items():
            drops.setdefault(uid, []).append((iid, c))
    dungeons, gear = [], {}
    for zone, code, kind in TURTLE_INSTANCES:
        name = zone_names.get(zone)
        lv = sorted(levels.get(zone, []))
        if not name or not lv:
            sys.exit("TURTLE_INSTANCES names zone %d, where pfQuest-turtle places no elites" % zone)
        lo = min(60, lv[len(lv) // 10])
        hi = min(60, lv[-1])
        best = {}
        for uid in sorted(in_zone[zone]):
            for item, c in drops.get(uid, []):
                if c < MIN_CHANCE:
                    continue
                it = known.get(item)
                if it:
                    slot = INVTYPE.get(num(it["InventoryType"]))
                    if not slot or num(it["Quality"]) < 2:
                        continue
                    mask = num(it["AllowableClass"])
                    gear[item] = (slot, num(it["Quality"]), num(it["RequiredLevel"]),
                                  0 if mask <= 0 or (mask & ALL_CLASSES) == ALL_CLASSES else mask)
                if item not in best or c > best[item][1]:
                    best[item] = (unit_names.get(uid, "?"), c)
        loot = sorted(((item, src, round(c, 1)) for item, (src, c) in best.items()),
                      key=lambda x: (x[1], -x[2], x[0]))
        dungeons.append({"code": code, "name": name, "lo": lo, "hi": hi, "kind": kind,
                         "faction": None, "loot": loot, "turtle": True})
    return dungeons, gear


def turtle_vanilla(pf, db, dungeons, gear):
    """Turtle WoW's changes to the vanilla instances, over the CMaNGOS loot.

    pfQuest-turtle's entry for an item replaces pfQuest's own outright, so
    where it has one, Turtle's direct drops in the instance are what drops
    there: a chance changed, an item added (to a boss Turtle added, too),
    an item that no longer drops. An item Turtle removed ("_") is gone. An
    item whose entry lists shared tables ("R") keeps the CMaNGOS chance: those
    tables carry no groups, so the chance cannot be worked out from them.
    Items Turtle has no entry for are as CMaNGOS has them. Returns how many
    drops each instance had added, changed and taken away."""
    def path(*parts):
        p = os.path.join(pf, "db", *parts)
        if not os.path.exists(p):
            sys.exit("missing pfQuest-turtle file: %s" % p)
        return p
    zone_names = lua_names(path("enUS", "zones-turtle.lua"))
    # Areas with a place on an outdoor map are outdoors: an instance has none.
    outdoor = set(int(z) for z in re.findall(r"^  \[(\d+)\] = \{ ",
                                             open(path("zones-turtle.lua")).read(), re.M))
    names = {num(r["Entry"]): r["Name"] for r in db.rows("creature_template")}
    names.update(lua_names(path("enUS", "units-turtle.lua")))
    placed = {}
    for uid, body in lua_entries(path("units-turtle.lua")).items():
        for z in re.findall(r"\{ [\d.]+, [\d.]+, (\d+), \d+ \}", body or ""):
            placed.setdefault(int(z), set()).add(uid)
    items = lua_entries(path("items-turtle.lua"))
    known = {num(r["entry"]): r for r in db.rows("item_template")}
    counts = {}
    for d in dungeons:
        code = d["code"]
        want = VANILLA_NAME.get(code, d["name"])
        zones = {VANILLA_AREA[code]} | set(z for z, n in zone_names.items()
                                           if n.replace("\\'", "'") == want and z not in outdoor)
        units = set(d["units"])
        for z in zones:
            units |= placed.get(z, set())
        loot = {item: (src, c) for item, src, c in d["loot"]}
        added = changed = removed = 0
        for iid, body in items.items():
            if body is None:
                if loot.pop(iid, None):
                    removed += 1
                continue
            here = [(c, u) for u, c in lua_sub(body, "U").items() if u in units]
            if not here:
                if iid in loot and '["R"]' not in body:
                    del loot[iid]
                    removed += 1
                continue
            c, u = max(here)
            it = known.get(iid)
            if it:
                slot = INVTYPE.get(num(it["InventoryType"]))
                if not slot or num(it["Quality"]) < 2:
                    continue
                mask = num(it["AllowableClass"])
                gear[iid] = (slot, num(it["Quality"]), num(it["RequiredLevel"]),
                             0 if mask <= 0 or (mask & ALL_CLASSES) == ALL_CLASSES else mask)
            if c < MIN_CHANCE:
                if loot.pop(iid, None):
                    removed += 1
                continue
            if iid not in loot:
                added += 1
            elif abs(loot[iid][1] - c) >= 0.05:
                changed += 1
            loot[iid] = (names.get(u, "?"), c)
        d["loot"] = sorted(((item, src, round(c, 1)) for item, (src, c) in loot.items()),
                           key=lambda x: (x[1], -x[2], x[0]))
        counts[code] = (added, changed, removed)
    return counts


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--cmangos", required=True, help="CMaNGOS classic-db full dump (.sql or .sql.gz)")
    ap.add_argument("--pfquest-turtle", required=True, help="pfQuest-turtle checkout")
    args = ap.parse_args()
    db = Dump(args.cmangos)
    sell = reward_prices(db)
    dungeons, gear = dungeon_loot(db)
    changes = turtle_vanilla(args.pfquest_turtle, db, dungeons, gear)
    turtle, turtle_gear = turtle_loot(args.pfquest_turtle, db)
    dungeons += turtle
    gear.update(turtle_gear)

    lua = [
        "-- GearData.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Source:    CMaNGOS classic-db (https://github.com/cmangos/classic-db):",
        "--            quest_template, item_template, creature, creature_spawn_entry,",
        "--            creature_template, creature_loot_template, reference_loot_template;",
        "--            and for Turtle WoW's own dungeons, and its changes to the vanilla ones, pfQuest-turtle",
        "--            (https://github.com/shagu/pfQuest-turtle): db/units-turtle.lua,",
        "--            db/items-turtle.lua, db/enUS/units-turtle.lua, db/enUS/zones-turtle.lua",
        "-- Generator: Tools/build_gear_data.py",
        "",
        "AegisPathfinder.GearData = {",
        "\t-- What a vendor pays, in copper, for each item a quest offers as a choice.",
        "\tsell = {",
    ]
    ids = sorted(sell)
    for i in range(0, len(ids), 8):
        lua.append("\t\t" + " ".join("[%d] = %d," % (k, sell[k]) for k in ids[i:i + 8]))
    lua.append("\t},")
    lua.append("\t-- Each dungeon and raid: its levels, and what drops there --")
    lua.append("\t-- { item, who drops it (the likeliest), percent chance }. Turtle WoW's own")
    lua.append("\t-- (turtle = true) list items with no entry under items: the client says what they are.")
    lua.append("\tdungeons = {")
    for d in dungeons:
        lua.append("\t\t{ code = %s, name = %s, lo = %d, hi = %d, kind = %s%s%s, loot = {"
                   % (lua_str(d["code"]), lua_str(d["name"]), d["lo"], d["hi"], lua_str(d["kind"]),
                      (", faction = %s" % lua_str(d["faction"])) if d["faction"] else "",
                      ", turtle = true" if d.get("turtle") else ""))
        for item, src, c in d["loot"]:
            lua.append("\t\t\t{ %d, %s, %s }," % (item, lua_str(src), "%g" % c))
        lua.append("\t\t} },")
    lua.append("\t},")
    lua.append("\t-- Each item there: { slot, quality, required level, class mask (0: any class) }.")
    lua.append("\titems = {")
    for item in sorted(gear):
        slot, q, lvl, mask = gear[item]
        lua.append("\t\t[%d] = { %s, %d, %d, %d }," % (item, lua_str(slot), q, lvl, mask))
    lua.append("\t},")
    lua += ["}", ""]

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lua))
    print("wrote %s: sell prices for %d quest reward items; %d items from %d dungeons and raids"
          % (os.path.relpath(OUT, ROOT), len(sell), len(gear), len(dungeons)))
    for d in dungeons:
        a, c, r = changes.get(d["code"], (0, 0, 0))
        print("  %-10s %4d items%s" % (d["code"], len(d["loot"]),
                                       ("   Turtle: +%d ~%d -%d" % (a, c, r)) if (a or c or r) else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
