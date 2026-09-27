#!/usr/bin/env python3
"""Extract the data behind the Gear Advisor into GearData.lua.

    python3 Tools/build_gear_data.py --cmangos FILE

When no quest reward is an upgrade, the Gear Advisor recommends the one worth
most at a vendor, as Zygor's does -- but a 1.12 client cannot tell an addon
what an item sells for. So the sell price of every item a quest offers as a
choice is taken from the CMaNGOS classic-db dump (quest_template's
RewChoiceItemId1-6, item_template's SellPrice) and committed, so the addon
reads it with no database. FILE is the full dump, .sql or .sql.gz.

Turtle WoW's own quests are not in that database; their rewards simply have
no price, and the advisor says so rather than guess.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_gathering import Dump, num  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "GearData.lua")


def reward_prices(db):
    ids = set()
    for r in db.rows("quest_template"):
        for k in range(1, 7):
            i = num(r.get("RewChoiceItemId%d" % k))
            if i:
                ids.add(i)
    return {num(r["entry"]): num(r["SellPrice"]) for r in db.rows("item_template")
            if num(r["entry"]) in ids and num(r["SellPrice"]) > 0}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--cmangos", required=True, help="CMaNGOS classic-db full dump (.sql or .sql.gz)")
    args = ap.parse_args()
    db = Dump(args.cmangos)
    sell = reward_prices(db)

    lua = [
        "-- GearData.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Source:    CMaNGOS classic-db (https://github.com/cmangos/classic-db):",
        "--            quest_template, item_template",
        "-- Generator: Tools/build_gear_data.py",
        "",
        "AegisPathfinder.GearData = {",
        "\t-- What a vendor pays, in copper, for each item a quest offers as a choice.",
        "\tsell = {",
    ]
    ids = sorted(sell)
    for i in range(0, len(ids), 8):
        lua.append("\t\t" + " ".join("[%d] = %d," % (k, sell[k]) for k in ids[i:i + 8]))
    lua += ["\t},", "}", ""]
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lua))
    print("wrote %s: sell prices for %d quest reward items" % (os.path.relpath(OUT, ROOT), len(sell)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
