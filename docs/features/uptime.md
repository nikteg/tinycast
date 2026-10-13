# Uptime

**Uptime** shows what the `uptime` command prints, in a pill:
`9:36 up 3 days, 2:14, 6 users, load averages: 1.42 1.61 1.75`.

## Invariants

- **The same reads as `uptime`, no subprocess.** `UptimeProvider` takes `kern.boottime`, counts
  utmpx `USER_PROCESS` sessions and calls `getloadavg`, all synchronously on the main actor.
- **BSD `w`'s wording.** `UptimeReport.span` keeps its units, its singulars and its rounding to the
  nearest minute once past the first; `uptime-test` pins them. Only the clock follows the reader's
  locale, and the runs of padding spaces `uptime` aligns with are dropped, since nothing lines up
  under a pill.
