-- Warrior reactive-ability warnings: a pop-up with a sound when Overpower or Revenge
-- becomes usable. Both only light up after a dodge, parry or block, so "usable" is the
-- proc. This reads spell usability, not auras, which the game hides from addons in combat.

local ADDON_NAME, ns = ...
local Procs = {}
ns.Procs = Procs

local issecretvalue = issecretvalue or function() return false end

-- Rank 1 ids; the spell's name is what is asked about, so the highest known rank is used.
local SPELLS = {
    { key = "overpower", id = 7384, text = "OVERPOWER!" },
    { key = "revenge",   id = 6572, text = "REVENGE!" },
}

local frame
local state = {}   -- [key] = true while the ability is up
local ticker = 0

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id) or nil
end

-- True when the reactive condition is met. Not enough rage still counts: the proc is the
-- window, and the pop-up should tell you to get rage, not stay silent.
local function IsUp(name)
    local usable, noPower
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noPower = C_Spell.IsSpellUsable(name)
    elseif IsUsableSpell then
        usable, noPower = IsUsableSpell(name)
    end
    if issecretvalue(usable) or issecretvalue(noPower) then return false end
    return (usable or noPower) and true or false
end

local function Position()
    local p = ns.db.procs
    frame:ClearAllPoints()
    frame:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 140)
end

local function Create()
    frame = CreateFrame("Frame", "LuzennaForeverProcFrame", UIParent)
    frame:SetSize(260, 64)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(56, 56)
    frame.icon:SetPoint("LEFT", 4, 0)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 10, 0)
    frame.text:SetTextColor(1, 0.82, 0)

    -- Shift-drag to move it; the position is kept.
    frame:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p = ns.db.procs
        p.point, p.relPoint, p.x, p.y = select(1, self:GetPoint()), select(3, self:GetPoint()), select(4, self:GetPoint()), select(5, self:GetPoint())
    end)
    Position()
end

local function Show(spell)
    frame.icon:SetTexture(SpellIcon(spell.id))
    frame.text:SetText(spell.text)
    frame:Show()
end

local function Check()
    local p = ns.db.procs
    local shown
    for _, spell in ipairs(SPELLS) do
        local name = p[spell.key] and SpellName(spell.id)
        local up = name and IsUp(name) or false
        if up and not state[spell.key] and p.sound then
            PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
        end
        state[spell.key] = up
        if up and not shown then
            shown = spell
            Show(spell)
        end
    end
    if not shown and not frame.testing then frame:Hide() end
end

function Procs.Test()
    if not frame then return end
    frame.testing = true
    Show(SPELLS[1])
    if ns.db.procs.sound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master") end
    C_Timer.After(4, function() frame.testing = false end)
    print("|cff66ccffLuzennaForever|r: pop-up test. Shift-drag the pop-up to move it.")
end

function Procs.Refresh()
    if frame and not ns.db.procs.enabled then frame:Hide() end
end

function Procs.Init()
    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then return end
    Create()
    frame:SetScript("OnUpdate", nil)
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function(_, elapsed)
        ticker = ticker + elapsed
        if ticker < 0.1 then return end
        ticker = 0
        if ns.db.procs.enabled then Check() end
    end)
end
