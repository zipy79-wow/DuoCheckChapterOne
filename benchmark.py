import time

class Run:
    def __init__(self):
        self.zoneID = 1417
        self.mobCount = 0
        self.bossesKilled = {}
        self.done = False

currentRun = Run()

DUNGEONS = {
    1417: {
        'name': "The Deadmines",
        'cap': 20,
        'bosses': [
            "Rhahk'Zor", "Sneed", "Gilnid", "Mr. Smite", "Cookie", "Captain Greenskin", "Edwin VanCleef"
        ]
    }
}

class Addon:
    def AnnounceBossKill(self, bossName): pass
    def CheckCompletion(self): pass
    def UpdateProgressFrame(self): pass
    def SaveRunState(self): pass

addon = Addon()

def run_benchmark():
    start_time = time.time()
    for _ in range(1000000):
        subEvent = "UNIT_DIED"
        destGUID = "Creature-0-0-0-0-1234"
        destName = "Random Mob"

        if subEvent == "UNIT_DIED":
            if destGUID and (destGUID[:8] == "Creature" or destGUID[:7] == "Vehicle"):
                currentRun.mobCount += 1

                dungeon = DUNGEONS[currentRun.zoneID]
                boss_killed = False
                for bossName in dungeon['bosses']:
                    if destName == bossName and not currentRun.bossesKilled.get(bossName):
                        currentRun.bossesKilled[bossName] = time.time()
                        addon.AnnounceBossKill(bossName)
                        boss_killed = True

                # BASELINE: always called
                addon.CheckCompletion()
                addon.UpdateProgressFrame()
                addon.SaveRunState()

    print(f"Baseline Time: {time.time() - start_time:.4f}s")

run_benchmark()

def run_optimized_benchmark():
    currentRun.mobCount = 0
    start_time = time.time()
    for _ in range(1000000):
        subEvent = "UNIT_DIED"
        destGUID = "Creature-0-0-0-0-1234"
        destName = "Random Mob"

        if subEvent == "UNIT_DIED":
            if destGUID and (destGUID[:8] == "Creature" or destGUID[:7] == "Vehicle"):
                currentRun.mobCount += 1

                dungeon = DUNGEONS[currentRun.zoneID]
                boss_killed = False
                for bossName in dungeon['bosses']:
                    if destName == bossName and not currentRun.bossesKilled.get(bossName):
                        currentRun.bossesKilled[bossName] = time.time()
                        addon.AnnounceBossKill(bossName)
                        boss_killed = True

                # OPTIMIZED: only called if boss killed
                if boss_killed:
                    addon.CheckCompletion()
                    addon.UpdateProgressFrame()
                    addon.SaveRunState()

    print(f"Optimized Time: {time.time() - start_time:.4f}s")

run_optimized_benchmark()
