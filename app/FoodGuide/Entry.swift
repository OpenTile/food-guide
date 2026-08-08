import Foundation

/// A single eating occasion returned by the backend.
nonisolated struct Entry: Equatable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let eatenAt: Date
}

/// The half-open range of instants making up one local calendar day.
nonisolated struct DayWindow: Equatable, Sendable {
    let from: Date
    let to: Date

    /// Creates the Day Window containing `date` in `calendar`'s timezone.
    init(containing date: Date, calendar: Calendar) {
        let from = calendar.startOfDay(for: date)
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
