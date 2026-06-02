import AppKit
import SwiftUI
import OSLog

/// Owns the Settings window directly, instead of relying on the SwiftUI
/// `Settings` scene + `showSettingsWindow:` (which no-ops in a `LSUIElement`
/// agent app — no app menu means no responder target).
///
/// The window uses the native preferences chrome: an `NSToolbar` in
/// `.preference` style renders the tabs centered in the title bar, the title
/// shows the active pane, and selecting a tab swaps the hosted SwiftUI view.
/// While Settings is open the app becomes a regular Dock app (findable +
/// focusable); closing it returns to a pure menu bar agent.
@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let settings: SettingsStore
    private let audio: AudioService
    private var window: NSWindow?
    private let log = Logger(subsystem: "com.wedevs.prayertimes", category: "settings")

    /// Fixed pane size so the window doesn't jump between tabs; tall panes scroll.
    private static let paneSize = NSSize(width: 480, height: 520)

    init(settings: SettingsStore, audio: AudioService) {
        self.settings = settings
        self.audio = audio
    }

    // MARK: Tabs

    private enum Tab: String, CaseIterable {
        case general, location, calculation, notifications

        var title: String {
            switch self {
            case .general: return "General"
            case .location: return "Location & Time"
            case .calculation: return "Calculation"
            case .notifications: return "Notifications"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .location: return "location"
            case .calculation: return "moon.circle"
            case .notifications: return "bell"
            }
        }
        var id: NSToolbarItem.Identifier { .init(rawValue) }
    }

    private var current: Tab = .general

    // MARK: Show / dismiss

    func show() {
        log.debug("Settings show() requested")

        // The click came from inside the MenuBarExtra panel, so it's the current
        // key window — capture it before we change focus, then dismiss it.
        let menuBarPanel = NSApp.keyWindow

        NSApp.setActivationPolicy(.regular)
        if window == nil { buildWindow() }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        if let menuBarPanel, menuBarPanel !== window,
           menuBarPanel is NSPanel || menuBarPanel.className.contains("MenuBarExtra") {
            menuBarPanel.orderOut(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        log.debug("Settings window closing; returning to accessory")
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: Window construction

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.paneSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = Tab.general.id
        window.toolbar = toolbar

        self.window = window
        select(.general)
        window.center()
        log.debug("Built Settings window with preference toolbar")
    }

    private func select(_ tab: Tab) {
        current = tab
        let host = NSHostingController(rootView: pane(for: tab))
        host.view.frame = NSRect(origin: .zero, size: Self.paneSize)
        window?.title = tab.title
        window?.contentViewController = host
        window?.toolbar?.selectedItemIdentifier = tab.id
    }

    private func pane(for tab: Tab) -> AnyView {
        let content: AnyView
        switch tab {
        case .general: content = AnyView(GeneralTab(settings: settings))
        case .location: content = AnyView(LocationTimeTab(settings: settings))
        case .calculation: content = AnyView(CalculationTab(settings: settings))
        case .notifications: content = AnyView(NotificationsTab(settings: settings, audio: audio))
        }
        return AnyView(content.frame(width: Self.paneSize.width, height: Self.paneSize.height))
    }

    @objc private func toolbarItemSelected(_ sender: NSToolbarItem) {
        guard let tab = Tab(rawValue: sender.itemIdentifier.rawValue) else { return }
        select(tab)
    }

    // MARK: NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = Tab(rawValue: identifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(toolbarItemSelected(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map(\.id)
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map(\.id)
    }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map(\.id)
    }
}
