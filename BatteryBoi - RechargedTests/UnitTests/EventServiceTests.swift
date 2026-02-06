//
//  EventServiceTests.swift
//  BatteryBoi-RechargedTests
//
//  Behavioral tests for event service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class EventServiceTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockEventService: MockEventService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockEventService()
        }
        mockEventService = service
    }

    override nonisolated func tearDown() {
        mockEventService = nil
        super.tearDown()
    }

    // MARK: - Event Refresh Tests

    @MainActor
    func testRefreshEventsCallCount() {
        // Given initial state
        XCTAssertEqual(mockEventService.refreshEventsCallCount, 0)

        // When refreshing events
        mockEventService.refreshEvents()

        // Then call count should increment
        XCTAssertEqual(mockEventService.refreshEventsCallCount, 1)
    }

    @MainActor
    func testMultipleRefreshCalls() {
        // When refreshing multiple times
        mockEventService.refreshEvents()
        mockEventService.refreshEvents()
        mockEventService.refreshEvents()

        // Then all calls should be counted
        XCTAssertEqual(mockEventService.refreshEventsCallCount, 3)
    }

    // MARK: - Event List Tests

    @MainActor
    func testEmptyEventsList() {
        // Given no events
        mockEventService.events = []

        // Then events should be empty
        XCTAssertTrue(mockEventService.events.isEmpty)
    }

    @MainActor
    func testSingleEventInList() {
        // Given a single event
        let event = MockEventService.createMockEvent(
            name: "Team Meeting",
            start: Date(),
            duration: 3600
        )
        mockEventService.events = [event]

        // Then events should contain one item
        XCTAssertEqual(mockEventService.events.count, 1)
        XCTAssertEqual(mockEventService.events.first?.name, "Team Meeting")
    }

    @MainActor
    func testMultipleEventsInList() {
        // Given multiple events
        let event1 = MockEventService.createMockEvent(name: "Meeting 1", start: Date())
        let event2 = MockEventService.createMockEvent(name: "Meeting 2", start: Date().addingTimeInterval(3600))
        let event3 = MockEventService.createMockEvent(name: "Meeting 3", start: Date().addingTimeInterval(7200))

        mockEventService.events = [event1, event2, event3]

        // Then events should contain all items
        XCTAssertEqual(mockEventService.events.count, 3)
    }

    // MARK: - Event Filtering Tests

    @MainActor
    func testUpcomingEventDetection() {
        // Given events at different times
        let now = Date()
        let pastEvent = MockEventService.createMockEvent(
            name: "Past Meeting",
            start: now.addingTimeInterval(-7200)
        )
        let upcomingEvent = MockEventService.createMockEvent(
            name: "Upcoming Meeting",
            start: now.addingTimeInterval(1800)
        )

        mockEventService.events = [pastEvent, upcomingEvent]

        // When filtering for upcoming events
        let upcoming = mockEventService.events.filter { $0.start > now }

        // Then only upcoming event should be found
        XCTAssertEqual(upcoming.count, 1)
        XCTAssertEqual(upcoming.first?.name, "Upcoming Meeting")
    }

    @MainActor
    func testEventWithinNextHour() {
        // Given an event starting in 30 minutes
        let now = Date()
        let event = MockEventService.createMockEvent(
            name: "Soon Meeting",
            start: now.addingTimeInterval(1800)
        )
        mockEventService.events = [event]

        // When checking if event is within next hour
        let oneHourFromNow = now.addingTimeInterval(3600)
        let eventsWithinHour = mockEventService.events.filter {
            $0.start > now && $0.start < oneHourFromNow
        }

        // Then event should be found
        XCTAssertEqual(eventsWithinHour.count, 1)
    }

    // MARK: - Event Properties Tests

    @MainActor
    func testEventId() {
        // Given an event with specific ID
        let event = MockEventService.createMockEvent(id: "test-event-123")
        mockEventService.events = [event]

        // Then ID should be accessible
        XCTAssertEqual(mockEventService.events.first?.id, "test-event-123")
    }

    @MainActor
    func testEventName() {
        // Given an event with specific name
        let event = MockEventService.createMockEvent(name: "Project Sync")
        mockEventService.events = [event]

        // Then name should be accessible
        XCTAssertEqual(mockEventService.events.first?.name, "Project Sync")
    }

    @MainActor
    func testEventStartDate() {
        // Given an event with specific start time
        let startDate = Date()
        let event = MockEventService.createMockEvent(start: startDate)
        mockEventService.events = [event]

        // Then start date should match
        XCTAssertEqual(mockEventService.events.first?.start, startDate)
    }

    @MainActor
    func testEventEndDate() {
        // Given an event with 1 hour duration
        let startDate = Date()
        let event = MockEventService.createMockEvent(start: startDate, duration: 3600)
        mockEventService.events = [event]

        // Then end date should be 1 hour after start
        let expectedEnd = startDate.addingTimeInterval(3600)
        XCTAssertEqual(mockEventService.events.first?.end, expectedEnd)
    }

    // MARK: - Simulation Tests

    @MainActor
    func testSimulateEventsChange() {
        // Given empty events
        XCTAssertTrue(mockEventService.events.isEmpty)

        // When simulating events change
        let newEvents = [
            MockEventService.createMockEvent(name: "New Event 1"),
            MockEventService.createMockEvent(name: "New Event 2"),
        ]
        mockEventService.simulateEventsChange(newEvents)

        // Then events should update
        XCTAssertEqual(mockEventService.events.count, 2)
    }

    @MainActor
    func testSimulateClearEvents() {
        // Given events
        mockEventService.events = [MockEventService.createMockEvent()]

        // When clearing events
        mockEventService.simulateEventsChange([])

        // Then events should be empty
        XCTAssertTrue(mockEventService.events.isEmpty)
    }

    // MARK: - Edge Cases

    @MainActor
    func testEventEquality() {
        // Given two events with same properties
        let id = "event-1"
        let name = "Test Meeting"
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let event1 = EventObject(id: id, name: name, start: start, end: end)
        let event2 = EventObject(id: id, name: name, start: start, end: end)

        // Then events should be equal
        XCTAssertEqual(event1, event2)
    }

    @MainActor
    func testEventInequality() {
        // Given two events with different IDs
        let event1 = MockEventService.createMockEvent(id: "event-1")
        let event2 = MockEventService.createMockEvent(id: "event-2")

        // Then events should not be equal
        XCTAssertNotEqual(event1, event2)
    }

    @MainActor
    func testLongDurationEvent() throws {
        // Given a very long event (8 hours)
        let event = MockEventService.createMockEvent(duration: 28800)
        mockEventService.events = [event]

        // Then event duration should be 8 hours
        let duration = try XCTUnwrap(try mockEventService.events.first?.end.timeIntervalSince(
            XCTUnwrap(mockEventService.events.first?.start)
        ))
        XCTAssertEqual(duration, 28800)
    }
}
