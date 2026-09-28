-- Dungeon guide: Scarlet Monastery, Alliance
-- Written by Tools/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Scarlet Monastery (34-45)", nil, "Alliance", function()

return [[

N Scarlet Monastery |N|Every quest for Scarlet Monastery: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Scarlet Monastery, not on this guide's way: The Orb of Kaladus, from Watch Paladin Janathos in Deadwind Pass; Rituals of Power (Mage), from Magus Tirth in Thousand Needles; Scarlet Corruption, from Brother Elias in Gilneas|

R Stormwind City |N|Travel to Stormwind City| |Z|Stormwind City|
A Brother Anton |QID|6141| |N|Brother Crowley (52.6, 43.4)| |Z|Stormwind City|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
A Mythology of the Titans |QID|1050| |N|Librarian Mae Paledust (75, 12.5)| |Z|Ironforge|

F Nijel's Point |N|Fly to Nijel's Point in Desolace| |Z|Desolace|
T Brother Anton |QID|6141| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|
A Down the Scarlet Path |QID|261| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|
C Down the Scarlet Path |QID|261| |N|Destroy 30 Undead Ravagers (63.2, 88.8)| |Z|Desolace|
T Down the Scarlet Path |QID|261| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|
A Down the Scarlet Path |QID|1052| |N|Brother Anton (66.5, 7.9)| |Z|Desolace|

F Southshore |N|Fly to Southshore in Hillsbrad Foothills| |Z|Hillsbrad Foothills|
T Down the Scarlet Path |QID|1052| |N|Raleigh the Devout (51.5, 58.4)| |Z|Hillsbrad Foothills|
A In the Name of the Light |QID|1053| |N|Raleigh the Devout (51.5, 58.4)| |Z|Hillsbrad Foothills|

R Scarlet Monastery |N|In the north-east of Tirisfal Glades: the Graveyard, Library, Armory and Cathedral all open off the monastery's courtyard (83, 33.6)| |Z|Tirisfal Glades|
C Mythology of the Titans |QID|1050| |N|Retrieve Mythology of the Titans from the Monastery|
C In the Name of the Light |QID|1053| |N|Kill High Inquisitor Whitemane, Scarlet Commander Mograine,  Herod, the Scarlet Champion and Houndmaster Loksey|

F Southshore |N|Fly to Southshore in Hillsbrad Foothills| |Z|Hillsbrad Foothills|
T In the Name of the Light |QID|1053| |N|Raleigh the Devout (51.5, 58.4)| |Z|Hillsbrad Foothills|

R Ironforge |N|Travel to Ironforge| |Z|Ironforge|
T Mythology of the Titans |QID|1050| |N|Librarian Mae Paledust (75, 12.5)| |Z|Ironforge|

N Done |N|That is every quest for Scarlet Monastery|

]]
end)
