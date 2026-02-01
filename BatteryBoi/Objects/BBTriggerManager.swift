//
//  BBTriggerManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 9/1/23.
//

import Combine
import Foundation

@MainActor
final class TriggerClass {
    static let shared = TriggerClass()

    init() {
        // TODO: Implement trigger system for custom battery actions
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
