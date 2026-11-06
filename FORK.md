# This fork

```sh
git clone https://github.com/nikteg/tinycast.git && cd tinycast
mise trust && mise run bootstrap
```

A personal fork of [abue-ammar/tinycast](https://github.com/abue-ammar/tinycast) that follows upstream
but lives on its own. Everything runs through [mise](https://mise.jdx.dev) tasks (`mise tasks`):

| Task | Does |
| --- | --- |
| `mise run bootstrap` | a fresh clone to a running app: `setup`, then `install` |
| `mise run setup` | check macOS and Xcode, install xcodegen/swiftlint/node, add `upstream`, create the signing identity |
| `mise run install` | Release build installed as `/Applications/Tinycast Fork.app`, then launched |
| `mise run build` / `build:release` | Debug or Release build; Release compiles incrementally |
| `mise run run` | build and relaunch `Tinycast Dev.app` |
| `mise run check` | tests, lint and build |
| `mise run upstream:status` | what upstream has that `main` lacks, and the reverse |
| `mise run upstream:sync` | merge `upstream/main` into `main`, regenerate the project, build |
| `mise run branch:merge <branch>` | merge a local feature branch into `main` |

Builds sign with **`Tinycast Self-Signed`**, a self-signed identity `setup` creates in the login
keychain once per machine. Every build on that machine then carries the same signature, which is
what makes macOS keep the Accessibility and Input Monitoring grants across rebuilds and updates —
an ad-hoc signature changes with every build, and the grant with it. The identity is passed to
`xcodebuild` on the command line, never written into `project.yml`, so the project stays
byte-identical to upstream and syncs do not conflict on it. A build without the identity stops and
says to run `setup`.

Syncing merges rather than rebases, so `main` never needs a force push. `setup` installs
`xcodegen`, `swiftlint` and `node` through mise, so nothing needs Homebrew.

## Its own app

`mise run install` builds **Tinycast Fork** (`com.tinycast.app.fork`), a separate app from upstream's
Tinycast: its own preferences, Application Support folder, TCC grants and login item, so both can be
installed side by side. Do not run both at once — whichever registers a hotkey first keeps it.

## Updates

The fork publishes no GitHub releases, so it never installs one. `build:release` stamps the commit and
clone path it was built from into Info.plist, and the `.fork` channel's `ForkUpdateChecker` asks
GitHub daily whether `nikteg/tinycast`'s `main` has moved past that commit. When it has, a dialog
lists the new commits and offers to copy `cd <clone> && git pull && mise run install` or open the
comparison on GitHub; Later skips that head until something newer is pushed. A build from a commit
that was never pushed says so rather than guessing. Check for Updates runs the same check on demand.

## What differs from upstream

- **Pomodoro.** A work/break timer after Mater, with its sounds, a menu-bar countdown and a
  notification at each change. See [docs/features/pomodoro.md](docs/features/pomodoro.md).
- **Typing Practice.** Raycast's Monkeytype test in the palette: time and quote tests, a results
  chart, personal bests and a copyable score card. See
  [docs/features/typing-practice.md](docs/features/typing-practice.md).
- **Timers, Caffeinate and Toggle Low Power Mode.** Named countdowns from a typed length, keeping
  the Mac awake until turned off or for a while, and flipping the battery's Energy Mode between
  Automatic and Low Power. See [timers](docs/features/timers.md),
  [caffeinate](docs/features/caffeinate.md) and [power mode](docs/features/power-mode.md).
- **Color Picker, Kill Process, Listening Ports and Confetti.** The system eyedropper with a
  history, the reader's processes and listening ports to quit, and Raycast's confetti. See
  [color picker](docs/features/color-picker.md), [processes](docs/features/processes.md) and
  [confetti](docs/features/confetti.md).
- **Uptime.** How long the Mac has been up and when it booted, in a pill. See
  [uptime](docs/features/uptime.md).
- **About** shows the commit a build came from beside its version, and links to this fork's
  repository, issues and commits instead of upstream's website and socials.
- **No support asks.** The About card, the menu-bar and palette items, the launcher command and the
  monthly reminder are gone — the checkout behind them is upstream's. The code stays, unwired, so
  upstream syncs merge cleanly.
- **No AI.** See [AI is left out](#ai-is-left-out).
- The About footer keeps a short licence notice. The AGPL (§5(d)) requires one in the interface of
  any copy that is passed on, so it stays even though the rest of upstream's branding is removed.

## AI is left out

`Features/AI`, `Features/MCP` and `Features/QuickActions` are excluded from the app target in
`project.yml`, so their ~26,000 lines are never compiled. Code outside them that reaches into them
sits behind `#if AI_FEATURES`; everything else asks `CommandID.isBuilt` or `SettingsTab.isBuilt`,
which hide the six AI commands and the AI and Quick Actions panes. `AppSettings` reads the AI
switches as off, so a stored `true` from an older build cannot surface a fallback or Tab-to-ask.

Nothing on disk is touched: chat history, `quick-actions.json`, the AI Keychain items and the
preferences are still there for a build that has AI. A `settings.json` with `ai` or `quickActions`
sections reports those keys as unknown. Hotkeys bound to custom Quick Actions are pruned at launch.

To build with AI, delete the three `Features/…` lines from the app's `excludes` in `project.yml`,
add `AI_FEATURES` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, and run `xcodegen generate`.
`TINYCAST_AI_FEATURES=1 ./Scripts/run-tests.sh` runs the suite as that build, AI-only harnesses
included; without it the `ai`-marked harnesses are skipped.

On an upstream sync, a conflict inside the three folders resolves to upstream's side. A new
reference to an AI type from elsewhere fails the build here, and goes behind `#if AI_FEATURES`.
