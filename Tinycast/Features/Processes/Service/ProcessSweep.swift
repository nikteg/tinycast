import Darwin
import Foundation

/// Reads processes from the kernel and listeners from `netstat`, never from a rewritable argv[0].
enum ProcessSweep {
    /// The reader's own processes, the only ones a signal from Tinycast could reach.
    nonisolated static func reading(excluding ownPID: Int32) -> ProcessReading {
        let takenAt = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let samples = kernelProcesses(uid: getuid()).compactMap { info -> ProcessSample? in
            let pid = info.kp_proc.p_pid
            guard pid > 0, pid != ownPID, Int32(info.kp_proc.p_stat) != SZOMB,
                let path = executablePath(pid)
            else { return nil }
            var usage = rusage_info_v4()
            let status = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard status == 0 else { return nil }
            return ProcessSample(
                identity: ProcessIdentity(pid: pid, startedAt: startedAt(info)), path: path,
                cpuNanoseconds: nanoseconds(ticks: usage.ri_user_time &+ usage.ri_system_time),
                memoryBytes: Int64(clamping: usage.ri_phys_footprint))
        }
        return ProcessReading(samples: samples, takenAtNanoseconds: takenAt)
    }

    /// Every TCP listener on the Mac, root's included, since `netstat` names each socket's pid.
    nonisolated static func ports(excluding ownPID: Int32) -> [ListeningPort] {
        let reader = getuid()
        return ListeningPort.parse(netstatOutput: run("/usr/sbin/netstat", ["-anv", "-p", "tcp"]))
            .filter { $0.pid != ownPID }
            .map { listener in
                var listener = listener
                guard let info = kernelProcess(listener.pid) else { return listener }
                listener.path = executablePath(listener.pid)
                let uid = info.kp_eproc.e_ucred.cr_uid
                listener.holder =
                    uid == reader
                    ? .reader(ProcessIdentity(pid: listener.pid, startedAt: startedAt(info)))
                    : .otherUser(userName(uid))
                return listener
            }
    }

    /// Nil once the pid has exited.
    nonisolated static func startedAt(_ pid: Int32) -> UInt64? {
        kernelProcess(pid).map(startedAt)
    }

    // MARK: - Kernel

    nonisolated private static func kernelProcess(_ pid: Int32) -> kinfo_proc? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        // A pid that no longer exists still succeeds, only with nothing written.
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info
    }

    nonisolated private static func kernelProcesses(uid: uid_t) -> [kinfo_proc] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(bitPattern: uid)]
        let stride = MemoryLayout<kinfo_proc>.stride
        // The table can grow between measuring and reading it, so a short read is retried.
        for _ in 0..<3 {
            var size = 0
            guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [] }
            var processes = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 16)
            size = processes.count * stride
            if sysctl(&mib, 4, &processes, &size, nil, 0) == 0 {
                return Array(processes.prefix(size / stride))
            }
            guard errno == ENOMEM else { return [] }
        }
        return []
    }

    nonisolated private static func startedAt(_ info: kinfo_proc) -> UInt64 {
        let start = info.kp_proc.p_un.__p_starttime
        return UInt64(max(start.tv_sec, 0)) * 1_000_000 + UInt64(max(start.tv_usec, 0))
    }

    nonisolated private static func executablePath(_ pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(bytes: buffer.prefix(Int(length)), encoding: .utf8)
    }

    nonisolated private static func userName(_ uid: uid_t) -> String {
        var entry = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 1024)
        guard getpwuid_r(uid, &entry, &buffer, buffer.count, &result) == 0, result != nil,
            let name = entry.pw_name
        else { return "uid \(uid)" }
        return String(cString: name)
    }

    /// Rusage counts CPU time in Mach ticks, which are not nanoseconds on Apple silicon.
    nonisolated private static let nanosecondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom != 0 else { return 1 }
        return Double(timebase.numer) / Double(timebase.denom)
    }()

    nonisolated private static func nanoseconds(ticks: UInt64) -> UInt64 {
        UInt64(Double(ticks) * nanosecondsPerTick)
    }

    /// Output is drained before the exit is awaited, so a full pipe can never stall the child.
    nonisolated private static func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard let exit = try? process.runObservingExit() else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        exit.wait()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}
