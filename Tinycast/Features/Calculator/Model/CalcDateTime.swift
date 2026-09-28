import Foundation

enum CalcDateTime {
    /// Which occurrence of a bare, recurring date/time a phrase resolves to.
    private enum MomentBias { case future, past, nearest }

    static func evaluate(
        _ raw: String, now: Date, calendar: Calendar
    )
        -> CalcResult?
    {
        let echo = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = echo.lowercased()
        guard !lowered.isEmpty else { return nil }
        if factSubjects.contains(lowered.prefix { $0 != " " }),
            let fact = dateFact(normalized(lowered), echo: echo, now: now, calendar: calendar)
        {
            return fact
        }

        // One pass over the words, since an app search pays this on every keystroke.
        let signals = keywordSignals(lowered)
        let hasDigit = signals.contains(.digit)
        let hasUntil = signals.contains(.until)
        let hasSince = signals.contains(.since)
        let hasArith = signals.contains(.arithmetic) && signals.contains(.moment)
        let hasFromAgo = signals.contains(.fromAgo)
        let hasIn = signals.contains(.inWord)
        let hasTimestamp = signals.contains(.timestamp)
        // A named moment needs a qualifier: a lone `tomorrow` is an app search.
        let isBareMoment =
            signals.contains(.at) || signals.contains(.nextOrLast)
            || (hasDigit && signals.contains(.dayName) && namesADay(lowered))
            || (hasDigit && signals.contains(.holiday) && CalcHoliday.parse(lowered)?.year != nil)
            || CalcTimestamp.looksLikeISO(lowered)
        let hasRange = signals.contains(.range) && signals.contains(.moment)
        guard hasUntil || hasSince || hasArith || hasFromAgo || hasIn || hasRange || isBareMoment || hasTimestamp
        else {
            return nil
        }

        let query = normalized(lowered)
        if hasTimestamp || query.hasSuffix(" to date") && CalcTimestamp.looksLikeISO(query),
            let result = parseTimestamp(query, echo: echo, now: now, calendar: calendar)
        {
            return result
        }
        if hasUntil, let result = parseUntil(query, echo: echo, now: now, calendar: calendar) {
            return result
        }
        if hasSince, let result = parseSince(query, echo: echo, now: now, calendar: calendar) {
            return result
        }
        if hasArith, let result = parseArithmetic(query, echo: echo, now: now, calendar: calendar) {
            return result
        }
        if hasFromAgo, let result = parseOffset(query, echo: echo, now: now, calendar: calendar) {
            return result
        }
        if hasRange || hasFromAgo, let result = parseRange(query, echo: echo, now: now, calendar: calendar) {
            return result
        }
        if hasIn, let result = parseWeekdayIn(query, echo: echo, now: now, calendar: calendar) {
            return result
        }
        if isBareMoment, let result = bareMoment(query, echo: echo, now: now, calendar: calendar) {
            return result
        }
        return nil
    }

    private struct Signals: OptionSet {
        let rawValue: Int
        static let digit = Signals(rawValue: 1 << 0)
        static let until = Signals(rawValue: 1 << 1)
        static let since = Signals(rawValue: 1 << 2)
        static let arithmetic = Signals(rawValue: 1 << 3)
        static let fromAgo = Signals(rawValue: 1 << 4)
        static let inWord = Signals(rawValue: 1 << 5)
        static let at = Signals(rawValue: 1 << 6)
        static let nextOrLast = Signals(rawValue: 1 << 7)
        static let timestamp = Signals(rawValue: 1 << 8)
        static let moment = Signals(rawValue: 1 << 9)
        static let dayName = Signals(rawValue: 1 << 10)
        static let range = Signals(rawValue: 1 << 11)
        static let holiday = Signals(rawValue: 1 << 12)
    }

    /// Whitespace collapsed, and the comma of `April 1, 2019` dropped: no date grammar reads it.
    private static func normalized(_ lowered: String) -> String {
        lowered.split(whereSeparator: \.isWhitespace).map { word in
            word.count > 1 && word.last == "," ? word.dropLast() : word
        }.joined(separator: " ")
    }

    private static func keywordSignals(_ query: String) -> Signals {
        var signals: Signals = []
        let words = query.split(whereSeparator: \.isWhitespace)
        for (index, word) in words.enumerated() {
            let isFirst = index == 0
            let isLast = index == words.count - 1
            switch word {
            case "till", "until", "til": if !isFirst, !isLast { signals.insert(.until) }
            case "since": if !isFirst, !isLast { signals.insert(.since) }
            case "+", "-": if !isFirst, !isLast { signals.insert(.arithmetic) }
            case "from", "after", "before": if !isFirst, !isLast { signals.insert(.fromAgo) }
            case "ago": if !isFirst { signals.insert(.fromAgo) }
            case "to", "through", "between": if !isLast { signals.insert(.range) }
            case "in": if !isFirst, !isLast { signals.insert(.inWord) }
            case "at": if !isFirst, !isLast { signals.insert(.at) }
            case "next", "last": if isFirst { signals.insert(.nextOrLast) }
            case "unix", "timestamp": signals.formUnion([.timestamp, .moment])
            default: break
            }
            var dots = 0
            var dashes = 0
            for byte in word.utf8 {
                if (48...57).contains(byte) { signals.insert(.digit) }
                if byte == 46 { dots += 1 }
                if byte == 45 { dashes += 1 }
                if byte == 58 || byte == 47 { signals.insert(.moment) }
            }
            if dots >= 2 { signals.formUnion([.dayName, .moment]) }
            if dashes >= 2 { signals.insert(.moment) }
            for letters in word.utf8.split(whereSeparator: { !(97...122).contains($0) }) {
                let name = String(bytes: letters, encoding: .utf8)!
                if monthByName[name] != nil { signals.formUnion([.dayName, .moment]) }
                if weekdayByName[name] != nil { signals.insert(.moment) }
                if CalcHoliday.keywords.contains(name) { signals.formUnion([.holiday, .moment]) }
                switch name {
                case "now", "today", "tomorrow", "yesterday", "noon", "midnight", "am", "pm":
                    signals.insert(.moment)
                default: break
                }
            }
        }
        return signals
    }

    /// A day number beside a month, which no app search looks like — `25. aug`, `aug 25`.
    private static func namesADay(_ query: String) -> Bool {
        let atoms = atomize(query)
        guard atoms.count == 2 || atoms.count == 3 else { return atoms.count == 1 && isDottedDate(atoms) }
        let months = atoms.filter { monthByName[$0] != nil }.count
        let days = atoms.filter { ordinalDay($0) != nil }.count
        return months == 1 && days == atoms.count - 1
    }

