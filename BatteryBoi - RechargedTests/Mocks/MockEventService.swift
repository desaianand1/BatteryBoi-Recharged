//
//  MockEventService.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock event service for unit testing.
    @MainActor
    final class MockEventService: EventServiceProtocol {
        // MARK: - Observable Properties

        var events: [EventObject]

        // MARK: - Test Helpers

        var refreshEventsCallCount = 0

        // MARK: - Initialization

        nonisolated init(events: [EventObject] = []) {
            self.events = events
        }

        // MARK: - Methods

        func refreshEvents() {
            refreshEventsCallCount += 1
        }

        // MARK: - Test Simulation

        func simulateEventsChange(_ newEvents: [EventObject]) {
            events = newEvents
        }

        /// Creates a mock event for testing
        static func createMockEvent(
            id: String = UUID().uuidString,
            name: String = "Test Meeting",
            start: Date = Date(),
            duration: TimeInterval = 3600
        ) -> EventObject {
            EventObject(
                id: id,
                name: name,
                start: start,
                end: start.addingTimeInterval(duration)
            )
        }
    }

#endif
