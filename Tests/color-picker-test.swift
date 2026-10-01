import Foundation

@main
@MainActor
struct ColorPickerTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        formatsEveryNotation()
        readsUnitChannels()
        keepsEachColourOnce()
        matchesAQuery()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func color(_ red: Int, _ green: Int, _ blue: Int) -> PickedColor {
        PickedColor(red: red, green: green, blue: blue, pickedAt: now)
    }

    static func formatsEveryNotation() {
        let orange = color(255, 136, 0)
        expect(orange.formatted(.hex) == "#FF8800", "hex, upper case")
        expect(orange.formatted(.rgba) == "rgba(255, 136, 0, 1)", "rgba")
        expect(orange.formatted(.hsl).hasPrefix("hsl(32"), "hsl — got \(orange.formatted(.hsl))")
        expect(orange.formats == [.hex, .rgba, .hsl, .oklch], "an opaque colour offers no alpha rows")
        expect(color(300, -4, 16).hex == "#FF0010", "channels clamp to a byte")
        for channel in 0...255 {
            let grey = color(channel, channel, channel)
            if ColorValue.parse(grey.hex).map({ PickedColor(
                red: $0.red, green: $0.green, blue: $0.blue, pickedAt: now).hex }) != grey.hex {
                expect(false, "\(grey.hex) survives a round trip through ColorValue")
            }
        }
    }

    static func readsUnitChannels() {
        let picked = PickedColor(red: 1.0, green: 0.5, blue: 1.2, pickedAt: now)
        expect(picked.red == 255 && picked.green == 128 && picked.blue == 255, "rounded and clamped")
    }

    static func keepsEachColourOnce() {
        let first = color(1, 2, 3)
        let second = color(4, 5, 6)
        var history = ColorHistory.adding(first, to: [])
        history = ColorHistory.adding(second, to: history)
        expect(history.map(\.hex) == [second.hex, first.hex], "newest first")
        let again = color(1, 2, 3)
        history = ColorHistory.adding(again, to: history)
        expect(history.map(\.id) == [again.id, second.id], "a repeat moves to the top, once")
        var full: [PickedColor] = []
        for index in 0..<(ColorHistory.limit + 5) {
            full = ColorHistory.adding(color(index % 256, index / 256, 0), to: full)
        }
        expect(full.count == ColorHistory.limit, "the history is capped")
    }

    static func matchesAQuery() {
        let orange = color(255, 136, 0)
        expect(orange.matches(""), "empty matches all")
        expect(orange.matches("ff88") && orange.matches("#FF8800"), "hex, with or without #")
        expect(orange.matches("136"), "a channel")
        expect(!orange.matches("00ff"), "not another colour")
    }
}
