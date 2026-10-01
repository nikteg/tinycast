# Power mode

**Toggle Low Power Mode** flips the battery's Energy Mode (Settings › Battery) between Automatic and
Low Power.

## Invariants

- **`Model/` stays Foundation-only.** `PowerMode` is compiled by `power-mode-test`.
- **The battery's mode only** — `pmset -b powermode`. The power adapter's setting is left alone, and
  High Power counts as "not low", so toggling from it lands on Low Power.
- **Read fresh on every toggle**: Settings, Control Center or `pmset` may have changed it since.
- **Writing needs root.** `PowerModeRunner` tries `sudo -n` first, which succeeds silently when a
  sudoers rule allows it, then asks through macOS's own administrator prompt. A cancelled prompt
  changes nothing and says nothing.

To toggle without a password prompt, allow `pmset` for your user with `sudo visudo -f
/etc/sudoers.d/pmset`:

```
<your-user> ALL=(root) NOPASSWD: /usr/bin/pmset
```
