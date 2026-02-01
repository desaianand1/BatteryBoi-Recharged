//
//  MockBluetoothService.swift
//  BatteryBoi
//
//  Mock implementation for unit testing.
//

import Combine
import Foundation

#if DEBUG

/// Mock Bluetooth service for unit testing.
@MainActor
final class MockBluetoothService: BluetoothServiceProtocol {
    // MARK: - Published Properties

    var list: [BluetoothObject]
    var connected: [BluetoothObject]
    var icons: [String]

    // MARK: - Publishers

    private let listSubject = PassthroughSubject<[BluetoothObject], Never>()
    private let connectedSubject = PassthroughSubject<[BluetoothObject], Never>()

    var listPublisher: AnyPublisher<[BluetoothObject], Never> {
        listSubject.eraseToAnyPublisher()
    }

    var connectedPublisher: AnyPublisher<[BluetoothObject], Never> {
        connectedSubject.eraseToAnyPublisher()
    }

    // MARK: - Test Helpers

    var updateConnectionCallCount = 0
    var refreshDeviceListCallCount = 0
    var lastUpdateConnectionDevice: BluetoothObject?
    var lastUpdateConnectionState: BluetoothState?

    // MARK: - Initialization

    init(
        list: [BluetoothObject] = [],
        connected: [BluetoothObject] = [],
        icons: [String] = []
    ) {
        self.list = list
        self.connected = connected
        self.icons = icons
    }

    // MARK: - Methods

    func updateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
        updateConnectionCallCount += 1
        lastUpdateConnectionDevice = device
        lastUpdateConnectionState = state
        return .connected
    }

    func refreshDeviceList() async {
        refreshDeviceListCallCount += 1
    }

    // MARK: - Test Simulation

    func simulateListChange(_ newList: [BluetoothObject]) {
        list = newList
        listSubject.send(newList)
    }

    func simulateConnectedChange(_ newConnected: [BluetoothObject]) {
        connected = newConnected
        connectedSubject.send(newConnected)
    }
}

#endif
