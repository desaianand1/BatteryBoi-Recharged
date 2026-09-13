//
//  OnboardingServiceTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class OnboardingServiceTests: XCTestCase {

    @MainActor
    func testAdvanceProgressesThroughSteps() {
        let service = MockOnboardingService()

        XCTAssertEqual(service.currentStep, .welcome)

        service.advance()
        XCTAssertEqual(service.currentStep, .permissions)

        service.advance()
        XCTAssertEqual(service.currentStep, .preferences)

        service.advance()
        XCTAssertEqual(service.currentStep, .complete)
    }

    @MainActor
    func testAdvanceAtLastStepStaysAtLastStep() {
        let service = MockOnboardingService(currentStep: .complete)

        service.advance()

        XCTAssertEqual(service.currentStep, .complete)
    }

    @MainActor
    func testCompleteMarksOnboardingDone() {
        let service = MockOnboardingService()

        service.complete()

        XCTAssertTrue(service.isCompleted)
    }

    @MainActor
    func testShouldShowOnboardingIsFalseWhenCompleted() {
        let service = MockOnboardingService()

        service.complete()

        XCTAssertFalse(service.shouldShowOnboarding)
    }

    @MainActor
    func testResetRestoresInitialState() {
        let service = MockOnboardingService(currentStep: .complete, isCompleted: true)

        service.reset()

        XCTAssertEqual(service.currentStep, .welcome)
        XCTAssertFalse(service.isCompleted)
    }

    @MainActor
    func testCompleteAndResetCycle() {
        let service = MockOnboardingService()

        service.complete()
        XCTAssertTrue(service.isCompleted)

        service.reset()
        XCTAssertFalse(service.isCompleted)
        XCTAssertEqual(service.currentStep, .welcome)
        XCTAssertTrue(service.shouldShowOnboarding)
    }
}
