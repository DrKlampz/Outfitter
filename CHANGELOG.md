# Outfitter

## v0.7.0
- Dungeon and raid drops are now accurate: every item lists the actual bosses that drop it and the instance (up to three bosses, bosses only; ordinary monsters only when nothing else drops it). Before, the first monster in the quest database was shown, often a trash mob or the wrong place.
- WoW Forever's own dungeons are covered: The Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands and City of Dalaran, with their bosses and gear. Classic's database did not know these dungeons, so their drops were missing or unplaced.
- Sources: the Classic loot database (CMaNGOS) for the original dungeons; WoW Forever loot tables compiled by the community (wowtbc.gg, AzerothCompendium) for the new ones. Loot in the newest Forever dungeons is still being discovered.

## v0.6.3
- Same as v0.6.2 (which was tagged on the wrong commit); first release listed on Wago Addons.

## v0.6.2
- Weapons whose skill you still have to learn from a trainer (for example one-handed swords for a Warlock) are no longer suggested; they show as "train Swords" in /outfit weapons.
- New `/outfit weapons` lists the weapons in your level range with their score against what you hold.
- Where to get rows are roomier so wrapped text and costs no longer crowd the next item.
- Where to get shows every result instead of cutting off with "+N more".
- Long source lines (several vendors, long zone names) now wrap inside the window instead of running off the edge.
- Vendor items show what they cost: gold, honor, arena points or trade items. Prices are remembered once you open that vendor (honor, tokens and reputation-discounted prices); until then it falls back to a bundled list of vendor gold prices (Classic database), and says unknown only if the item isn't on it.

