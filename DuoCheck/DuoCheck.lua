local addonName, addon = ...

-- Cache global functions for performance
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local strsub = strsub
local ipairs = ipairs
local time = time

addon.frame = CreateFrame("Frame", "DuoCheckFrame", UIParent)
addon.frame:RegisterEvent("ADDON_LOADED")
addon.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
addon.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
addon.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon.frame:RegisterEvent("PLAYER_LEVEL_UP")
addon.frame:RegisterEvent("PLAYER_LOGOUT")

-- Constants
-- Updated with Classic Era Map IDs
local DUNGEONS = {
    [1417] = { -- The Deadmines (Classic Map ID: 1417)
        name = "The Deadmines",
        cap = 20,
        bosses = {
            "Rhahk'Zor",
            "Sneed",
            "Gilnid",
            "Mr. Smite",
            "Cookie",
            "Captain Greenskin",
            "Edwin VanCleef"
        }
    },
    [1413] = { -- Wailing Caverns (Classic Map ID: 1413)
        name = "Wailing Caverns",
        cap = 22,
        bosses = {
            "Lady Anacondra",
            "Lord Cobrahn",
            "Kresh",
            "Lord Pythas",
            "Skum",
            "Lord Serpentis",
            "Verdan the Everliving",
            "Mutanus the Devourer"
        }
    },
    [1414] = { -- Shadowfang Keep (Classic Map ID: 1414)
        name = "Shadowfang Keep",
        cap = 26,
        bosses = {
            "Rethilgore",
            "Razorclaw the Butcher",
            "Baron Silverlaine",
            "Commander Springvale",
            "Odo the Watcher",
            "Fenrus the Devourer",
            "Wolf Master Nandos",
            "Archmage Arugal"
        }
    },
    [1415] = { -- Blackfathom Deeps (Classic Map ID: 1415)
        name = "Blackfathom Deeps",
        cap = 28,
        bosses = {
            "Ghamoo-ra",
            "Lady Sarevess",
            "Gelihast",
            "Baron Aquanis",
            "Lorgus Jett",
            "Twilight Lord Kelris",
            "Aku'mai"
        }
    }
}

local DUNGEON_ORDER = {1417, 1413, 1414, 1415} -- DM, WC, SFK, BFD (Classic IDs)

-- State
local currentZoneID = nil
local currentRun = nil
local progressFrame = nil
local summaryFrame = nil

-- Utility
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DuoCheck]|r " .. msg)
end

-- Database Initialization
function addon:InitDB()
    if not DuoCheckDungeonsDB then
        DuoCheckDungeonsDB = {
            completed = {},
            positions = {},
            sizes = {},
            summaryVisible = true,
            currentRun = nil -- For persistence
        }
    end
    DuoCheckDungeonsDB.completed = DuoCheckDungeonsDB.completed or {}
    DuoCheckDungeonsDB.positions = DuoCheckDungeonsDB.positions or {}
    DuoCheckDungeonsDB.sizes = DuoCheckDungeonsDB.sizes or {}
    if DuoCheckDungeonsDB.summaryVisible == nil then DuoCheckDungeonsDB.summaryVisible = true end
end

-- UI - Progress Frame
function addon:CreateProgressFrame()
    if progressFrame then return end

    local f = CreateFrame("Frame", "DuoCheckProgressFrame", UIParent, "BackdropTemplate")
    f:SetSize(220, 300)
    f:SetPoint("RIGHT", -20, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    -- Draggable
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        DuoCheckDungeonsDB.positions["progress"] = {point, "UIParent", relativePoint, x, y}
    end)

    -- Load Position
    if DuoCheckDungeonsDB.positions["progress"] then
        local p = DuoCheckDungeonsDB.positions["progress"]
        f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    end

    -- Title
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.Title:SetPoint("TOP", 0, -15)
    f.Title:SetText("Dungeon Progress")

    -- Info
    f.Info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Info:SetPoint("TOP", 0, -40)

    -- Timer
    f.Timer = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Timer:SetPoint("TOP", 0, -55)

    -- Mob Count
    f.Mobs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Mobs:SetPoint("TOP", 0, -70)

    -- Boss List Container
    f.BossFrame = CreateFrame("Frame", nil, f)
    f.BossFrame:SetSize(200, 200)
    f.BossFrame:SetPoint("TOP", 0, -90)

    f.BossLines = {}
    f.StrikeLines = {} -- For strikethrough effect

    local timeSinceLastUpdate = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        timeSinceLastUpdate = timeSinceLastUpdate + elapsed
        if timeSinceLastUpdate >= 0.1 then
            if currentRun and not currentRun.done then
                local duration = GetTime() - currentRun.startTime
                self.Timer:SetText(date("!%H:%M:%S", duration))
            end
            timeSinceLastUpdate = 0
        end
    end)

    progressFrame = f
