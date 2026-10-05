import Foundation
import IOKit.hid

/// Watches for mice coming and going. Trackpads register as HID mice too, so
/// the built-in one and Magic Trackpads are skipped, as is anything not on a
/// real external transport (virtual drivers and the like).
final class MouseWatcher {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private let onChange: (Bool) -> Void
    private var pending: DispatchWorkItem?

    /// `onChange` gets whether a mouse is connected, on the main queue, after
    /// every plug-in or removal. Devices are never opened, so no Input
    /// Monitoring permission is needed: the manager only reports what's there.
    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
        ] as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            Unmanaged<MouseWatcher>.fromOpaque(context!).takeUnretainedValue().devicesChanged()
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            Unmanaged<MouseWatcher>.fromOpaque(context!).takeUnretainedValue().devicesChanged(removing: device)
        }, context)
        // Common modes, so changes still land while the status menu is open.
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    }

    var mouseConnected: Bool { mouseConnected(excluding: nil) }

    private func mouseConnected(excluding gone: IOHIDDevice?) -> Bool {
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        return devices.contains { device in
            guard device != gone else { return false }
            func property(_ key: String) -> Any? { IOHIDDeviceGetProperty(device, key as CFString) }
            let builtIn = property(kIOHIDBuiltInKey) as? Bool ?? false
            let transport = property(kIOHIDTransportKey) as? String ?? ""
            let product = property(kIOHIDProductKey) as? String ?? ""
            return !builtIn
                && (transport.hasPrefix("USB") || transport.hasPrefix("Bluetooth"))
                && !product.localizedCaseInsensitiveContains("trackpad")
        }
    }

    private func devicesChanged(removing gone: IOHIDDevice? = nil) {
        // Act right away (the departing device may still be listed, so leave
        // it out by hand), then re-read once the device list has settled in
        // case that first answer was early. Repeats are cheap: setting the
        // direction it already has is a no-op.
        onChange(mouseConnected(excluding: gone))
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            onChange(mouseConnected)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