## v0.6.1
- Quest rewards are back for every class: a bundled list of Classic quest rewards (armor and weapons, with each quest's level, race and class limits and zone) is combined with the Questie vendor and dungeon data. Quest rewards show as "Quest: name - zone".
- Items that would give you nothing (fishing hats and buckets, anything with no stats you use) are no longer suggested for empty slots.
- Off-hand pieces are not suggested while you are using a two-handed weapon.
- Where to get shows the real colored item names once the game knows them.

## v0.6.0
- Where to get now works for every class with real quest, vendor and dungeon sources. It reads the quest database that Questie installs (QuestieDB) and lists, for your class, race and level, armor and weapons from quest rewards ("Quest: name - zone"), vendors ("Vendor: name, zone") and dungeon bosses ("Drop: boss, dungeon"), each checked against what you wear. The built-in Mage/Warlock/Priest lists still add their own notes.
- The database is read once per session in small slices a few seconds after login, so there is no hitch; opening Where to get before it finishes shows "Loading..." and fills in by itself.
- Needs Questie (QuestieDB) installed; without it you still get the built-in lists and your other characters' gear and recipes.

## v0.5.7
- Where to get no longer offers gear you cannot actually get: bind-on-pickup crafts only show if your own character has the profession ("Leatherworking - you know the recipe"), and soulbound or bind-on-pickup gear sitting on another character is no longer offered (it cannot be passed on). Bind-on-equip crafts by your other characters still show.
- Auction tab rows now show the real colored item names instead of raw "item:1234:::..." text.
- Weapons your class cannot use at all (a Druid with a sword, a Mage with an axe, and so on) are no longer suggested.

## v0.5.6
- Read the "Increases healing done by up to X and damage done by up to Y for all magical spells and effects" line (it was ignored, so pieces carrying it were undervalued and swaps looked much bigger than they are, e.g. +114% instead of about +21%).
- More stat line forms understood: "+N Spell Damage/Power", "+N Healing Spells", "+N <school> Damage", "+N mana every 5 sec", "+N Attack Power", ranged attack power, and armor with a bonus. Bonuses that only apply "when fighting" something are no longer counted.
- Enchants and gems are not counted twice (the game already puts them in the stat lines).
- Swapping out a piece of an active set now counts the set bonus you would lose.
- New `/outfit unread` lists any stat lines on your worn gear that Outfitter does not understand.

## v0.5.5
- Single-school spell damage ("+10 Frost damage") is now only worth what your spec actually casts from that school: Frost pants are no longer an upgrade for an Affliction Warlock, but are for a Frost Mage. Each spec has its own school weights (Affliction: Shadow, some Fire; Destruction: Fire, some Shadow; and so on).
- "Restores N Mana per 5 sec" is now read (the game capitalizes Mana), so mana regeneration is counted. Before this, a gear piece with MP5 was under-valued and weak swaps looked like upgrades.

## v0.5.4
- Where to get now names the Scarlet Monastery wing (Graveyard, Library, Cathedral) and the Dire Maul wing for the drops that come from there, e.g. "Scarlet Monastery Graveyard - Bloodmage Thalnos".

## v0.5.3
- Gear you cannot use yet no longer gets suggested: level, profession rank ("Requires Blacksmithing (125)"), class ("Classes: ..."), and armor type your class cannot wear yet (plate/mail before level 40, shields for non-shield classes) are now checked from the item text itself, not only from the tooltip's red color. The item's minimum level from the game is used as a backup.

## v0.5.2
- Fixed the actual cause of the Auction tab freezing: the game rejected a level lookup (UnitLevel needs "player"), so no item was ever checked.
- The Auction tab can no longer get stuck on "Checking auction items... 0 of N": every batch is error-protected, a stalled check restarts itself, and new auction data replaces a check that was running on old data.
- `/outfit debug` now prints the auction state (saved listings, progress, errors) so a problem can be reported precisely.

## v0.5.1
- Auction tab no longer sticks at "Checking auction items... 0 of N". It now reads the live Auction House listing itself (every item with its real random suffix, e.g. "of Frozen Wrath"), so stats are scored correctly, and one unreadable item can no longer stop the whole check.
- Shows up to 12 buys instead of 8, and says how many items could not be read.
- Open the Auction House and let the scan finish (Profiteer's scan is picked up automatically), then open the Auction tab.

## v0.5.0
- Where to get now works for every class: it lists gear your other characters hold in their bags or bank ("Alt: in Barry's bags") and gear your characters know how to craft ("Crafted: Blacksmithing - Barry knows the recipe"), each checked against your class, level and what you wear. This reads the data Profiteer saves, so Profiteer must be installed.
- The built-in quest/dungeon/vendor lists are still Mage, Warlock and Priest only.

## v0.4.1
- Where to get now has early-game gear for Mages, Warlocks and Priests: 40 crafted cloth pieces (robes, pants, boots, gloves, belts, cloaks, hoods, shoulders) and two wands, read from the game's own tailoring and enchanting lists, so low-level characters (a level 10 Mage, for one) get suggestions instead of an empty list.
- The empty list now says how many items it checked and points to the Auction tab.

## v0.4.0
- New "Auction" tab, works for every class: reads the prices Profiteer saved from your last Auction House scan, scores every piece of gear in it against what you wear, and shows the best buy per slot with its price (red if you cannot afford it yet).
- Empty slots now rank by how good the item is, not just by price.
- Tabs renamed to fit four: Bag upgrades, What I wear, Where to get, Auction.

## v0.3.0
- Minimap button: left click opens the window, right click opens "Where to get", drag to move. `/outfit minimap` hides or shows it.
- Chat alert when a new upgrade lands in your bags (`/outfit alert` turns it off).
- `/outfit gain N` sets how much better (in %) an item must be to be suggested.

## v0.2.3
- One suggestion per slot: only the best item for each slot is listed (two for rings and trinkets), in both "Upgrades in bags" and "Where to get".

## v0.2.2
- Where to get: an empty slot always gets the best known item you can use, even if it scores low.
- Added necklaces and trinkets (levels 15-60) to the lists.

## v0.2.1
- Where to get only lists items you can use at your current level. Huge percentages show as "big upgrade".

## v0.2.0
- Where to get: lists known gear (quest, dungeon, vendor, crafted) for cloth casters (Mage, Warlock, Priest), levels 10-60, scored in game against what you wear.
- First list is small: only items confirmed on a web page are in it.

## v0.1.1
- Fixed: bags were not read and icons were missing (the game uses different item functions); added /outfit debug.
- Spec button is now a drop-down list of all specs for your class.
- Window height fits the list, so rows no longer spill out of the frame; text columns resized.

## v0.1.0
- First version: class and spec setup (guessed from your talents), item scoring from tooltips, upgrades in your bags, a tooltip line on every item, and a view of what you wear.
