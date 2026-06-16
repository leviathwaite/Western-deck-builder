# Western Deck Builder

A modular **LÖVE2D** deck-building game prototype with a western theme, inspired by Slay the Spire–style combat flow.

## Features
- Data-driven cards, weapons, enemies, and player config via JSON
- Single-folder friendly file layout for mobile editing in CodeFlash
- Weapon loadout system:
  - Left holster pistol slot
  - Right holster pistol slot
  - Knife sheath slot
  - Back slot for rifle, bow, or shotgun
- Starting equipment:
  - Left holster unlocked with a basic pistol equipped
  - Right holster locked initially
  - Knife sheath unlocked with a basic knife equipped
  - Back slot unlocked but empty
- Loadout screen before starting a run
- Turn-based battle prototype with draw, discard, energy, block, damage, and weapon-based card generation

## Planned file layout
All files live in the same folder:
- `main.lua`
- `game.lua`
- `state_loadout.lua`
- `state_battle.lua`
- `card.lua`
- `deck.lua`
- `player.lua`
- `enemy.lua`
- `weapons.lua`
- `json.lua`
- `cards.json`
- `weapons.json`
- `enemies.json`

## Run
Install LÖVE and run the repository folder with it.

## Notes
This project is intentionally structured so gameplay content can be edited mostly through JSON files without changing Lua code.
