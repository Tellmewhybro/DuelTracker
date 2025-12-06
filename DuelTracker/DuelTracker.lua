--[[
    DuelTracker - Dynamic Duel Stats
    WoW 3.3.5a (Warmane)
    
    Features:
    - Target a player → Shows duel history
    - Untarget → Frame disappears
    - Modern colorful design
    - Rival detection
    - Persistent stats (saved forever)
]]

local DT = CreateFrame("Frame", "DuelTracker")
DuelTrackerDB = DuelTrackerDB or {}

-- State variables (declared early for proper scope)
local pendingDuelTarget = nil  -- Who we sent duel request to
local pendingDuelClass = nil
local activeDuelTarget = nil   -- Who we're actively dueling
local activeDuelClass = nil
local myName = nil
local duelInProgress = false
local duelPending = false
local lastDuelTarget = nil
local lastDuelResult = nil
local duelAttemptFailed = false  -- Flag to catch failed duel attempts
local UpdateDisplay  -- Forward declaration

-- Animation state variables
local animationTime = 0
local duelStartTime = 0
local pendingStartTime = 0
local dotCount = 1  -- For animated dots

-- Zone restriction (only works in The Ruby Sanctum)
local DUEL_ZONE = "The Ruby Sanctum"
local isInDuelZone = false

local function CheckDuelZone()
    local zone = GetRealZoneText()
    isInDuelZone = (zone == DUEL_ZONE)
    return isInDuelZone
end

-- ============================================================
-- COLOR PALETTE (Modern/Vibrant)
-- ============================================================
local COLORS = {
    bg = {0.08, 0.08, 0.12, 0.95},
    border = {0.3, 0.8, 1, 1},
    title = {0, 1, 1},
    win = {0.2, 1, 0.4},
    loss = {1, 0.3, 0.3},
    tie = {1, 1, 0.4},
    rival = {1, 0.4, 0.8},
    newPlayer = {0.6, 0.6, 0.6},
    accent = {0.4, 0.8, 1},
}

-- Class colors
local CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43},
    PALADIN = {0.96, 0.55, 0.73},
    HUNTER = {0.67, 0.83, 0.45},
    ROGUE = {1, 0.96, 0.41},
    PRIEST = {1, 1, 1},
    DEATHKNIGHT = {0.77, 0.12, 0.23},
    SHAMAN = {0, 0.44, 0.87},
    MAGE = {0.41, 0.80, 0.94},
    WARLOCK = {0.58, 0.51, 0.79},
    DRUID = {1, 0.49, 0.04},
}

-- ============================================================
-- MAIN DISPLAY FRAME (Modern Design)
-- ============================================================
local mainFrame = CreateFrame("Frame", "DT_MainFrame", UIParent)
mainFrame:SetWidth(220)
mainFrame:SetHeight(145)
mainFrame:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
mainFrame:SetFrameStrata("HIGH")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Background with gradient effect
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
mainFrame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4])
mainFrame:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
mainFrame:Hide()

-- Glow border effect (inner frame)
local glowFrame = CreateFrame("Frame", nil, mainFrame)
glowFrame:SetPoint("TOPLEFT", 3, -3)
glowFrame:SetPoint("BOTTOMRIGHT", -3, 3)
glowFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
glowFrame:SetBackdropColor(0, 0, 0, 0)
glowFrame:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.5)

-- Title Bar
local titleBar = mainFrame:CreateTexture(nil, "ARTWORK")
titleBar:SetPoint("TOPLEFT", 4, -4)
titleBar:SetPoint("TOPRIGHT", -4, -4)
titleBar:SetHeight(22)
titleBar:SetTexture("Interface\\Buttons\\WHITE8x8")
titleBar:SetGradientAlpha("HORIZONTAL", 0.1, 0.4, 0.5, 0.8, 0.05, 0.2, 0.3, 0.4)

-- Icon
local icon = mainFrame:CreateTexture(nil, "OVERLAY")
icon:SetPoint("TOPLEFT", 8, -6)
icon:SetWidth(18)
icon:SetHeight(18)
icon:SetTexture("Interface\\Icons\\Achievement_Arena_2v2_7")

-- Title Text
local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
titleText:SetTextColor(COLORS.title[1], COLORS.title[2], COLORS.title[3])
titleText:SetText("DUEL STATS")

-- Player Name
local playerName = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
playerName:SetPoint("TOP", 0, -30)
playerName:SetWidth(200)
playerName:SetTextColor(1, 1, 1)
playerName:SetText("")

