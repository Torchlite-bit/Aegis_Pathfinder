#!/usr/bin/env python3
"""Draft talent builds for the Talent Advisor (Part 4), checked against the
original 1.12 trees, and written to Tools/data/talent_builds_draft.json.

  * A levelling build for every class: RestedXP's (import_rxp_talents.py),
    their regular build rather than the hardcore one.
  * A build at 60 for each spec of the five classes Turtle WoW has changed
    least -- Warrior, Mage, Rogue, Priest, Warlock -- as the talents and their
    ranks, which is all a build at 60 needs: the points are spent at once.

The 1.12 trees below are checked against every place RestedXP's builds name
before anything is checked against them. They are the original trees, not
Turtle WoW's: every build here waits on the trees the game has (`/apg
talents`) before the advisor follows it. Paladin, Shaman, Hunter and Druid,
which Turtle WoW reworked, get their spec builds then.

  python3 Tools/build/talent_builds_draft.py
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RXP = os.path.join(ROOT, "Tools", "data", "rxp_classic_talents.json")
OUT = os.path.join(ROOT, "Tools", "data", "talent_builds_draft.json")

# The 1.12 trees: "row column ranks name [< prerequisite]" a line.
TREES = {
    "WARRIOR": [("Arms", """
        1 1 3 Improved Heroic Strike
        1 2 5 Deflection
        1 3 3 Improved Rend
        2 1 2 Improved Charge
        2 2 5 Tactical Mastery
        2 3 3 Improved Thunder Clap
        3 1 2 Improved Overpower
        3 2 1 Anger Management < Tactical Mastery
        3 3 3 Deep Wounds < Improved Rend
        4 2 5 Two-Handed Weapon Specialization
        4 3 2 Impale < Deep Wounds
        5 1 5 Axe Specialization
        5 2 1 Sweeping Strikes
        5 3 5 Mace Specialization
        5 4 5 Sword Specialization
        6 1 5 Polearm Specialization
        6 3 3 Improved Hamstring
        7 2 1 Mortal Strike < Sweeping Strikes
    """), ("Fury", """
        1 2 5 Booming Voice
        1 3 5 Cruelty
        2 2 5 Improved Demoralizing Shout
        2 3 5 Unbridled Wrath
        3 1 3 Improved Cleave
        3 2 1 Piercing Howl
        3 3 3 Blood Craze
        3 4 5 Improved Battle Shout
        4 1 5 Dual Wield Specialization
        4 2 2 Improved Execute
        4 3 5 Enrage
        5 1 5 Improved Slam
        5 2 1 Death Wish
        5 4 2 Improved Intercept
        6 1 2 Improved Berserker Rage
        6 3 5 Flurry < Enrage
        7 2 1 Bloodthirst < Death Wish
    """), ("Protection", """
        1 2 5 Shield Specialization
        1 3 5 Anticipation
        2 1 2 Improved Bloodrage
        2 3 5 Toughness
        2 4 5 Iron Will
        3 1 1 Last Stand < Improved Bloodrage
        3 2 3 Improved Shield Block < Shield Specialization
        3 3 3 Improved Revenge
        3 4 5 Defiance
        4 1 3 Improved Sunder Armor
        4 2 3 Improved Disarm
        4 3 2 Improved Taunt
        5 1 2 Improved Shield Wall
        5 2 1 Concussion Blow
        5 3 2 Improved Shield Bash
        6 3 5 One-Handed Weapon Specialization
        7 2 1 Shield Slam < Concussion Blow
    """)],
    "MAGE": [("Arcane", """
        1 1 2 Arcane Subtlety
        1 2 5 Arcane Focus
        1 3 5 Improved Arcane Missiles
        2 1 2 Wand Specialization
        2 2 5 Magic Absorption
        2 3 5 Arcane Concentration
        3 1 2 Magic Attunement
        3 2 3 Improved Arcane Explosion
        3 3 1 Arcane Resilience
        4 1 2 Improved Mana Shield
        4 2 2 Improved Counterspell
        4 4 3 Arcane Meditation
        5 2 1 Presence of Mind
        5 3 5 Arcane Mind
        6 2 3 Arcane Instability < Presence of Mind
        7 2 1 Arcane Power < Arcane Instability
    """), ("Fire", """
        1 2 5 Improved Fireball
        1 3 5 Impact
        2 1 5 Ignite
        2 2 2 Flame Throwing
        2 3 3 Improved Fire Blast
        3 1 2 Incinerate
        3 2 3 Improved Flamestrike
        3 3 1 Pyroblast
        3 4 2 Burning Soul
        4 1 3 Improved Scorch
        4 2 2 Improved Fire Ward
        4 4 3 Master of Elements
        5 2 3 Critical Mass
        5 3 1 Blast Wave < Pyroblast
        6 3 5 Fire Power
        7 2 1 Combustion < Critical Mass
    """), ("Frost", """
        1 1 2 Frost Warding
        1 2 5 Improved Frostbolt
        1 3 3 Elemental Precision
        2 1 5 Ice Shards
        2 2 3 Frostbite
        2 3 2 Improved Frost Nova
        2 4 3 Permafrost
        3 1 3 Piercing Ice
        3 2 1 Cold Snap
        3 4 3 Improved Blizzard
        4 1 2 Arctic Reach
        4 2 3 Frost Channeling
        4 3 5 Shatter < Improved Frost Nova
        5 2 1 Ice Block
        5 3 3 Improved Cone of Cold
        6 3 5 Winter's Chill
        7 2 1 Ice Barrier < Ice Block
    """)],
    "ROGUE": [("Assassination", """
        1 1 3 Improved Eviscerate
        1 2 2 Remorseless Attacks
        1 3 5 Malice
        2 1 3 Ruthlessness
        2 2 2 Murder
        2 4 3 Improved Slice & Dice
        3 1 1 Relentless Strikes
        3 2 2 Improved Expose Armor
        3 3 5 Lethality < Malice
        4 2 5 Vile Poisons
        4 3 5 Improved Poisons
        5 2 1 Cold Blood
        5 3 3 Improved Kidney Shot
        6 2 5 Seal Fate < Cold Blood
        7 2 1 Vigor
    """), ("Combat", """
        1 1 3 Improved Gouge
        1 2 2 Improved Sinister Strike
        1 3 5 Lightning Reflexes
        2 1 3 Improved Backstab
        2 2 5 Deflection
        2 3 5 Precision
        3 1 2 Endurance
        3 2 1 Riposte < Deflection
        3 4 2 Improved Sprint
        4 1 2 Improved Kick
        4 2 5 Dagger Specialization
        4 3 5 Dual Wield Specialization < Precision
        5 1 5 Mace Specialization
        5 2 1 Blade Flurry
        5 3 5 Sword Specialization
        5 4 5 Fist Weapon Specialization
        6 2 2 Weapon Expertise < Blade Flurry
        6 3 3 Aggression
        7 2 1 Adrenaline Rush
    """), ("Subtlety", """
        1 2 5 Master of Deception
        1 3 5 Opportunity
        2 1 2 Sleight of Hand
        2 2 2 Elusiveness
        2 3 5 Camouflage
        3 1 3 Initiative
        3 2 1 Ghostly Strike
        3 3 3 Improved Ambush
        4 1 3 Setup
        4 2 2 Improved Sap
        4 3 3 Serrated Blades
        5 1 2 Heightened Senses
        5 2 1 Preparation
        5 3 2 Dirty Deeds
        5 4 1 Hemorrhage
        6 3 5 Deadliness
        7 2 1 Premeditation < Preparation
    """)],
    "PRIEST": [("Discipline", """
        1 2 5 Unbreakable Will
        1 3 5 Wand Specialization
        2 1 5 Silent Resolve
        2 2 2 Improved Power Word: Fortitude
        2 3 3 Improved Power Word: Shield
        2 4 2 Martyrdom
        3 2 1 Inner Focus
        3 3 3 Meditation
        4 1 3 Improved Inner Fire
        4 2 5 Mental Agility
        4 4 2 Improved Mana Burn
        5 2 5 Mental Strength
        5 3 1 Divine Spirit
        6 3 5 Force of Will
        7 2 1 Power Infusion < Mental Strength
    """), ("Holy", """
        1 1 2 Healing Focus
        1 2 3 Improved Renew
        1 3 5 Holy Specialization
        2 2 5 Spell Warding
        2 3 5 Divine Fury
        3 1 1 Holy Nova
        3 2 3 Blessed Recovery
        3 4 3 Inspiration
        4 1 2 Holy Reach
        4 2 3 Improved Healing
        4 3 2 Searing Light
        5 1 2 Improved Prayer of Healing
        5 2 1 Spirit of Redemption
        5 3 5 Spiritual Guidance
        6 3 5 Spiritual Healing
        7 2 1 Lightwell < Spirit of Redemption
    """), ("Shadow", """
        1 2 5 Spirit Tap
        1 3 5 Blackout
        2 1 3 Shadow Affinity
        2 2 2 Improved Shadow Word: Pain
        2 3 5 Shadow Focus
        3 1 2 Improved Psychic Scream
        3 2 5 Improved Mind Blast
        3 3 1 Mind Flay
        4 2 2 Improved Fade
        4 3 3 Shadow Reach
        4 4 5 Shadow Weaving
        5 1 1 Silence
        5 2 1 Vampiric Embrace
        5 3 2 Improved Vampiric Embrace < Vampiric Embrace
        6 3 5 Darkness
        7 2 1 Shadowform < Vampiric Embrace
    """)],
    "WARLOCK": [("Affliction", """
        1 2 5 Suppression
        1 3 5 Improved Corruption
        2 1 3 Improved Curse of Weakness
        2 2 2 Improved Drain Soul
        2 3 2 Improved Life Tap
        2 4 5 Improved Drain Life
        3 1 3 Improved Curse of Agony
        3 2 5 Fel Concentration
        3 3 1 Amplify Curse
        4 1 2 Grim Reach
        4 2 2 Nightfall
        4 4 2 Improved Drain Mana
        5 2 1 Siphon Life
        5 3 1 Curse of Exhaustion < Amplify Curse
        6 2 5 Shadow Mastery < Siphon Life
        6 3 4 Improved Curse of Exhaustion < Curse of Exhaustion
        7 2 1 Dark Pact
    """), ("Demonology", """
        1 1 2 Improved Healthstone
        1 2 3 Improved Imp
        1 3 5 Demonic Embrace
        2 1 2 Improved Health Funnel
        2 2 3 Improved Voidwalker
        2 3 5 Fel Intellect
        3 1 3 Improved Succubus
        3 2 1 Fel Domination
        3 3 5 Fel Stamina
        4 2 2 Master Summoner < Fel Domination
        4 3 5 Unholy Power
        5 1 5 Improved Enslave Demon
        5 2 1 Demonic Sacrifice
        5 4 2 Improved Firestone
        6 3 5 Master Demonologist < Unholy Power
        7 2 1 Soul Link < Demonic Sacrifice
        7 3 2 Improved Spellstone
    """), ("Destruction", """
        1 2 5 Improved Shadow Bolt
        1 3 5 Cataclysm
        2 2 5 Bane
        2 3 5 Aftermath
        3 1 2 Improved Firebolt
        3 2 2 Improved Lash of Pain
        3 3 5 Devastation
        3 4 1 Shadowburn
        4 1 2 Intensity
        4 2 2 Destructive Reach
        4 4 5 Improved Searing Pain
        5 1 2 Pyroclasm < Intensity
        5 2 5 Improved Immolate
        5 3 1 Ruin < Devastation
        6 3 5 Emberstorm
        7 2 1 Conflagrate < Improved Immolate
    """)],
}

# Builds at 60: each tree's talents and ranks, with what the build is for.
BUILDS = {
    "WARRIOR": [
        ("Arms", "Mortal Strike with a two-hander: questing at 60, PvP, and raids before Fury gear.", {
            "Improved Heroic Strike": 3, "Improved Rend": 3, "Tactical Mastery": 5, "Improved Overpower": 2,
            "Anger Management": 1, "Deep Wounds": 3, "Two-Handed Weapon Specialization": 5, "Impale": 2,
            "Sweeping Strikes": 1, "Axe Specialization": 5, "Mortal Strike": 1,
            "Cruelty": 5, "Unbridled Wrath": 5, "Improved Battle Shout": 5, "Enrage": 5}),
        ("Fury", "Dual wield with Bloodthirst: the raid damage build.", {
            "Improved Heroic Strike": 3, "Improved Rend": 3, "Tactical Mastery": 5, "Anger Management": 1,
            "Deep Wounds": 3, "Impale": 2,
            "Cruelty": 5, "Unbridled Wrath": 5, "Improved Battle Shout": 5, "Dual Wield Specialization": 5,
            "Improved Execute": 2, "Enrage": 5, "Death Wish": 1, "Flurry": 5, "Bloodthirst": 1}),
        ("Protection", "Shield Slam tank: holds threat and lasts in dungeons and raids.", {
            "Improved Heroic Strike": 3, "Deflection": 5, "Tactical Mastery": 5,
            "Cruelty": 3,
            "Shield Specialization": 5, "Anticipation": 5, "Improved Bloodrage": 2, "Toughness": 5,
            "Last Stand": 1, "Improved Shield Block": 3, "Defiance": 5, "Improved Sunder Armor": 3,
            "Improved Taunt": 2, "Concussion Blow": 1, "One-Handed Weapon Specialization": 2, "Shield Slam": 1}),
    ],
    "MAGE": [
        ("Arcane", "Presence of Mind and Arcane Power, with Frost's slows: burst for PvP.", {
            "Arcane Subtlety": 2, "Arcane Focus": 5, "Magic Absorption": 1, "Arcane Concentration": 5,
            "Improved Arcane Explosion": 3, "Arcane Resilience": 1, "Improved Mana Shield": 1,
            "Arcane Meditation": 3, "Presence of Mind": 1, "Arcane Mind": 5, "Arcane Instability": 3,
            "Arcane Power": 1,
            "Improved Frostbolt": 5, "Elemental Precision": 3, "Ice Shards": 5, "Piercing Ice": 3,
            "Cold Snap": 1, "Frost Channeling": 3}),
        ("Fire", "Combustion with Arcane's Clearcasting: raid damage once fire resistance allows.", {
            "Arcane Subtlety": 2, "Arcane Focus": 5, "Arcane Concentration": 5, "Improved Arcane Explosion": 3,
            "Arcane Meditation": 3,
            "Improved Fireball": 5, "Ignite": 5, "Flame Throwing": 2, "Incinerate": 2, "Pyroblast": 1,
            "Burning Soul": 2, "Improved Scorch": 3, "Master of Elements": 3, "Critical Mass": 3,
            "Blast Wave": 1, "Fire Power": 5, "Combustion": 1}),
        ("Frost", "Winter's Chill and Ice Barrier with Arcane's Clearcasting: steady raid damage.", {
            "Arcane Subtlety": 2, "Arcane Focus": 5, "Magic Absorption": 2, "Arcane Concentration": 5,
            "Improved Arcane Explosion": 3, "Arcane Meditation": 3,
            "Improved Frostbolt": 5, "Elemental Precision": 3, "Ice Shards": 5, "Piercing Ice": 3,
            "Cold Snap": 1, "Arctic Reach": 2, "Frost Channeling": 3, "Improved Blizzard": 2, "Ice Block": 1,
            "Winter's Chill": 5, "Ice Barrier": 1}),
    ],
    "ROGUE": [
        ("Assassination", "Seal Fate with daggers: combo points from crits.", {
            "Improved Eviscerate": 3, "Malice": 5, "Ruthlessness": 3, "Murder": 2, "Improved Slice & Dice": 3,
            "Relentless Strikes": 1, "Improved Expose Armor": 2, "Lethality": 5, "Cold Blood": 1,
            "Seal Fate": 5, "Vigor": 1,
            "Improved Sinister Strike": 2, "Lightning Reflexes": 3, "Improved Backstab": 3,
            "Opportunity": 5, "Camouflage": 5, "Initiative": 2}),
        ("Combat", "Swords with Blade Flurry and Adrenaline Rush: the raid damage build.", {
            "Improved Eviscerate": 1, "Malice": 5, "Ruthlessness": 3, "Murder": 2, "Improved Slice & Dice": 3,
            "Relentless Strikes": 1, "Lethality": 5,
            "Improved Sinister Strike": 2, "Lightning Reflexes": 3, "Precision": 5, "Deflection": 3,
            "Endurance": 2, "Dual Wield Specialization": 5, "Blade Flurry": 1, "Sword Specialization": 5,
            "Weapon Expertise": 2, "Aggression": 2, "Adrenaline Rush": 1}),
        ("Subtlety", "Hemorrhage, Preparation and Premeditation: control and burst for PvP.", {
            "Remorseless Attacks": 2, "Malice": 5, "Ruthlessness": 1, "Murder": 2, "Improved Slice & Dice": 3,
            "Relentless Strikes": 1, "Lethality": 5,
            "Opportunity": 5, "Camouflage": 5, "Elusiveness": 2, "Initiative": 3, "Ghostly Strike": 1,
            "Improved Sap": 2, "Serrated Blades": 3, "Heightened Senses": 2, "Preparation": 1,
            "Dirty Deeds": 1, "Hemorrhage": 1, "Deadliness": 5, "Premeditation": 1}),
    ],
    "PRIEST": [
        ("Discipline", "Power Infusion and Divine Spirit with Holy's healing: raid support.", {
            "Wand Specialization": 5, "Improved Power Word: Fortitude": 2, "Improved Power Word: Shield": 3,
            "Martyrdom": 1, "Inner Focus": 1, "Meditation": 3, "Mental Agility": 5, "Mental Strength": 5,
            "Divine Spirit": 1, "Force of Will": 4, "Power Infusion": 1,
            "Healing Focus": 2, "Improved Renew": 3, "Divine Fury": 5, "Holy Nova": 1, "Inspiration": 3,
            "Blessed Recovery": 1, "Improved Healing": 3, "Holy Reach": 2}),
        ("Holy", "Spiritual Healing and Spiritual Guidance, with Discipline's mana: the raid healer.", {
            "Wand Specialization": 5, "Improved Power Word: Fortitude": 2, "Improved Power Word: Shield": 3,
            "Martyrdom": 1, "Inner Focus": 1, "Meditation": 3, "Mental Agility": 5, "Divine Spirit": 1,
            "Healing Focus": 2, "Improved Renew": 3, "Divine Fury": 5, "Holy Nova": 1, "Inspiration": 3,
            "Blessed Recovery": 1, "Improved Healing": 3, "Holy Reach": 2, "Improved Prayer of Healing": 2,
            "Spirit of Redemption": 1, "Spiritual Guidance": 2, "Spiritual Healing": 5}),
        ("Shadow", "Shadowform with Shadow Weaving and Vampiric Embrace: damage, and a little healing for the group.", {
            "Wand Specialization": 5, "Improved Power Word: Fortitude": 2, "Improved Power Word: Shield": 3,
            "Inner Focus": 1, "Meditation": 2,
            "Spirit Tap": 5, "Shadow Affinity": 3, "Improved Shadow Word: Pain": 2, "Shadow Focus": 5,
            "Improved Mind Blast": 5, "Mind Flay": 1, "Shadow Reach": 3, "Shadow Weaving": 5,
            "Vampiric Embrace": 1, "Improved Vampiric Embrace": 2, "Darkness": 5, "Shadowform": 1}),
    ],
    "WARLOCK": [
        ("Affliction", "Nightfall, Siphon Life and Dark Pact, with Demonology's pet: damage over time that lasts.", {
            "Improved Corruption": 5, "Improved Life Tap": 2, "Improved Drain Life": 5,
            "Improved Curse of Agony": 3, "Fel Concentration": 5, "Grim Reach": 2, "Nightfall": 2,
            "Siphon Life": 1, "Shadow Mastery": 5, "Dark Pact": 1,
            "Demonic Embrace": 5, "Improved Health Funnel": 1, "Improved Voidwalker": 3, "Fel Intellect": 2,
            "Fel Domination": 1, "Fel Stamina": 3, "Master Summoner": 2, "Unholy Power": 3}),
        ("Demonology", "Soul Link and Master Demonologist: a strong pet and a hard warlock to kill.", {
            "Demonic Embrace": 5, "Improved Voidwalker": 3, "Fel Intellect": 3, "Fel Domination": 1,
            "Fel Stamina": 5, "Master Summoner": 2, "Unholy Power": 5, "Demonic Sacrifice": 1,
            "Master Demonologist": 5, "Soul Link": 1,
            "Improved Corruption": 5, "Improved Life Tap": 2, "Improved Drain Life": 3,
            "Improved Curse of Agony": 3, "Fel Concentration": 3, "Grim Reach": 2, "Nightfall": 2}),
        ("Destruction", "Shadow Mastery with Ruin: the Shadow Bolt raid build.", {
            "Suppression": 5, "Improved Corruption": 5, "Improved Drain Soul": 2, "Improved Life Tap": 2,
            "Improved Curse of Agony": 3, "Amplify Curse": 1, "Grim Reach": 2, "Nightfall": 2,
            "Improved Drain Mana": 2, "Siphon Life": 1, "Shadow Mastery": 5,
            "Improved Shadow Bolt": 5, "Cataclysm": 5, "Bane": 5, "Devastation": 5, "Ruin": 1}),
    ],
}


def parse_trees():
    out = {}
    for cls, trees in TREES.items():
        tabs = []
        for name, body in trees:
            talents = {}
            for line in body.strip().splitlines():
                head, _, pre = line.strip().partition(" < ")
                row, col, ranks, tname = head.split(" ", 3)
                talents[tname] = {"row": int(row), "col": int(col), "max": int(ranks), "pre": pre or None}
            tabs.append((name, talents))
        out[cls] = tabs
    return out


def check_against_rxp(trees, rxp):
    """Every place RestedXP's builds name has that talent in these trees."""
    problems = []
    for cls, tabs in trees.items():
        for g in rxp["classes"][cls]:
            for p in g["points"]:
                for c in p.get("choices", [p]):
                    name, talents = tabs[c["tab"] - 1]
                    t = talents.get(c["name"])
                    if not t or (t["row"], t["col"]) != (c["row"], c["col"]):
                        problems.append("%s %s: RestedXP has %s at row %d column %d; the tree here has %s"
                                        % (cls, name, c["name"], c["row"], c["col"],
                                           "it at row %d column %d" % (t["row"], t["col"]) if t else "no such talent"))
    return sorted(set(problems))


