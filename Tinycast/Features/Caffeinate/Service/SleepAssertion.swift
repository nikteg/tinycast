import IOKit.pwr_mgt

/// While held, the display — and so the Mac — never idles to sleep. Exiting releases it.
@MainActor
final class SleepAssertion {
    private var id: IOPMAssertionID?

    var isHeld: Bool { id != nil }

    /// False when the power manager refused, which leaves nothing held.
    func hold(reason: String) -> Bool {
        guard id == nil else { return true }
        var assertion = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &assertion)
        guard result == kIOReturnSuccess else { return false }
        id = assertion
        return true
    }

    func release() {
        guard let id else { return }
        IOPMAssertionRelease(id)
        self.id = nil
    }
}
