#!/usr/bin/env python3
"""Convert OctoPawn's stat weights and stat patterns into ItemScoreData.lua.

    python3 Tools/import_octopawn.py <path to an OctoPawn checkout>

OctoPawn (https://github.com/iGreed1993/OctoPawn, MIT, (c) 2026 iGreed) scores
1.12 items from their tooltips, with weights for every class and spec. Its
defaults are Lua built by a few helpers (OctoPawn_MeleeDPS, OctoPawn_Tank,
...), so they are evaluated with lua5.1 rather than parsed, and written out
as plain tables: the weights (zeros dropped), the tooltip patterns in
OctoPawn's order -- the order matters, the first match on a line wins over
the general ones after it -- its soft caps, and its stat labels.

Only the data is taken. The scoring in ItemScore.lua is this addon's own.
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ItemScoreData.lua")

DUMP = r"""
local dir = arg[1]
defaultWeights = {}
print = function() end
-- OctoPawn's files touch the WoW API as they load; anything missing is a
-- do-nothing function here, since only their tables are wanted.
local noop = function() return nil end
setmetatable(_G, { __index = function() return noop end })
dofile(dir .. "/Defaults/Helpers.lua")
local toc = io.open(dir .. "/OctoPawn.toc"):read("*a")
for path in string.gfind(toc, "Defaults\\([%w\\]+)%.lua") do
	if path ~= "Helpers" then dofile(dir .. "/Defaults/" .. string.gsub(path, "\\", "/") .. ".lua") end
end
dofile(dir .. "/Scoring/ScoringStats.lua")
local function q(s) return string.format("%q", s) end
local out = {}
-- weights
table.insert(out, "W")
for class, specs in pairs(defaultWeights) do
	for spec, w in pairs(specs) do
		if type(w) == "table" then
			for stat, v in pairs(w) do
				table.insert(out, "w\t" .. class .. "\t" .. spec .. "\t" .. stat .. "\t" .. string.format("%.4f", v))
			end
		end
	end
end
for i, e in ipairs(OctoPawn_StatPatterns) do
	table.insert(out, "p\t" .. i .. "\t" .. e.pattern .. "\t" .. e.stat)
end
local stats = {}
for stat in pairs(defaultWeights.WARRIOR.Arms) do table.insert(stats, stat) end
for _, stat in ipairs(stats) do
	table.insert(out, "l\t" .. stat .. "\t" .. OctoPawn_StatLabel(stat))
end
io.write(table.concat(out, "\n"))
"""

CLASS_ORDER = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]


def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def num(v):
    s = ("%.4f" % float(v)).rstrip("0").rstrip(".")
    return s or "0"


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    src = sys.argv[1]
    with open(os.path.join(ROOT, "Tools", ".octopawn_dump.lua"), "w") as fh:
        fh.write(DUMP)
    try:
        raw = subprocess.run(["lua5.1", os.path.join(ROOT, "Tools", ".octopawn_dump.lua"), src],
                             check=True, capture_output=True, text=True).stdout
    finally:
        os.remove(os.path.join(ROOT, "Tools", ".octopawn_dump.lua"))

    weights, patterns, caps, labels = {}, [], {}, {}
    for line in raw.split("\n"):
        f = line.split("\t")
        if f[0] == "w" and float(f[4]) != 0:
            weights.setdefault(f[1], {}).setdefault(f[2], {})[f[3]] = f[4]
        elif f[0] == "p":
            patterns.append((int(f[1]), f[2], f[3]))
        elif f[0] == "d":
            caps[f[1]] = (f[2], f[3])
        elif f[0] == "l":
            labels[f[1]] = f[2]
    patterns.sort()
    # The soft caps are a local table in ScoringCore.lua, which does too much
    # at load to run here; the table itself is plain.
    with open(os.path.join(src, "Scoring", "ScoringCore.lua"), encoding="utf-8") as fh:
        core = fh.read()
    block = re.search(r"local DEFAULT_DR = \{(.*?)\n\}", core, re.S).group(1)
    for m in re.finditer(r'(?:\["([^"]+)"\]|(\w+))\s*=\s*\{\s*softCap\s*=\s*([\d.]+),\s*postScale\s*=\s*([\d.]+)\s*\}', block):
        caps[m.group(1) or m.group(2)] = (m.group(3), m.group(4))
    stats = sorted(labels)

    with open(os.path.join(src, "LICENSE"), encoding="utf-8") as fh:
        licence = fh.read().strip()

    lua = [
        "-- ItemScoreData.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Source:    OctoPawn's default weights, stat patterns, soft caps and labels",
        "--            (https://github.com/iGreed1993/OctoPawn)",
        "-- Generator: Tools/import_octopawn.py",
        "--",
        "-- OctoPawn's licence, which covers this data:",
        "--",
    ]
    lua += ["-- " + l if l else "--" for l in licence.split("\n")]
    lua += ["", "AegisPathfinder.ItemScoreData = {"]

    lua.append("\t-- Every stat the scorer knows, in a fixed order (the options panel's).")
    lua.append("\tstats = {")
    for s in stats:
        lua.append("\t\t%s," % lua_str(s))
    lua.append("\t},")

    lua.append("\t-- How the options panel names a stat.")
    lua.append("\tlabels = {")
    for s in stats:
        if labels[s] != s:
            lua.append("\t\t[%s] = %s," % (lua_str(s), lua_str(labels[s])))
    lua.append("\t},")

    lua.append("\t-- class -> spec -> stat -> weight (a stat with no weight counts 0).")
    lua.append("\tweights = {")
    for cls in CLASS_ORDER + sorted(set(weights) - set(CLASS_ORDER)):
        if cls not in weights:
            continue
        lua.append("\t\t%s = {" % cls)
        for spec in sorted(weights[cls]):
            lua.append("\t\t\t%s = {" % spec)
            for stat in sorted(weights[cls][spec]):
                lua.append("\t\t\t\t[%s] = %s," % (lua_str(stat), num(weights[cls][spec][stat])))
            lua.append("\t\t\t},")
        lua.append("\t\t},")
    lua.append("\t},")

    lua.append("\t-- { upper-case text on a tooltip line, the stat it adds to }. In order:")
    lua.append("\t-- a line's first match for a stat wins, so the specific come first.")
    lua.append("\tpatterns = {")
    for _, pat, stat in patterns:
        lua.append("\t\t{ %s, %s }," % (lua_str(pat), lua_str(stat)))
    lua.append("\t},")

    lua.append("\t-- Soft caps: past `cap`, each further point counts `after` of one.")
    lua.append("\tsoftcaps = {")
    for stat in sorted(caps):
        lua.append("\t\t[%s] = { cap = %s, after = %s }," % (lua_str(stat), num(caps[stat][0]), num(caps[stat][1])))
    lua.append("\t},")
    lua.append("}")
    lua.append("")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lua))
    n = sum(len(v) for v in weights.values())
    print("wrote %s: %d classes, %d specs, %d stats, %d patterns, %d soft caps"
          % (os.path.relpath(OUT, ROOT), len(weights), n, len(stats), len(patterns), len(caps)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
