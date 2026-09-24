#!/usr/bin/env python3
"""Convert the professions reference document into AEGIS: Pathfinder guides.

    python3 Tools/convert_professions.py [--check]

Reads Tools/data/Professions_Reference.docx and writes Guides/Professions/.
With --check it parses and validates but writes nothing.

Output is QuestShell+ (structured Lua tables), not the pipe-delimited DSL:
these guides are generated, and a generated corpus wants a format that diffs
and validates cleanly. QuestShellPlusParser turns the tables into the tag
strings the core parser consumes.

The converter refuses to invent anything. Where the document is silent -- a
skill range it has no recipe for, a trainer it does not name -- that silence is
carried through into the guide as a note, rather than filled in with a guess.
"""

import argparse
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCX = os.path.join(ROOT, "Tools", "data", "Professions_Reference.docx")
# Rank levels and costs, the secondary professions' books and quests, and
# trainers the reference document is missing -- drawn from the owner-supplied
# FAQ in Tools/data/Profession_FAQ.md.
TRAINING = os.path.join(ROOT, "Tools", "data", "profession_training.json")
OUTDIR = os.path.join(ROOT, "Guides", "Professions")

# Professions the concept's Professions tab lists but the document has no route
# for. They ship as visibly-unauthored templates rather than being dropped, so
# the tab matches the concept and nobody mistakes an empty guide for a real one.
UNSOURCED = [
    ("Engineering", "crafting"),
    ("Herbalism", "gathering"),
    ("Skinning", "gathering"),
    ("Fishing", "gathering"),
]

MAX_SKILL = 300


# --------------------------------------------------------------------------
# Document reading
# --------------------------------------------------------------------------

def docx_paragraphs(path):
    """Yield (style, text) for every non-empty paragraph."""
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml").decode("utf-8")
    for para in re.findall(r"<w:p[ >].*?</w:p>", xml, re.S):
        text = "".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", para, re.S))
        text = (text.replace("&amp;", "&").replace("&lt;", "<")
                    .replace("&gt;", ">").replace("&quot;", '"')
                    .replace("&#39;", "'"))
        style = re.search(r'w:pStyle w:val="([^"]+)"', para)
        if text.strip():
            yield (style.group(1) if style else ""), text.strip()


# The document uses an en dash in ranges and an arrow in skill transitions.
DASH = "–"
ARROW = "→"

# Most sections are titled "<Name> Leveling Planner (1-300)", but Enchanting is
# "Leveling Guide" and several headings carry emoji. Both variants are the
# document's, not typos to normalise away, so the patterns accept both.
RE_PLANNER = re.compile(r"^(.+?)\s+Leveling (?:Planner|Guide)\s+\(1[%s-]300\)(.*)$" % DASH)
RE_CRAFTS = re.compile(r"~(\d+)\s+total crafts")
RE_SHOP_ITEM = re.compile(r"^(\d+)x\s+(.+?)$")
RE_TRAINER_TIER = re.compile(r"^(.+?)\s*\(([\d%s]+)\):\s*(.+)$" % DASH)
RE_TRAINER_ENTRY = re.compile(r"^(.+?)\s*\(([^)]+)\)$")
RE_STEP_RANGE = re.compile(r"^(\d+)\s*%s\s*(\d+)$" % ARROW)
RE_TRAIN_HDR = re.compile(r"^\[([\d%s]+)\]\s+(.+)$" % DASH)
RE_CRAFT = re.compile(r"^Craft:\s*(\d+)x\s+(.+)$")
RE_METHOD = re.compile(r"^Method:\s*(.+)$")
RE_REAGENTS = re.compile(r"^Reagents:\s*(.+)$")
RE_SOURCE = re.compile(r"^Source:\s*(.+)$")
RE_ALTS = re.compile(r"^Alternatives:\s*(.+)$")
RE_NOTE = re.compile(r"^Note:\s*(.+)$")
RE_REAGENT = re.compile(r"^(.+?)\s+x(\d+)$")

SECTION_SHOPPING = "shopping"
SECTION_TRAINERS = "trainers"
SECTION_ROUTE = "route"


