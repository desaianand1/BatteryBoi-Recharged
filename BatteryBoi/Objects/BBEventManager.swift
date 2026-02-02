import EventKit
import Foundation
import Logging

struct EventObject: Equatable {
    var id: String
    var name: String
    var start: Date
    var end: Date

    init(_ event: EKEvent) {
        id = event.eventIdentifier
        name = event.title
        start = event.startDate
        end = event.endDate

    }

}

@Observable
@MainActor
final class EventManager {
    static let shared = EventManager()

    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    var events = [EventObject]()

    init() {
        // Initial check after delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10.0))
            self.eventAuthorizeStatus()
        }

        // Periodic check every 30 minutes (1800 seconds)
        timerTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(1800) {
                guard let self, !Task.isCancelled else { break }
                eventAuthorizeStatus()
            }
        }
    }

    deinit {
        timerTask?.cancel()
    }

    private func eventAuthorizeStatus() {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            EKEventStore().requestFullAccessToEvents { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    events = eventsList()
                }
            }
        } else {
            events = eventsList()
        }
    }

    private func eventsList() -> [EventObject] {
        var output = [EventObject]()

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = EKEventStore().predicateForEvents(withStart: Date(), end: end, calendars: nil)

        BBLogger.events.debug("Fetching events from \(start) to \(end)")

        for event in EKEventStore().events(matching: predicate) {
            if let notes = event.notes, notes.contains("http://") || notes.contains("https://") {
                output.append(.init(event))

            } else if let url = event.url?.absoluteString, url.contains("http://") || url.contains("https://") {
                output.append(.init(event))

            }

        }

        return output

    }

}
