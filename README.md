# APSudoku
Classic Sudoku Game
- Play Sudoku at 3 different difficulty levels (Easy:48, Normal:35, Hard:24)
- Connect to [Archipelago Randomizer](https://archipelago.gg/)
  - Earn hints:
    - Completing a puzzle grants you a random hint for a location in the slot you are connected to
    - Harder difficulty puzzles are more likely to hint a 'Progression' type item
  - DeathLink support (Set before connecting!)
    - Lose a life if you check an incorrect puzzle (not an _incomplete_ puzzle), or quit a puzzle without solving it (including disconnecting).
    - Life count customizable (default 0). Dying with 0 lives left kills linked players AND resets your puzzle.
    - On receiving a DeathLink from another player, your puzzle resets.

## Building
Made with Godot. Open `project.godot`, and use Godot's exporting tools.
