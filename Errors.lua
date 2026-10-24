-- Small error log for LuzennaForever: catches Lua errors that come from this
-- addon, keeps the last MAX in LuzennaForeverDB.errors.list (readable from the
-- SavedVariables file after a /reload), prints a one-line notice in chat, puts
-- a red dot on the minimap button, and shows them in a copyable window
-- (/luz errors). It wraps the current error handler rather than replacing it,
-- so BugSack and the game's own error frame keep working.

local ADDON_NAME, ns = ...
local Errors = {}
ns.Errors = Errors

local MAX = 20
local NEEDLE = "LuzennaForever"

local buffer = {}   -- errors caught before the saved variables were loaded
local unseen = false
local previous, handling
local window

local function Store()
    return ns.db and ns.db.errors
end

local function Badge()
    if ns.SetErrorBadge then ns.SetErrorBadge(unseen) end
end

local function Record(message, stack)
    local entry = {
        message = message,
        stack = stack,
        time = date("%Y-%m-%d %H:%M:%S"),
        count = 1,
        build = (select(4, GetBuildInfo())),
        version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?",
    }
    local store = Store()
    local list = store and store.list or buffer
    local last = list[#list]
    if last and last.message == message and last.stack == stack then
        last.count = last.count + 1
        last.time = entry.time
    else
        list[#list + 1] = entry
        while #list > MAX do table.remove(list, 1) end
        print("|cffff5555LuzennaForever:|r a Lua error was caught. Type |cffffff00/luz errors|r to see it.")
    end
    unseen = true
    Badge()
    if window and window:IsShown() then Errors.Refresh() end
end

local function Handler(message)
    if not handling then
        handling = true
        local ok = pcall(function()
            local store = Store()
            if store and store.keep == false then return end
            local text = tostring(message)
            local stack = debugstack and debugstack(3) or ""
            if text:find(NEEDLE, 1, true) or stack:find(NEEDLE, 1, true) then
                Record(text, stack)
            end
        end)
        handling = false
        if not ok then -- never let the logger itself raise
            handling = false
        end
    end
    if previous then return previous(message) end
end

-- Wraps whatever handler is current. Called now, and again at login in case
-- another addon (BugGrabber) installed its own after us.
local function Install()
    local current = geterrorhandler()
    if current == Handler then return end
    previous = current
    seterrorhandler(Handler)
end

Install()

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function FormatAll()
    local store = Store()
    local list = store and store.list or {}
    if #list == 0 then return "No errors recorded." end
    local lines = {}
    for i = #list, 1, -1 do -- newest first
        local e = list[i]
        lines[#lines + 1] = ("[%s] x%d  (v%s, build %s)\n%s\n%s\n"):format(
            e.time or "?", e.count or 1, e.version or "?", e.build or "?", e.message or "", e.stack or "")
    end
    return table.concat(lines, "\n----------------------------------------\n")
end

function Errors.Refresh()
    if not window then return end
    window.edit:SetText(FormatAll())
    window.edit:SetCursorPosition(0)
end

local function CreateWindow()
    window = CreateFrame("Frame", "LuzennaForeverErrorWindow", UIParent, "BackdropTemplate")
    window:SetSize(640, 400)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("LuzennaForever errors")

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local scroll = CreateFrame("ScrollFrame", "LuzennaForeverErrorScroll", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -42)
    scroll:SetPoint("BOTTOMRIGHT", -36, 44)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(570)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    -- Read-only: whatever is typed is put back, so the text can be selected and copied.
    edit:SetScript("OnTextChanged", function(self, user)
        if user then Errors.Refresh() end
    end)
    scroll:SetScrollChild(edit)
    window.edit = edit

    local function Button(text, anchorPoint, x, onClick)
        local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        b:SetSize(100, 22)
        b:SetPoint(anchorPoint, x, 14)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    Button("Clear", "BOTTOMLEFT", 20, function() Errors.Clear() end)
    Button("Close", "BOTTOMRIGHT", -20, function() window:Hide() end)

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("BOTTOM", 0, 18)
    hint:SetText("Click in the text, Ctrl+A, Ctrl+C to copy")

    tinsert(UISpecialFrames, "LuzennaForeverErrorWindow")
    window:Hide()
end

function Errors.Show()
    if not window then CreateWindow() end
    Errors.Refresh()
    window:Show()
    unseen = false
    Badge()
end

function Errors.Clear()
    local store = Store()
    if store then wipe(store.list) end
    unseen = false
    Badge()
    Errors.Refresh()
end

---------------------------------------------------------------------------
-- Init (called by Core once the saved variables are loaded)
---------------------------------------------------------------------------

function Errors.Init()
    local store = ns.db.errors
    -- Errors caught while loading come in first.
    for _, entry in ipairs(buffer) do store.list[#store.list + 1] = entry end
    wipe(buffer)
    while #store.list > MAX do table.remove(store.list, 1) end
    unseen = #store.list > 0 and unseen
    Badge()
end

function Errors.OnLogin()
    Install()
end

function Errors.Command(arg)
    if arg == "clear" then
        Errors.Clear()
        print("|cff00ccffLuzennaForever:|r error log cleared.")
    else
        Errors.Show()
    end
end
