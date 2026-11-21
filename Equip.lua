local _, ns = ...

-- Right-clicking a ring, trinket or one-hander in your bags equips it over the piece Gearhawk judges
-- the weakest, instead of whichever slot the game picks (it always takes the first one).

local CC = C_Container
local origUse = (CC and CC.UseContainerItem) or UseContainerItem
local getLink = (CC and CC.GetContainerItemLink) or GetContainerItemLink
local pickup = (CC and CC.PickupContainerItem) or PickupContainerItem

local function VendorishOpen()
    return (MerchantFrame and MerchantFrame:IsShown()) or (BankFrame and BankFrame:IsShown())
        or (MailFrame and MailFrame:IsShown()) or (TradeFrame and TradeFrame:IsShown())
        or (AuctionFrame and AuctionFrame:IsShown()) or (ItemSocketingFrame and ItemSocketingFrame:IsShown())
        or (GuildBankFrame and GuildBankFrame:IsShown())
end

local function Target(bag, slot)
    if InCombatLockdown() or VendorishOpen() or CursorHasItem() then return nil end
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return nil end
    local link = getLink and getLink(bag, slot)
    if type(link) == "table" then link = link.hyperlink end
    if not link then return nil end
    local loc = ns.EquipLoc and ns.EquipLoc(link)
    local slots = loc and ns.SlotsFor and ns.SlotsFor(loc)
    if not slots or (#slots < 2 and loc ~= "INVTYPE_WEAPON") then return nil end
    local r = ns.Compare and ns.Compare(link)
    if not r or r.unusable or r.tooHigh or r.isWorn or not r.slot then return nil end
    return r.slot
end

local function Smart(bag, slot, ...)
    local ok, target = pcall(Target, bag, slot)
    if ok and target and pickup and PickupInventoryItem then
        pickup(bag, slot)
        if CursorHasItem() then
            PickupInventoryItem(target)
            if CursorHasItem() then pickup(bag, slot) end   -- could not swap: put it back
            return
        end
    end
    return origUse(bag, slot, ...)
end

if origUse and getLink then
    if CC and CC.UseContainerItem then CC.UseContainerItem = Smart end
    if UseContainerItem then UseContainerItem = Smart end
end
