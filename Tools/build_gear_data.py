#!/usr/bin/env python3
"""Extract the data behind the Gear Advisor and Gear Finder into GearData.lua.

    python3 Tools/build_gear_data.py --cmangos FILE

Both need facts a 1.12 client will not give an addon, taken from the CMaNGOS
classic-db dump (FILE, .sql or .sql.gz) and committed, so the addon reads them
with no database:

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
first-time setup uses (SetupFrame.lua), and the usual ones for the rest.

Turtle WoW's own quests and dungeons are not in that database. Their rewards
have no price and their loot is not in the finder, and both say so rather
than guess.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_gathering import Dump, num  # noqa: E402

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
    for mapid, code, name, lo, hi, kind, faction in INSTANCES:
        best = {}
        for cid in sorted(creatures.get(mapid, ())):
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
                         "kind": kind, "faction": faction, "loot": loot})
    return dungeons, gear


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--cmangos", required=True, help="CMaNGOS classic-db full dump (.sql or .sql.gz)")
    args = ap.parse_args()
    db = Dump(args.cmangos)
    sell = reward_prices(db)
    dungeons, gear = dungeon_loot(db)

    lua = [
        "-- GearData.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Source:    CMaNGOS classic-db (https://github.com/cmangos/classic-db):",
        "--            quest_template, item_template, creature, creature_spawn_entry,",
        "--            creature_template, creature_loot_template, reference_loot_template",
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
    lua.append("\t-- { item, who drops it (the likeliest), percent chance }.")
    lua.append("\tdungeons = {")
    for d in dungeons:
        lua.append("\t\t{ code = %s, name = %s, lo = %d, hi = %d, kind = %s%s, loot = {"
                   % (lua_str(d["code"]), lua_str(d["name"]), d["lo"], d["hi"], lua_str(d["kind"]),
                      (", faction = %s" % lua_str(d["faction"])) if d["faction"] else ""))
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
        print("  %-10s %4d items" % (d["code"], len(d["loot"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
