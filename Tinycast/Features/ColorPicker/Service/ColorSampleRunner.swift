import AppKit

/// The system eyedropper: a loupe over every display, answering the colour under it or nil.
@MainActor
final class ColorSampleRunner {
    /// Held for the loupe's lifetime; AppKit drops the sample when the sampler goes first.
    private var sampler: NSColorSampler?

    var isSampling: Bool { sampler != nil }

    func sample(now: Date = Date()) async -> PickedColor? {
        let sampler = NSColorSampler()
        self.sampler = sampler
        defer { self.sampler = nil }
        let color = await withCheckedContinuation { continuation in
            sampler.show { continuation.resume(returning: $0) }
        }
        guard let srgb = color?.usingColorSpace(.sRGB) else { return nil }
        return PickedColor(
            red: Double(srgb.redComponent), green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent), pickedAt: now)
    }
}