end

function addon:UpdateProgressFrame()
    if not progressFrame or not currentRun then return end

    local dungeon = DUNGEONS[currentRun.zoneID]
    progressFrame.Title:SetText(dungeon.name)
    progressFrame.Info:SetText(currentRun.mode .. " - Lvl " .. currentRun.startLevel .. " (Cap " .. dungeon.cap .. ")")
    progressFrame.Mobs:SetText("Mobs Killed: " .. currentRun.mobCount)

    -- Update Boss List
    local yOffset = 0
    for i, bossName in ipairs(dungeon.bosses) do
        local line = progressFrame.BossLines[i]
        local strike = progressFrame.StrikeLines[i]

        if not line then
            line = progressFrame.BossFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line:SetPoint("TOPLEFT", 10, yOffset)
            progressFrame.BossLines[i] = line
        end
        if not strike then
             strike = progressFrame.BossFrame:CreateTexture(nil, "OVERLAY")
             strike:SetColorTexture(1, 0, 0, 0.8)
             strike:SetHeight(1)
             progressFrame.StrikeLines[i] = strike
        end

        local killedData = currentRun.bossesKilled[bossName] -- Can be true (bool) or timestamp (number)

        if killedData then
             local timestamp = ""
             if type(killedData) == "number" then
                 timestamp = date(" %H:%M:%S", killedData)
             end
            line:SetText("|cff00ff00|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t " .. bossName .. "|r|cffaaaaaa" .. timestamp .. "|r")
            line:SetTextColor(0, 1, 0)

            -- Show Strikethrough
            strike:SetPoint("LEFT", line, "LEFT", 15, 0) -- Adjust to start after icon
            strike:SetPoint("RIGHT", line, "RIGHT", -string.len(timestamp)*5, 0) -- Adjust end before timestamp roughly
            strike:Show()
        else
            line:SetText(bossName)
            line:SetTextColor(1, 1, 1)
            strike:Hide()
        end
        line:Show()
        yOffset = yOffset - 15
    end

    -- Hide unused lines
    for i = #dungeon.bosses + 1, #progressFrame.BossLines do
        progressFrame.BossLines[i]:Hide()
        if progressFrame.StrikeLines[i] then progressFrame.StrikeLines[i]:Hide() end
    end

    -- Adjust height
    progressFrame:SetHeight(100 + (#dungeon.bosses * 15) + 20)
end

-- UI - Summary Frame
function addon:CreateSummaryFrame()
    if summaryFrame then return end

    local f = CreateFrame("Frame", "DuoCheckSummaryFrame", UIParent, "BackdropTemplate")
    f:SetSize(300, 250)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    -- Resizable
    f:SetResizable(true)
    f:SetMinResize(250, 200)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        DuoCheckDungeonsDB.positions["summary"] = {point, "UIParent", relativePoint, x, y}
    end)

    -- Resize Grip
    local resizeButton = CreateFrame("Button", nil, f)
    resizeButton:SetPoint("BOTTOMRIGHT", -6, 6)
    resizeButton:SetSize(16, 16)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeButton:SetScript("OnMouseDown", function(self, button)
        f:StartSizing("BOTTOMRIGHT")
    end)

    resizeButton:SetScript("OnMouseUp", function(self, button)
        f:StopMovingOrSizing()
        DuoCheckDungeonsDB.sizes["summary"] = {f:GetWidth(), f:GetHeight()}
    end)

    -- Load Position and Size
    if DuoCheckDungeonsDB.positions["summary"] then
        local p = DuoCheckDungeonsDB.positions["summary"]
        f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    end
    if DuoCheckDungeonsDB.sizes["summary"] then
        local s = DuoCheckDungeonsDB.sizes["summary"]
        f:SetSize(s[1], s[2])
    end

    -- Close Button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function()
        f:Hide()
        DuoCheckDungeonsDB.summaryVisible = false
    end)

    -- Title
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.Title:SetPoint("TOP", 0, -15)
    f.Title:SetText("Duo Dungeon Challenge")

    f.Lines = {}
    f.Content = CreateFrame("Frame", nil, f)
    f.Content:SetPoint("TOPLEFT", 15, -40)
    f.Content:SetPoint("BOTTOMRIGHT", -15, 15)

    summaryFrame = f

    if not DuoCheckDungeonsDB.summaryVisible then
        f:Hide()
    end
