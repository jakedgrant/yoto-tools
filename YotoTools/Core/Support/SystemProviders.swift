import Foundation

/// Injectable "current date" source so time-dependent logic is deterministic in tests.
struct DateProvider: Sendable {
    var now: @Sendable () -> Date

    static let live = DateProvider { Date.now }

    static func fixed(_ date: Date) -> DateProvider {
        DateProvider { date }
    }
}

/// Injectable UUID source for deterministic identifiers in tests.
struct UUIDProvider: Sendable {
    var next: @Sendable () -> UUID

    static let live = UUIDProvider { UUID() }
}
