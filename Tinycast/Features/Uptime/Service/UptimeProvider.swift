import Foundation

/// The boot moment from `kern.boottime`, the same clock `uptime` reads.
enum UptimeProvider {
    static func current(now: Date = .now) -> UptimeReport? {
        guard let booted = bootTime() else { return nil }
        let style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
            .hour().minute()
        return UptimeReport(sinceBoot: now.timeIntervalSince(booted), booted: booted.formatted(style))
    }

    private static func bootTime() -> Date? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(boot.tv_sec) + TimeInterval(boot.tv_usec) / 1e6)
    }
}
