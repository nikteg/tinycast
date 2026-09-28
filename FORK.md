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
| `mise run build` / `build:release` | Debug or Release build |
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

Syncing merges rather than rebases, so `main` never needs a force push. Needs `xcodegen` and
`swiftlint` (`brew install xcodegen swiftlint`).

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
- **About** shows the commit a build came from beside its version, and links to this fork's
  repository, issues and commits instead of upstream's website and socials.
- **No support asks.** The About card, the menu-bar and palette items, the launcher command and the
  monthly reminder are gone — the checkout behind them is upstream's. The code stays, unwired, so
  upstream syncs merge cleanly.
- The About footer keeps a short licence notice. The AGPL (§5(d)) requires one in the interface of
  any copy that is passed on, so it stays even though the rest of upstream's branding is removed.