end

function addon:UpdateSummaryFrame()
    if not summaryFrame then return end

    local yOffset = 0
    -- Iterate through dungeons in specific order
    local count = 0

    for _, zoneID in ipairs(DUNGEON_ORDER) do
        local dungeon = DUNGEONS[zoneID]
        local record = DuoCheckDungeonsDB.completed[zoneID]
        count = count + 1

        local line = summaryFrame.Lines[count]
        if not line then
            line = summaryFrame.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            line:SetJustifyH("LEFT")
            line:SetPoint("TOPLEFT", 0, yOffset)
            line:SetWidth(270)
            summaryFrame.Lines[count] = line
        end

        if record and record.done then
            line:SetText("|cff00ff00[x] " .. dungeon.name .. "|r")
        else
            line:SetText("|cffaaaaaa[ ] " .. dungeon.name .. " (Cap " .. dungeon.cap .. ")|r")
        end
        line:Show()

        -- Add details line if completed
        if record and record.done then
            count = count + 1
            local detailLine = summaryFrame.Lines[count]
            if not detailLine then
                detailLine = summaryFrame.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                detailLine:SetJustifyH("LEFT")
                detailLine:SetPoint("TOPLEFT", 15, yOffset - 15)
                 detailLine:SetWidth(255)
                summaryFrame.Lines[count] = detailLine
            end
            local txt = string.format("Completed: %s | Time: %s | Lvl: %s | Mode: %s",
                record.last.whenText, record.last.durationText, record.last.level, record.last.mode)
            detailLine:SetText(txt)
            detailLine:Show()
            yOffset = yOffset - 30 -- More space for details
        else
            yOffset = yOffset - 20
        end
    end

    -- Hide unused lines (fix bug)
    for i = count + 1, #summaryFrame.Lines do
        summaryFrame.Lines[i]:Hide()
    end
end


-- Tracking Logic
function addon:StartRun(zoneID)
    local dungeon = DUNGEONS[zoneID]
    local numGroup = GetNumGroupMembers()
    local mode = (numGroup <= 1) and "Solo" or "Duo"

    -- Check for persisted run first
    if DuoCheckDungeonsDB.currentRun and DuoCheckDungeonsDB.currentRun.zoneID == zoneID and not DuoCheckDungeonsDB.currentRun.done then
        currentRun = DuoCheckDungeonsDB.currentRun

        if currentRun.startTimeEpoch then
             -- Re-calculate local startTime relative to now
             local elapsed = time() - currentRun.startTimeEpoch
             currentRun.startTime = GetTime() - elapsed
        else
            -- Legacy or fresh
            currentRun.startTime = GetTime()
            currentRun.startTimeEpoch = time()
        end

        Print("Restored run for " .. dungeon.name)
    else
        currentRun = {
            zoneID = zoneID,
            startTime = GetTime(),
            startTimeEpoch = time(),
            startLevel = UnitLevel("player"),
            mode = mode,
            bossesKilled = {},
            mobCount = 0,
            done = false
        }
        -- Initialize bossesKilled
        for _, boss in ipairs(dungeon.bosses) do
            currentRun.bossesKilled[boss] = false
        end
        Print("Started tracking: " .. dungeon.name .. " (" .. mode .. ")")
    end

    addon:ShowProgressFrame()
end

function addon:StopRun()
    currentRun = nil
    DuoCheckDungeonsDB.currentRun = nil -- Clear persistence
    if progressFrame then progressFrame:Hide() end
end

function addon:SaveRunState()
    if currentRun then
        DuoCheckDungeonsDB.currentRun = currentRun
    end
end

function addon:CheckZone()
    local zoneID = nil

    local mapID = C_Map.GetBestMapForUnit("player")

    if mapID and DUNGEONS[mapID] then
        zoneID = mapID
    end

    -- If zoneID is found and we are not tracking, start.
    if zoneID then
        if currentRun then
             if currentRun.zoneID ~= zoneID then
                -- Changed dungeon? Reset?
                addon:StartRun(zoneID)
             end
        else
            addon:StartRun(zoneID)
        end
    else
        -- Left dungeon
        if currentRun then
            addon:StopRun()
        end
    end

    currentZoneID = zoneID
end

function addon:ShowProgressFrame()
    if not progressFrame then addon:CreateProgressFrame() end
    progressFrame:Show()
    addon:UpdateProgressFrame()
