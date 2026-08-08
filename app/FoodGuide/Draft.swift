import Foundation

/// Text being composed for an Entry, including any submission available for retry.
nonisolated struct Draft: Equatable, Sendable {
    var hasChangedSinceSubmission = false
    var submission: DraftSubmission?
    var text = ""

    var canSubmit: Bool {
        let serverWhitespace = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "\u{FEFF}")
        )
        return !text.trimmingCharacters(in: serverWhitespace).isEmpty
    }

    /// Replaces the composed text; clearing it also ends any submission’s retry lifecycle.
    mutating func updateText(_ text: String) {
        self.text = text
        if text.isEmpty {
            hasChangedSinceSubmission = false
            submission = nil
            return
        }
        if let submission, !hasSameBytes(as: submission.text) {
            hasChangedSinceSubmission = true
        }
    }

    /// Returns the unchanged submission for retry, or creates one for the current text.
    mutating func prepareSubmission(id: UUID, eatenAt: Date) -> DraftSubmission {
        if let submission, hasSameBytes(as: submission.text) {
            hasChangedSinceSubmission = false
            return submission
        }
        let submission = DraftSubmission(id: id, text: text, eatenAt: eatenAt)
        hasChangedSinceSubmission = false
        self.submission = submission
        return submission
    }

    /// Completes a submission without clearing text composed after it began.
    mutating func accept(_ entry: Entry) {
        if submission?.id == entry.id, !hasChangedSinceSubmission {
            text = ""
        }
        hasChangedSinceSubmission = false
        submission = nil
    }

    private func hasSameBytes(as other: String) -> Bool {
        text.utf8.elementsEqual(other.utf8)
    }
}

/// The stable identifier, text, and Eaten At sent when committing a Draft.
nonisolated struct DraftSubmission: Equatable, Sendable {
    let id: UUID
    let text: String
    let eatenAt: Date
}
