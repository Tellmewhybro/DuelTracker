# DuelTracker

A World of Warcraft 3.3.5a addon for tracking duel statistics against other players.

**Server:** Warmane (WotLK 3.3.5a)  
**Duel Zone:** The Ruby Sanctum

![WoW 3.3.5a](https://img.shields.io/badge/WoW-3.3.5a-blue)
![Warmane](https://img.shields.io/badge/Server-Warmane-orange)

## Features

### 📊 Live Duel Statistics
- Automatically shows your Win/Loss record when targeting any player
- Stats are saved permanently across sessions
- Class-colored player names for easy identification

### ⚔️ Dynamic Duel States
- **Normal Mode:** Shows W/L stats with one-click Duel button
- **Pending Mode:** Animated "Waiting..." screen with cancel button and elapsed timer
- **Fight Mode:** Pulsing "FIGHT!" display with elapsed duel timer and forfeit option

### 🔥 Rival Detection
- Automatically marks players who have beaten you 3+ times as **RIVALS**
- Special visual indicator for revenge opportunities

### 🎨 Modern UI
- Sleek, minimal design with animated glow effects
- Pulsing gold border during active duels
- Pulsing orange border while waiting for response
- Draggable frame - position it anywhere

### 📍 Zone Restriction
- Only active in **The Ruby Sanctum** (Warmane's duel zone)
- Automatically hidden in battlegrounds, arenas, and other zones

## Installation

1. Download this repository (Code → Download ZIP)
2. Extract the ZIP file
3. **Important:** Rename the extracted folder from `DuelTracker-main` to `DuelTracker`
4. Copy the `DuelTracker` folder to your `Interface/AddOns/` directory
5. Restart WoW or type `/reload`

```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── DuelTracker/        ← folder must be named exactly "DuelTracker"
            ├── DuelTracker.lua
            ├── DuelTracker.toc
            └── README.md
```

> ⚠️ **Note:** The folder name must be `DuelTracker`, not `DuelTracker-main`!

## Usage

### Basic Usage
1. Go to **The Ruby Sanctum**
2. Target any player
3. The DuelTracker panel appears showing your history with that player
4. Click **Duel** to challenge them

### Buttons
- **Duel** - Send a duel request to your target
- **Cancel** - Cancel a pending duel request
- **Forfeit** - Surrender during an active duel
- **Share** - Post your stats against the target in /say chat

## Screenshots

### Normal Mode
Shows your W/L record against the targeted player with status indicators:
- 🟢 "You're winning!" / "EASY TARGET"
- 🔴 "He's ahead..."
- 🟡 "Tied!"
- ⚪ "First encounter!"
- 💗 "RIVAL!"

### Fight Mode
Animated "FIGHT!" header with:
- Pulsing gold glow effect
- Live elapsed time counter (MM:SS)
- Crossed swords icon
- Forfeit button

## Technical Details

- **Interface Version:** 30300 (WotLK 3.3.5a)
- **Saved Variables:** `DuelTrackerDB`
- **Events Used:** 
  - `PLAYER_TARGET_CHANGED`
  - `DUEL_REQUESTED` / `DUEL_FINISHED`
  - `CHAT_MSG_SYSTEM`
  - `PLAYER_REGEN_DISABLED`
  - `ZONE_CHANGED_NEW_AREA`

## License

Free to use and modify. Have fun dueling!

## Author

Made by **Tellmewhybro** ⚔️ for Warmane players

