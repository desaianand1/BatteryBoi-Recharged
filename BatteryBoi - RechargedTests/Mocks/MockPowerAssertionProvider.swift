@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    @MainActor
    final class MockPowerAssertionProvider: PowerAssertionProviding {
        var createShouldSucceed = true
        var createCallCount = 0
        var releaseCallCount = 0
        var lastCreatedName: String?
        private var nextID: UInt32 = 1

        func createAssertion(name: String) -> UInt32? {
            self.createCallCount += 1
            self.lastCreatedName = name
            guard self.createShouldSucceed else { return nil }
            let id = self.nextID
            self.nextID += 1
            return id
        }

        func releaseAssertion(_: UInt32) {
            self.releaseCallCount += 1
        }
    }

#endif