-- Player Class Icon
local classIcon = mainFrame:CreateTexture(nil, "OVERLAY")
classIcon:SetPoint("RIGHT", playerName, "LEFT", -4, 0)
classIcon:SetWidth(20)
classIcon:SetHeight(20)
classIcon:Hide()

-- Stats Container
local statsFrame = CreateFrame("Frame", nil, mainFrame)
statsFrame:SetPoint("TOP", playerName, "BOTTOM", 0, -8)
statsFrame:SetWidth(200)
statsFrame:SetHeight(50)

-- Win Box
local winBox = CreateFrame("Frame", nil, statsFrame)
winBox:SetWidth(60)
winBox:SetHeight(45)
winBox:SetPoint("LEFT", statsFrame, "LEFT", 10, 0)
winBox:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
winBox:SetBackdropColor(0.1, 0.3, 0.15, 0.8)
winBox:SetBackdropBorderColor(COLORS.win[1], COLORS.win[2], COLORS.win[3], 0.8)

local winLabel = winBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
winLabel:SetPoint("TOP", 0, -4)
winLabel:SetTextColor(0.7, 0.7, 0.7)
winLabel:SetText("WINS")

local winCount = winBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
winCount:SetPoint("CENTER", 0, -4)
winCount:SetTextColor(COLORS.win[1], COLORS.win[2], COLORS.win[3])
winCount:SetText("0")

-- VS Text
local vsText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
vsText:SetPoint("CENTER", 0, 0)
vsText:SetTextColor(0.5, 0.5, 0.5)
vsText:SetText("VS")

-- Loss Box
local lossBox = CreateFrame("Frame", nil, statsFrame)
lossBox:SetWidth(60)
lossBox:SetHeight(45)
lossBox:SetPoint("RIGHT", statsFrame, "RIGHT", -10, 0)
lossBox:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
lossBox:SetBackdropColor(0.3, 0.1, 0.1, 0.8)
lossBox:SetBackdropBorderColor(COLORS.loss[1], COLORS.loss[2], COLORS.loss[3], 0.8)

local lossLabel = lossBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lossLabel:SetPoint("TOP", 0, -4)
lossLabel:SetTextColor(0.7, 0.7, 0.7)
lossLabel:SetText("LOSSES")

local lossCount = lossBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
lossCount:SetPoint("CENTER", 0, -4)
lossCount:SetTextColor(COLORS.loss[1], COLORS.loss[2], COLORS.loss[3])
lossCount:SetText("0")

-- Status Text (Rival/First Time/etc)
local statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("BOTTOM", 0, 28)
statusText:SetWidth(200)
statusText:SetTextColor(1, 1, 1)
statusText:SetText("")

-- Modern Share Button (top right corner)
local shareButton = CreateFrame("Button", nil, mainFrame)
shareButton:SetWidth(45)
shareButton:SetHeight(16)
shareButton:SetPoint("TOPRIGHT", -8, -6)

-- Button background
local shareBg = shareButton:CreateTexture(nil, "BACKGROUND")
shareBg:SetAllPoints()
shareBg:SetTexture("Interface\\Buttons\\WHITE8x8")
shareBg:SetVertexColor(0.2, 0.6, 0.8, 0.7)

-- Button border
shareButton:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
shareButton:SetBackdropBorderColor(0.4, 0.8, 1, 0.8)

-- Button text
local shareText = shareButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
shareText:SetPoint("CENTER", 0, 0)
shareText:SetTextColor(1, 1, 1)
shareText:SetText("Share")

-- Hover effects
shareButton:SetScript("OnEnter", function(self)
    shareBg:SetVertexColor(0.3, 0.7, 0.9, 1)
end)
shareButton:SetScript("OnLeave", function(self)
    shareBg:SetVertexColor(0.2, 0.6, 0.8, 0.7)
end)
shareButton:Hide()

-- DUEL Button (Green)
local duelButton = CreateFrame("Button", nil, mainFrame)
duelButton:SetWidth(50)
duelButton:SetHeight(18)
duelButton:SetPoint("BOTTOM", 0, 8)

local duelBg = duelButton:CreateTexture(nil, "BACKGROUND")
duelBg:SetAllPoints()
duelBg:SetTexture("Interface\\Buttons\\WHITE8x8")
duelBg:SetVertexColor(0.2, 0.7, 0.3, 0.8)

duelButton:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
duelButton:SetBackdropBorderColor(0.3, 0.9, 0.4, 1)

local duelText = duelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
duelText:SetPoint("CENTER", 0, 0)
duelText:SetTextColor(1, 1, 1)
duelText:SetText("Duel")

