//
//  ObservationStreamTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
import Observation
@preconcurrency import XCTest

@Observable
@MainActor
private final class TestModel {
    var value: Int = 0
    var text: String = ""
}

final class ObservationStreamTests: XCTestCase {

    @MainActor
    func testEmitsInitialValueImmediately() async {
        let model = TestModel()
        model.value = 42

        let stream = ObservationStream.changes(of: model, keyPath: \.value)
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        XCTAssertEqual(first, 42)
    }

    @MainActor
    func testEmitsOnPropertyChange() async {
        let model = TestModel()
        model.value = 1

        let stream = ObservationStream.changes(of: model, keyPath: \.value)

        let expectation = XCTestExpectation(description: "Value changed")
        var received: [Int] = []

        let task = Task {
            for await value in stream {
                received.append(value)
                if received.count >= 2 {
                    expectation.fulfill()
                    break
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(50))
        model.value = 99

        await fulfillment(of: [expectation], timeout: 2.0)
        task.cancel()

        XCTAssertEqual(received.first, 1)
        XCTAssertEqual(received.last, 99)
    }

    @MainActor
    func testTerminatesOnTaskCancellation() async {
        let model = TestModel()
        var streamEnded = false

        let task = Task {
            for await _ in ObservationStream.changes(of: model, keyPath: \.value) {
                // consume
            }
            streamEnded = true
        }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(task.isCancelled)
        XCTAssertTrue(streamEnded, "Code after for-await loop should execute after cancellation")
    }

    @MainActor
    func testHandlesRapidChanges() async {
        let model = TestModel()
        model.value = 0

        let stream = ObservationStream.changes(of: model, keyPath: \.value)

        let expectation = XCTestExpectation(description: "Rapid changes")
        var received: [Int] = []

        let task = Task {
            for await value in stream {
                received.append(value)
                if received.count >= 5 {
                    expectation.fulfill()
                    break
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(50))
        for i in 1 ... 10 {
            model.value = i
            try? await Task.sleep(for: .milliseconds(10))
        }

        await fulfillment(of: [expectation], timeout: 3.0)
        task.cancel()

        XCTAssertGreaterThanOrEqual(received.count, 5)
    }

    @MainActor
    func testNoZombieTrackingAfterTermination() async {
        let model = TestModel()
        model.value = 1

        var received: [Int] = []

        let task = Task {
            for await value in ObservationStream.changes(of: model, keyPath: \.value) {
                received.append(value)
            }
        }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        try? await Task.sleep(for: .milliseconds(100))

        let countAfterCancel = received.count
        model.value = 999
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(received.count, countAfterCancel, "No emissions after cancellation")
    }

    @MainActor
    func testSameValueNotReEmitted() async {
        let model = TestModel()
        model.value = 1

        let stream = ObservationStream.changes(of: model, keyPath: \.value)
        var received: [Int] = []

        let expectation = XCTestExpectation(description: "Changed value received")

        let task = Task {
            for await value in stream {
                received.append(value)
                if value == 2 {
                    expectation.fulfill()
                    break
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(50))
        model.value = 1
        try? await Task.sleep(for: .milliseconds(50))
        model.value = 2

        await fulfillment(of: [expectation], timeout: 2.0)
        task.cancel()

        XCTAssertEqual(received, [1, 2], "Same-value assignment should not produce duplicate emission")
    }

    @MainActor
    func testMultiPropertyObservation() async {
        let model = TestModel()
        model.value = 0
        model.text = "a"

        let stream = ObservationStream.changes { (model.value, model.text) }

        let expectation = XCTestExpectation(description: "Multi-property change")
        var received: [(Int, String)] = []

        let task = Task {
            for await pair in stream {
                received.append(pair)
                if received.count >= 2 {
                    expectation.fulfill()
                    break
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(50))
        model.value = 42
        model.text = "b"

        await fulfillment(of: [expectation], timeout: 2.0)
        task.cancel()

        XCTAssertGreaterThanOrEqual(received.count, 2)
    }
}