end

function addon:OnCombatLog()
    if not currentRun then return end

    local _, subEvent, _, _, _, _, _, destGUID, destName, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()

    if subEvent == "UNIT_DIED" then
        -- Count Mobs
        if destGUID and (strsub(destGUID, 1, 8) == "Creature" or strsub(destGUID, 1, 7) == "Vehicle") then
            currentRun.mobCount = currentRun.mobCount + 1

            -- Check if Boss
            local dungeon = DUNGEONS[currentRun.zoneID]
            for _, bossName in ipairs(dungeon.bosses) do
                if destName == bossName and not currentRun.bossesKilled[bossName] then
                    currentRun.bossesKilled[bossName] = time()
                    addon:AnnounceBossKill(bossName)
                end
            end

            addon:CheckCompletion()
            addon:UpdateProgressFrame()
            addon:SaveRunState() -- Save after updates
        end
    end
end

function addon:AnnounceBossKill(bossName)
    RaidNotice_AddMessage(RaidWarningFrame, bossName .. " Defeated!", ChatTypeInfo["RAID_WARNING"])
    PlaySound(8959)
    Print("Boss Defeated: " .. bossName)
end

function addon:CheckCompletion()
    if not currentRun or currentRun.done then return end

    local dungeon = DUNGEONS[currentRun.zoneID]
    local allDead = true
    for _, bossName in ipairs(dungeon.bosses) do
        if not currentRun.bossesKilled[bossName] then
            allDead = false
            break
        end
    end

    if allDead then
        local currentLevel = UnitLevel("player")
        if currentLevel <= dungeon.cap then
             addon:CompleteRun()
        else
             Print("Dungeon clear, but level too high for challenge (" .. currentLevel .. " > " .. dungeon.cap .. ")")
        end
    end
end

function addon:CompleteRun()
    if not currentRun then return end
    currentRun.done = true

    local duration = GetTime() - currentRun.startTime
    local dateStr = date("%Y-%m-%d %H:%M:%S")
    local durationStr = date("!%H:%M:%S", duration)

    local record = {
        done = true,
        last = {
            when = time(),
            whenText = dateStr,
            duration = duration,
            durationText = durationStr,
            level = currentRun.startLevel,
            mode = currentRun.mode
        }
    }

    -- Save to DB
    DuoCheckDungeonsDB.completed[currentRun.zoneID] = record
    DuoCheckDungeonsDB.currentRun = nil -- Clear active run since done

    RaidNotice_AddMessage(RaidWarningFrame, "DUNGEON COMPLETED!", ChatTypeInfo["RAID_WARNING"])
    PlaySound(878) -- Quest Complete sound
    Print("Dungeon Completed! Saved to history.")

    addon:UpdateSummaryFrame()
end

-- Event Handler
addon.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            addon:InitDB()
            addon:CreateSummaryFrame()
            addon:UpdateSummaryFrame()
            Print("Loaded. Type /dc for options.")
            -- Restore active run if exists
            if DuoCheckDungeonsDB.currentRun and not currentRun then
                 addon:CheckZone() -- Will trigger StartRun which handles restore
            end
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        addon:CheckZone()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        addon:OnCombatLog()
    elseif event == "PLAYER_LEVEL_UP" then
        if currentRun then
            local newLevel = ...
            if newLevel > DUNGEONS[currentRun.zoneID].cap then
                Print("Warning: You have exceeded the level cap for this dungeon challenge!")
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        addon:SaveRunState()
    end
end)

-- Slash Commands
SLASH_DUOCHECK1 = "/duocheck"
SLASH_DUOCHECK2 = "/dc"
SlashCmdList["DUOCHECK"] = function(msg)
    if msg == "reset" then
        DuoCheckDungeonsDB.completed = {}
        DuoCheckDungeonsDB.currentRun = nil
        Print("History reset.")
        addon:UpdateSummaryFrame()
    elseif msg == "test" then
        -- Test functionality
        Print("Test mode: simulating entry.")
    else
        -- Toggle Summary
        if summaryFrame then
            if summaryFrame:IsShown() then
                summaryFrame:Hide()
                DuoCheckDungeonsDB.summaryVisible = false
            else
                summaryFrame:Show()
                DuoCheckDungeonsDB.summaryVisible = true
            end
        else
            addon:CreateSummaryFrame()
            addon:UpdateSummaryFrame()
            summaryFrame:Show()
            DuoCheckDungeonsDB.summaryVisible = true
        end
    end
end

addon.Dungeons = DUNGEONS