    /// `25.8.27` on its own: three dotted parts, which cannot be read as one number.
    private static func isDottedDate(_ atoms: [String]) -> Bool {
        guard let only = atoms.first else { return false }
        let parts = only.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[2].count == 2 || parts[2].count == 4 else { return false }
        return parts.allSatisfy { Int($0) != nil }
    }

    /// `next monday`, `tomorrow`, `tomorrow at 9am` — a moment named without any arithmetic.
    private static func bareMoment(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        guard let moment = parseMoment(query, now: now, calendar: calendar, bias: .nearest)
        else { return nil }
        let date = moment.date
        let hasTime = moment.hasTime
        let text = answerString(date, hasTime: hasTime, now: now, calendar: calendar)
        return CalcResult(
            expression: echo,
            sourceBadge: dateString(now, now: now, calendar: calendar),
            targetBadge: weekdayName(date, calendar: calendar),
            payload: .value(display: text, copyText: text))
    }

    /// `9am`, `5:30pm`, `14:00` as a wall clock, with no bias applied.
    private static func parseMeridiemClock(_ text: String) -> (hour: Int, minute: Int)? {
        if text == "noon" { return (12, 0) }
        if text == "midnight" { return (0, 0) }
        var body = text
        var meridiem: String?
        for suffix in ["am", "pm"] where body.hasSuffix(suffix) {
            meridiem = suffix
            body.removeLast(2)
        }
        body = body.trimmingCharacters(in: .whitespaces)
        guard let (hour, minute) = parseClock(body) else { return nil }
        guard let meridiem else {
            return (0...23).contains(hour) ? (hour, minute) : nil
        }
        guard (1...12).contains(hour) else { return nil }
        return (meridiem == "pm" ? (hour % 12) + 12 : hour % 12, minute)
    }

