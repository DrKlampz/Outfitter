# Outfitter

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
