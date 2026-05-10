-- Mock globals
CombatLogGetCurrentEventInfo = function() return nil, "UNIT_DIED", nil, nil, nil, nil, nil, "Creature-0-0-0-0-1234", "Random Mob", nil, nil, nil, nil, nil, nil end
strsub = string.sub
time = os.time
GetTime = os.clock

DUNGEONS = {
    [1417] = {
        name = "The Deadmines",
        cap = 20,
        bosses = {
            "Rhahk'Zor", "Sneed", "Gilnid", "Mr. Smite", "Cookie", "Captain Greenskin", "Edwin VanCleef"
        }
    }
}

currentRun = {
    zoneID = 1417,
    mobCount = 0,
    bossesKilled = {},
    done = false
}

addon = {}
function addon:AnnounceBossKill(bossName) end
function addon:CheckCompletion() end
function addon:UpdateProgressFrame() end
function addon:SaveRunState() end

local function run_benchmark()
    local start_time = os.clock()
    for i = 1, 1000000 do
        local _, subEvent, _, _, _, _, _, destGUID, destName, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()

        if subEvent == "UNIT_DIED" then
            if destGUID and (strsub(destGUID, 1, 8) == "Creature" or strsub(destGUID, 1, 7) == "Vehicle") then
                currentRun.mobCount = currentRun.mobCount + 1

                local dungeon = DUNGEONS[currentRun.zoneID]
                for _, bossName in ipairs(dungeon.bosses) do
                    if destName == bossName and not currentRun.bossesKilled[bossName] then
                        currentRun.bossesKilled[bossName] = time()
                        addon:AnnounceBossKill(bossName)
                    end
                end

                addon:CheckCompletion()
                addon:UpdateProgressFrame()
                addon:SaveRunState()
            end
        end
    end
    local end_time = os.clock()
    print("Baseline Time: " .. (end_time - start_time) .. "s")
end

run_benchmark()
