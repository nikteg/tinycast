# Processes and ports

**Kill Process** lists the reader's own processes, busiest first, with their CPU, memory, PID and any
TCP ports they listen on. **Listening Ports** lists every TCP listener on the Mac, one row per process
and port, and who holds it. On either screen ↵ quits the process (`SIGTERM`), ⌘↵ force quits it
(`SIGKILL`), and ⌘R sweeps again and re-sorts.

## Invariants

- **`Model/` stays Foundation-only.** The `netstat` parser, CPU measurement, row ordering, selection
  following and `ProcessQuery` are compiled by `process-test`.
- **Names and paths come from the kernel**, never `ps`'s `comm`: that is `argv[0]`, which a process
  can rewrite (`ssh: … [mux]`) or leave relative. `ProcessSweep` reads `sysctl(KERN_PROC_UID)`,
  `proc_pidpath` and `proc_pid_rusage`.
- **CPU is a share of one core between two readings**, as Activity Monitor shows it. Rusage counts
  CPU time in Mach ticks, so it is converted with `mach_timebase_info` — on Apple silicon a tick is
  not a nanosecond. The first sweep of an open takes two readings 250 ms apart.
- **Memory is the physical footprint** (`ri_phys_footprint`), Activity Monitor's Memory column.
- **Kill Process lists only the reader's own processes**, which are the only ones a signal could reach.
  Tinycast leaves itself off — Quit Tinycast is its own command.
- **Listening Ports lists every listener**, root's included, from `netstat -anv -p tcp`, which names
  each socket's pid without privileges. Another account's row says whose it is and cannot be quit.
- **A signal goes to the process that was shown, or to nothing.** Every row carries a
  `ProcessIdentity` — pid and start time — and `ProcessSignalRunner` re-reads the start time before
  `kill(2)`, so a pid reused since the sweep is never signalled.
- **The list is live while visible and cleared on every open.** `ProcessSession.keepCurrent` runs in
  the screen's `.task(id: vm.isVisible)`, sweeping every 2 seconds, and ends when the palette hides or
  the screen changes. A sweep that lands after a newer one, or after a reset, is dropped.
- **Rows keep their places between sweeps.** A refresh updates numbers in place, drops exited
  processes and appends new ones; only an open or ⌘R sorts by load again. When rows change under the
  reader, `RowFollowing` keeps the highlight on the same row, or on the one that took its place.
- **A quit row goes at once**, and a sweep follows half a second later, so a process that ignored
  `SIGTERM` comes back rather than staying hidden.
- **No confirmation**, as in Raycast: the rows are the reader's own processes, and a refused signal
  reports why in the pill.

## Layout

| Path | Role |
| --- | --- |
| `Model/RunningProcess.swift` | `ProcessIdentity`, samples and readings, CPU measurement, ordering, `ProcessPath` |
| `Model/ListeningPort.swift` | One `netstat` listener, IPv4 and IPv6 merged, and its holder |
| `Model/ProcessQuery.swift` | A name, a PID, or a port — `3000` or `:3000` |
| `Model/RowFollowing.swift` | Where the highlight goes when rows change |
| `Service/ProcessSweep.swift` | The kernel reads, `netstat`, and a pid's start time |
| `Service/ProcessSession.swift` | The live sweep loop and its rows, shared by both screens |
| `Service/ProcessSignalRunner.swift` | `kill(2)`, guarded by the process's identity |
| `UI/ProcessCoordinator.swift` | Reset on open, reload, quit, copy, reveal, open a port in the browser |
| `UI/ProcessListHost.swift` | Runs the sweep while visible and follows the selection |
| `UI/ProcessesScreen.swift`, `UI/PortsScreen.swift` | The two palette screens |

A process inside an app bundle wears the outermost app's icon, so a helper nested in a framework still
shows the app it belongs to. Typing a port on Kill Process finds the process listening on it.