duelButton:SetScript("OnEnter", function(self)
    duelBg:SetVertexColor(0.3, 0.8, 0.4, 1)
end)
duelButton:SetScript("OnLeave", function(self)
    duelBg:SetVertexColor(0.2, 0.7, 0.3, 0.8)
end)
-- Simple timer for delayed updates
local updateTimer = CreateFrame("Frame")
updateTimer.elapsed = 0
updateTimer.pending = false
updateTimer.attemptTarget = nil
updateTimer.attemptClass = nil
updateTimer:SetScript("OnUpdate", function(self, delta)
    if self.pending then
        self.elapsed = self.elapsed + delta
        if self.elapsed >= 0.15 then
            self.pending = false
            self.elapsed = 0
            -- Only set pending if no error was detected
            if self.attemptTarget and not duelAttemptFailed then
                pendingDuelTarget = self.attemptTarget
                pendingDuelClass = self.attemptClass
                duelPending = true
                pendingStartTime = GetTime()  -- Start timer for waiting display
            end
            self.attemptTarget = nil
            self.attemptClass = nil
            duelAttemptFailed = false
            UpdateDisplay()
        end
    end
end)

duelButton:SetScript("OnClick", function()
    if UnitExists("target") and UnitIsPlayer("target") then
        -- Don't set pending immediately - wait to see if error fires
        updateTimer.attemptTarget = UnitName("target")
        local _, class = UnitClass("target")
        updateTimer.attemptClass = class
        duelAttemptFailed = false
        StartDuel("target")
        -- Trigger delayed UI update (gives time for error to fire)
        updateTimer.pending = true
        updateTimer.elapsed = 0
    end
end)
duelButton:Hide()

-- CANCEL Button (Orange) - for canceling pending duel
local cancelButton = CreateFrame("Button", nil, mainFrame)
cancelButton:SetWidth(55)
cancelButton:SetHeight(18)
cancelButton:SetPoint("BOTTOMRIGHT", -12, 8)

local cancelBg = cancelButton:CreateTexture(nil, "BACKGROUND")
cancelBg:SetAllPoints()
cancelBg:SetTexture("Interface\\Buttons\\WHITE8x8")
cancelBg:SetVertexColor(0.8, 0.5, 0.1, 0.8)

cancelButton:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
cancelButton:SetBackdropBorderColor(1, 0.6, 0.2, 1)

local cancelText = cancelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cancelText:SetPoint("CENTER", 0, 0)
cancelText:SetTextColor(1, 1, 1)
cancelText:SetText("Cancel")

cancelButton:SetScript("OnEnter", function(self)
    cancelBg:SetVertexColor(0.9, 0.6, 0.2, 1)
end)
cancelButton:SetScript("OnLeave", function(self)
    cancelBg:SetVertexColor(0.8, 0.5, 0.1, 0.8)
end)
cancelButton:SetScript("OnClick", function()
    CancelDuel()
    duelPending = false
    pendingDuelTarget = nil
    pendingDuelClass = nil
    -- Trigger delayed UI update
    updateTimer.pending = true
    updateTimer.elapsed = 0
end)
cancelButton:Hide()

-- FORFEIT Button (Red) - for surrendering during duel
local forfeitButton = CreateFrame("Button", nil, mainFrame)
forfeitButton:SetWidth(70)
forfeitButton:SetHeight(18)
forfeitButton:SetPoint("BOTTOM", 0, 8)

local forfeitBg = forfeitButton:CreateTexture(nil, "BACKGROUND")
forfeitBg:SetAllPoints()
forfeitBg:SetTexture("Interface\\Buttons\\WHITE8x8")
forfeitBg:SetVertexColor(0.7, 0.2, 0.2, 0.8)

forfeitButton:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
forfeitButton:SetBackdropBorderColor(0.9, 0.3, 0.3, 1)

local forfeitText = forfeitButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
forfeitText:SetPoint("CENTER", 0, 0)
forfeitText:SetTextColor(1, 1, 1)
forfeitText:SetText("Forfeit")

forfeitButton:SetScript("OnEnter", function(self)
    forfeitBg:SetVertexColor(0.8, 0.3, 0.3, 1)
end)
forfeitButton:SetScript("OnLeave", function(self)
    forfeitBg:SetVertexColor(0.7, 0.2, 0.2, 0.8)
end)
forfeitButton:SetScript("OnClick", function()
    -- Forfeit the duel by running away or /forfeit
    DoEmote("forfeit")
end)
forfeitButton:Hide()

-- ============================================================
-- DUEL STATE VISUAL ELEMENTS (Enhanced)
-- ============================================================

