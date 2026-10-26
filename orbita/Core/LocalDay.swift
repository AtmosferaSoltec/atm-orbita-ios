import Foundation

/// A calendar day without time or zone (Android `LocalDate`). A movement keeps only its day, so it
/// never shifts when the person travels; the API sends and receives it as `YYYY-MM-DD`.
struct LocalDay: Hashable, Comparable, Codable {
    let year: Int
    let month: Int
    let day: Int

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day [date] falls on in [timeZone] (the device's by default).
    init(date: Date, in timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// `2026-10-02`
    init?(iso: String) {
        let parts = iso.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year, month, day)
    }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let value = LocalDay(iso: String(text.prefix(10))) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(text)")
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }

    static func today(in timeZone: TimeZone = .current) -> LocalDay {
        LocalDay(date: Date(), in: timeZone)
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Midnight UTC of this day, only to do calendar arithmetic.
    private var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    private init(utc date: Date) {
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    func adding(days: Int) -> LocalDay {
        LocalDay(utc: Self.calendar.date(byAdding: .day, value: days, to: date) ?? date)
    }

    /// Like `plusMonths`: the day is kept, or cut to the last day of the shorter month.
    func adding(months: Int) -> LocalDay {
        LocalDay(utc: Self.calendar.date(byAdding: .month, value: months, to: date) ?? date)
    }

    var firstOfMonth: LocalDay { LocalDay(year, month, 1) }

    var lengthOfMonth: Int {
        Self.calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    var lastOfMonth: LocalDay { LocalDay(year, month, lengthOfMonth) }

    /// 0 = Sunday … 6 = Saturday.
    var weekdayIndex: Int { Self.calendar.component(.weekday, from: date) - 1 }

    /// Whole days from this day to [other]; negative when [other] is earlier.
    func days(until other: LocalDay) -> Int {
        Self.calendar.dateComponents([.day], from: date, to: other.date).day ?? 0
    }
}

/// Inclusive on both ends.
struct DatePeriod: Hashable {
    let from: LocalDay
    let to: LocalDay

    func contains(_ day: LocalDay) -> Bool { day >= from && day <= to }

    static func ofMonth(_ day: LocalDay) -> DatePeriod {
        DatePeriod(from: day.firstOfMonth, to: day.lastOfMonth)
    }

    static func ofYear(_ year: Int) -> DatePeriod {
        DatePeriod(from: LocalDay(year, 1, 1), to: LocalDay(year, 12, 31))
    }
}
