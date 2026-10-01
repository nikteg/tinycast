# Color Picker

**Pick Color** opens the system eyedropper (`NSColorSampler`) over every display and copies the colour
under it as hex. **Color History** lists what was picked, newest first, and copies any of them as Hex,
RGBA, HSL or Oklch.

## Invariants

- **`Model/` stays Foundation-only.** `PickedColor` and `ColorHistory` are compiled by
  `color-picker-test`, together with the clipboard's colour files.
- **Notations are the clipboard's.** A picked colour formats through `ColorValue` and `ColorFormat`,
  and draws with `ColorSwatch`, so a colour reads the same in both features. A new notation is added
  there, never here.
- **Each hex is kept once.** Picking a colour again moves it to the top; the history caps at 100 and
  is persisted to `colors.json`.
- **The palette hides before the loupe opens**, handing focus back so the eyedropper can reach what it
  was covering. A cancelled pick copies nothing.

## Layout

| Path | Role |
| --- | --- |
| `Model/PickedColor.swift` | One picked colour in sRGB bytes, its notations and its query match |
| `Model/ColorHistory.swift` | Newest first, de-duplicated, capped |
| `Service/ColorHistoryStore.swift` | The history, persisted |
| `Service/ColorSampleRunner.swift` | `NSColorSampler`, converted to sRGB |
| `UI/ColorPickerCoordinator.swift` | Pick, copy, delete |
| `UI/ColorHistoryScreen.swift` | The palette screen |

On the screen, ↵ copies hex, ⌘↵ RGBA, ⌘N picks another, ⌃X deletes one and ⌃⇧X all, after asking.