    /// `monday in 3 weeks` — that weekday, in the week the duration lands in.
    private static func parseWeekdayIn(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        guard let range = query.range(of: " in ") else { return nil }
        let head = String(query[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard let weekday = weekdayByName[head],
            let durations = parseDurations(String(query[range.upperBound...])),
            durations.count == 1, let duration = durations.first,
            !duration.subDay, !duration.businessDays,
            let landing = calendar.date(
                byAdding: duration.component, value: duration.count,
                to: calendar.startOfDay(for: now))
        else { return nil }

        // The weekday inside the landing week, so `monday in 3 weeks` is that week's Monday.
        guard let week = calendar.dateInterval(of: .weekOfYear, for: landing),
            let result = shift(
                week.start, days: (weekday - calendar.firstWeekday + 7) % 7, calendar: calendar)
        else { return nil }

        let text = answerString(result, hasTime: false, now: now, calendar: calendar)
        return CalcResult(
            expression: echo,
            sourceBadge: dateString(now, now: now, calendar: calendar),
            targetBadge: weekdayName(result, calendar: calendar),
            payload: .value(display: text, copyText: text))
    }

    /// `5 weekdays from now`, `3 days from today`, `2 weeks ago` — the duration leads.
    private static func parseOffset(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        let durationText: String
        let anchorText: String
        let sign: Int
        if let (range, connector) = [" from ", " after ", " before "].lazy
            .compactMap({ connector in query.range(of: connector).map { ($0, connector) } }).first
        {
            durationText = String(query[..<range.lowerBound])
            anchorText = String(query[range.upperBound...])
            sign = connector == " before " ? -1 : 1
        } else if query.hasSuffix(" ago") {
            durationText = String(query.dropLast(4))
            anchorText = ""
            sign = -1
        } else {
            return nil
        }

        guard let durations = parseDurations(durationText) else { return nil }
        let subDay = durations.contains(where: \.subDay)
        let anchorPhrase = anchorText.isEmpty ? (subDay ? "now" : "today") : anchorText
        guard let anchor = parseMoment(anchorPhrase, now: now, calendar: calendar, bias: .nearest),
            let shifted = shift(anchor, by: durationText, op: sign < 0 ? "-" : "+", calendar: calendar)
        else { return nil }
        let result = shifted.date
        let hasTime = shifted.hasTime && (subDay || anchorPhrase != "now")
        let display = answerString(result, hasTime: hasTime, now: now, calendar: calendar)
        return CalcResult(
            expression: echo,
            sourceBadge: momentString(
                anchor.date, hasTime: hasTime, now: now, calendar: calendar),
            targetBadge: weekdayName(result, calendar: calendar),
            payload: .value(
                display: display, copyText: display))
    }

    private static func parseUntil(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        guard let connector = [" until ", " till ", " til "].first(where: query.contains) else { return nil }
        return parseInterval(
            query, connector: connector, past: false, echo: echo, now: now, calendar: calendar)
    }

    private static func parseSince(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        parseInterval(query, connector: " since ", past: true, echo: echo, now: now, calendar: calendar)
    }

    private static func parseInterval(
        _ query: String, connector: String, past: Bool, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        let parts = query.components(separatedBy: connector)
        if parts.count == 2, parts[0] == "time",
            let moment = parseMoment(parts[1], now: now, calendar: calendar, bias: past ? .past : .future)
        {
            let text = CalcFormatter.timespan(abs(moment.date.timeIntervalSince(now)))
            let (start, end) = past ? (moment.date, now) : (now, moment.date)
            return CalcResult(
                expression: echo, sourceBadge: momentString(start, hasTime: true, now: now, calendar: calendar),
                targetBadge: momentString(end, hasTime: true, now: now, calendar: calendar),
                payload: .value(display: text, copyText: text))
        }
        guard parts.count == 2, let unit = durationUnit(parts[0]),
            let moment = parseMoment(parts[1], now: now, calendar: calendar, bias: past ? .past : .future)
        else { return nil }
        let reference = unit.subDay ? now : calendar.startOfDay(for: now)
        let target = unit.subDay ? moment.date : calendar.startOfDay(for: moment.date)
        return measured(
            unit, from: past ? target : reference, to: past ? reference : target, echo: echo, now: now,
            calendar: calendar)
    }

    /// `start` to `end` counted in `unit`: whole calendar days, weekdays, or elapsed time.
    private static func measured(
        _ unit: DurUnit, from start: Date, to end: Date, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult {
        let value: Double
        switch unit.kind {
        case .day, .week:
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            value = Double(days) / (unit.kind == .week ? 7 : 1)
        case .workday:
            value = Double(countWorkdays(from: start, to: end, calendar: calendar))
        case .subSecond:
            value = end.timeIntervalSince(start) / unit.seconds
        }
        let word = abs(value) == 1 ? unit.singular : unit.plural
        return CalcResult(
            expression: echo,
            sourceBadge: unit.subDay
                ? timeString(start, calendar: calendar) : dateString(start, now: now, calendar: calendar),
            targetBadge: unit.subDay
                ? timeString(end, calendar: calendar) : dateString(end, now: now, calendar: calendar),
            payload: .number(value, suffix: " \(word)"))
    }

    // MARK: - Ranges: `3 march to 30 may`, `days between x and y`, `workdays from x to y`

    private static func parseRange(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        var phrase = Substring(query)
        var unit: DurUnit?
        if let range = phrase.range(of: " in ", options: .backwards),
            !phrase[range.upperBound...].contains(" "),
            let named = durationUnit(String(phrase[range.upperBound...]))
        {
            unit = named
            phrase = phrase[..<range.lowerBound]
        }
        let words = phrase.split(separator: " ", maxSplits: 1)
        if words.count == 2, let named = durationUnit(String(words[0])),
            words[1].hasPrefix("between ") || words[1].hasPrefix("from ")
        {
            guard unit == nil else { return nil }
            unit = named
            phrase = words[1]
        }
        let connectors: [(lead: String, split: String)] = [
            ("between ", " and "), ("from ", " to "), ("", " to "), ("", " through ")
        ]
        guard let (lead, split) = connectors.first(where: { phrase.hasPrefix($0.lead) && phrase.contains($0.split) })
        else { return nil }
        let parts = phrase.dropFirst(lead.count).components(separatedBy: split)
        guard parts.count == 2,
            let first = parseMoment(parts[0], now: now, calendar: calendar, bias: .nearest),
            var last = parseMoment(parts[1], now: now, calendar: calendar, bias: .nearest)
        else { return nil }
        let hasTime = first.hasTime || last.hasTime
        // Letter-free slashes are fractions, as in grammar D: `1/2 to 3/4` is no date range.
        guard hasTime || parts.joined().contains(where: \.isLetter) || !phrase.contains("/") else { return nil }
        // A clock range runs forward, so `4pm to 3am` is the night between them.
        if hasTime, lead != "between ", last.date < first.date,
            calendar.isDate(first.date, inSameDayAs: last.date),
            let next = calendar.date(byAdding: .day, value: 1, to: last.date)
        {
            last = Moment(date: next, hasTime: true)
        }
        let (start, end) = first.date <= last.date ? (first.date, last.date) : (last.date, first.date)
        let inclusive = split == " through " ? shift(calendar.startOfDay(for: end), days: 1, calendar: calendar) : nil
        if let unit {
            let whole = !unit.subDay
            var result = measured(
                unit, from: whole ? calendar.startOfDay(for: start) : start,
                to: inclusive ?? (whole ? calendar.startOfDay(for: end) : end), echo: echo, now: now,
                calendar: calendar)
            if inclusive != nil {
                result = CalcResult(
                    expression: echo, sourceBadge: result.sourceBadge,
                    targetBadge: dateString(end, now: now, calendar: calendar), payload: result.payload)
            }
            return result
        }
        let text =
            hasTime
            ? CalcFormatter.timespan(end.timeIntervalSince(start))
            : calendarSpan(from: start, to: inclusive ?? end, calendar: calendar)
        return CalcResult(
            expression: echo,
            sourceBadge: momentString(start, hasTime: hasTime, now: now, calendar: calendar),
            targetBadge: momentString(end, hasTime: hasTime, now: now, calendar: calendar),
            payload: .value(display: text, copyText: text))
    }

    /// Monday to Friday in `[start, end)`; whole weeks count five without walking them.
    private static func countWorkdays(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard days > 0 else { return days < 0 ? -countWorkdays(from: end, to: start, calendar: calendar) : 0 }
        var count = days / 7 * 5
        var cursor = shift(start, days: days / 7 * 7, calendar: calendar) ?? end
        while cursor < end {
            if !isWeekend(cursor, calendar: calendar) { count += 1 }
            guard let next = shift(cursor, days: 1, calendar: calendar) else { break }
            cursor = next
        }
        return count
    }

    // MARK: - Facts about a date: `week number`, `days in q3`, `weekday on 9 march 2024`

    /// The first words a fact can open with, checked before any other parsing.
    private static let factSubjects: Set<Substring> = [
        "week", "day", "weekday", "days", "workdays", "weekdays", "business", "working", "midpoint",
        "halfway", "midway", "year", "month"
    ]

    private static func dateFact(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        partOfDate(query, echo: echo, now: now, calendar: calendar)
            ?? daysInPeriod(query, echo: echo, now: now, calendar: calendar)
            ?? elapsedShare(query, echo: echo, now: now, calendar: calendar)
            ?? midpoint(query, echo: echo, now: now, calendar: calendar)
    }

    private enum DatePart { case isoWeek, dayOfYear, dayOfMonth, weekday }

    private static let datePartNames: [(name: String, part: DatePart)] = [
        ("week number", .isoWeek), ("week of the year", .isoWeek), ("week of year", .isoWeek),
        ("week no", .isoWeek), ("day of the year", .dayOfYear), ("day of year", .dayOfYear),
        ("day number", .dayOfYear), ("day of the month", .dayOfMonth), ("day of month", .dayOfMonth),
        ("day of the week", .weekday), ("day of week", .weekday), ("weekday", .weekday)
    ]

    /// `week number`, `day of year on 15 march 2024`: one part of a date, today's when none is named.
    private static func partOfDate(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        guard let (name, part) = datePartNames.first(where: { query == $0.name || query.hasPrefix($0.name + " ") })
        else { return nil }
        let rest = query.dropFirst(name.count).drop { $0 == " " }
        var date = now
        if !rest.isEmpty {
            guard let connector = ["on ", "of ", "for ", "in "].first(where: rest.hasPrefix),
                let moment = parseMoment(
                    String(rest.dropFirst(connector.count)), now: now, calendar: calendar, bias: .nearest)
            else { return nil }
            date = moment.date
        }
        let payload: CalcResult.Payload
        let badge: String
        switch part {
        case .isoWeek:
            var iso = Calendar(identifier: .iso8601)
            iso.timeZone = calendar.timeZone
            payload = .number(Double(iso.component(.weekOfYear, from: date)))
            badge = "ISO Week"
        case .dayOfYear:
            payload = .number(Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 0))
            badge = "Day of Year"
        case .dayOfMonth:
            payload = .number(Double(calendar.component(.day, from: date)))
            badge = "Day of Month"
        case .weekday:
            let name = weekdayName(date, calendar: calendar)
            payload = .value(display: name, copyText: name)
            badge = "Weekday"
        }
        return CalcResult(
            expression: echo, sourceBadge: dateString(date, now: now, calendar: calendar), targetBadge: badge,
            payload: payload)
    }

    /// `days in february 2028`, `workdays in q3`, `workdays in 3 weeks`.
    private static func daysInPeriod(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        guard let range = query.range(of: " in ") else { return nil }
        let head = query[..<range.lowerBound]
        let workdays = businessDayPhrases.contains(head.filter { $0 != " " })
        guard workdays || head == "days",
            let (start, end, label) = period(String(query[range.upperBound...]), now: now, calendar: calendar)
        else { return nil }
        let count =
            workdays
            ? countWorkdays(from: start, to: end, calendar: calendar)
            : calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let word = workdays ? (count == 1 ? "workday" : "workdays") : (count == 1 ? "day" : "days")
        return CalcResult(
            expression: echo, sourceBadge: label, targetBadge: workdays ? "Workdays" : "Days",
            payload: .number(Double(count), suffix: " \(word)"))
    }

    /// A span of whole days a phrase names — `q3`, `february 2028`, `2027`, `next month`, `3 weeks`.
    private static func period(
        _ phrase: String, now: Date, calendar: Calendar
    ) -> (start: Date, end: Date, label: String)? {
        let words = phrase.split(separator: " ").map(String.init)
        let current = calendar.component(.year, from: now)
        let year: Int
        let named: [String]
        if words.count == 2, words[1].count == 4, let value = Int(words[1]) {
            (year, named) = (value, [words[0]])
        } else {
            (year, named) = (current, words)
        }
        let first: (month: Int, months: Int, label: String)?
        switch named.count == 1 ? named[0] : "" {
        case "q1", "q2", "q3", "q4":
            let quarter = Int(String(named[0].last!))!
            first = ((quarter - 1) * 3 + 1, 3, "Q\(quarter) \(year)")
        case let name where monthByName[name] != nil:
            let month = monthByName[name]!
            let start = makeDate(year, month, 1, calendar)
            first = start.map { (month, 1, format($0, calendar: calendar, pattern: "MMMM yyyy")) }
        case let name where name.count == 4 && Int(name) != nil && named == words:
            return yearSpan(Int(name)!, calendar: calendar)
        default:
            first = nil
        }
        if let first {
            guard let start = makeDate(year, first.month, 1, calendar),
                let end = calendar.date(byAdding: .month, value: first.months, to: start)
            else { return nil }
            return (start, end, first.label)
        }
        if named.count == 2, let step = ["last": -1, "this": 0, "next": 1][named[0]] {
            return relativeSpan(named[1], step: step, now: now, calendar: calendar)
        }
        guard let durations = parseDurations(phrase), durations.allSatisfy({ !$0.subDay && !$0.businessDays })
        else { return nil }
        let start = calendar.startOfDay(for: now)
        var end = start
        for duration in durations {
            guard let next = calendar.date(byAdding: duration.component, value: duration.count, to: end)
            else { return nil }
            end = next
        }
        return (start, end, dateString(start, now: now, calendar: calendar))
    }

    private static func yearSpan(_ year: Int, calendar: Calendar) -> (start: Date, end: Date, label: String)? {
        guard let start = makeDate(year, 1, 1, calendar), let end = makeDate(year + 1, 1, 1, calendar)
        else { return nil }
        return (start, end, String(year))
    }

    /// `this week`, `next month`, `last quarter`, `this year`.
    private static func relativeSpan(
        _ unit: String, step: Int, now: Date, calendar: Calendar
    ) -> (start: Date, end: Date, label: String)? {
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        switch unit {
        case "week":
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: step, to: now),
                let week = calendar.dateInterval(of: .weekOfYear, for: anchor)
            else { return nil }
            return (week.start, week.end, dateString(week.start, now: now, calendar: calendar))
        case "month", "quarter":
            let months = unit == "month" ? 1 : 3
            let startMonth = unit == "month" ? month : (month - 1) / 3 * 3 + 1
            guard let base = makeDate(year, startMonth, 1, calendar),
                let start = calendar.date(byAdding: .month, value: step * months, to: base),
                let end = calendar.date(byAdding: .month, value: months, to: start)
            else { return nil }
            let label =
                unit == "month"
                ? format(start, calendar: calendar, pattern: "MMMM yyyy")
                : "Q\((calendar.component(.month, from: start) - 1) / 3 + 1) \(calendar.component(.year, from: start))"
            return (start, end, label)
        case "year":
            return yearSpan(year + step, calendar: calendar)
        default:
            return nil
        }
    }

    /// `year percentage`: how much of the current year, month, week or day has gone.
    private static func elapsedShare(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        let words = query.split(separator: " ")
        guard words.count == 2, words[1] == "percentage" || words[1] == "progress" else { return nil }
        let component: Calendar.Component
        let label: String
        switch words[0] {
        case "year":
            component = .year
            label = String(calendar.component(.year, from: now))
        case "month":
            component = .month
            label = format(now, calendar: calendar, pattern: "MMMM yyyy")
        case "week":
            component = .weekOfYear
            label = "This Week"
        case "day":
            component = .day
            label = dateString(now, now: now, calendar: calendar)
        default:
            return nil
        }
        guard let span = calendar.dateInterval(of: component, for: now), span.duration > 0 else { return nil }
        let text = String(format: "%.1f%%", now.timeIntervalSince(span.start) / span.duration * 100)
        return CalcResult(
            expression: echo, sourceBadge: label, targetBadge: "Elapsed",
            payload: .value(display: text, copyText: text))
    }

    /// `midpoint between 12 march and 5 april`, `halfway between today and next thursday`.
    private static func midpoint(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        guard let lead = ["midpoint between ", "halfway between ", "midway between "].first(where: query.hasPrefix)
        else { return nil }
        let parts = query.dropFirst(lead.count).components(separatedBy: " and ")
        guard parts.count == 2,
            let first = parseMoment(parts[0], now: now, calendar: calendar, bias: .nearest),
            let last = parseMoment(parts[1], now: now, calendar: calendar, bias: .nearest)
        else { return nil }
        let hasTime = first.hasTime || last.hasTime
        let (start, end) = first.date <= last.date ? (first.date, last.date) : (last.date, first.date)
        let middle: Date?
        if hasTime {
            middle = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
        } else {
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            middle = shift(start, days: days / 2, calendar: calendar)
        }
        guard let middle else { return nil }
        let text = answerString(middle, hasTime: hasTime, now: now, calendar: calendar)
        return CalcResult(
            expression: echo, sourceBadge: momentString(start, hasTime: hasTime, now: now, calendar: calendar),
            targetBadge: weekdayName(middle, calendar: calendar), payload: .value(display: text, copyText: text))
    }

    // MARK: - Grammars C & D: moment ± duration / moment − moment

    private static func parseArithmetic(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        var expression = query
        var targetUnit: UnitDef?
        for connector in [" to ", " in "] {
            if let range = expression.range(of: connector, options: .backwards),
                let unit = CalcUnits.byName[String(expression[range.upperBound...])], unit.category == .time
            {
                targetUnit = unit
                expression = String(expression[..<range.lowerBound])
                break
            }
        }
        let (left, operation, tail) = splitTerm(expression[...])
        guard let op = operation else { return nil }
        let right = String(tail)
        guard let base = parseMoment(left, now: now, calendar: calendar, bias: .nearest) else { return nil }

        // C: moment ± duration, chained left to right — every term after the first shifts again.
        if targetUnit == nil, let shifted = applyShifts(op, right, to: base, calendar: calendar) {
            let display = answerString(
                shifted.date, hasTime: shifted.hasTime, now: now, calendar: calendar)
            return CalcResult(
                expression: echo,
                sourceBadge: momentString(
                    base.date, hasTime: base.hasTime, now: now, calendar: calendar),
                targetBadge: weekdayName(shifted.date, calendar: calendar),
                payload: .value(display: display, copyText: display))
        }

        // D: moment − moment. Two letter-free operands (`5/2 - 1/2`) belong to the calculator.
        guard op == "-",
            targetUnit != nil || base.hasTime || left.contains(where: \.isLetter)
                || right.contains(where: \.isLetter) || left.contains("-") || isDottedDate(atomize(left)),
            let other = parseMoment(right, now: now, calendar: calendar, bias: .nearest)
        else {
            return nil
        }
        let hasTime = base.hasTime || other.hasTime
        // A difference is a span, the way Soulver reads it: `jan 10 - feb 5` is 3 weeks 5 days.
        let seconds = abs(base.date.timeIntervalSince(other.date))
        let payload: CalcResult.Payload
        if let unit = targetUnit {
            payload = .measurement(seconds / unit.factor, unit: unit)
        } else if hasTime {
            let text = CalcFormatter.timespan(seconds)
            payload = .value(display: text, copyText: text)
        } else {
            let text = calendarSpan(from: other.date, to: base.date, calendar: calendar)
            payload = .value(display: text, copyText: text)
        }
        return CalcResult(
            expression: echo,
            sourceBadge: momentString(base.date, hasTime: base.hasTime, now: now, calendar: calendar),
            targetBadge: targetUnit?.name
                ?? momentString(other.date, hasTime: other.hasTime, now: now, calendar: calendar),
            payload: payload)
    }

    /// Nil unless every term is a duration, so grammar D still sees a trailing moment.
    private static func applyShifts(
        _ firstOperator: Character, _ tail: String, to base: Moment, calendar: Calendar
    ) -> Moment? {
        var moment = base
        var op = firstOperator
        var rest = Substring(tail)

        while true {
            let (term, nextOperator, remainder) = splitTerm(rest)
            guard let shifted = shift(moment, by: term, op: op, calendar: calendar) else {
                return nil
            }
            moment = shifted
            guard let nextOperator else { return moment }
            op = nextOperator
            rest = remainder
        }
    }

    /// The text up to the next spaced `+` / `-`, that operator, and whatever follows it.
    private static func splitTerm(
        _ text: Substring
    ) -> (term: String, nextOperator: Character?, remainder: Substring) {
        let plus = text.range(of: " + ")
        let minus = text.range(of: " - ")
        let next: (Range<Substring.Index>, Character)?
        switch (plus, minus) {
        case (let p?, let m?): next = p.lowerBound < m.lowerBound ? (p, "+") : (m, "-")
        case (let p?, nil): next = (p, "+")
        case (nil, let m?): next = (m, "-")
        default: next = nil
        }
        guard let (range, op) = next else { return (String(text), nil, text) }
        return (String(text[..<range.lowerBound]), op, text[range.upperBound...])
    }

    /// One term against a moment: a spelled duration, or a bare number in the moment's own unit.
    private static func shift(
        _ moment: Moment, by term: String, op: Character, calendar: Calendar
    ) -> Moment? {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        let phrase = Double(trimmed) == nil ? trimmed : "\(trimmed) \(moment.hasTime ? "hours" : "days")"
        guard let durations = parseDurations(phrase) else { return nil }
        var result = moment
        for duration in durations {
            let signed = op == "-" ? -duration.count : duration.count
            let date =
                duration.businessDays
                ? addBusinessDays(signed, to: result.date, calendar: calendar)
                : calendar.date(byAdding: duration.component, value: signed, to: result.date)
            guard let date, (1...9999).contains(calendar.component(.year, from: date)) else { return nil }
            result = Moment(date: date, hasTime: result.hasTime || duration.subDay)
        }
        return result
    }

    // MARK: - Moment parsing

    private struct Moment {
        let date: Date
        /// True when the phrase named a clock time ("9am", "now") — drives the time badge.
        let hasTime: Bool
    }

    private static func parseTimestamp(
        _ query: String, echo: String, now: Date, calendar: Calendar
    ) -> CalcResult? {
        if let range = query.range(of: " to ", options: .backwards),
            let scale = CalcTimestamp.scale(String(query[range.upperBound...]))
        {
            let source = String(query[..<range.lowerBound])
            let (term, op, tail) = splitTerm(source[...])
            guard var moment = parseMoment(term, now: now, calendar: calendar, bias: .nearest) else {
                return nil
            }
            if let op {
                guard let shifted = applyShifts(op, String(tail), to: moment, calendar: calendar) else {
                    return nil
                }
                moment = shifted
            }
            let timestamp = moment.date.timeIntervalSince1970 * scale
            let rounded = timestamp.rounded()
            let tolerance = moment.date.timeIntervalSinceReferenceDate.ulp * scale
            let whole = abs(timestamp - rounded) <= tolerance ? rounded : timestamp.rounded(.down)
            guard let value = Int64(exactly: whole)
            else { return nil }
            let text = String(value)
            return CalcResult(
                expression: echo, sourceBadge: "Date",
                targetBadge: scale == 1 ? "Unix Seconds" : "Unix Milliseconds",
                payload: .value(display: CalcFormatter.grouped(text), copyText: text))
        }
        let source = query.hasSuffix(" to date") ? String(query.dropLast(8)) : query
        guard CalcTimestamp.isoDate(source) != nil || CalcTimestamp.epochDate(source) != nil else {
            return nil
        }
        return bareMoment(source, echo: echo, now: now, calendar: calendar)
    }

    private static func parseMoment(
        _ phrase: String, now: Date, calendar: Calendar, bias: MomentBias = .future
    ) -> Moment? {
        if let date = CalcTimestamp.isoDate(phrase) ?? CalcTimestamp.epochDate(phrase) {
            return Moment(date: date, hasTime: true)
        }
        if let holiday = holidayMoment(phrase, now: now, calendar: calendar, bias: bias) { return holiday }
        if !phrase.contains(" at "), let spelled = spelledAt(phrase) {
            return parseMoment(spelled, now: now, calendar: calendar, bias: bias)
        }
        if let range = phrase.range(of: " at ") {
            let dayPhrase = String(phrase[..<range.lowerBound])
            let atoms = atomize(dayPhrase)
            let recurring =
                weekdayByName[dayPhrase] != nil || monthByName[dayPhrase] != nil
                || (atoms.count == 2 && namesADay(dayPhrase))
                || (atoms.count == 1 && dayPhrase.split(separator: "/").count == 2)
                || CalcHoliday.parse(dayPhrase).map { $0.year == nil } == true
            guard let clock = parseMeridiemClock(String(phrase[range.upperBound...])),
                let day = parseMoment(
                    dayPhrase, now: now, calendar: calendar,
                    bias: recurring && bias != .nearest ? .future : bias)
            else { return nil }
            var anchor = day.date
            if recurring, bias != .nearest,
                let candidate = calendar.date(
                    bySettingHour: clock.hour, minute: clock.minute, second: 0, of: anchor),
                bias == .future ? candidate <= now : candidate > now
            {
                guard let reference = shift(now, days: bias == .future ? 1 : -1, calendar: calendar),
                    let shifted = parseMoment(dayPhrase, now: reference, calendar: calendar, bias: bias)
                else { return nil }
                anchor = shifted.date
            }
            guard
                let date = calendar.date(
                    bySettingHour: clock.hour, minute: clock.minute, second: 0, of: anchor),
                calendar.isDate(date, inSameDayAs: anchor),
                calendar.component(.hour, from: date) == clock.hour,
                calendar.component(.minute, from: date) == clock.minute
            else { return nil }
            return Moment(date: date, hasTime: true)
        }
        let atoms = atomize(phrase)
        switch atoms.count {
        case 1:
            return parseSingle(atoms[0], now: now, calendar: calendar, bias: bias)
        case 2:
            return parsePair(atoms[0], atoms[1], now: now, calendar: calendar, bias: bias)
        case 3:
            return parseTriple(atoms[0], atoms[1], atoms[2], calendar: calendar)
        default:
            return nil
        }
    }

    /// `friday 5pm`, `aug 25 10:00` — a day then a clock, read as `friday at 5pm`.
    private static func spelledAt(_ phrase: String) -> String? {
        var words = phrase.split(separator: " ")
        guard words.count >= 2, var clock = words.popLast() else { return nil }
        if clock == "am" || clock == "pm", words.count >= 2, let hour = words.popLast() {
            clock = hour + clock
        }
        // A bare `25` is a day, not a clock, so only a colon or a meridiem makes one.
        guard clock.contains(":") || clock.hasSuffix("am") || clock.hasSuffix("pm") || clock == "noon",
            parseMeridiemClock(String(clock)) != nil
        else { return nil }
        return "\(words.joined(separator: " ")) at \(clock)"
    }

    /// A named holiday; without a year it recurs, so the bias picks which year's.
    private static func holidayMoment(
        _ phrase: String, now: Date, calendar: Calendar, bias: MomentBias
    ) -> Moment? {
        guard let (name, year) = CalcHoliday.parse(phrase) else { return nil }
        let current = calendar.component(.year, from: now)
        let sod = calendar.startOfDay(for: now)
        guard var date = CalcHoliday.date(name, year: year ?? current, calendar: calendar) else { return nil }
        if year == nil, bias == .future, date < sod {
            guard let next = CalcHoliday.date(name, year: current + 1, calendar: calendar) else { return nil }
            date = next
        } else if year == nil, bias == .past, date > sod {
            guard let last = CalcHoliday.date(name, year: current - 1, calendar: calendar) else { return nil }
            date = last
        }
        return Moment(date: date, hasTime: false)
    }

    /// `august 26 2026` / `26 august 2026` — a month name with both a day and a year.
    private static func parseTriple(
        _ a: String, _ b: String, _ c: String, calendar: Calendar
    ) -> Moment? {
        guard let year = Int(c) else { return nil }
        let month: Int
        let day: Int
        if let named = monthByName[a], let value = ordinalDay(b) {
            (month, day) = (named, value)
        } else if let named = monthByName[b], let value = ordinalDay(a) {
            (month, day) = (named, value)
        } else {
            return nil
        }
        guard let date = makeDate(fullYear(year), month, day, calendar) else { return nil }
        return Moment(date: date, hasTime: false)
    }

    private static func parseSingle(
        _ atom: String, now: Date, calendar: Calendar, bias: MomentBias
    ) -> Moment? {
        let sod = calendar.startOfDay(for: now)
        switch atom {
        case "now": return Moment(date: now, hasTime: true)
        case "today": return Moment(date: sod, hasTime: false)
        case "tomorrow":
            return shift(sod, days: 1, calendar: calendar).map { Moment(date: $0, hasTime: false) }
        case "yesterday":
            return shift(sod, days: -1, calendar: calendar).map { Moment(date: $0, hasTime: false) }
        case "noon": return clockMoment(hour: 12, minute: 0, now: now, calendar: calendar, bias: bias)
        case "midnight":
            return clockMoment(hour: 0, minute: 0, now: now, calendar: calendar, bias: bias)
        default: break
        }
        if let weekday = weekdayByName[atom] {
            return nextWeekday(
                weekday, offsetToFuture: false, past: bias == .past, now: now, calendar: calendar)
        }
        if let month = monthByName[atom] {
            return monthDayMoment(month: month, day: 1, now: now, calendar: calendar, bias: bias)
        }
        return parseDateAtom(atom, now: now, calendar: calendar, bias: bias)
    }

    private static func parsePair(
        _ a: String, _ b: String, now: Date, calendar: Calendar, bias: MomentBias
    ) -> Moment? {
        // number + month  /  month + number  →  a day in that month
        if let month = monthByName[b], let day = ordinalDay(a) {
            return monthDayMoment(month: month, day: day, now: now, calendar: calendar, bias: bias)
        }
        if let month = monthByName[a], let day = ordinalDay(b) {
            return monthDayMoment(month: month, day: day, now: now, calendar: calendar, bias: bias)
        }
        // clock + am/pm  →  a time today (or tomorrow if it has passed)
        if b == "am" || b == "pm", let (hour, minute) = parseClock(a) {
            guard (1...12).contains(hour) else { return nil }
            let adjusted = b == "pm" ? (hour % 12) + 12 : hour % 12
            return clockMoment(
                hour: adjusted, minute: minute, now: now, calendar: calendar, bias: bias)
        }
        // next / last  +  weekday or month
        if a == "next" || a == "last" {
            if let weekday = weekdayByName[b] {
                return nextWeekday(
                    weekday, offsetToFuture: a == "next", past: a == "last", now: now,
                    calendar: calendar)
            }
            if let month = monthByName[b] {
                return monthDayMoment(
                    month: month, day: 1, now: now, calendar: calendar,
                    bias: a == "last" ? .past : .future)
            }
        }
        return nil
    }

    /// A lone numeric atom carrying its own separators: `14:00`, `2027-04-09`, `9/4`, `9/4/2027`.
    private static func parseDateAtom(
        _ atom: String, now: Date, calendar: Calendar, bias: MomentBias
    ) -> Moment? {
        if atom.contains(":") {
            guard let (hour, minute) = parseClock(atom) else { return nil }
            return clockMoment(hour: hour, minute: minute, now: now, calendar: calendar, bias: bias)
        }
        let separator: Character = atom.contains("-") ? "-" : atom.contains("/") ? "/" : "."
        let parts = atom.split(separator: separator)
        guard (2...3).contains(parts.count), let first = Int(parts[0]), let second = Int(parts[1]) else {
            return nil
        }
        if separator == "/", parts.count == 2 {
            return monthDayMoment(month: first, day: second, now: now, calendar: calendar, bias: bias)
        }
        guard parts.count == 3, let third = Int(parts[2]) else { return nil }
        let year: Int
        let month: Int
        let day: Int
        switch separator {
        case "-":
            guard first > 31 else { return nil }
            (year, month, day) = (first, second, third)
        case "/":
            (year, month, day) = (fullYear(third), first, second)
        default:
            guard parts[2].count == 2 || parts[2].count == 4 else { return nil }
            (year, month, day) = (fullYear(third), second, first)
        }
        guard let date = makeDate(year, month, day, calendar) else { return nil }
        return Moment(date: date, hasTime: false)
    }

    // MARK: - Moment builders

    private static func clockMoment(
        hour: Int, minute: Int, now: Date, calendar: Calendar, bias: MomentBias = .future
    ) -> Moment? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        let sod = calendar.startOfDay(for: now)
        guard var date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: sod)
        else { return nil }
        switch bias {
        case .future:
            if date <= now, let next = shift(date, days: 1, calendar: calendar) { date = next }
        case .past:
            if date > now, let prev = shift(date, days: -1, calendar: calendar) { date = prev }
        case .nearest:
            break
        }
        return Moment(date: date, hasTime: true)
    }

    /// The given day of `month`, resolved to the upcoming, most recent, or nearest year by `bias`.
    private static func monthDayMoment(
        month: Int, day: Int, now: Date, calendar: Calendar, bias: MomentBias = .future
    ) -> Moment? {
        let year = calendar.component(.year, from: now)
        guard let thisYear = makeDate(year, month, day, calendar) else { return nil }
        let sod = calendar.startOfDay(for: now)
        switch bias {
        case .future:
            if thisYear >= sod { return Moment(date: thisYear, hasTime: false) }
            guard let nextYear = makeDate(year + 1, month, day, calendar) else { return nil }
            return Moment(date: nextYear, hasTime: false)
        case .past:
            if thisYear <= sod { return Moment(date: thisYear, hasTime: false) }
            guard let lastYear = makeDate(year - 1, month, day, calendar) else { return nil }
            return Moment(date: lastYear, hasTime: false)
        // A date days behind is likelier the one meant than the same date a year out.
        case .nearest:
            return Moment(date: thisYear, hasTime: false)
        }
    }

    private static func nextWeekday(
        _ weekday: Int, offsetToFuture: Bool, past: Bool = false, now: Date, calendar: Calendar
    ) -> Moment? {
        let sod = calendar.startOfDay(for: now)
        let today = calendar.component(.weekday, from: sod)
        if past {
            var back = (today - weekday + 7) % 7
            if back == 0 { back = 7 }
            return shift(sod, days: -back, calendar: calendar).map {
                Moment(date: $0, hasTime: false)
            }
        }
        var ahead = (weekday - today + 7) % 7
        if ahead == 0 && offsetToFuture { ahead = 7 }
        return shift(sod, days: ahead, calendar: calendar).map { Moment(date: $0, hasTime: false) }
    }

    // MARK: - Durations

    private enum DurKind { case subSecond, day, week, workday }

    private struct DurUnit {
        let seconds: Double
        let singular: String
        let plural: String
        let kind: DurKind
        var subDay: Bool { kind == .subSecond }
    }

    private static func durationUnit(_ phrase: String) -> DurUnit? {
        if businessDayPhrases.contains(phrase.filter { $0 != " " }) {
            return DurUnit(seconds: 86400, singular: "workday", plural: "workdays", kind: .workday)
        }
        guard let last = phrase.split(separator: " ").last.map(String.init) else { return nil }
        switch last {
        case "s", "sec", "secs", "second", "seconds":
            return DurUnit(seconds: 1, singular: "second", plural: "seconds", kind: .subSecond)
        case "min", "mins", "minute", "minutes":
            return DurUnit(seconds: 60, singular: "minute", plural: "minutes", kind: .subSecond)
        case "h", "hr", "hrs", "hour", "hours":
            return DurUnit(seconds: 3600, singular: "hour", plural: "hours", kind: .subSecond)
        case "d", "day", "days":
            return DurUnit(seconds: 86400, singular: "day", plural: "days", kind: .day)
        case "wk", "week", "weeks":
            return DurUnit(seconds: 604800, singular: "week", plural: "weeks", kind: .week)
        default:
            return nil
        }
    }

    private struct DurationPhrase {
        let count: Int
        let component: Calendar.Component
        let subDay: Bool
        /// Weekend days are skipped rather than counted, so the result lands Mon–Fri.
        var businessDays = false
    }

    private static func parseDurations(_ phrase: String) -> [DurationPhrase]? {
        let atoms = atomize(phrase)
        var durations: [DurationPhrase] = []
        var index = 0
        while index + 1 < atoms.count {
            guard let amount = Double(atoms[index]), amount.isFinite else { return nil }
            var name = atoms[index + 1]
            index += 2
            if index < atoms.count, businessDayPhrases.contains(name + atoms[index]) {
                name += atoms[index]
                index += 1
            }
            let component: Calendar.Component
            let count: Double
            let subDay: Bool
            let businessDays = businessDayPhrases.contains(name)
            if businessDays {
                component = .day
                count = amount
                subDay = false
            } else if ["mo", "month", "months", "yr", "year", "years"].contains(name) {
                component = name.hasPrefix("mo") ? .month : .year
                count = amount
                subDay = false
            } else if let unit = durationUnit(name) {
                component = unit.subDay ? .second : .day
                count = amount * (unit.subDay ? unit.seconds : unit.seconds / 86400)
                subDay = unit.subDay
                guard subDay || amount.rounded() == amount else { return nil }
            } else {
                return nil
            }
            guard let value = Int(exactly: count), value != .min else { return nil }
            durations.append(
                DurationPhrase(count: value, component: component, subDay: subDay, businessDays: businessDays)
            )
        }
        return index == atoms.count && !durations.isEmpty ? durations : nil
    }

    // MARK: - Formatting

    /// Whole calendar days as years, months, weeks and days: `14 sep` to `28 sep` is `2 weeks`.
    private static func calendarSpan(from start: Date, to end: Date, calendar: Calendar) -> String {
        let (from, to) = (calendar.startOfDay(for: start), calendar.startOfDay(for: end))
        let parts = calendar.dateComponents([.year, .month, .day], from: min(from, to), to: max(from, to))
        let days = parts.day ?? 0
        let counts = [
            (parts.year ?? 0, "year", "years"), (parts.month ?? 0, "month", "months"),
            (days / 7, "week", "weeks"), (days % 7, "day", "days")
        ]
        let words = counts.filter { $0.0 != 0 }.map { "\($0.0) \($0.0 == 1 ? $0.1 : $0.2)" }
        return words.isEmpty ? "0 days" : words.joined(separator: " ")
    }

    private static func momentString(
        _ date: Date, hasTime: Bool, now: Date, calendar: Calendar
    )
        -> String
    {
        let day = dateString(date, now: now, calendar: calendar)
        return hasTime ? "\(day) at \(timeString(date, calendar: calendar))" : day
    }

    /// The weekday moves to the badge, so an answered moment leads with the date itself.
    private static func answerString(
        _ date: Date, hasTime: Bool, now: Date, calendar: Calendar
    ) -> String {
        let sameYear =
            calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let day = format(
            date, calendar: calendar, pattern: sameYear ? "d MMMM" : "d MMMM, yyyy")
        return hasTime ? "\(day) at \(timeString(date, calendar: calendar))" : day
    }

    private static func dateString(_ date: Date, now: Date, calendar: Calendar) -> String {
        let sameYear =
            calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return format(
            date, calendar: calendar, pattern: sameYear ? "EEEE, d MMMM" : "EEEE, d MMMM, yyyy")
    }

    private static func timeString(_ date: Date, calendar: Calendar) -> String {
        let template = calendar.component(.second, from: date) == 0 ? "jmm" : "jmmss"
        return CalcDateFormatters.string(
            from: date, calendar: calendar, zone: calendar.timeZone, template: template)
    }

    /// The answer's own weekday, which the date itself never spells out.
    private static func weekdayName(_ date: Date, calendar: Calendar) -> String {
        format(date, calendar: calendar, pattern: "EEEE")
    }

    private static func format(_ date: Date, calendar: Calendar, pattern: String) -> String {
        CalcDateFormatters.string(from: date, calendar: calendar, zone: calendar.timeZone, pattern: pattern)
    }

    // MARK: - Low-level helpers

    /// Split into letter-runs and number-runs; ":", "/", "-", "." stay inside a number-run.
    private static func atomize(_ text: String) -> [String] {
        var atoms: [String] = []
        var current = ""
        var currentIsNumber = false
        func flush() {
            if !current.isEmpty { atoms.append(current) }
            current = ""
        }
        for ch in text {
            if ch == " " {
                flush()
                continue
            }
            let isNumeric = ch.isNumber || ch == ":" || ch == "/" || ch == "-" || ch == "."
            let isLetter = ch.isLetter
            if current.isEmpty {
                current.append(ch)
                currentIsNumber = isNumeric && !isLetter
            } else if isLetter && currentIsNumber {
                flush()
                current.append(ch)
                currentIsNumber = false
            } else if isNumeric && !isLetter && !currentIsNumber {
                flush()
                current.append(ch)
                currentIsNumber = true
            } else {
                current.append(ch)
            }
        }
        flush()
        return atoms
    }

    /// A day number, with the ordinal dot German and Austrian dates write: `28. aug`.
    private static func ordinalDay(_ atom: String) -> Int? {
        Int(atom.hasSuffix(".") ? String(atom.dropLast()) : atom)
    }

    private static func parseClock(_ atom: String) -> (hour: Int, minute: Int)? {
        if atom.contains(":") {
            let parts = atom.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
                (0...59).contains(minute)
            else {
                return nil
            }
            return (hour, minute)
        }
        guard let hour = Int(atom) else { return nil }
        return (hour, 0)
    }

    @inline(never) private static func makeDate(
        _ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar
    )
        -> Date?
    {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components),
            calendar.component(.day, from: date) == day,
            calendar.component(.month, from: date) == month
        else { return nil }
        return date
    }

    private static func shift(_ date: Date, days: Int, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: days, to: date)
    }

    /// Whole weeks jump at once; only the weekend alignment and remainder walk individual days.
    private static func addBusinessDays(_ count: Int, to date: Date, calendar: Calendar) -> Date? {
        guard (-10_000...10_000).contains(count) else { return nil }
        let step = count < 0 ? -1 : 1
        var remaining = abs(count)
        var cursor = date
        while remaining > 0, isWeekend(cursor, calendar: calendar) {
            guard let next = shift(cursor, days: step, calendar: calendar) else { return nil }
            cursor = next
            if !isWeekend(cursor, calendar: calendar) { remaining -= 1 }
        }
        guard let jumped = shift(cursor, days: remaining / 5 * 7 * step, calendar: calendar) else {
            return nil
        }
        cursor = jumped
        remaining %= 5
        while remaining > 0 {
            guard let next = shift(cursor, days: step, calendar: calendar) else { return nil }
            cursor = next
            if !isWeekend(cursor, calendar: calendar) { remaining -= 1 }
        }
        return cursor
    }

    private static func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// Expand a 2-digit year the way date pickers do; 4-digit years pass through.
    private static func fullYear(_ year: Int) -> Int {
        if year >= 100 { return year }
        return year <= 68 ? 2000 + year : 1900 + year
    }

    private static let monthByName: [String: Int] = [
        "january": 1, "jan": 1, "february": 2, "feb": 2, "march": 3, "mar": 3, "april": 4,
        "apr": 4, "may": 5, "june": 6, "jun": 6, "july": 7, "jul": 7, "august": 8, "aug": 8,
        "september": 9, "sep": 9, "sept": 9, "october": 10, "oct": 10, "november": 11, "nov": 11,
        "december": 12, "dec": 12
    ]

    private static let businessDayPhrases: Set<String> = [
        "businessday", "businessdays", "workday", "workdays", "workingday", "workingdays",
        "weekday", "weekdays"
    ]

    /// Gregorian weekday numbers (Sunday = 1).
    private static let weekdayByName: [String: Int] = [
        "sunday": 1, "sun": 1, "monday": 2, "mon": 2, "tuesday": 3, "tue": 3, "tues": 3,
        "wednesday": 4, "wed": 4, "thursday": 5, "thu": 5, "thurs": 5, "friday": 6, "fri": 6,
        "saturday": 7, "sat": 7
    ]
}
