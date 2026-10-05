import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var mouseWatcher: MouseWatcher!
    /// Direction the status item last showed, to spot flips in refresh().
    private var shownNatural: Bool?
    private var bubble: NSPopover?
    private var hideBubble: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set here, not before run(): LSUIElement has already been applied by
        // this point, so this is what actually sticks.
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Either click only opens the menu, so a stray click can't flip
        // anything: the switch is one deliberate pick inside it.
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Another app (or System Settings) can change this behind our back.
        // KVO on UserDefaults never fires for NSGlobalDomain keys written by
        // another process, so listen for the broadcast System Settings posts.
        // AppKit holds distributed notifications back while an app is
        // inactive, and this one never activates, so ask for them right away.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(externalChange),
            name: NSNotification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil,
            suspensionBehavior: .deliverImmediately)

        // Follow the mouse: a wheel wants natural scrolling off, the trackpad
        // alone wants it on. Applied at launch and on every plug-in or
        // removal; a pick from the menu in between still wins until the next change.
        shownNatural = ScrollDirection.isNatural
        mouseWatcher = MouseWatcher { [weak self] in self?.follow(mouseConnected: $0) }
        follow(mouseConnected: mouseWatcher.mouseConnected)

        if !ScrollDirection.isAvailable { reportUnavailable() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func externalChange() {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    private func follow(mouseConnected: Bool) {
        ScrollDirection.set(natural: !mouseConnected)
        refresh()
    }

    // MARK: - Interaction

    /// Rebuilt on every open so the state line and the switch's wording
    /// always match the current direction.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let natural = ScrollDirection.isNatural

        let state = NSMenuItem(title: natural ? "자연스러운 스크롤: 켬" : "자연스러운 스크롤: 끔",
                               action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)

        let toggle = NSMenuItem(title: natural ? "자연스러운 스크롤 끄기" : "자연스러운 스크롤 켜기",
                                action: #selector(toggleScrolling), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "로그인 시 실행",
                               action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleScrolling() {
        ScrollDirection.toggle()
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            present("로그인 항목을 변경하지 못했습니다", error.localizedDescription)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Presentation

    private func refresh() {
        guard let button = statusItem.button else { return }
        let natural = ScrollDirection.isNatural
        let name = natural ? "arrow.up.and.down" : "arrow.up.arrow.down"
        let label = natural ? "자연스러운 스크롤: 켬" : "자연스러운 스크롤: 끔"

        button.image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        button.image?.isTemplate = true
        button.appearsDisabled = !natural
        button.toolTip = label

        // Spell out the new state under the icon for a moment whenever it
        // flips, whatever flipped it: the menu, a mouse, or System Settings.
        if let shown = shownNatural, shown != natural { showBubble(label) }
        shownNatural = natural
    }

    /// A popover hanging off the status item. It never takes key focus, so
    /// it can pop up mid-typing without stealing keystrokes.
    private func showBubble(_ text: String) {
        guard let button = statusItem.button else { return }

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.sizeToFit()
        let content = NSView(frame: NSRect(x: 0, y: 0, width: label.frame.width + 28,
                                           height: label.frame.height + 16))
        label.setFrameOrigin(NSPoint(x: 14, y: 8))
        content.addSubview(label)
        let controller = NSViewController()
        controller.view = content

        bubble?.close()
        hideBubble?.cancel()
        let popover = NSPopover()
        // Closed by the timer below, not by clicks elsewhere: the app is
        // never active, so a transient popover would vanish immediately.
        popover.behavior = .applicationDefined
        popover.contentViewController = controller
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        bubble = popover

        let work = DispatchWorkItem { [weak popover] in popover?.performClose(nil) }
        hideBubble = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func reportUnavailable() {
        present("이 macOS 버전에서는 전환할 수 없습니다",
                "시스템 내부 설정 함수를 찾지 못했습니다. 현재 상태는 계속 표시됩니다.")
    }

    private func present(_ message: String, _ info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
