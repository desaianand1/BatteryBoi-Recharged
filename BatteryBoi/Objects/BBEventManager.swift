//
//  BBEventManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 9/18/23.
//

import Combine
import EventKit
import Foundation

struct EventRecipients: Equatable {
    var email: String
    var avatar: String

}

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

class EventManager: ObservableObject {
    nonisolated(unsafe) static var shared = EventManager()

    private var updates = Set<AnyCancellable>()

    @Published var events = [EventObject]()

    init() {
        AppManager.shared.appTimer(1800).sink { _ in
            self.eventAuthorizeStatus()

        }.store(in: &updates)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.eventAuthorizeStatus()

        }

    }

    private func eventAuthorizeStatus() {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            if #available(macOS 14.0, *) {
                EKEventStore().requestFullAccessToEvents { _, _ in
                    DispatchQueue.main.async {
                        self.events = self.eventsList()

                    }

                }

            } else {
                EKEventStore().requestAccess(to: .event) { _, _ in
                    DispatchQueue.main.async {
                        self.events = self.eventsList()

                    }

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

        print("start \(start) end \(end)")

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
