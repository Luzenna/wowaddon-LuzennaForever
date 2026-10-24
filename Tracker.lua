-- Remembers what each character carries (bags, bank, worn) and adds the other
-- characters' counts to item tooltips: "Name: 12 (bags 4, bank 8)".

local ADDON_NAME, ns = ...
local Tracker = {}
ns.Tracker = Tracker

local issecretvalue = issecretvalue or function() return false end

local function CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function Container()
    return C_Container
end

local function Count(bagIDs)
    local counts = {}
    local api = Container()
    for _, bag in ipairs(bagIDs) do
        local slots = api.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = api.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return counts
end

local function BagIDs()
    local ids = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) + (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag and 1 or 0) do
        ids[#ids + 1] = bag
    end
    return ids
end

local function BankIDs()
    local ids = { -1 } -- the bank's main slots
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do ids[#ids + 1] = bag end
    return ids
end

local bankOpen = false

local function Scan()
    local db = ns.db
    local entry = db.chars[CharKey()] or {}
    db.chars[CharKey()] = entry
    entry.class = select(2, UnitClass("player"))
    entry.bags = Count(BagIDs())
    if bankOpen then entry.bank = Count(BankIDs()) end
    local worn = {}
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then worn[id] = (worn[id] or 0) + 1 end
    end
    entry.worn = worn
    entry.time = time()
end

local pending
local function ScanSoon()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = nil
        Scan()
    end)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function ClassColor(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color and color.colorStr or "ffffffff"
end

local function DisplayName(key)
    local name, realm = key:match("^(.-)%-(.+)$")
    if realm and realm ~= GetRealmName() then return name .. "-" .. realm end
    return name or key
end

local function AddLines(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    if not ns.db or not ns.db.tracker.tooltip then return end
    local id = data and data.id
    if not id or issecretvalue(id) then return end
    local me = CharKey()
    local keys = {}
    for key in pairs(ns.db.chars) do
        if key ~= me then keys[#keys + 1] = key end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local entry = ns.db.chars[key]
        local bags = entry.bags and entry.bags[id] or 0
        local bank = entry.bank and entry.bank[id] or 0
        local worn = entry.worn and entry.worn[id] or 0
        local total = bags + bank + worn
        if total > 0 then
            local line = total
            if ns.db.tracker.split then
                local parts = {}
                if bags > 0 then parts[#parts + 1] = "bags " .. bags end
                if bank > 0 then parts[#parts + 1] = "bank " .. bank end
                if worn > 0 then parts[#parts + 1] = "worn " .. worn end
                line = total .. " (" .. table.concat(parts, ", ") .. ")"
            end
            tooltip:AddLine(("|c%s%s|r: %s"):format(ClassColor(entry.class), DisplayName(key), line))
        end
    end
end

function Tracker.Forget(name)
    local target = name:lower()
    for key in pairs(ns.db.chars) do
        if key:lower() == target or DisplayName(key):lower() == target then
            ns.db.chars[key] = nil
            print("|cff00ccffLuzennaForever:|r forgot " .. key)
            return
        end
    end
    print("|cff00ccffLuzennaForever:|r no tracked character called " .. name)
end

function Tracker.Init()
    ns.db.chars = ns.db.chars or {}
    local events = CreateFrame("Frame")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("BANKFRAME_OPENED")
    events:RegisterEvent("BANKFRAME_CLOSED")
    events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    events:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" then
            bankOpen = true
        elseif event == "BANKFRAME_CLOSED" then
            Scan() -- one last look while bankOpen is still true
            bankOpen = false
            return
        end
        ScanSoon()
    end)
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddLines)
    end
    Scan()
end
