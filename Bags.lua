-- Movable one-bag: drag Blizzard's combined bag frame, a tiny gear button with
-- "Reverse item order" and "Sort bags", position saved per account.
--
-- Written without Blizzard's UI source to hand, so every frame/method name is
-- looked up defensively. Check in game with /dump ContainerFrameCombinedBags
-- and /fstack if something doesn't move or the gear sits badly.

local ADDON_NAME, ns = ...
local Bags = {}
ns.Bags = Bags

local frame, gear

local function InCombat() return InCombatLockdown() end

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------

local function ApplyPosition()
    local pos = ns.db.bag
    if not (frame and pos.point) or InCombat() then return end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
end

function Bags.ResetPosition()
    -- Let Blizzard place it again.
    if frame and UpdateContainerFrameAnchors then UpdateContainerFrameAnchors() end
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    local pos = ns.db.bag
    pos.point, pos.relPoint, pos.x, pos.y = point, relPoint, x, y
end

---------------------------------------------------------------------------
-- Reverse item order. The slots' own positions are mirrored: the button in
-- reading-order place i goes to place n+1-i. Applying it twice puts them back,
-- so each button's last placement is remembered, and if a button is where we
-- left it the layout is already reversed (Blizzard has not laid it out again).
---------------------------------------------------------------------------

local placed = {} -- button -> { x, y } where this addon last put it

