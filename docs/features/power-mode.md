# Power mode

**Toggle Low Power Mode** flips the battery's Energy Mode (Settings › Battery) between Automatic and
Low Power.

## Invariants

- **`Model/` stays Foundation-only.** `PowerMode` and `PowerModeHelperMessage` are compiled by
  `power-mode-test`, and by the helper.
- **The battery's mode only** — `pmset -b powermode`. The power adapter's setting is left alone, and
  High Power counts as "not low", so toggling from it lands on Low Power.
- **Read fresh on every toggle**: Settings, Control Center or `pmset` may have changed it since.
- **Writing needs root, so a root helper does it.** `PowerModeHelper` is a launchd daemon shipped in
  `Contents/Helpers`, registered through `SMAppService.daemon` on the first toggle. Its only verb is
  "set the battery's mode to one of the `PowerMode` cases" — never a path, a command or an argument.
- **The helper trusts one peer.** launchd passes the app's bundle id, and the `XPCListener` takes a
  lightweight code requirement on that signing identifier; any other caller is refused.
- **Every channel has its own job.** The label and Mach service are `<bundle id>.power-mode`, and the
  plist in `Contents/Library/LaunchDaemons/` is written by a `project.yml` post-build script, so Dev,
  Fork and the release channels never share a daemon or an approval.

## First use

The first toggle registers the daemon, which macOS holds until the reader allows it: Tinycast asks
through its own dialog, then opens System Settings › General › Login Items, where **Allow in the
Background** gets a switch for Tinycast. After that every toggle is silent.

A build the helper cannot run from — unsigned, or with the job's plist missing — falls back to
`PowerModeRunner`'s old path: `sudo -n`, then macOS's administrator prompt. A cancelled prompt
changes nothing and says nothing.