def parse(path):
    professions = []
    cur = None
    section = None
    faction = None
    step = None

    def flush_step():
        nonlocal step
        if step and cur:
            cur["steps"].append(step)
        step = None

    def heading(text):
        """Section headings vary: some carry a leading emoji and a space."""
        return re.sub(r"^[^\w\[]+", "", text).strip()

    for _, raw in docx_paragraphs(path):
        text = heading(raw)
        m = RE_PLANNER.match(text)
        if m:
            # Some headings are glued to the intro paragraph that follows.
            flush_step()
            name, trailing = m.group(1).strip(), m.group(2)
            cur = {
                "name": name, "crafts": None, "shopping": [], "shoppingNote": None,
                "trainers": {"Alliance": [], "Horde": []}, "steps": [],
            }
            crafts = RE_CRAFTS.search(trailing)
            if crafts:
                cur["crafts"] = int(crafts.group(1))
            professions.append(cur)
            section = None
            faction = None
            continue

        if cur is None:
            continue

        if RE_CRAFTS.search(text) and cur["crafts"] is None:
            cur["crafts"] = int(RE_CRAFTS.search(text).group(1))
            continue

        if text.startswith("Shopping List"):
            flush_step()
            section = SECTION_SHOPPING
            continue
        if text.startswith("Step-by-Step Leveling Route"):
            flush_step()
            section = SECTION_ROUTE
            continue
        if re.match(r"^(Alliance|Horde) Trainers?( Locations)?$", text):
            flush_step()
            section = SECTION_TRAINERS
            faction = text.split()[0]
            continue
        if text == "Trainer Locations":
            flush_step()
            section = SECTION_TRAINERS
            continue

        if section == SECTION_SHOPPING:
            m = RE_SHOP_ITEM.match(text)
            if m:
                qty, item = int(m.group(1)), m.group(2)
                note = None
                paren = re.match(r"^(.+?)\s+\((.+)\)$", item)
                if paren:
                    item, note = paren.group(1).strip(), paren.group(2).strip()
                cur["shopping"].append({"qty": qty, "item": item, "note": note})
            elif text.startswith("Note:"):
                cur["shoppingNote"] = RE_NOTE.match(text).group(1)
            # Anything else here is a category header (Survival groups its list);
            # the totals are what matter, so headers are not carried through.
            continue

        if section == SECTION_TRAINERS:
            m = RE_TRAINER_TIER.match(text)
            if m and faction:
                tier, rng, who = m.group(1).strip(), m.group(2), m.group(3)
                entries = []
                for part in who.split(","):
                    part = part.strip()
                    em = RE_TRAINER_ENTRY.match(part)
                    if em:
                        entries.append({"name": em.group(1).strip(),
                                        "zone": em.group(2).strip()})
                    elif part:
                        entries.append({"name": part, "zone": None})
                cur["trainers"][faction].append(
                    {"tier": tier, "range": rng.replace(DASH, "-"), "entries": entries})
            continue

        if section == SECTION_ROUTE:
            m = RE_TRAIN_HDR.match(text)
            if m:
                flush_step()
                cur["steps"].append({
                    "kind": "train", "at": m.group(1).replace(DASH, "-"),
                    "label": m.group(2).strip(),
                })
                continue

            m = RE_STEP_RANGE.match(text)
            if m:
                flush_step()
                step = {"kind": None, "from": int(m.group(1)), "to": int(m.group(2)),
                        "reagents": [], "alternatives": [], "note": None,
                        "source": None, "count": None, "item": None, "method": None}
                continue

            if step is None:
                continue

            m = RE_CRAFT.match(text)
            if m:
                step["kind"] = "craft"
                step["count"] = int(m.group(1))
                step["item"] = m.group(2).strip()
                continue
            m = RE_METHOD.match(text)
            if m:
                step["kind"] = "method"
                step["method"] = m.group(1).strip()
                continue
            m = RE_REAGENTS.match(text)
            if m:
                for part in m.group(1).split(","):
                    part = part.strip()
                    rm = RE_REAGENT.match(part)
                    if rm:
                        step["reagents"].append({"item": rm.group(1).strip(),
                                                 "qty": int(rm.group(2))})
                    elif part:
                        step["reagents"].append({"item": part, "qty": 1})
                continue
            m = RE_SOURCE.match(text)
            if m:
                # "Source: Recipe: Recipe: X" appears in the document; collapse it.
                src = m.group(1).strip()
                src = re.sub(r"^(Recipe:\s*)+", "Recipe: ", src)
                step["source"] = src
                continue
            m = RE_ALTS.match(text)
            if m:
                alts = m.group(1).strip()
                if alts.lower() != "none":
                    step["alternatives"] = [a.strip() for a in alts.split(",") if a.strip()]
                continue
            m = RE_NOTE.match(text)
            if m:
                step["note"] = m.group(1).strip()
                continue

    flush_step()
    return professions


# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------

def validate(professions):
    """Report inconsistencies in the source document. Never silently repairs."""
    problems = []

    for p in professions:
        name = p["name"]
        ranges = [s for s in p["steps"] if s["kind"] in ("craft", "method")]

        if not ranges:
            problems.append("%s: no skill ranges parsed" % name)
            continue

        # Contiguity: each range must start where the previous one ended.
        cursor = ranges[0]["from"]
        if cursor != 1:
            problems.append("%s: route starts at %d, not 1" % (name, cursor))
        for s in ranges:
            if s["from"] != cursor:
                problems.append("%s: gap/overlap at %d%s%d (previous ended %d)"
                                % (name, s["from"], DASH, s["to"], cursor))
            if s["to"] <= s["from"]:
                problems.append("%s: non-advancing range %d%s%d"
                                % (name, s["from"], DASH, s["to"]))
            cursor = s["to"]
        if cursor != MAX_SKILL:
            problems.append("%s: route ends at %d, not %d" % (name, cursor, MAX_SKILL))

        # Every reagent a step calls for should appear in the shopping list.
        listed = {i["item"].lower() for i in p["shopping"]}
        # Intermediates are crafted mid-route from listed materials.
        crafted = {s["item"].lower() for s in ranges if s.get("item")}
        for s in ranges:
            for r in s["reagents"]:
                key = r["item"].lower()
                if key not in listed and key not in crafted:
                    problems.append("%s: reagent '%s' (%d%s%d) is in no shopping list"
                                    % (name, r["item"], s["from"], DASH, s["to"]))

        # A craft step with no reagents cannot be shopped for.
        for s in ranges:
            if s["kind"] == "craft" and not s["reagents"]:
                problems.append("%s: craft '%s' lists no reagents" % (name, s["item"]))

        if not p["trainers"]["Alliance"] and not p["trainers"]["Horde"]:
            problems.append("%s: no trainers parsed" % name)

    return problems


# --------------------------------------------------------------------------
# Lua emission
# --------------------------------------------------------------------------

def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def lua_list(items):
    return "{ " + ", ".join(lua_str(i) for i in items) + " }"


RANKS = ("Apprentice", "Journeyman", "Expert", "Artisan")
FACTIONS = ("Alliance", "Horde")


def load_training():
    import json
    with open(TRAINING, encoding="utf-8") as fh:
        return json.load(fh)


def rank_of(label):
    """The rank a route's training step is for, from its label."""
    for rank in RANKS:
        if rank in label:
            return rank
    return None


def trainers_for(p, rank, faction, training):
    """The faction's trainers for a rank: the reference document's tier that
    names the rank ("Apprentice / Journeyman" covers both), else the FAQ's."""
    entries = []
    for tier in p["trainers"][faction]:
        if rank in tier["tier"]:
            entries.extend(tier["entries"])
    if not entries:
        entries = (training["supplementTrainers"].get(p["name"], {})
                   .get(rank, {}).get(faction, []))
    return entries


def where(e):
    """"Name (Zone)", or "Name (Zone, Place)"."""
    at = ", ".join(x for x in (e.get("zone"), e.get("place")) if x)
    return e["name"] + (" (%s)" % at if at else "")


def level_gate(what, level):
    return {"type": "GRIND", "title": "Reach level %d" % level, "level": level,
            "note": "%s needs character level %d. This step clears itself when you get there."
                    % (what, level)}


def train_steps(p, s, training):
    """A route's "train the next rank" step, as the player's faction sees it:
    a level gate where the profession has one, then who to go to, what it
    costs, and the cap it completes on."""
    name, rank = p["name"], rank_of(s["label"])
    info = training["ranks"][rank]
    gated = name not in training["noLevelRequirement"]
    out = []
    if gated:
        out.append(level_gate("%s %s" % (rank, name), info["level"]))

    needs = []
    if info["skill"]:
        needs.append("skill %d" % info["skill"])
    if gated:
        needs.append("level %d" % info["level"])
    head = ("Needs %s; costs %s." % (" and ".join(needs), info["cost"]) if needs
            else "Costs %s." % info["cost"])

    for fac in FACTIONS:
        entries = trainers_for(p, rank, fac, training)
        if entries:
            note = head + " Trainers: " + ", ".join(where(e) for e in entries) + "."
        else:
            note = head + " Ask a city guard for the nearest trainer."
        step = {"type": "TRAIN", "title": s["label"], "note": note, "faction": fac,
                "rank": {"profession": name, "cap": info["cap"]}}
        if entries:
            step["npcs"] = [e["name"] for e in entries]
        out.append(step)
    return out


