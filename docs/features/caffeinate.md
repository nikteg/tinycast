# Caffeinate

Keeps the Mac awake, after Raycast's Coffee extension. **Toggle Caffeinate** holds it awake until
turned off; **Caffeinate for Duration** opens a palette screen where a typed length (`45m`, `2h`) or a
preset sets when it lets go. A cup sits in the menu bar while it holds.

## Invariants

- **`Model/` stays Foundation-only.** `Caffeination` is compiled by `caffeinate-test`, with Timers'
  `DurationText`.
- **One assertion, `kIOPMAssertPreventUserIdleDisplaySleep`**, as `caffeinate -d` takes: the display
  stays on, and so the Mac never idles to sleep. A lid close still sleeps it.
- **Nothing is persisted.** The kernel releases the assertion when Tinycast exits, so a relaunch
  starts decaffeinated rather than resuming a hold the reader may have forgotten.
- **A new length replaces the running one**; it never adds to it.

## Layout

| Path | Role |
| --- | --- |
| `Model/Caffeination.swift` | Until turned off or until a moment; the presets and the wording |
| `Service/SleepAssertion.swift` | The IOKit power assertion |
| `UI/CaffeinateCoordinator.swift` | Toggle, caffeinate for a length, the expiry, the status |
| `UI/CaffeinateScreen.swift` | The duration screen |
| `UI/CaffeinateMenuBarItem.swift` | The cup and its menu |

The menu-bar cup is inserted while caffeinated and has no setting; dragging it out hides it until the
next caffeination.
