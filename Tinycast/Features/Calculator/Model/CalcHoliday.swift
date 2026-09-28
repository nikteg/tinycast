import Foundation

/// Named holidays a date phrase may use: fixed days, and the movable feasts computed per year.
enum CalcHoliday {
    private enum Rule {
        case fixed(month: Int, day: Int)
        case easter(offset: Int)
        case orthodoxEaster(offset: Int)
        /// The `ordinal`-th `weekday` (Sunday = 1) of `month`, shifted by `offset` days.
        case nthWeekday(month: Int, weekday: Int, ordinal: Int, offset: Int)
        /// The Swedish midsummer eve: the Friday between 19 and 25 June.
        case midsummer(offset: Int)
    }

    /// The holiday a phrase names and the year it was written with, if any: `easter 2027`.
    static func parse(_ phrase: String) -> (rule: String, year: Int?)? {
        var words = phrase.filter { $0 != "'" && $0 != "’" }.split(separator: " ")
        var year: Int?
        if let last = words.last, last.count == 4, let value = Int(last), words.count > 1 {
            year = value
            words.removeLast()
        }
        let name = words.joined(separator: " ")
        return rules[name] == nil ? nil : (name, year)
    }

    /// The first word of every holiday name, so the keyword pass can flag a moment cheaply.
    static let keywords: Set<String> = Set(rules.keys.compactMap { $0.split(separator: " ").first.map(String.init) })

    static func date(_ name: String, year: Int, calendar: Calendar) -> Date? {
        guard let rule = rules[name], (1...9999).contains(year) else { return nil }
        switch rule {
        case .fixed(let month, let day):
            return makeDay(year, month, day, calendar)
        case .easter(let offset):
            let (month, day) = gregorianEaster(year)
            return shifted(makeDay(year, month, day, calendar), by: offset, calendar)
        case .orthodoxEaster(let offset):
            // The Julian calendar runs 13 days behind the Gregorian from 1900 to 2099.
            guard (1900...2099).contains(year) else { return nil }
            let (month, day) = julianEaster(year)
            return shifted(makeDay(year, month, day, calendar), by: offset + 13, calendar)
        case .nthWeekday(let month, let weekday, let ordinal, let offset):
            guard let first = makeDay(year, month, 1, calendar) else { return nil }
            let lead = (weekday - calendar.component(.weekday, from: first) + 7) % 7
            return shifted(first, by: lead + 7 * (ordinal - 1) + offset, calendar)
        case .midsummer(let offset):
            guard let start = makeDay(year, 6, 19, calendar) else { return nil }
            let lead = (6 - calendar.component(.weekday, from: start) + 7) % 7
            return shifted(start, by: lead + offset, calendar)
        }
    }

    private static func makeDay(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func shifted(_ date: Date?, by days: Int, _ calendar: Calendar) -> Date? {
        date.flatMap { calendar.date(byAdding: .day, value: days, to: $0) }
    }

    /// The anonymous Gregorian computus.
    private static func gregorianEaster(_ year: Int) -> (month: Int, day: Int) {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let n = h + l - 7 * m + 114
        return (n / 31, n % 31 + 1)
    }

    /// Meeus' Julian computus, as a Julian-calendar date.
    private static func julianEaster(_ year: Int) -> (month: Int, day: Int) {
        let d = (19 * (year % 19) + 15) % 30
        let e = (2 * (year % 4) + 4 * (year % 7) - d + 34) % 7
        let n = d + e + 114
        return (n / 31, n % 31 + 1)
    }

    private static let rules: [String: Rule] = [
        "christmas": .fixed(month: 12, day: 25), "christmas day": .fixed(month: 12, day: 25),
        "xmas": .fixed(month: 12, day: 25), "xmas day": .fixed(month: 12, day: 25),
        "christmas eve": .fixed(month: 12, day: 24), "xmas eve": .fixed(month: 12, day: 24),
        "boxing day": .fixed(month: 12, day: 26),
        "new year": .fixed(month: 1, day: 1), "new years": .fixed(month: 1, day: 1),
        "new years day": .fixed(month: 1, day: 1), "new year day": .fixed(month: 1, day: 1),
        "new years eve": .fixed(month: 12, day: 31), "new year eve": .fixed(month: 12, day: 31),
        "nye": .fixed(month: 12, day: 31),
        "halloween": .fixed(month: 10, day: 31),
        "valentines": .fixed(month: 2, day: 14), "valentines day": .fixed(month: 2, day: 14),
        "valentine day": .fixed(month: 2, day: 14),
        "easter": .easter(offset: 0), "easter sunday": .easter(offset: 0), "easter day": .easter(offset: 0),
        "good friday": .easter(offset: -2), "holy saturday": .easter(offset: -1),
        "easter saturday": .easter(offset: -1), "easter monday": .easter(offset: 1),
        "ascension": .easter(offset: 39), "ascension day": .easter(offset: 39),
        "pentecost": .easter(offset: 49), "whitsun": .easter(offset: 49),
        "orthodox easter": .orthodoxEaster(offset: 0), "orthodox good friday": .orthodoxEaster(offset: -2),
        "orthodox christmas": .fixed(month: 1, day: 7),
        "thanksgiving": .nthWeekday(month: 11, weekday: 5, ordinal: 4, offset: 0),
        "black friday": .nthWeekday(month: 11, weekday: 5, ordinal: 4, offset: 1),
        "midsummer": .midsummer(offset: 0), "midsummer eve": .midsummer(offset: 0),
        "midsummer day": .midsummer(offset: 1)
    ]
}
