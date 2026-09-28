# Pomodoro

A work/break timer after [Mater](https://github.com/jasonlong/mater): 25 minutes of work, 5 of break,
alternating until stopped, with Mater's sounds, a countdown in the menu bar, and a notification at
each change saying how long the next phase runs and until when.

## Invariants

- **`Model/` stays Foundation-only.** `PomodoroTimer` and `PomodoroAnnouncement` are compiled by
  `pomodoro-test`, and take `now` as a parameter everywhere.
- **Stopped is the absence of a timer.** `PomodoroStore.timer == nil` means no cycle; there is no
  third state, and `pomodoro.json` exists only while one runs or is paused.
- **The wall clock decides the phase.** `advance` rolls past every phase that ended while the Mac
  slept or Tinycast was quit, each starting where the last ended — never from when it noticed.
- **The notification is scheduled ahead**, at the phase's `endsAt`, so it lands on time even when the
  pump wakes late. Every change to the timer, a length or the notification switch reschedules it.
- **A length change applies from the next phase.** The phase running keeps the end it started with.

## Layout

| Path | Role |
| --- | --- |
| `Model/PomodoroTimer.swift` | Phase, running/paused clock, pause/resume/skip/advance |
| `Model/PomodoroAnnouncement.swift` | What a phase change says |
| `Service/PomodoroStore.swift` | The cycle in progress, persisted to `pomodoro.json` |
| `Service/PomodoroSoundRunner.swift` | Mater's wind-up, toggles and ding |
| `Service/PomodoroNotificationRunner.swift` | The one pending phase-change notification |
| `UI/PomodoroCoordinator.swift` | Commands, the minute pump, sounds, notifications, presence |
| `UI/PomodoroMenuBarItem.swift` | The menu-bar label and menu |
| `Settings/PomodoroSettingsView.swift` | Lengths, alerts, the menu-bar switch, the commands |

## Sounds

Two generations of Mater. The wind-up as a phase starts is v2.0.3's — its Swift rewrite generates
one from a tick instead — and plays two seconds after the ding when a phase rolls over on its own.
The ding as a phase ends, and `toggle-on` on resume and `toggle-off` on pause and stop, are the
current Mater's.

## Commands and the menu bar

**Start Pomodoro** is listed while stopped; **Skip Pomodoro Phase** and **Stop Pomodoro** while a
cycle exists. **Pause or Resume Pomodoro** is always listed and starts a cycle when stopped, so one
chord can drive the whole timer.

The countdown is its own `MenuBarExtra`, inserted while a cycle exists and **Countdown in Menu Bar**
is on, independent of Tinycast's item and the calendar's. It shows the minutes left rounded up, as
Mater does, and re-renders only when that count changes. Dragging it out turns the switch off.
