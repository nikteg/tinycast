# Tinycast Fork

**A personal fork of [Tinycast](https://github.com/abue-ammar/tinycast), the tiny, fully native macOS
launcher.** It follows upstream but lives on its own. The changes here were made for my own use and
will most likely never be merged back, so this repository is not a place to report upstream bugs or
ask for upstream features.

<p align="center">
  <img alt="Swift 6.0"
       src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat&logo=swift&logoColor=white">
  <img alt="macOS 26 or later"
       src="https://img.shields.io/badge/macOS-26%2B-000000?style=flat&logo=apple&logoColor=white">
  <a href="LICENSE">
    <img alt="License: AGPL-3.0"
         src="https://img.shields.io/badge/License-AGPL--3.0-3DA639?style=flat"></a>
</p>

<p align="center">
  <img src="docs/screenshot.png" alt="Tinycast command palette" width="720">
</p>

## What this fork adds

- **Pomodoro.** A work/break timer after [Mater](https://github.com/jasonlong/mater): 25 minutes of
  work and 5 of break by default, Mater's sounds, a countdown in the menu bar, and a notification at
  each change saying how long the next phase runs and until when.
- **Better date math.** The calculator reads dates the way Soulver and Raycast do: `today - 14 sep`
  is 2 weeks rather than 351 days, plus ranges (`to`, `through`, `between`), `after`/`before`, named
  holidays, workday counts, and date facts such as week number or day of year.
- **The launcher keeps its query.** Closing the palette no longer clears what you typed. It comes
  back selected, so typing replaces it and Escape clears it.
- **Its own app.** It installs as `Tinycast Fork.app` with its own bundle id, preferences and
  permissions, so it can sit beside upstream's Tinycast.
- **Updates from this repository.** There are no release downloads. The app checks this fork's
  `main` and, when there are new commits, tells you the command to rebuild.
- **No support asks.** Upstream's tip jar, reminders and social links are gone. The About page links
  here and shows the commit each build came from.

Everything else is upstream Tinycast: app launcher, global and per-app hotkeys, file search,
clipboard history, calculator, quicklinks, Apple Shortcuts, snippets, custom commands, window
management, system actions, calendar and meetings, notes, emoji picker, opt-in AI chat and Quick
Actions, Raycast extensions, and backup/import. SwiftUI and AppKit, zero third-party dependencies, no
telemetry.

## Install

There are no prebuilt downloads: you build it yourself, which takes a few minutes. You need macOS 26
or later, [Xcode 26](https://apps.apple.com/app/xcode/id497799835) opened once, and
[mise](https://mise.jdx.dev).

```sh
git clone https://github.com/nikteg/tinycast.git && cd tinycast
mise trust && mise run bootstrap
```

`bootstrap` checks your toolchain, installs the build tools through mise, creates a local
self-signed signing identity in your login keychain, then builds and installs
`/Applications/Tinycast Fork.app` and launches it. Signing every build with the same identity is
what keeps macOS from asking for Accessibility again after each rebuild.

To update, run `git pull && mise run install` in the clone, or follow the prompt the app shows when
this fork has new commits.

## Permissions

**Accessibility** is needed when Tinycast pastes or expands text into another app, and it is the only
permission snippet expansion needs. You're prompted the first time a feature needs it; grant it in
**System Settings → Privacy & Security → Accessibility**. The Pomodoro asks for **notifications**
when you start your first cycle.

## Using it

1. Open **Settings → General** and record a global shortcut to summon the palette.
2. Press it anywhere. Type to filter, **↵** to launch, **↑/↓** to move, **Esc** to dismiss.
3. **Settings → Shortcuts**: give any app or command its own global shortcut.
4. Type **Start Pomodoro** in the palette, or set up the timer under **Settings → Pomodoro**.

## Working on it

[FORK.md](FORK.md) covers the fork workflow: every mise task, how signing works, syncing with
upstream, and how the updater decides a new build exists. `mise run check` runs the tests, lint and
a build. [docs/](docs/README.md) is upstream's documentation of the architecture, standards and each
feature, kept current for the fork's changes.

## Upstream

All credit for Tinycast goes to [Abue Ammar](https://github.com/abue-ammar) and its contributors. If
you want Tinycast itself, with signed releases, Homebrew installs and support, use
[upstream](https://github.com/abue-ammar/tinycast). Report problems with the fork's own changes
[here](https://github.com/nikteg/tinycast/issues).

## License

[AGPL-3.0](LICENSE), like upstream. Third-party material, including the Pomodoro sounds, is
listed in [NOTICE.md](NOTICE.md).
