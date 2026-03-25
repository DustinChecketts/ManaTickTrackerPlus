-- ManaTickTrackerPlus - A lightweight WoW addon to track the five-second rule countdown and mana regeneration ticks.

local ManaTickTrackerPlus = {
    lastManaUseTime = 0,
    mp5Delay = 5,  -- 5-second rule delay
    previousMana = UnitPower("player", 0),
    lastTickTime = GetTime(),
    tickStartTime = GetTime(),
    powerRegenTime = 2  -- Default mana tick interval
}

local anchorFrame = PlayerFrameManaBar or StatusTrackingBarManager or UIParent
local ManaTickTrackerPlusFrame = CreateFrame("Frame", "ManaTickTrackerPlusFrame", anchorFrame)
ManaTickTrackerPlusFrame:SetFrameStrata("HIGH")

-- FSR Countdown Spark (Right to Left)
local fsrSpark = ManaTickTrackerPlusFrame:CreateTexture(nil, "OVERLAY")
fsrSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
fsrSpark:SetBlendMode("ADD")
fsrSpark:SetSize(16, 32)
fsrSpark:Hide()

-- Tick Regen Spark (Left to Right)
local regenSpark = ManaTickTrackerPlusFrame:CreateTexture(nil, "OVERLAY")
regenSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
regenSpark:SetBlendMode("ADD")
regenSpark:SetSize(16, 32)
regenSpark:Hide()

-- Mana Gain Text
local manaGainText = ManaTickTrackerPlusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
manaGainText:SetPoint("LEFT", anchorFrame, "RIGHT", 5, -2)
manaGainText:SetText("")
manaGainText:SetTextColor(0.4, 0.8, 1, 1)
manaGainText:Hide()

-- Function to calculate expected regen per tick using Blizzard API
local function CalculateExpectedRegen()
    local mp5Casting, mp5NotCasting = GetManaRegen()
    return math.floor((mp5NotCasting / 5) * 2 + 0.5)
end

-- Function to update FSR countdown spark
function ManaTickTrackerPlus:UpdateFSRSpark()
    local now = GetTime()
    if now < self.lastManaUseTime + self.mp5Delay then
        local progress = (now - self.lastManaUseTime) / self.mp5Delay
        fsrSpark:SetPoint("CENTER", PlayerFrameManaBar, "LEFT", PlayerFrameManaBar:GetWidth() * (1 - progress), 0)
        fsrSpark:Show()
    else
        fsrSpark:Hide()
    end
end

-- Function to update Tick Spark
function ManaTickTrackerPlus:UpdateTickSpark()
    if fsrSpark:IsShown() then
        regenSpark:Hide()
        return
    end
    
    local now = GetTime()
    local barWidth = PlayerFrameManaBar:GetWidth()
    local progress = (now - self.tickStartTime) / self.powerRegenTime
    if progress <= 1 and UnitPower("player", 0) < UnitPowerMax("player") then
        regenSpark:SetPoint("CENTER", PlayerFrameManaBar, "LEFT", barWidth * progress, 0)
        regenSpark:Show()
    else
        regenSpark:Hide()
        self.tickStartTime = now
    end
end

-- Event handler function
local function OnEvent(self, event, arg1, arg2)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        local costInfo = GetSpellPowerCost(arg2)
        local spentMana = false
        if costInfo then
            for _, cost in pairs(costInfo) do
                if cost.type == 0 and cost.cost > 0 then
                    spentMana = true
                    break
                end
            end
        end
        if spentMana then
            ManaTickTrackerPlus.lastManaUseTime = GetTime()
        end
    elseif event == "UNIT_POWER_UPDATE" and arg1 == "player" then
        local currentMana = UnitPower("player", 0)
        local manaGained = currentMana - ManaTickTrackerPlus.previousMana
        if manaGained < 0 then
            ManaTickTrackerPlus.lastManaUseTime = GetTime()
        end

        ManaTickTrackerPlus.previousMana = currentMana
        
        if manaGained ~= 0 then
            local expectedRegen = CalculateExpectedRegen()
            if manaGained > 0 and manaGained >= expectedRegen * 0.9 then
                ManaTickTrackerPlus.tickStartTime = GetTime()
            end
            if manaGained > 0 then
                manaGainText:SetText("|cff66ccff+" .. manaGained .. "|r")
            else
                manaGainText:SetText("|cff9933ff" .. manaGained .. "|r")
            end
            manaGainText:SetAlpha(1)
            manaGainText:Show()
            C_Timer.After(0.5, function()
                local fadeOutTime = 1.0
                local fadeStep = 0.1
                local fadeTicker = C_Timer.NewTicker(fadeOutTime / (1 / fadeStep), function()
                    local alpha = manaGainText:GetAlpha() - fadeStep
                    if alpha <= 0 then
                        manaGainText:Hide()
                    else
                        manaGainText:SetAlpha(alpha)
                    end
                end, 1 / fadeStep)
            end)
        end
    end
end

-- Register events
ManaTickTrackerPlusFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
ManaTickTrackerPlusFrame:RegisterEvent("UNIT_POWER_UPDATE")
ManaTickTrackerPlusFrame:SetScript("OnEvent", OnEvent)
ManaTickTrackerPlusFrame:SetScript("OnUpdate", function()
    ManaTickTrackerPlus:UpdateFSRSpark()
    ManaTickTrackerPlus:UpdateTickSpark()
end)
