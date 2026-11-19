# HOLDFAST

A character-driven, turn-based tactical game about first contact, built in Godot 4. The design baseline is **HOLDFAST Game Design Document v3.1** at the top of this repository; older versions are in `archive/`.

**Status:** prototype. The game now opens in a desktop layout (1920×1080, landscape): big map on the left, real buttons and panels on the right, story/results/roster as pop-up windows. Keyboard shortcuts are unchanged; press **Controls** in the top bar for the list.

 One playable mission (Farm Road), its debrief, a persistent roster, a return mission shaped by the first mission's outcome, and an ending logic test. It is not a campaign yet.

## Play it (Mac)

Double-click **Play HOLDFAST.command**. Godot must be installed at `/Applications/Godot.app`. Close the game window to stop.

Or open `holdfast/project.godot` in Godot (tested with 4.7.2) and press **F5**.

## Run the tests

From the repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path holdfast --script res://tests/test_follow_rescue.gd
```

Every file in `holdfast/tests/` runs the same way. A passing run prints `FAILURES: 0` and exits with code 0. Tests use their own save folder and never touch your campaign.

## Where things are

| Folder | What it holds |
| --- | --- |
| `holdfast/` | The Godot project |
| `holdfast/state/` | Game state: combat, machine, evacuation, story, campaign, results |
| `holdfast/systems/` | Game rules that don't draw anything: turns, machine behavior, civilians, saving |
| `holdfast/presentation/` | Screens, panels and input handling |
| `holdfast/presentation/hud/` | The desktop interface (`game.tscn` is the main scene) |
| `holdfast/encounter_controller.gd` | Coordinator: shared state, turn order, thin wrappers into `systems/` |
| `holdfast/missions/` | Mission layouts as data files |
| `holdfast/tests/` | Automated tests |
| `docs/` | Plans, decisions, art direction and test evidence |
| `art-source/`, `tools/art/` | Editable Blender files and the scripts that build game models from them |

## Key documents

- [Development history](docs/CHANGELOG.md): what was built, in order, with test notes
- [Foundation plan](docs/foundation-plan.md): how the code was restructured, and why
- [Presentation plan](docs/presentation-plan.md): camera and visual direction
- [Foundation verification](docs/verification/foundation/README.md): test evidence and known readability issues

## Current decisions

- **Camera:** stylized 2D or 2.5D (StarCraft / Shadowrun style), not full 3D. The 3D preview and Machine A model stay in the project as reference.
- **Art:** paused until the interface is readable and the controls are clear in playtesting.
- **Overwatch:** deferred to the first armed-enemy encounter.
