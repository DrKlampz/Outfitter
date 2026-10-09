# Outfitter

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
