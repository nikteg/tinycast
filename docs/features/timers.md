# Timers

Any number of named countdowns, after Raycast's Timers: **Start Timer** opens a palette screen where a
typed length and name — `10m tea`, `1h30`, `4:30 eggs` — starts one, or a preset does. Running timers
sit on the same screen, in the menu bar, and ring with a chime, a pill and a notification.

## Invariants

- **`Model/` stays Foundation-only.** `DurationPhrase`, `DurationText` and `CountdownTimer` are
  compiled by `timers-test`, and take `now` as a parameter everywhere.
- **A timer that has rung is gone.** `CountdownTimer` is running or paused; there is no finished state,
  and `timers.json` exists only while a timer does.
- **The banner is scheduled ahead**, at the timer's end, so it lands on time mid-sleep or while
  Tinycast is quit. Pausing cancels it and resuming reschedules it.
- **A timer that ended while Tinycast was quit is dropped at launch without a chime**: its banner has
  already been delivered by the system.
- **`DurationPhrase` is shared with Caffeinate**, which reads its typed lengths the same way. A bare
  number is minutes, and anything over a day is no duration.

## Layout

| Path | Role |
| --- | --- |
| `Model/DurationPhrase.swift` | A typed length and the words around it, which name the timer |
| `Model/DurationText.swift` | "1 hour 30 minutes" and "1:04:30" |
| `Model/CountdownTimer.swift` | One countdown's clock: start, pause, resume, restart, order |
| `Service/TimerStore.swift` | The timers, persisted to `timers.json` |
| `Service/TimerAlertRunner.swift` | The scheduled banners and the chime (`NSSound` "Glass") |
| `UI/TimerCoordinator.swift` | Commands, the second pump, ringing, presence |
| `UI/TimersScreen.swift` | The palette screen: start rows, then the running timers |
| `UI/TimerMenuBarItem.swift` | The soonest countdown in the menu bar, and a menu per timer |

## The screen

Empty, it lists the running timers first and the presets (1–60 minutes) below. A query that reads as a
length offers that one timer first; any other query filters the running timers by name. On a running
timer, ↵ pauses or resumes, ⌘R restarts, ⌃X stops it and ⌃⇧X stops them all.

## The pump and the menu bar

While a timer runs, the coordinator wakes as the soonest countdown's second turns and advances `now`,
the one clock every countdown on screen reads. The menu-bar item is its own `MenuBarExtra`, inserted
while any timer exists. There is no setting for it: dragging it out hides it until the next timer
starts. **Stop All Timers** is listed only while a timer exists.
