import Foundation

/// The last sweep of processes and listening ports, re-read on every open of either screen.
@MainActor
@Observable
final class ProcessSession {
    private(set) var processes: [RunningProcess] = []
    private(set) var ports: [ListeningPort] = []
    private(set) var isLoadingProcesses = false
    private(set) var isLoadingPorts = false

    /// A sweep that lands after a newer one started is dropped rather than shown.
    @ObservationIgnored private var generation = 0

    func load(excluding ownPID: Int32) {
        generation += 1
        let current = generation
        isLoadingProcesses = true
        isLoadingPorts = true
        Task {
            let swept = await Task.detached { ProcessSweep.processes() }.value
            guard current == generation else { return }
            processes = swept.filter { $0.pid != ownPID }
            isLoadingProcesses = false
        }
        Task {
            let swept = await Task.detached { ProcessSweep.ports() }.value
            guard current == generation else { return }
            ports = swept.filter { $0.pid != ownPID }
            isLoadingPorts = false
        }
    }

    /// Off the list at once, so the row goes when the signal does rather than at the next sweep.
    func forget(_ pid: Int32) {
        processes.removeAll { $0.pid == pid }
        ports.removeAll { $0.pid == pid }
    }
}