-- Outer glow layers for pulsing effect
local glowLayer1 = CreateFrame("Frame", nil, mainFrame)
glowLayer1:SetPoint("TOPLEFT", -2, 2)
glowLayer1:SetPoint("BOTTOMRIGHT", 2, -2)
glowLayer1:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
})
glowLayer1:SetBackdropBorderColor(1, 0.85, 0, 0)
glowLayer1:Hide()

local glowLayer2 = CreateFrame("Frame", nil, mainFrame)
glowLayer2:SetPoint("TOPLEFT", -4, 4)
glowLayer2:SetPoint("BOTTOMRIGHT", 4, -4)
glowLayer2:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 3,
})
glowLayer2:SetBackdropBorderColor(1, 0.6, 0, 0)
glowLayer2:Hide()

-- "FIGHT!" Header Text (for duel in progress)
local fightText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
fightText:SetPoint("TOP", 0, -32)
fightText:SetTextColor(1, 0.2, 0.2)
fightText:SetText("|cffFFD700FIGHT!|r")
fightText:Hide()

-- Crossed Swords Icon (for duel in progress)
local combatIcon = mainFrame:CreateTexture(nil, "OVERLAY")
combatIcon:SetPoint("LEFT", fightText, "RIGHT", 4, 0)
combatIcon:SetWidth(24)
combatIcon:SetHeight(24)
combatIcon:SetTexture("Interface\\Icons\\Ability_DualWield")
combatIcon:Hide()

-- Elapsed Time Display
local elapsedText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
elapsedText:SetPoint("TOP", playerName, "BOTTOM", 0, -5)
elapsedText:SetTextColor(1, 1, 1)
elapsedText:SetText("00:00")
elapsedText:Hide()

-- Waiting dots text (animated)
local waitingDotsText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
waitingDotsText:SetPoint("TOP", playerName, "BOTTOM", 0, -8)
waitingDotsText:SetTextColor(1, 0.6, 0.2)
waitingDotsText:SetText("Waiting.")
waitingDotsText:Hide()

-- Hourglass icon for waiting
local hourglassIcon = mainFrame:CreateTexture(nil, "OVERLAY")
hourglassIcon:SetPoint("RIGHT", waitingDotsText, "LEFT", -4, 0)
hourglassIcon:SetWidth(20)
hourglassIcon:SetHeight(20)
hourglassIcon:SetTexture("Interface\\Icons\\Spell_Holy_BorrowedTime")
hourglassIcon:Hide()

-- ============================================================
-- ANIMATION SYSTEM
-- ============================================================

local animFrame = CreateFrame("Frame")
animFrame:SetScript("OnUpdate", function(self, delta)
    if not mainFrame:IsShown() then return end
    
    animationTime = animationTime + delta
    
    -- DUEL IN PROGRESS animations
    if duelInProgress then
        -- Fast pulsing gold glow (combat feel)
        local pulse1 = (math.sin(animationTime * 6) + 1) / 2  -- Fast pulse
        local pulse2 = (math.sin(animationTime * 4 + 1) + 1) / 2  -- Offset pulse
        
        glowLayer1:SetBackdropBorderColor(1, 0.85, 0, pulse1 * 0.8)
        glowLayer2:SetBackdropBorderColor(1, 0.5, 0, pulse2 * 0.5)
        glowFrame:SetBackdropBorderColor(1, 0.85, 0, 0.5 + pulse1 * 0.5)
        
        -- FIGHT text pulse
        local fightPulse = 0.8 + (math.sin(animationTime * 8) + 1) * 0.1
        fightText:SetAlpha(fightPulse)
        
        -- Update elapsed time
        local elapsed = GetTime() - duelStartTime
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        elapsedText:SetText(string.format("%02d:%02d", mins, secs))
        
    -- DUEL PENDING animations
    elseif duelPending then
        -- Slower pulsing orange glow
        local pulse = (math.sin(animationTime * 3) + 1) / 2
        
        glowLayer1:SetBackdropBorderColor(1, 0.5, 0, pulse * 0.6)
        glowLayer2:SetBackdropBorderColor(1, 0.3, 0, pulse * 0.4)
        glowFrame:SetBackdropBorderColor(1, 0.6, 0.2, 0.4 + pulse * 0.4)
        
        -- Animated waiting dots
        local dotCycle = math.floor(animationTime * 2) % 3 + 1
        local dots = string.rep(".", dotCycle)
        
        -- Update elapsed waiting time
        local elapsed = GetTime() - pendingStartTime
        local secs = math.floor(elapsed)
        waitingDotsText:SetText("Waiting" .. dots .. " (" .. secs .. "s)")
    end
end)

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

local function GetPlayerKey(name)
    if not name then return nil end
    -- Remove realm name if present
    local shortName = name:match("([^-]+)") or name
    return shortName:lower()
