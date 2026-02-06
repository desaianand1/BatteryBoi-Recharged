//
//  EventService.swift
//  BatteryBoi
//
//  Event service with proper task lifecycle management.
//

import EventKit
import Foundation
import Logging

/// Service for monitoring calendar events.
/// MainActor isolated for Swift 6.2 strict concurrency compliance.
@Observable
@MainActor
final class EventService: EventServiceProtocol {
    // MARK: - Static Instance

    static let shared = EventService()

    // MARK: - Properties

    /// Current calendar events containing URLs
    var events = [EventObject]()

    /// Single shared EKEventStore - creating multiple instances is expensive
    private let eventStore = EKEventStore()

    /// Timer task for periodic authorization checks (nonisolated(unsafe) for deinit access per SE-0371)
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Force refresh of events
    func refreshEvents() {
        eventAuthorizeStatus()
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        // Initial check after delay
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(10.0))
            self?.eventAuthorizeStatus()
        }

        // Periodic check every 30 minutes (1800 seconds)
        timerTask = Task(name: "EventService.monitor") { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1800))
                guard let self, !Task.isCancelled else { break }
                eventAuthorizeStatus()
            }
        }
    }

    private func eventAuthorizeStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            // Use async API to avoid callback isolation violations
            Task { [weak self] in
                guard let self else { return }

                let granted: Bool = if #available(macOS 14.0, *) {
                    await (try? eventStore.requestFullAccessToEvents()) ?? false
                } else {
                    await withCheckedContinuation { continuation in
                        eventStore.requestFullAccessToEvents { result, _ in
                            continuation.resume(returning: result)
                        }
                    }
                }

                if granted {
                    events = eventsList()
                }
            }
        case .fullAccess, .authorized:
            events = eventsList()
        case .denied, .restricted, .writeOnly:
            BLogger.events.info("EventKit access denied, restricted, or write-only")
        @unknown default:
            break
        }
    }

    private func eventsList() -> [EventObject] {
        var output = [EventObject]()

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = eventStore.predicateForEvents(withStart: Date(), end: end, calendars: nil)

        BLogger.events.debug("Fetching events from \(start) to \(end)")

        for event in eventStore.events(matching: predicate) {
            if let notes = event.notes, notes.contains("http://") || notes.contains("https://") {
                output.append(.init(event))
            } else if let url = event.url?.absoluteString, url.contains("http://") || url.contains("https://") {
                output.append(.init(event))
            }
        }

        return output
    }
}
