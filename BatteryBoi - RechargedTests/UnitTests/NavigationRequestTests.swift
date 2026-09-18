@testable import BatteryBoi___Recharged
import Testing

@Suite("NavigationRequest")
@MainActor
struct NavigationRequestTests {

    // MARK: - Equality & Identity

    @Test
    func `tab requests are equal by same tab`() {
        #expect(NavigationRequest.tab(.settings) == NavigationRequest.tab(.settings))
        #expect(NavigationRequest.tab(.settings) != NavigationRequest.tab(.devices))
    }

    @Test
    func `device detail uses address not full object`() {
        let request = NavigationRequest.deviceDetail("aa-bb-cc-dd-ee-ff")
        #expect(request == .deviceDetail("aa-bb-cc-dd-ee-ff"))
        #expect(request != .deviceDetail("11-22-33-44-55-66"))
    }

    @Test
    func `device detail nil is valid request`() {
        #expect(NavigationRequest.deviceDetail(nil) == .deviceDetail(nil))
        #expect(NavigationRequest.deviceDetail(nil) != .deviceDetail("aa-bb-cc-dd-ee-ff"))
    }

    // MARK: - navigate() state transitions via MockWindowService

    @Test
    func `navigate from hidden opens window and transitions to detailed`() {
        let mock = MockWindowService(state: .hidden)
        mock.navigate(to: .tab(.settings))

        #expect(mock.openCallCount == 1)
        #expect(mock.lastOpenType == .userInitiated)
        #expect(mock.state == .detailed)
        #expect(mock.navigationRequest == .tab(.settings))
    }

    @Test
    func `navigate from detailed does not change state`() {
        let mock = MockWindowService(state: .detailed)
        mock.navigate(to: .tab(.about))

        #expect(mock.openCallCount == 0)
        #expect(mock.state == .detailed)
        #expect(mock.navigationRequest == .tab(.about))
    }

    @Test
    func `navigate from revealed expands to detailed`() {
        let mock = MockWindowService(state: .revealed)
        mock.navigate(to: .tab(.settings))

        #expect(mock.openCallCount == 0)
        #expect(mock.state == .detailed)
    }

    @Test
    func `navigate from dismissed opens window`() {
        let mock = MockWindowService(state: .dismissed)
        mock.navigate(to: .tab(.devices))

        #expect(mock.openCallCount == 1)
        #expect(mock.state == .detailed)
    }

    @Test
    func `double navigate second request wins`() {
        let mock = MockWindowService(state: .hidden)
        mock.navigate(to: .tab(.settings))
        mock.navigate(to: .tab(.about))

        #expect(mock.navigationRequest == .tab(.about))
        #expect(mock.navigateCallCount == 2)
    }

    @Test
    func `navigate request cleared by nil assignment`() {
        let mock = MockWindowService(state: .detailed)
        mock.navigate(to: .tab(.settings))
        #expect(mock.navigationRequest != nil)
        mock.navigationRequest = nil
        #expect(mock.navigationRequest == nil)
    }

    @Test
    func `navigate request cleared on sleep`() {
        let mock = MockWindowService(state: .detailed)
        mock.navigate(to: .tab(.settings))
        mock.handleSleep()
        #expect(mock.navigationRequest == nil)
    }
}