end

local function GetPlayerStats(name)
    local key = GetPlayerKey(name)
    if not key then return nil end
    
    if not DuelTrackerDB.players then
        DuelTrackerDB.players = {}
    end
    
    return DuelTrackerDB.players[key]
end

local function CreatePlayerStats(name, class)
    local key = GetPlayerKey(name)
    if not key then return nil end
    
    if not DuelTrackerDB.players then
        DuelTrackerDB.players = {}
    end
    
    if not DuelTrackerDB.players[key] then
        DuelTrackerDB.players[key] = {
            name = name,
            class = class or "UNKNOWN",
            wins = 0,
            losses = 0,
            lastDuel = time(),
            isRival = false,
        }
    end
    
    return DuelTrackerDB.players[key]
end

local function AddWin(name, class)
    local stats = CreatePlayerStats(name, class)
    if stats then
        stats.wins = stats.wins + 1
        stats.lastDuel = time()
        stats.class = class or stats.class
        -- Check rival status (they beat you 3+ times more)
        if stats.losses >= stats.wins + 3 then
            stats.isRival = true
        end
    end
end

local function AddLoss(name, class)
    local stats = CreatePlayerStats(name, class)
    if stats then
        stats.losses = stats.losses + 1
        stats.lastDuel = time()
        stats.class = class or stats.class
        -- Check rival status
        if stats.losses >= stats.wins + 3 then
            stats.isRival = true
        end
    end
end

local function GetWinRate(wins, losses)
    local total = wins + losses
    if total == 0 then return 0 end
    return (wins / total) * 100
end

-- Share button click handler (defined after functions)
shareButton:SetScript("OnClick", function()
    local targetName = UnitName("target")
    if targetName then
        local stats = GetPlayerStats(targetName)
        if stats then
            local msg = "Duel Stats vs " .. targetName .. ": " .. stats.wins .. " - " .. stats.losses
            if stats.wins > stats.losses then
                msg = msg .. " (I'm winning!)"
            elseif stats.losses > stats.wins then
                msg = msg .. " (He's ahead...)"
            else
                msg = msg .. " (Tied!)"
            end
            SendChatMessage(msg, "SAY")
        else
            SendChatMessage("No duel stats with " .. targetName .. " yet!", "SAY")
        end
    end
end)

-- ============================================================
-- UPDATE DISPLAY
-- ============================================================

