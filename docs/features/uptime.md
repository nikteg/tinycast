# Uptime

**Uptime** shows how long the Mac has been up and when it booted, in a pill:
`Up 2 days 14 hours 22 minutes · since Sat 11 Oct 19:21`.

## Invariants

- **`kern.boottime` is the only source**, the clock `uptime` itself reads, taken synchronously on the
  main actor rather than by running the command.
- **To the minute.** `UptimeReport.span` drops seconds and empty units, so the pill holds still for
  the `readingHUD` dwell it stays up; `uptime-test` pins the wording. Only the boot date follows the
  reader's locale.