def expert_book_steps(p, sec):
    """Secondary professions read their Expert rank from a book."""
    name, book = p["name"], sec["expert"]
    out = []
    for fac in FACTIONS:
        vendors = book["vendors"][fac]
        who = " or ".join(where(v) for v in vendors)
        out.append({
            "type": "BUY", "title": "Buy %s" % book["book"], "faction": fac,
            "note": "%s sells it for %s. Read it to raise your %s cap to 225; it needs skill 125."
                    % (who, book["cost"], name),
            "rank": {"profession": name, "cap": 225},
            "npcs": [v["name"] for v in vendors],
        })
    return out


def artisan_quest_steps(p, sec):
    """Secondary professions earn Artisan by a quest at level 40 and 225."""
    name, q = p["name"], sec["artisan"]
    out = [level_gate("The Artisan %s quest" % name, q["level"])]
    for fac in FACTIONS:
        st = q["starters"][fac]
        note = "%s in %s, %s, starts it." % (st["name"], st["zone"], st["place"])
        step = {"type": "NOTE", "title": "Start the Artisan %s quest" % name, "faction": fac,
                "note": note + " Needs level %d and skill %d." % (q["level"], q["skill"]),
                "npcs": [st["name"]]}
        if q.get("starterOptional"):
            fin = q["finish"]["name"]
            step["note"] += " You can skip this and go straight to %s." % fin
            step["optional"] = True
        out.append(step)

    if q.get("bring"):
        out.append({"type": "NOTE", "title": "Gather for %s" % q["finish"]["name"],
                    "note": q["gatherNote"], "reagents": q["bring"]})

    finishes = q.get("finishes") or {fac: q["finish"] for fac in FACTIONS}
    shared = len(set(f["name"] for f in finishes.values())) == 1
    for fac in (("Both",) if shared else FACTIONS):
        fin = finishes["Alliance" if shared else fac]
        step = {"type": "NOTE", "title": "Hand in to %s" % fin["name"],
                "note": "%s, %s. %s" % (fin["zone"], fin["place"], q["finishNote"]),
                "rank": {"profession": name, "cap": 300}, "npcs": [fin["name"]]}
        if not shared:
            step["faction"] = fac
        out.append(step)
    return out


def split_at(s, skill):
    """Split a craft or method step at `skill`, sharing the craft count out by
    skill points. The counts are estimates already; the split keeps their sum."""
    first, second = dict(s), dict(s)
    first["to"], second["from"] = skill, skill
    if s.get("count"):
        span = s["to"] - s["from"]
        first["count"] = max(1, int(round(s["count"] * (skill - s["from"]) / float(span))))
        second["count"] = max(1, s["count"] - first["count"])
    return first, second


def craft_step(p, s):
    name = p["name"]
    if s["kind"] == "craft":
        step = {
            "type": "USE",
            "title": "Craft %dx %s" % (s["count"], s["item"]),
            "skill": {"profession": name, "from": s["from"], "to": s["to"]},
            "craft": {"item": s["item"], "count": s["count"]},
            "reagents": s["reagents"],
        }
        if s["source"]:
            step["source"] = s["source"]
        if s["alternatives"]:
            step["alternatives"] = s["alternatives"]
    else:
        step = {
            "type": "GRIND",
            "title": s["method"],
            "skill": {"profession": name, "from": s["from"], "to": s["to"]},
        }
    note = "Takes you from %d to %d." % (s["from"], s["to"])
    if s["note"]:
        note += " " + s["note"]
    step["note"] = note
    return step


