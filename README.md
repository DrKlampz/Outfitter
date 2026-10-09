# Outfitter

A gear advisor for **WoW: Forever**. Tell it your class and spec and it rates the gear in your bags against what you wear, tells you where to get better gear for your level, and shows the best buys in the Auction House.

Open it with `/outfit`, the minimap button, or the addon list.

## What it does
- **Bag upgrades.** Every piece of gear in your bags is read from its real tooltip, scored for your spec, and compared with the item you would replace. Only the best upgrade per slot is listed (two for rings and trinkets). An empty slot always gets the best item you can use.
- **What I wear.** Every equipped item with its score, and which slots are empty.
- **Where to get.** Known quest rewards, dungeon drops, vendor and crafted items for your level, scored the same way, with where to get each one. Built-in lists so far cover **Mage, Warlock and Priest** (levels 10-60); other classes use the Auction tab for now.
- **Auction.** Reads the prices Profiteer saved from your last Auction House scan and shows the best gear for sale per slot, with its price (red when you cannot afford it yet). Needs Profiteer.
- **Tooltips.** Hover any item for a line saying whether it is an upgrade, worse or about the same compared with what you wear.
- **Minimap button** (left click opens, right click opens Where to get, drag to move) and a chat alert when a new upgrade lands in your bags.

Everything is limited to what you can use now: items above your level or that your class cannot wear are never suggested.

## Spec and weights
Outfitter guesses your spec from your talents. Pick a different one from the drop-down in the window, or `/outfit spec` to cycle. Each spec has its own stat weights (`/outfit weights` prints them).

## Commands
| | |
|---|---|
| `/outfit` | Open or close the window |
| `/outfit spec` | Next spec |
| `/outfit weights` | The numbers the current spec uses |
| `/outfit tip` | Tooltip line on/off |
| `/outfit minimap` | Minimap button show/hide |
| `/outfit alert` | Chat alert for new bag upgrades on/off |
| `/outfit gain N` | Only suggest items at least N% better |
| `/outfit debug` | Print what the game reports about your bags |

The item text is read in English. MIT licensed.
