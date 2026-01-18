# DuoCheck

DuoCheck is a World of Warcraft (Classic Era) addon designed to track Solo and Duo dungeon challenges. It monitors your progress in real-time, validates completion based on level caps, and saves your run history.

## Features

### Supported Dungeons
DuoCheck automatically tracks runs for the following dungeons:
*   **The Deadmines** (Level Cap: 20)
*   **Wailing Caverns** (Level Cap: 22)
*   **Shadowfang Keep** (Level Cap: 26)
*   **Blackfathom Deeps** (Level Cap: 28)

### Real-Time Tracking
When you enter a supported dungeon, the **Progress Frame** appears automatically:
*   **Timer:** Tracks run duration in real-time.
*   **Mob Counter:** Counts every non-player unit killed.
*   **Boss Checklist:** Displays a list of required bosses.
    *   Bosses are marked with a green checkmark and strikethrough when defeated.
    *   Records the exact time of the kill.
*   **Status Info:** Shows your entry mode (Solo/Duo) and entry level.

### Completion & History
*   **Validation:** A run is marked as "Complete" only if all bosses are defeated while your character is at or below the dungeon's level cap.
*   **Persistence:** Active runs are saved even if you reload the UI or log out, preventing data loss during disconnects.
*   **Summary Frame:** A movable and resizable window that shows your completion status for all 4 dungeons.
    *   Displays details of your completed runs (Date, Duration, Level, Mode).

### Alerts
*   **Boss Kills:** Announces boss defeats with a "Raid Warning" style message and sound.
*   **Completion:** plays a victory sound and alerts you upon successfully clearing the dungeon.
*   **Level Warning:** Warns you if you level up past the dungeon's cap during a run.

## Usage

### Slash Commands
*   `/dc` or `/duocheck` - Toggles the Summary Frame visibility.
*   `/dc reset` - Resets all stored history and completion data for the current character.
*   `/dc test` - Simulates a dungeon entry (for testing UI positioning).

### Interface
*   **Move:** Drag the frames with the Left Mouse Button to position them anywhere on your screen.
*   **Resize:** The Summary Frame can be resized using the grip in the bottom-right corner.
*   **Save:** All positions and sizes are saved per-character.

## Installation
1.  Download the `DuoCheck` folder.
2.  Place it in your WoW Classic `Interface/AddOns/` directory.
3.  (Optional) Restart the game or reload the UI.
