import Foundation

/// Processes and listening ports, swept while either screen shows and cleared on every open.
@MainActor
@Observable
final class ProcessSession {
    private(set) var processes: [RunningProcess] = []
    private(set) var ports: [ListeningPort] = []
    private(set) var hasSwept = false
    /// Bumped whenever rows change under the reader, so a screen can keep its highlight on its row.
    private(set) var revision = 0

    @ObservationIgnored private var lastReading: ProcessReading?
    @ObservationIgnored private var dueAt = ContinuousClock.now
    @ObservationIgnored private var resorts = true
    /// A sweep that lands after a reset or a newer sweep is dropped rather than shown.
    @ObservationIgnored private var generation = 0

    static let refreshInterval: Duration = .seconds(2)
    /// The first CPU column needs two readings; this gap is short enough not to read as a wait.
    private static let firstWindow: Duration = .milliseconds(250)
    private static let tick: Duration = .milliseconds(200)
    private static let afterSignal: Duration = .milliseconds(500)

    /// Each open starts clean, so rows from an earlier visit never stand in for current ones.
    func reset() {
        generation += 1
        processes = []
        ports = []
        hasSwept = false
        lastReading = nil
        resorts = true
        dueAt = .now
        revision += 1
    }

    /// ⌘R: sweep at once, and sort by load afresh.
    func reload() {
        resorts = true
        dueAt = .now
    }

    /// Soon after a signal, so a process that ignored it comes back rather than staying hidden.
    func sweepSoon() {
        dueAt = min(dueAt, .now + Self.afterSignal)
    }

    /// Off the list at once, so the row goes when the signal does rather than at the next sweep.
    func forget(_ pid: Int32) {
        processes.removeAll { $0.pid == pid }
        ports.removeAll { $0.pid == pid }
        revision += 1
    }

    /// Sweeps for as long as the caller's task lives: the screen's own, which ends when it hides.
    func keepCurrent(excluding ownPID: Int32) async {
        while !Task.isCancelled {
            if ContinuousClock.now >= dueAt { await sweep(excluding: ownPID) }
            try? await Task.sleep(for: Self.tick)
        }
    }

    private func sweep(excluding ownPID: Int32) async {
        generation += 1
        let current = generation
        dueAt = .now + Self.refreshInterval
        var baseline = lastReading
        if baseline == nil {
            baseline = await Self.readProcesses(excluding: ownPID)
            try? await Task.sleep(for: Self.firstWindow)
        }
        async let reading = Self.readProcesses(excluding: ownPID)
        async let listeners = Self.readPorts(excluding: ownPID)
        let (fresh, swept) = await (reading, listeners)
        guard current == generation, !Task.isCancelled else { return }
        let measured = RunningProcess.measure(fresh, since: baseline)
        processes = RunningProcess.arranged(measured, keepingOrderOf: resorts ? [] : processes)
        ports = swept
        lastReading = fresh
        resorts = false
        hasSwept = true
        revision += 1
    }

    @concurrent nonisolated private static func readProcesses(excluding ownPID: Int32) async -> ProcessReading {
        ProcessSweep.reading(excluding: ownPID)
    }

    @concurrent nonisolated private static func readPorts(excluding ownPID: Int32) async -> [ListeningPort] {
        ProcessSweep.ports(excluding: ownPID)
    }
}
