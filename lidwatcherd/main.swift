//
//  main.swift
//  lidwatcherd
//
//  Created by Max Johnson on 1/7/19.
//  Copyright © 2019 Max Johnson. All rights reserved.
//

import Foundation
import IOKit
import IOBluetooth

let fmt = ISO8601DateFormatter.init();
func ts() -> String {
    return fmt.string(from: Date.init());
}

struct ClamshellState {
    // AppleClamshellState is true when the lid is closed.
    var AppleClamshellState = false;
    // AppleClamshellCausesSleep is false when power is connected and an external display is connected. Otherwise it is true.
    var AppleClamshellCausesSleep = true;
}

// Gets the state of the lid by scanning the iokit registry.
func getClamshellState() -> ClamshellState {
    var clamshellState = ClamshellState();
    var it: io_iterator_t = 0;
    IORegistryCreateIterator(kIOMasterPortDefault, kIOServicePlane, UInt32(kIORegistryIterateRecursively), &it);
    while (IOIteratorIsValid(it) != 0) {
        let obj = IOIteratorNext(it);
        // Check for the AppleClamshellState key
        let kAppleClamshellState = "AppleClamshellState" as CFString;
        let appleClamshellStateProp = IORegistryEntryCreateCFProperty(obj, kAppleClamshellState, kCFAllocatorDefault, 0);
        if (appleClamshellStateProp != nil) {
            // Set the AppleClamshellState field
            let appleClamshellStateValue = appleClamshellStateProp?.takeRetainedValue() as! Optional<Bool>;
            clamshellState.AppleClamshellState = appleClamshellStateValue!;
            
            // Check for AppleClamshellCausesSleep proprty
            let kAppleClamshellCausesSleep = "AppleClamshellCausesSleep" as CFString;
            let appleClamshellCausesSleepProp = IORegistryEntryCreateCFProperty(obj, kAppleClamshellCausesSleep, kCFAllocatorDefault, 0);
            if (appleClamshellCausesSleepProp != nil) {
                // Set the AppleClamshellCausesSleep field
                let appleClamshellCausesSleepValue = appleClamshellCausesSleepProp?.takeRetainedValue() as! Optional<Bool>;
                clamshellState.AppleClamshellCausesSleep = appleClamshellCausesSleepValue!;
            }

            // Done - stop scanning.
            IOObjectRelease(obj);
            break;
        }
        IOObjectRelease(obj);
    }
    IOObjectRelease(it);
    return clamshellState;
}

func getDeviceByAddress(address: String) -> Optional<IOBluetoothDevice> {
    let devices = IOBluetoothDevice.pairedDevices() as! [IOBluetoothDevice];
    for device in devices {
        if device.addressString == address {
            return device;
        }
    }
    return nil;
}

func getConnectedBluetoothAddresses() -> [String] {
    let devices = IOBluetoothDevice.pairedDevices() as! [IOBluetoothDevice];
    return devices.filter{$0.isConnected()}.map { $0.addressString }
}

let kBluetoothNotOnError = IOReturn(-536870185);

func connectDevice(device: IOBluetoothDevice) -> IOReturn {
    var res = kBluetoothNotOnError;
    while (res == kBluetoothNotOnError) {
        res = device.openConnection();
        usleep(2000);
    }
    return res;
}

func connectDeviceWithRetry(device: IOBluetoothDevice) {
    for i in 0..<10 {
        print(ts(), "connecting", device.addressString);
        let res = connectDevice(device: device);
        if res != kIOReturnSuccess {
            let delay = useconds_t(2000 * 1 << i);
            print(ts(), "Failed to connect", device.addressString, res, "delay", delay);
            usleep(delay);
        } else {
            print(ts(), "connected", device.addressString);
            break;
        }
    }
}

func connectDevicesByAddress(addresses: [String]) {
    for address in addresses {
        let device = getDeviceByAddress(address: address);
        if (device != nil && !device!.isConnected()) {
            connectDeviceWithRetry(device: device!);
        } else {
            print(ts(), "no matching device", address)
        }
    }
}

struct LidWatcherState : Codable {
    var lidPreviouslyClosed = false;
    var connectedBluetoothAddresses = [String]();
}

func main() {
    let path = "state.json"
    var state = LidWatcherState()
    if FileManager.default.fileExists(atPath: path) {
        let data = try! Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        state = try! JSONDecoder().decode(LidWatcherState.self, from: data)
        print(ts(), "read", path);
    }
    print(ts(), "state", state);
    let clamshellState = getClamshellState();

    // Only consider the lid closed if AppleClamshellCausesSleep is true.
    let lidCurrentlyClosed = clamshellState.AppleClamshellState && clamshellState.AppleClamshellCausesSleep;
    print(ts(), "lidCurrentlyClosed", lidCurrentlyClosed);
    if (state.lidPreviouslyClosed && !lidCurrentlyClosed) {
        print(ts(), "Opened");
        IOBluetoothPreferenceSetControllerPowerState(1);
        connectDevicesByAddress(addresses: state.connectedBluetoothAddresses);
        state.connectedBluetoothAddresses = [];
    } else if (!state.lidPreviouslyClosed && lidCurrentlyClosed) {
        print(ts(), "Closed");
        state.connectedBluetoothAddresses = getConnectedBluetoothAddresses();
        IOBluetoothPreferenceSetControllerPowerState(0);
    }
    state.lidPreviouslyClosed = lidCurrentlyClosed;
    let jsonData = try! JSONEncoder().encode(state);
    try! jsonData.write(to: URL(fileURLWithPath: path));
    print(ts(), "wrote", path)
}

main();
