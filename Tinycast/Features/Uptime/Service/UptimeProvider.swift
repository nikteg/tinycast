import Foundation

/// The same three system reads `uptime` makes: `kern.boottime`, utmpx sessions and `getloadavg`.
enum UptimeProvider {
    static func current(now: Date = .now) -> UptimeReport? {
        guard let booted = bootTime() else { return nil }
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else { return nil }
        return UptimeReport(
            clock: now.formatted(date: .omitted, time: .shortened),
            sinceBoot: now.timeIntervalSince(booted),
            users: signedInSessions(),
            loadAverages: loads)
    }

    private static func bootTime() -> Date? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(boot.tv_sec) + TimeInterval(boot.tv_usec) / 1e6)
    }

    private static func signedInSessions() -> Int {
        setutxent()
        defer { endutxent() }
        var count = 0
        while let entry = getutxent() {
            if entry.pointee.ut_type == USER_PROCESS { count += 1 }
        }
        return count
    }
}
