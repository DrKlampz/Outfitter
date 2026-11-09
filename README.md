# Gearhawk

A gear advisor for **WoW: Forever**. Tell it your class and spec and it rates the gear in your bags against what you wear, tells you where to get better gear for your level, and shows the best buys in the Auction House.

Open it with `/hawk`, the minimap button, or the addon list.

## What it does
- **Inventory.** Every piece of gear in your bags is read from its real tooltip, scored for your spec, and compared with the item you would replace. Only the best upgrade per slot is listed (two for rings and trinkets). An empty slot always gets the best item you can use.
- **Equipped.** Every equipped item with its score, and which slots are empty.
- **What to get.** Known quest rewards, dungeon drops, vendor and crafted items for your level, scored the same way, with where to get each one. For **every class** it also lists gear your other characters carry in their bags or bank, and gear one of your characters can craft (this part reads Profiteer's saved data, so install Profiteer). Built-in lists of quest, dungeon and vendor gear cover **Mage, Warlock and Priest** so far; the Auction tab works for every class. Tick boxes along the bottom pick which kinds (Quest, Dungeon, Battleground, Vendor) each character sees.
- **Auction.** Reads the prices Profiteer saved from your last Auction House scan and shows the best gear for sale per slot, with its price (red when you cannot afford it yet). Needs Profiteer.
- **Tooltips.** Hover any item for a line saying whether it is an upgrade, worse or about the same compared with what you wear.
- **Minimap button** (left click opens, right click opens What to get, drag to move) and a chat alert when a new upgrade lands in your bags.

Everything is limited to what you can use now: items above your level or that your class cannot wear are never suggested.

## Spec and weights
Gearhawk guesses your spec from your talents. Pick a different one from the drop-down in the window, or `/hawk spec` to cycle. Each spec has its own stat weights (`/hawk weights` prints them).

## Commands
| | |
|---|---|
| `/hawk` | Open or close the window |
| `/hawk spec` | Next spec |
| `/hawk weights` | The numbers the current spec uses |
| `/hawk tip` | Tooltip line on/off |
| `/hawk minimap` | Minimap button show/hide |
| `/hawk alert` | Chat alert for new bag upgrades on/off |
| `/hawk gain N` | Only suggest items at least N% better |
| `/hawk debug` | Print what the game reports about your bags |

The item text is read in English. MIT licensed.

What to get uses the quest database from Questie (QuestieDB) when it is installed, so every class gets quest, vendor and dungeon suggestions.