UpdateDisplay = function()
    -- Only show in The Ruby Sanctum
    if not isInDuelZone then
        mainFrame:Hide()
        return
    end
    
    -- Check if target is a player
    if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then
        mainFrame:Hide()
        return
    end
    
    -- Check if target is enemy (can duel)
    local targetName = UnitName("target")
    local _, targetClass = UnitClass("target")
    
    if not targetName then
        mainFrame:Hide()
        return
    end
    
    -- Set class color for name
    local classColor = CLASS_COLORS[targetClass] or {1, 1, 1}
    playerName:SetText(targetName)
    playerName:SetTextColor(classColor[1], classColor[2], classColor[3])
    
    -- DUEL IN PROGRESS MODE (actual fighting)
    if duelInProgress and activeDuelTarget == targetName then
        -- Hide normal elements
        winBox:Hide()
        lossBox:Hide()
        vsText:Hide()
        duelButton:Hide()
        cancelButton:Hide()
        statusText:Hide()
        
        -- Hide pending elements
        waitingDotsText:Hide()
        hourglassIcon:Hide()
        
        -- Show in-progress elements
        forfeitButton:Show()
        fightText:Show()
        combatIcon:Show()
        elapsedText:Show()
        glowLayer1:Show()
        glowLayer2:Show()
        
        -- Move player name up a bit
        playerName:SetPoint("TOP", 0, -55)
        
        shareButton:Show()
        mainFrame:Show()
        return
    end
    
    -- DUEL PENDING MODE (waiting for accept/decline)
    if duelPending and pendingDuelTarget == targetName then
        -- Hide normal elements
        winBox:Hide()
        lossBox:Hide()
        vsText:Hide()
        duelButton:Hide()
        forfeitButton:Hide()
        statusText:Hide()
        
        -- Hide in-progress elements
        fightText:Hide()
        combatIcon:Hide()
        elapsedText:Hide()
        
        -- Show pending elements
        cancelButton:Show()
        waitingDotsText:Show()
        hourglassIcon:Show()
        glowLayer1:Show()
        glowLayer2:Show()
        
        -- Reset player name position
        playerName:SetPoint("TOP", 0, -30)
        
        shareButton:Show()
        mainFrame:Show()
        return
    end
    
    -- NORMAL MODE - Show stats
    -- Hide special state elements
    fightText:Hide()
    combatIcon:Hide()
    elapsedText:Hide()
    waitingDotsText:Hide()
    hourglassIcon:Hide()
    glowLayer1:Hide()
    glowLayer2:Hide()
    
    -- Reset player name position
    playerName:SetPoint("TOP", 0, -30)
    
    -- Show normal elements
    winBox:Show()
    lossBox:Show()
    vsText:Show()
    statusText:Show()
    duelButton:Show()
    cancelButton:Hide()
    forfeitButton:Hide()
    
    -- Get or create stats
    local stats = GetPlayerStats(targetName)
    local wins = 0
    local losses = 0
    local isRival = false
    local isNewPlayer = true
    
    if stats then
        wins = stats.wins
        losses = stats.losses
        isRival = stats.isRival
        isNewPlayer = false
    end
    
    -- Update win/loss counts
    winCount:SetText(tostring(wins))
    lossCount:SetText(tostring(losses))
    
    -- Status text
    if lastDuelResult and lastDuelTarget == targetName then
        -- Just finished a duel with this person
        if lastDuelResult == "win" then
            statusText:SetText("|cff66ff66VICTORY!|r |cff99ff99You won!|r")
            glowFrame:SetBackdropBorderColor(COLORS.win[1], COLORS.win[2], COLORS.win[3], 1)
        else
            statusText:SetText("|cffff6666DEFEAT!|r |cffff9999Better luck next time...|r")
            glowFrame:SetBackdropBorderColor(COLORS.loss[1], COLORS.loss[2], COLORS.loss[3], 1)
        end
    elseif isNewPlayer then
        statusText:SetText("|cff999999First encounter!|r")
        glowFrame:SetBackdropBorderColor(COLORS.newPlayer[1], COLORS.newPlayer[2], COLORS.newPlayer[3], 0.5)
    elseif isRival then
        statusText:SetText("|cffff66ccRIVAL!|r |cffff9999Revenge time...|r")
        glowFrame:SetBackdropBorderColor(COLORS.rival[1], COLORS.rival[2], COLORS.rival[3], 0.8)
    elseif wins > losses then
        local diff = wins - losses
        if diff >= 5 then
            statusText:SetText("|cff66ff66EASY TARGET|r |cff99ff99(+" .. diff .. ")|r")
        else
            statusText:SetText("|cff66ff66You're winning!|r |cff99ff99(+" .. diff .. ")|r")
        end
        glowFrame:SetBackdropBorderColor(COLORS.win[1], COLORS.win[2], COLORS.win[3], 0.6)
    elseif losses > wins then
        local diff = losses - wins
        statusText:SetText("|cffff6666He's ahead...|r |cffff9999(-" .. diff .. ")|r")
        glowFrame:SetBackdropBorderColor(COLORS.loss[1], COLORS.loss[2], COLORS.loss[3], 0.6)
    else
        statusText:SetText("|cffffff66Tied!|r |cffffffcc(" .. wins .. " - " .. losses .. ")|r")
        glowFrame:SetBackdropBorderColor(COLORS.tie[1], COLORS.tie[2], COLORS.tie[3], 0.6)
    end
    
    shareButton:Show()  -- Always show share in top right
    mainFrame:Show()
end

-- ============================================================
-- EVENT HANDLING
-- ============================================================

-- (State variables moved to top of file)

DT:RegisterEvent("PLAYER_TARGET_CHANGED")
DT:RegisterEvent("DUEL_REQUESTED")
DT:RegisterEvent("DUEL_FINISHED")
DT:RegisterEvent("CHAT_MSG_SYSTEM")
DT:RegisterEvent("UI_ERROR_MESSAGE")
DT:RegisterEvent("PLAYER_ENTERING_WORLD")
DT:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Combat start (for duel detection)
DT:RegisterEvent("ZONE_CHANGED_NEW_AREA")  -- Zone change detection

