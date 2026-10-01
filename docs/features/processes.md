# Processes and ports

**Kill Process** lists the reader's own processes, busiest first, with their CPU, memory, PID and any
TCP ports they listen on. **Listening Ports** lists one row per listening port and the process holding
it. On either screen ↵ quits the process (`SIGTERM`), ⌘↵ force quits it (`SIGKILL`), and ⌘R sweeps
again.

## Invariants

- **`Model/` stays Foundation-only.** The `ps` and `lsof` parsers and `ProcessQuery` are compiled by
  `process-test` against captured output.
- **Only the reader's own processes.** `ps -x` and `lsof -u <uid>` never list another user's, which
  could not be signalled anyway, and Tinycast leaves itself off — Quit Tinycast is its own command.
- **Both sweeps run off-main** through `ProcessSweep`, each reading its pipe to the end before
  awaiting the exit, and a sweep that lands after a newer one began is dropped.
- **No confirmation**, as in Raycast: the rows are the reader's own processes, and a refused signal
  reports why in the pill.

## Layout

| Path | Role |
| --- | --- |
| `Model/RunningProcess.swift` | One `ps` row: pid, CPU, memory, path, name, enclosing app |
| `Model/ListeningPort.swift` | One `lsof` listener, IPv4 and IPv6 merged |
| `Model/ProcessQuery.swift` | A name, a PID, or a port — `3000` or `:3000` |
| `Service/ProcessSweep.swift` | Runs `ps -x -ww` and `lsof -iTCP -sTCP:LISTEN` |
| `Service/ProcessSession.swift` | The last sweep, shared by both screens |
| `Service/ProcessSignalRunner.swift` | `kill(2)` and its refusal |
| `UI/ProcessCoordinator.swift` | Open, sweep, quit, copy, reveal, open a port in the browser |
| `UI/ProcessesScreen.swift`, `UI/PortsScreen.swift` | The two palette screens |

A process inside an app bundle wears the outermost app's icon, so a helper nested in a framework still
shows the app it belongs to. Typing a port on Kill Process finds the process listening on it.
