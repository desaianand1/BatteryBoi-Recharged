//
//  BBTriggerManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 9/1/23.
//

import Combine
import Foundation

class TriggerClass {
    static var shared = Self()

    private var updates = Set<AnyCancellable>()

    init() {
        BatteryManager.shared.$charging.dropFirst().removeDuplicates().sink { _ in

        }.store(in: &updates)

    }

    deinit {
        self.updates.forEach { $0.cancel() }

    }

    func triggerPercent(_: Double) {
        // TBC

    }

    func triggerState(_ state: HUDAlertTypes, device _: BluetoothObject) {
        if state.trigger == false {
            fatalError("This is not a Trigger State")

        }

        // TBC

    }

}