local function ItemButtons()
    local list = {}
    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do list[#list + 1] = button end
    elseif frame.Items then
        for _, button in ipairs(frame.Items) do list[#list + 1] = button end
    else
        for _, child in ipairs({ frame:GetChildren() }) do
            if child.GetBagID and child:IsShown() then list[#list + 1] = child end
        end
    end
    return list
end

local function Offset(button)
    local left, top = button:GetLeft(), button:GetTop()
    local fl, ft = frame:GetLeft(), frame:GetTop()
    if not (left and top and fl and ft) then return nil end
    return left - fl, top - ft
end

local function Mirror(buttons)
    local spots = {}
    for _, button in ipairs(buttons) do
        local x, y = Offset(button)
        if not x then return false end
        spots[#spots + 1] = { button = button, x = x, y = y }
    end
    -- Reading order: top to bottom, then left to right (rows are 0.5 apart at most by rounding).
    table.sort(spots, function(a, b)
        if math.abs(a.y - b.y) > 1 then return a.y > b.y end
        return a.x < b.x
    end)
    local n = #spots
    for i, spot in ipairs(spots) do
        local target = spots[n + 1 - i]
        spot.target = target
    end
    for _, spot in ipairs(spots) do
        spot.button:ClearAllPoints()
        spot.button:SetPoint("TOPLEFT", frame, "TOPLEFT", spot.target.x, spot.target.y)
        placed[spot.button] = { x = spot.target.x, y = spot.target.y }
    end
    return true
end

local function IsReversedNow(buttons)
    if #buttons == 0 then return false end
    for _, button in ipairs(buttons) do
        local mark, x, y = placed[button], Offset(button)
        if not (mark and x and math.abs(mark.x - x) < 0.5 and math.abs(mark.y - y) < 0.5) then return false end
    end
    return true
end

local function ApplyOrder(retry)
    if not frame or InCombat() then return end
    local buttons = ItemButtons()
    local want = ns.db.bag.reverse
    if IsReversedNow(buttons) == want then return end
    if not Mirror(buttons) and not retry then
        C_Timer.After(0, function() ApplyOrder(true) end) -- the layout's rects weren't resolved yet
        return
    end
    if not want then wipe(placed) end
end

function Bags.Refresh()
    ApplyOrder()
end

---------------------------------------------------------------------------
-- Gear button and menu
---------------------------------------------------------------------------

local function SortBags()
    if InCombat() then return end
    if C_Container and C_Container.SortBags then
        C_Container.SortBags()
    elseif _G.SortBags then
        _G.SortBags()
    end
end

Bags.Sort = SortBags

local function ShowMenu(owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateCheckbox("Reverse item order",
                function() return ns.db.bag.reverse end,
                function()
                    ns.db.bag.reverse = not ns.db.bag.reverse
                    Bags.Refresh()
                end)
            root:CreateButton("Sort bags", SortBags)
            root:CreateButton("All settings...", ns.OpenSettings)
        end)
    else
        ns.OpenSettings()
    end
end

local function CreateGear()
    -- Parented to the screen (not the bag) at a higher strata so nothing in
    -- the bag's own layering can hide it; it follows the bag's visibility.
    gear = CreateFrame("Button", "LuzennaForeverBagGear", UIParent)
    gear:SetSize(20, 20)
    gear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -1) -- tweak if it overlaps the title or close button
    gear:SetFrameStrata("HIGH")
    gear:SetShown(frame:IsShown())
    frame:HookScript("OnShow", function() gear:Show() end)
    frame:HookScript("OnHide", function() gear:Hide() end)
    local bg = gear:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5) -- a faint dark backing so the icon reads on any bag colour
    local icon = gear:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    gear:SetScript("OnClick", function(self) ShowMenu(self) end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bag options")
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Quick sort, one click, just left of the gear.
    local sort = CreateFrame("Button", "LuzennaForeverBagSort", UIParent)
    sort:SetSize(20, 20)
    sort:SetPoint("TOPRIGHT", gear, "TOPLEFT", -3, 0)
    sort:SetFrameStrata("HIGH")
    sort:SetShown(frame:IsShown())
    frame:HookScript("OnShow", function() sort:Show() end)
    frame:HookScript("OnHide", function() sort:Hide() end)
    local sortBg = sort:CreateTexture(nil, "BACKGROUND")
    sortBg:SetAllPoints()
    sortBg:SetColorTexture(0, 0, 0, 0.5)
    local sortIcon = sort:CreateTexture(nil, "ARTWORK")
    sortIcon:SetAllPoints()
    -- Blizzard's own sort-button picture if this client has it, else a plain icon.
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-button-autosort-up") then
        sortIcon:SetAtlas("bags-button-autosort-up")
    else
        sortIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_05")
        sortIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    sort:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    sort:SetScript("OnClick", SortBags)
    sort:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort bags")
        GameTooltip:Show()
    end)
    sort:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Reagent bag in the one-bag view. This client's combined bag holds bags 0-4
-- only: GetContainedBagIDs(list) fills a list with the bag IDs it lays out,
-- and MatchesBagID/CanUseForBagID say which bags it owns (all three are plain
-- functions on the frame; bag 5 answers false). They are wrapped here to add
-- the reagent bag. In combat the originals are used untouched, so Blizzard's
-- secure code (creating item buttons) never runs through this addon's code
-- then; the layout picks the reagent slots up again after combat.
---------------------------------------------------------------------------

local REAGENT = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

local function MergeOn()
    return ns.db.bag.mergeReagent and not InCombat()
        and (C_Container.GetContainerNumSlots(REAGENT) or 0) > 0
end

-- A faint pink wash over the reagent bag's slots so they stand out in the
-- combined bag. Item buttons are pooled and reused, so each button's overlay is
-- set again from its bag every time the slots are rebuilt.
local TINT = { 1, 0.45, 0.75, 0.22 }

function Bags.TintReagent()
    if not frame or type(frame.EnumerateValidItems) ~= "function" then return end
    local on = ns.db.bag.tintReagent
    for _, button in frame:EnumerateValidItems() do
        local reagent = on and button.GetBagID and button:GetBagID() == REAGENT
        local overlay = button.luzTint
        if reagent and not overlay then
            overlay = button:CreateTexture(nil, "OVERLAY", nil, 3)
            overlay:SetAllPoints()
            overlay:SetColorTexture(TINT[1], TINT[2], TINT[3], TINT[4])
            button.luzTint = overlay
        end
        if overlay then overlay:SetShown(reagent and true or false) end
    end
end

local function Wrap(name, add)
    local original = frame[name]
    if type(original) ~= "function" then return end
    frame[name] = function(self, ...)
        if not MergeOn() then return original(self, ...) end
        return add(original, self, ...)
    end
end

-- Redo the layout so a changed setting shows (and the separate reagent frame
-- goes away or comes back).
function Bags.RefreshLayout()
    if not frame or InCombat() then return end
    if type(frame.UpdateIfShown) == "function" then
        pcall(frame.UpdateIfShown, frame)
    end
    if ns.db.bag.mergeReagent and ContainerFrame6 and ContainerFrame6:IsShown() then
        ContainerFrame6:Hide()
    end
    Bags.TintReagent()
end

function Bags.HookReagent()
    Wrap("GetContainedBagIDs", function(original, self, ids, ...)
        local results = { original(self, ids, ...) }
        if type(ids) == "table" then
            local present = false
            for _, id in ipairs(ids) do if id == REAGENT then present = true end end
            if not present then ids[#ids + 1] = REAGENT end
        end
        return unpack(results)
    end)
    Wrap("MatchesBagID", function(original, self, bagID, ...)
        if bagID == REAGENT then return true end
        return original(self, bagID, ...)
    end)
    Wrap("CanUseForBagID", function(original, self, bagID, ...)
        if bagID == REAGENT then return true end
        return original(self, bagID, ...)
    end)

    -- The layout itself (UpdateItemSlots) loops over a fixed range of bags 4..0
    -- and acquires one item button per slot: after it has run, the same is done
    -- for the reagent bag, so UpdateItemLayout grids those buttons with the rest.
    -- (Retail's ContainerFrame.lua does this; checked in Forever's client:
    -- AcquireNewItemButton and the button's Initialize(bag, slot) both exist.)
    if type(frame.UpdateItemSlots) == "function" and type(frame.AcquireNewItemButton) == "function" then
        hooksecurefunc(frame, "UpdateItemSlots", function(self)
            if MergeOn() then
                local size = C_Container.GetContainerNumSlots(REAGENT) or 0
                for i = 1, size do
                    local button = self:AcquireNewItemButton()
                    button:Initialize(REAGENT, size - i + 1)
                end
            end
            Bags.TintReagent()
        end)
    end
    -- And the bag counts them, so the grid gets the rows for them.
    Wrap("GetBagSize", function(original, self, ...)
        return (original(self, ...) or 0) + (C_Container.GetContainerNumSlots(REAGENT) or 0)
    end)

    -- The reagent bag's own window would show the same slots a second time.
    if ContainerFrame6 then
        ContainerFrame6:HookScript("OnShow", function(self)
            if MergeOn() then self:Hide() end
        end)
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Bags.Init()
    frame = _G.ContainerFrameCombinedBags
    if not frame then
        print("|cffff8800LuzennaForever:|r ContainerFrameCombinedBags not found; bag features are off. Is one-bag mode on?")
        return
    end

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnDragStart", function(self)
        if not InCombat() then self:StartMoving() end
    end)
    frame:HookScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:HookScript("OnShow", function()
        ApplyPosition()
        ApplyOrder()
    end)

    CreateGear()
    Bags.HookReagent()

    -- Blizzard places bag frames when they open and when the layout changes.
    if _G.UpdateContainerFrameAnchors then
        hooksecurefunc("UpdateContainerFrameAnchors", ApplyPosition)
    end
    -- And lays out the item buttons again whenever the contents or size change.
    for _, method in ipairs({ "UpdateItemSlots", "UpdateItemLayout", "Update" }) do
        if type(frame[method]) == "function" then
            hooksecurefunc(frame, method, function() ApplyOrder() end)
        end
    end

    ApplyPosition()
end
