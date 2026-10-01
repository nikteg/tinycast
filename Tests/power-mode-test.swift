import Foundation

@main
@MainActor
struct PowerModeTests {
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
        readsTheBatterySection()
        toggles()
        namesTheHelper()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static let laptop = """
        Battery Power:
         Sleep On Power Button 1
         powermode            1
         displaysleep         5
        AC Power:
         Sleep On Power Button 1
         powermode            0
         displaysleep         20
        """

    static func readsTheBatterySection() {
        expect(PowerMode.battery(pmsetCustom: laptop) == .low, "the battery's, not the adapter's")
        let flipped = laptop.replacingOccurrences(of: "powermode            1", with: "powermode            2")
        expect(PowerMode.battery(pmsetCustom: flipped) == .high, "high power")
        let desktop = "AC Power:\n powermode            1\n"
        expect(PowerMode.battery(pmsetCustom: desktop) == nil, "no battery, no mode")
        expect(PowerMode.battery(pmsetCustom: "") == nil, "nothing read")
    }

    static func toggles() {
        expect(PowerMode.automatic.toggled == .low, "automatic to low")
        expect(PowerMode.low.toggled == .automatic, "low back to automatic")
        expect(PowerMode.high.toggled == .low, "high counts as not low")
    }

    static func namesTheHelper() {
        expect(
            PowerModeHelperMessage.label(forApp: "com.tinycast.app.dev")
                == "com.tinycast.app.dev.power-mode", "each channel names its own job")
        expect(
            PowerModeHelperMessage.plistName(forApp: "com.tinycast.app")
                == "com.tinycast.app.power-mode.plist", "the plist the build script writes")
        let request = try? JSONDecoder().decode(
            PowerModeHelperMessage.Request.self,
            from: JSONEncoder().encode(PowerModeHelperMessage.Request(mode: .low)))
        expect(request?.mode == .low, "a request round-trips")
    }
}