def check_build(tabs, alloc):
    """What is wrong with a build at 60: talents its class has, ranks they
    have, five points a row down in each tree, prerequisites at full rank,
    51 points."""
    problems = []
    where = {}
    for i, (_, talents) in enumerate(tabs):
        for tname, t in talents.items():
            where[tname] = (i, t)
    by_tree = [dict() for _ in tabs]
    for tname, rank in alloc.items():
        if tname not in where:
            problems.append("no talent %r" % tname)
            continue
        i, t = where[tname]
        if rank > t["max"]:
            problems.append("%s %d of %d" % (tname, rank, t["max"]))
        by_tree[i][tname] = rank
        if t["pre"] and alloc.get(t["pre"], 0) < where[t["pre"]][1]["max"]:
            problems.append("%s needs %s at full rank" % (tname, t["pre"]))
    for i, picks in enumerate(by_tree):
        talents = tabs[i][1]
        for tname in picks:
            row = talents[tname]["row"]
            above = sum(r for n, r in picks.items() if talents[n]["row"] < row)
            if above < 5 * (row - 1):
                problems.append("%s (row %d of %s) needs %d points above it, has %d"
                                % (tname, row, tabs[i][0], 5 * (row - 1), above))
    total = sum(alloc.values())
    if total != 51:
        problems.append("%d points, not 51" % total)
    return problems, [sum(p.values()) for p in by_tree]