DT:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        -- Clear last duel result when targeting someone else
        local targetName = UnitName("target")
        if targetName ~= lastDuelTarget then
            lastDuelResult = nil
        end
        UpdateDisplay()
        
    elseif event == "DUEL_REQUESTED" then
        -- Someone requested US to duel (not when we request them)
        local requester = UnitName("target")
        if UnitExists("target") and UnitIsPlayer("target") then
            pendingDuelTarget = requester
            local _, class = UnitClass("target")
            pendingDuelClass = class
            duelPending = true
            duelInProgress = false
            lastDuelResult = nil
            pendingStartTime = GetTime()  -- Start timer for waiting display
            UpdateDisplay()
        end
        
    elseif event == "DUEL_FINISHED" then
        -- Duel ended (finished, cancelled, or declined)
        duelInProgress = false
        duelPending = false
        activeDuelTarget = nil
        activeDuelClass = nil
        pendingDuelTarget = nil
        pendingDuelClass = nil
        UpdateDisplay()
    
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat started - if we have pending duel (and not already in progress), it means duel started
        if duelPending and pendingDuelTarget and not duelInProgress then
            duelPending = false
            duelInProgress = true
            duelStartTime = GetTime()
            activeDuelTarget = pendingDuelTarget
            activeDuelClass = pendingDuelClass
            pendingDuelTarget = nil
            pendingDuelClass = nil
            UpdateDisplay()
        end
    
    elseif event == "UI_ERROR_MESSAGE" then
        -- Catch error messages like "can't duel", "target is in combat", "out of range"
        -- Only cancel if we're NOT in an active duel (these errors happen during combat too)
        if not duelInProgress then
            local msg = ...
            if msg then
                local msgLower = msg:lower()
                if msgLower:find("duel") or msgLower:find("in combat") or msgLower:find("out of range") or msgLower:find("too far") then
                    -- Mark that the duel attempt failed (before timer fires)
                    duelAttemptFailed = true
                    duelPending = false
                    pendingDuelTarget = nil
                    pendingDuelClass = nil
                    UpdateDisplay()
                end
            end
        end
        
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        if not msg then return end
        
        -- Get my name fresh
        myName = UnitName("player")
        if not myName then return end
        
        -- Convert to lowercase for easier matching
        local msgLower = msg:lower()
        
        -- Detect duel countdown (duel is starting) - "Duel starting: 3" or similar
        -- Only trigger once (on first countdown message)
        if msgLower:find("duel starting") and not duelInProgress then
            duelPending = false
            duelInProgress = true
            duelStartTime = GetTime()  -- Start elapsed time counter
            -- Transfer pending target to active target (if we have one)
            if pendingDuelTarget then
                activeDuelTarget = pendingDuelTarget
                activeDuelClass = pendingDuelClass
                pendingDuelTarget = nil
                pendingDuelClass = nil
            elseif UnitExists("target") and UnitIsPlayer("target") then
                -- Fallback: use current target
                activeDuelTarget = UnitName("target")
                local _, class = UnitClass("target")
                activeDuelClass = class
            end
            UpdateDisplay()
            return
        end
        
        -- Detect duel declined/cancelled/failed (only when not already fighting)
        if not duelInProgress and (
           msgLower:find("declined") or msgLower:find("cancelled") or
           msgLower:find("too far") or msgLower:find("out of range") or
           msgLower:find("can't duel") or msgLower:find("cannot duel") or
           msgLower:find("not in line of sight") or msgLower:find("no target")
        ) then
            duelPending = false
            pendingDuelTarget = nil
            pendingDuelClass = nil
            UpdateDisplay()
            return
        end
        
        -- Detect flee during duel (ends the duel)
        if duelInProgress and (msgLower:find("has fled") or msgLower:find("flee from the duel")) then
            duelPending = false
            duelInProgress = false
            pendingDuelTarget = nil
            pendingDuelClass = nil
            activeDuelTarget = nil
            activeDuelClass = nil
            UpdateDisplay()
            return
        end
        
        -- Detect duel winner (duel ended)
        local winner, loser = msg:match("(.+) has defeated (.+) in a duel")
        
        if winner and loser then
            -- Remove realm names if present
            winner = winner:match("([^-]+)") or winner
            loser = loser:match("([^-]+)") or loser
            
            -- ONLY process if I am the winner or loser (ignore other people's duels)
            local iAmWinner = (winner == myName)
            local iAmLoser = (loser == myName)
            
            if iAmWinner then
                -- I won! Now we can reset duel state
                duelPending = false
                duelInProgress = false
                AddWin(loser, activeDuelClass)
                lastDuelTarget = loser
                lastDuelResult = "win"
                DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFDuelTracker:|r |cff66ff66YOU WON|r vs |cffffffff" .. loser .. "|r!")
                activeDuelTarget = nil
                activeDuelClass = nil
                UpdateDisplay()
            elseif iAmLoser then
                -- I lost! Now we can reset duel state
                duelPending = false
                duelInProgress = false
                AddLoss(winner, activeDuelClass)
                lastDuelTarget = winner
                lastDuelResult = "loss"
                DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFDuelTracker:|r |cffff6666YOU LOST|r vs |cffffffff" .. winner .. "|r")
                activeDuelTarget = nil
                activeDuelClass = nil
                UpdateDisplay()
            end
            -- If neither, ignore completely (someone else's duel)
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        myName = UnitName("player")
        -- Check zone
        CheckDuelZone()
        -- Initialize saved variables
        if not DuelTrackerDB.players then
            DuelTrackerDB.players = {}
        end
        if not DuelTrackerDB.totalWins then
            DuelTrackerDB.totalWins = 0
        end
        if not DuelTrackerDB.totalLosses then
            DuelTrackerDB.totalLosses = 0
        end
    
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Check if we entered/left the duel zone
        local wasInZone = isInDuelZone
        CheckDuelZone()
        if wasInZone ~= isInDuelZone then
            UpdateDisplay()
            if isInDuelZone then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFDuelTracker:|r |cff66ff66Entered duel zone!|r")
            end
        end
    end
end)

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

SLASH_DUELTRACKER1 = "/duel"
SLASH_DUELTRACKER2 = "/dt"
SlashCmdList["DUELTRACKER"] = function(msg)
    msg = msg:lower()
    
    if msg == "stats" or msg == "" then
        -- Show overall stats
        local totalWins = 0
        local totalLosses = 0
        local rivalCount = 0
        
        if DuelTrackerDB.players then
            for _, stats in pairs(DuelTrackerDB.players) do
                totalWins = totalWins + stats.wins
                totalLosses = totalLosses + stats.losses
                if stats.isRival then
                    rivalCount = rivalCount + 1
                end
            end
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== DUEL TRACKER STATS ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ff66Wins:|r " .. totalWins)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6666Losses:|r " .. totalLosses)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff66ccRivals:|r " .. rivalCount)
        DEFAULT_CHAT_FRAME:AddMessage("Win Rate: |cffffff00" .. string.format("%.1f", GetWinRate(totalWins, totalLosses)) .. "%|r")
        
    elseif msg == "rivals" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== YOUR RIVALS ===|r")
        local found = false
        if DuelTrackerDB.players then
            for _, stats in pairs(DuelTrackerDB.players) do
                if stats.isRival then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff66cc" .. stats.name .. "|r - " .. stats.wins .. "W / " .. stats.losses .. "L")
                    found = true
                end
            end
        end
        if not found then
            DEFAULT_CHAT_FRAME:AddMessage("|cff999999No rivals yet!|r")
        end
        
    elseif msg == "top" then
        -- Top victims and nemesis
        local victims = {}
        local nemesis = {}
        
        if DuelTrackerDB.players then
            for key, stats in pairs(DuelTrackerDB.players) do
                if stats.wins > stats.losses then
                    table.insert(victims, {name = stats.name, diff = stats.wins - stats.losses, wins = stats.wins})
                elseif stats.losses > stats.wins then
                    table.insert(nemesis, {name = stats.name, diff = stats.losses - stats.wins, losses = stats.losses})
                end
            end
        end
        
        table.sort(victims, function(a, b) return a.diff > b.diff end)
        table.sort(nemesis, function(a, b) return a.diff > b.diff end)
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== TOP VICTIMS ===|r")
        for i = 1, math.min(5, #victims) do
            DEFAULT_CHAT_FRAME:AddMessage(i .. ". |cff66ff66" .. victims[i].name .. "|r - " .. victims[i].wins .. " wins")
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== TOP NEMESIS ===|r")
        for i = 1, math.min(5, #nemesis) do
            DEFAULT_CHAT_FRAME:AddMessage(i .. ". |cffff6666" .. nemesis[i].name .. "|r - " .. nemesis[i].losses .. " losses")
        end
        
    elseif msg == "reset" then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFDuelTracker:|r Position reset!")
        
    elseif msg == "clear" then
        DuelTrackerDB = { players = {}, totalWins = 0, totalLosses = 0 }
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFDuelTracker:|r All stats cleared!")
        
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== DuelTracker Commands ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("/duel - Show your overall stats")
        DEFAULT_CHAT_FRAME:AddMessage("/duel rivals - Show your rivals")
        DEFAULT_CHAT_FRAME:AddMessage("/duel top - Show leaderboards")
        DEFAULT_CHAT_FRAME:AddMessage("/duel reset - Reset frame position")
        DEFAULT_CHAT_FRAME:AddMessage("/duel clear - Clear all stats (careful!)")
        DEFAULT_CHAT_FRAME:AddMessage("/duel help - Show this help")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFDuelTracker:|r Unknown command. Type /duel help")
    end
end

-- ============================================================
-- STARTUP
-- ============================================================

DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFDuelTracker|r by |cffFFD700Tellmewhybro|r loaded!")
DEFAULT_CHAT_FRAME:AddMessage("Target a player to see duel stats.")
