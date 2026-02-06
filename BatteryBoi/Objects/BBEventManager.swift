import EventKit
import Foundation
import Logging

struct EventObject: Equatable {
    var id: String
    var name: String
    var start: Date
    var end: Date

    init(_ event: EKEvent) {
        self.id = event.eventIdentifier
        self.name = event.title
        self.start = event.startDate
        self.end = event.endDate

    }

}

@Observable
@MainActor
final class EventManager {
    static let shared = EventManager()

    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    /// Single shared EKEventStore - creating multiple instances is expensive
    private let eventStore = EKEventStore()

    var events = [EventObject]()

    init() {
        // Initial check after delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10.0))
            self.eventAuthorizeStatus()
        }

        // Periodic check every 30 minutes (1800 seconds)
        self.timerTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(1800) {
                guard let self, !Task.isCancelled else { break }
                self.eventAuthorizeStatus()
            }
        }
    }

    deinit {
        timerTask?.cancel()
    }

    private func eventAuthorizeStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor [weak self] in
                    guard let self, granted else { return }
                    self.events = self.eventsList()
                }
            }
        case .fullAccess, .authorized:
            self.events = self.eventsList()
        case .denied, .restricted, .writeOnly:
            BBLogger.events.info("EventKit access denied, restricted, or write-only")
        @unknown default:
            break
        }
    }

    private func eventsList() -> [EventObject] {
        var output = [EventObject]()

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = eventStore.predicateForEvents(withStart: Date(), end: end, calendars: nil)

        BBLogger.events.debug("Fetching events from \(start) to \(end)")

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