def main():
    trees = parse_trees()
    with open(RXP, encoding="utf-8") as fh:
        rxp = json.load(fh)
    problems = check_against_rxp({c: trees[c] for c in trees}, rxp)
    for p in problems:
        print("tree:", p)
    out = {"note": "Drafts on the original 1.12 trees; each waits on the trees the game has (/apg talents).",
           "levelling_source": rxp["source"], "classes": {}}
    for cls, guides in rxp["classes"].items():
        entry = {"levelling": [{"name": g["name"], "levels": [g["min_level"], g["max_level"]],
                                "respec": g["respec"], "next": g["next"], "order": g["order"]}
                               for g in guides if not g["survival"]],
                 "specs": []}
        for spec, why, alloc in BUILDS.get(cls, []):
            bad, split = check_build(trees[cls], alloc)
            problems += ["%s %s: %s" % (cls, spec, b) for b in bad]
            for b in bad:
                print("build: %s %s: %s" % (cls, spec, b))
            entry["specs"].append({"spec": spec, "split": "/".join(str(n) for n in split), "why": why,
                                   "trees": [[name, {t: alloc[t] for t in sorted(
                                       [n for n in alloc if n in talents],
                                       key=lambda n, ts=talents: (ts[n]["row"], ts[n]["col"]))}]
                                             for name, talents in trees[cls]]})
        out["classes"][cls] = entry
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, indent=1)
    print("wrote %s: %d problems" % (os.path.relpath(OUT, ROOT), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
