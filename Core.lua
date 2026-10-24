-- LuzennaForever core: saved variables, the settings page, the minimap button
-- (the one entry point for every setting), and the /luz command.

local ADDON_NAME, ns = ...

ns.defaults = {
    bag = { reverse = false, mergeReagent = true, tintReagent = true },                 -- point/x/y are added when the bag is first dragged
    minimap = { angle = 215, hide = false },
    tracker = { tooltip = true, split = true },
    errors = { keep = true, list = {} },
}

local function Merge(into, from)
    for key, value in pairs(from) do
        if type(value) == "table" then
            if type(into[key]) ~= "table" then into[key] = {} end
            Merge(into[key], value)
        elseif into[key] == nil then
            into[key] = value
        end
    end
end

---------------------------------------------------------------------------
-- Settings page (Options > AddOns > LuzennaForever)
---------------------------------------------------------------------------

local function RegisterSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("LuzennaForever")
    ns.category = category
    local db = ns.db

    local function Header(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function Checkbox(tbl, key, name, tooltip, onChange)
        local default
        for section, saved in pairs(db) do
            if saved == tbl then default = ns.defaults[section][key] end
        end
        local setting = Settings.RegisterAddOnSetting(category, "Luzenna_" .. name, key, tbl,
            "boolean", name, default)
        if onChange then setting:SetValueChangedCallback(onChange) end
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    Header("Bags")
    Checkbox(db.bag, "reverse", "Reverse item order",
        "Show the one-bag's slots last-to-first. Purely visual: no items move. Also in the gear menu on the bag.",
        function() if ns.Bags then ns.Bags.Refresh() end end)
    Checkbox(db.bag, "mergeReagent", "Include reagent bag in the one-bag",
        "Shows the reagent bag's slots inside the combined bag instead of as a separate window. Takes effect out of combat.",
        function() if ns.Bags then ns.Bags.RefreshLayout() end end)
    Checkbox(db.bag, "tintReagent", "Tint reagent slots pink",
        "A faint pink wash over the reagent bag's slots, so you can tell them from the normal ones.",
        function() if ns.Bags then ns.Bags.RefreshLayout() end end)
    layout:AddInitializer(CreateSettingsButtonInitializer("Reset bag position", RESET, function()
        db.bag.point, db.bag.relPoint, db.bag.x, db.bag.y = nil, nil, nil, nil
        if ns.Bags then ns.Bags.ResetPosition() end
    end, "Puts the bag back where Blizzard's UI puts it.", false))

    Header("Alt tracking")
    Checkbox(db.tracker, "tooltip", "Show other characters in item tooltips",
        "Hover an item to see which of your other characters has it.")
    Checkbox(db.tracker, "split", "Show where (bags, bank, worn)",
        "Adds the per-location split after each character's total.")

    Header("Errors")
    Checkbox(db.errors, "keep", "Keep an error log",
        "Records Lua errors from LuzennaForever (last 20) and shows a red dot on the minimap button. Open them with /luz errors. Other addons' errors are not recorded.")
    layout:AddInitializer(CreateSettingsButtonInitializer("Show errors", "Show", function()
        ns.Errors.Show()
    end, "Opens the error window.", false))

    Header("Minimap button")
    Checkbox(db.minimap, "hide", "Hide the minimap button",
        "You can still open this page with /luz.",
        function() ns.UpdateMinimapButton() end)


    Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
    if ns.category then Settings.OpenToCategory(ns.category:GetID()) end
end

---------------------------------------------------------------------------
-- Minimap button: left click opens the settings, drag to move it around the
-- minimap's edge.
---------------------------------------------------------------------------

local button

local function PlaceButton()
    local angle = math.rad(ns.db.minimap.angle)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.UpdateMinimapButton()
    if not button then return end
    button:SetShown(not ns.db.minimap.hide)
end

local function CreateMinimapButton()
    button = CreateFrame("Button", "LuzennaForeverMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08") -- the one thing to change to re-skin the button
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    -- A red dot while there are errors you haven't looked at.
    local badge = button:CreateTexture(nil, "OVERLAY", nil, 2)
    badge:SetTexture("Interface\\Buttons\\WHITE8X8")
    badge:SetVertexColor(1, 0.1, 0.1)
    badge:SetSize(8, 8)
    badge:SetPoint("TOPRIGHT", -4, -4)
    badge:Hide()
    local badgeMask = button:CreateMaskTexture()
    badgeMask:SetAtlas("CircleMask")
    badgeMask:SetAllPoints(badge)
    badge:AddMaskTexture(badgeMask)
    function ns.SetErrorBadge(on) badge:SetShown(on and true or false) end

    button:SetScript("OnClick", ns.OpenSettings)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("LuzennaForever")
        GameTooltip:AddLine("Click: settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            PlaceButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    PlaceButton()
    ns.UpdateMinimapButton()
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

SLASH_LUZENNAFOREVER1 = "/luz"
SlashCmdList.LUZENNAFOREVER = function(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    if command == "forget" and rest ~= "" and ns.Tracker then
        ns.Tracker.Forget(rest)
    elseif command == "sort" and ns.Bags then
        ns.Bags.Sort()
    elseif command == "errors" then
        ns.Errors.Command(rest)
    else
        ns.OpenSettings()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        LuzennaForeverDB = LuzennaForeverDB or {}
        Merge(LuzennaForeverDB, ns.defaults)
        ns.db = LuzennaForeverDB
        ns.db.diag = nil -- left by the old /luz diag command
        ns.Errors.Init()
        RegisterSettings()
        CreateMinimapButton()
    elseif event == "PLAYER_LOGIN" then
        ns.Errors.OnLogin()
        if ns.Bags then ns.Bags.Init() end
        if ns.Tracker then ns.Tracker.Init() end
    end
end)
