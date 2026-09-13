//
//  ObservationStream.swift
//  BatteryBoi
//
//  Bridges @Observable properties to AsyncStream for reactive observation.
//

import Foundation
import Observation

enum ObservationStream {

    static func changes<Value: Sendable>(
        _ observe: @escaping @MainActor () -> Value
    ) -> AsyncStream<Value> {
        if #available(macOS 26, *) {
            macOS26Stream(observe)
        } else {
            legacyStream(observe)
        }
    }

    @MainActor
    static func changes<Root: Observable, Value: Sendable & Equatable>(
        of object: Root,
        keyPath: KeyPath<Root, Value>
    ) -> AsyncStream<Value> {
        changes { object[keyPath: keyPath] }
    }

    // MARK: - macOS 26+ (Observations API)

    @available(macOS 26, *)
    private static func macOS26Stream<Value: Sendable>(
        _ observe: @escaping @MainActor () -> Value
    ) -> AsyncStream<Value> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                let observations = Observations { observe() }
                for await value in observations {
                    guard !Task.isCancelled else { break }
                    continuation.yield(value)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Pre-macOS 26 (withObservationTracking re-registration)

    private static func legacyStream<Value: Sendable>(
        _ observe: @escaping @MainActor () -> Value
    ) -> AsyncStream<Value> {
        AsyncStream { continuation in
            let flag = TerminationFlag()

            @Sendable
            func track() {
                guard !flag.isTerminated else { return }
                let value = MainActor.assumeIsolated { observe() }
                continuation.yield(value)

                withObservationTracking {
                    _ = MainActor.assumeIsolated { observe() }
                } onChange: {
                    Task { @MainActor in
                        guard !flag.isTerminated else { return }
                        track()
                    }
                }
            }

            Task { @MainActor in track() }

            continuation.onTermination = { @Sendable _ in
                flag.isTerminated = true
            }
        }
    }
}

nonisolated final class TerminationFlag: @unchecked Sendable {
    var isTerminated = false
}
