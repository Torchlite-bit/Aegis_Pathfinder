-- Dungeon guide: Shadowfang Keep, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Shadowfang Keep (22-30)", nil, "Horde", function()

return [[

N Shadowfang Keep |N|Every quest for Shadowfang Keep: picked up, then the way in, what each asks for inside, and the hand-ins after|

N Given elsewhere |N|Also for Shadowfang Keep, not on this guide's way: Too Late to Prelate, from Father Brightcopf in Tirisfal Glades; The Orb of Soran'ruk (Warlock), from Doan Karhan in The Barrens|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
A Into The Jaws |QID|40281| |N|Pierce Shackleton (85.5, 13.5)| |Z|Undercity| |O| |PRE|40280|
A The Book of Ur |QID|1013| |N|Keeper Bel'dugur (53.7, 54.5)| |Z|Undercity|

F The Sepulcher |N|Fly to the Sepulcher in Silverpine Forest| |Z|Silverpine Forest|
A Deathstalkers in Shadowfang |QID|1098| |N|High Executor Hadrec (43.4, 40.9)| |Z|Silverpine Forest|
A Arugal Must Die |QID|1014| |N|Dalar Dawnweaver (44.2, 39.8)| |Z|Silverpine Forest|

R Shadowfang Keep |N|The keep stands on the hill above Pyrewood Village (42.8, 67.5)| |Z|Silverpine Forest|
T Deathstalkers in Shadowfang |QID|1098| |N|Deathstalker Vincent|
C Into The Jaws |QID|40281| |N|Find Melenas' Belongings in the Shadowfang Keep Library| |O|
C The Book of Ur |QID|1013| |N|Get the Book of Ur|
C Arugal Must Die |QID|1014| |N|Kill Arugal and bring his head|

N Back outside |N|Out of Shadowfang Keep, in Silverpine Forest|
T Arugal Must Die |QID|1014| |N|Dalar Dawnweaver (44.2, 39.8)| |Z|Silverpine Forest|

R Undercity |N|Travel to the Undercity| |Z|Undercity|
T Into The Jaws |QID|40281| |N|Pierce Shackleton (85.5, 13.5)| |Z|Undercity| |O|
A Darlthos Legacy |QID|40282| |N|Pierce Shackleton (85.5, 13.5)| |Z|Undercity| |O| |PRE|40281|
T The Book of Ur |QID|1013| |N|Keeper Bel'dugur (53.7, 54.5)| |Z|Undercity|

F The Sepulcher |N|Fly to the Sepulcher in Silverpine Forest| |Z|Silverpine Forest|
T Darlthos Legacy |QID|40282| |N|Duchess Grelda (42, 10.2)| |Z|Silverpine Forest| |O|

N Done |N|That is every quest for Shadowfang Keep|

]]
end)
