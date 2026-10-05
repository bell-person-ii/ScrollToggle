import Cocoa

/// Wraps the private PreferencePanesSupport entry points that System Settings
/// itself uses for the "Natural scrolling" checkbox. Going through these keeps
/// the change live: the value lands in NSGlobalDomain and WindowServer picks it
/// up immediately, with no logout and no visible window.
enum ScrollDirection {
    private typealias GetFn = @convention(c) () -> ObjCBool
    private typealias SetFn = @convention(c) (ObjCBool) -> Void

    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport",
        RTLD_LAZY)

    private static let getFn: GetFn? = symbol("swipeScrollDirection")
    private static let setFn: SetFn? = symbol("setSwipeScrollDirection")

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    /// True when "natural" (content-tracks-finger) scrolling is on.
    /// Falls back to the preference domain if the private symbol ever vanishes.
    static var isNatural: Bool {
        if let getFn { return getFn().boolValue }
        return UserDefaults.standard.bool(forKey: "com.apple.swipescrolldirection")
    }

    /// Whether this build can actually flip the setting.
    static var isAvailable: Bool { getFn != nil && setFn != nil }

    static func set(natural: Bool) {
        // Skip no-op writes: each one broadcasts a change notification.
        guard natural != isNatural else { return }
        setFn?(ObjCBool(natural))
    }

    @discardableResult
    static func toggle() -> Bool {
        let next = !isNatural
        set(natural: next)
        return next
    }
}