def emit_steps(p, training=None):
    """Turn a parsed profession into QuestShell+ step tables."""
    training = training or load_training()
    name = p["name"]
    sec = training["secondary"].get(name)
    out = []

    intro = ("A low-cost 1-300 route. Craft counts are estimates"
             + (" (about %d crafts in total)." % p["crafts"] if p["crafts"] else "."))
    out.append({"type": "NOTE", "title": "%s (1-300)" % name, "note": intro})

    if p["shoppingNote"]:
        out.append({"type": "NOTE", "title": "Before you start",
                    "note": p["shoppingNote"]})

    # A secondary profession's Artisan quest needs skill 225, and nothing past
    # 225 is reachable without it -- so it goes exactly there, splitting the
    # route step that crosses 225.
    route = []
    for s in p["steps"]:
        if sec and s["kind"] == "train" and rank_of(s["label"]) == "Artisan":
            continue
        if sec and s["kind"] in ("craft", "method") and s["from"] < 225 < s["to"]:
            first, second = split_at(s, 225)
            route += [first, {"kind": "artisan"}, second]
            continue
        if sec and s["kind"] in ("craft", "method") and s["from"] == 225 \
                and not any(r.get("kind") == "artisan" for r in route):
            route.append({"kind": "artisan"})
        route.append(s)

    for s in route:
        if s["kind"] == "artisan":
            out.extend(artisan_quest_steps(p, sec))
        elif s["kind"] == "train":
            if sec and rank_of(s["label"]) == "Expert":
                out.extend(expert_book_steps(p, sec))
            else:
                out.extend(train_steps(p, s, training))
        else:
            out.append(craft_step(p, s))

    out.append({"type": "NOTE", "title": "Guide Complete",
                "note": "%s is maxed at %d." % (name, MAX_SKILL)})
    return out


def step_to_lua(step, indent="\t\t"):
    parts = ['type = %s' % lua_str(step["type"])]
    if "title" in step:
        parts.append("title = %s" % lua_str(step["title"]))
    if step.get("note"):
        parts.append("note = %s" % lua_str(step["note"]))
    if step.get("faction"):
        parts.append("faction = %s" % lua_str(step["faction"]))
    if step.get("optional"):
        parts.append("optional = true")
    if step.get("level"):
        parts.append("level = %d" % step["level"])
    if step.get("rank"):
        rk = step["rank"]
        parts.append("rank = { profession = %s, cap = %d }" % (lua_str(rk["profession"]), rk["cap"]))
    if step.get("npcs"):
        parts.append("npcs = %s" % lua_list(step["npcs"]))
    if step.get("skill"):
        sk = step["skill"]
        parts.append("skill = { profession = %s, from = %d, to = %d }"
                     % (lua_str(sk["profession"]), sk["from"], sk["to"]))
    if step.get("craft"):
        c = step["craft"]
        parts.append("craft = { item = %s, count = %d }" % (lua_str(c["item"]), c["count"]))
    if step.get("reagents"):
        inner = ", ".join("{ item = %s, qty = %d }" % (lua_str(r["item"]), r["qty"])
                          for r in step["reagents"])
        parts.append("reagents = { %s }" % inner)
    if step.get("source"):
        parts.append("source = %s" % lua_str(step["source"]))
    if step.get("alternatives"):
        parts.append("alternatives = %s" % lua_list(step["alternatives"]))

    body = (",\n" + indent + "\t").join(parts)
    return "%s{\n%s\t%s,\n%s}" % (indent, indent, body, indent)


HEADER = """-- %(name)s (1-300)
--
-- GENERATED FILE -- do not edit by hand.
-- Source:    Tools/data/Professions_Reference.docx
-- Generator: Tools/convert_professions.py
--
-- Regenerate with:  python3 Tools/convert_professions.py
"""


def emit_guide(p):
    steps = emit_steps(p)
    lua = [HEADER % {"name": p["name"]}, ""]
    lua.append('AegisPathfinder:RegisterQuestShellPlusGuide("%s (1-300)", {' % p["name"])
    lua.append('\tfaction = "Both",')
    lua.append('\tcategory = "Profession",')
    lua.append("\tsteps = {")
    for s in steps:
        lua.append(step_to_lua(s) + ",")
    lua.append("\t},")
    lua.append("})")
    lua.append("")
    return "\n".join(lua)


TEMPLATE_HEADER = """-- %(name)s (1-300) -- NOT YET AUTHORED
--
-- GENERATED FILE -- do not edit by hand.
-- Generator: Tools/convert_professions.py
--
-- The professions reference this addon's guides were built from does not cover
-- %(name)s, so there is no route to convert. This placeholder exists so the
-- Professions list matches the design concept and so an unauthored guide is
-- obviously unauthored rather than silently missing.
--
-- %(shape)s
"""

SHAPE = {
    "crafting": ("Authoring this needs a craft-by-craft route: skill ranges, what to "
                 "make in each, and the reagents. Follow the pattern in any generated "
                 "profession guide in this folder."),
    "gathering": ("This is a gathering profession, so it does not level by crafting. "
                  "It needs a different step shape from the generated guides here: "
                  "where to gather at each skill band, not what to craft."),
}


