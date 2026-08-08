import Foundation

/// A free-text record of one Eating Occasion.
nonisolated struct Entry: Equatable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let eatenAt: Date
}

/// The half-open range of instants making up one local calendar day.
nonisolated struct DayWindow: Equatable, Sendable {
    let from: Date
    let to: Date

    /// Creates the Day Window containing `instant` in `calendar`'s timezone.
    init(containing instant: Date, calendar: Calendar) {
        let from = calendar.startOfDay(for: instant)
        guard let to = calendar.date(byAdding: .day, value: 1, to: from) else {
            preconditionFailure("Calendar could not advance the Day Window")
        }
        self.init(from: from, to: to)
    }

    init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}