def emit_template(name, kind):
    lua = [TEMPLATE_HEADER % {"name": name, "shape": SHAPE[kind]}, ""]
    lua.append('AegisPathfinder:RegisterQuestShellPlusGuide("%s (1-300)", {' % name)
    lua.append('\tfaction = "Both",')
    lua.append('\tcategory = "Profession",')
    lua.append("\ttemplate = true,")
    lua.append("\tsteps = {")
    lua.append(step_to_lua({
        "type": "NOTE",
        "title": "%s -- not yet authored" % name,
        "note": ("This guide is a placeholder. No route for %s exists in the "
                 "reference this addon's profession guides were built from." % name),
    }) + ",")
    lua.append(step_to_lua({
        "type": "TRAIN",
        "title": "Learn %s" % name,
        "note": "Train with any %s trainer." % name,
    }) + ",")
    lua.append("\t},")
    lua.append("})")
    lua.append("")
    return "\n".join(lua)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="parse and validate without writing")
    args = ap.parse_args()

    if not os.path.exists(DOCX):
        print("missing source document: %s" % DOCX)
        return 1

    professions = parse(DOCX)
    print("Parsed %d professions from %s\n" % (len(professions), os.path.basename(DOCX)))

    for p in professions:
        ranges = [s for s in p["steps"] if s["kind"] in ("craft", "method")]
        print("  %-16s %2d ranges  %3d shopping items  %d/%d trainer tiers  ~%s crafts"
              % (p["name"], len(ranges), len(p["shopping"]),
                 len(p["trainers"]["Alliance"]), len(p["trainers"]["Horde"]),
                 p["crafts"] if p["crafts"] else "?"))

    problems = validate(professions)
    print("")
    if problems:
        print("%d consistency issue(s) in the source document:" % len(problems))
        for msg in problems:
            print("  ! " + msg)
        print("\nThese are reported, not repaired -- the document is the authority.")
    else:
        print("Source document is internally consistent.")

    # Every rank a player trains at a trainer has somewhere to go.
    training = load_training()
    gaps = []
    for p in professions:
        sec = training["secondary"].get(p["name"])
        for s in p["steps"]:
            if s["kind"] != "train":
                continue
            rank = rank_of(s["label"])
            if sec and rank in ("Expert", "Artisan"):
                continue
            for fac in FACTIONS:
                if not trainers_for(p, rank, fac, training):
                    gaps.append("%s %s: no %s trainer" % (rank, p["name"], fac))
    if gaps:
        print("\n%d rank(s) with nowhere to train (the step says to ask a guard):" % len(gaps))
        for msg in gaps:
            print("  ! " + msg)

    if args.check:
        # The guides are generated; what is committed must be what this
        # generator writes, or a hand edit -- or a forgotten regeneration --
        # ships unnoticed.
        stale = []
        for p in professions:
            fn = re.sub(r"[^A-Za-z0-9]+", "_", p["name"]) + ".lua"
            path = os.path.join(OUTDIR, fn)
            on_disk = open(path, encoding="utf-8").read() if os.path.exists(path) else None
            if on_disk != emit_guide(p):
                stale.append(fn)
        if stale:
            print("\nOut of date -- run python3 Tools/convert_professions.py:")
            for fn in stale:
                print("  ! Guides/Professions/" + fn)
            return 1
        print("\nGenerated guides match the sources.")
        return 0

    os.makedirs(OUTDIR, exist_ok=True)
    written = []
    for p in professions:
        fn = re.sub(r"[^A-Za-z0-9]+", "_", p["name"]) + ".lua"
        with open(os.path.join(OUTDIR, fn), "w", encoding="utf-8") as fh:
            fh.write(emit_guide(p))
        written.append(fn)

    for name, kind in UNSOURCED:
        fn = re.sub(r"[^A-Za-z0-9]+", "_", name) + ".lua"
        with open(os.path.join(OUTDIR, fn), "w", encoding="utf-8") as fh:
            fh.write(emit_template(name, kind))
        written.append(fn)

    with open(os.path.join(OUTDIR, "Guides.xml"), "w", encoding="utf-8") as fh:
        fh.write('<Ui xmlns="http://www.blizzard.com/wow/ui/">\n')
        for fn in sorted(written):
            fh.write('\t<Script file="%s"/>\n' % fn)
        fh.write("</Ui>\n")

    print("\nWrote %d guides (+ Guides.xml) to %s"
          % (len(written), os.path.relpath(OUTDIR, ROOT)))
    print("  authored: %d    templates: %d" % (len(professions), len(UNSOURCED)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
