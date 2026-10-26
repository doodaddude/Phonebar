import AppKit
import SwiftUI

/// Represents one running phone window instance.
@MainActor
final class WindowInstance: Identifiable, ObservableObject {
    let id: String // Unique instance ID
    let appID: String
    var app: WebAppConfig
    let instanceNumber: Int
    let controller: PhoneWindowController
    var statusItem: NSStatusItem?
    let openedAt: Date

    init(id: String, app: WebAppConfig, instanceNumber: Int, controller: PhoneWindowController, openedAt: Date = Date()) {
        self.id = id
        self.appID = app.id
        self.app = app
        self.instanceNumber = instanceNumber
        self.controller = controller
        self.openedAt = openedAt
    }
}

/// Tracks open phone windows, manages multi-instance support, and adds companion menu bar icons for each running instance.
@MainActor
final class WindowManager: NSObject, ObservableObject {
    @Published private(set) var openIDs: Set<String> = []
    @Published private(set) var instances: [WindowInstance] = []
    @Published var activeApp: WebAppConfig? = nil

    private var instanceMap: [String: WindowInstance] = [:]
    private var statusItemToInstanceID: [ObjectIdentifier: String] = [:]

    /// Floating bubble quick-access hub.
    private(set) var bubbleHub: BubbleHubController?

    @Published var isBubbleHubEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBubbleHubEnabled, forKey: "isBubbleHubEnabled")
            if isBubbleHubEnabled {
                bubbleHub?.show()
            } else {
                bubbleHub?.hide()
            }
        }
    }

    weak var store: AppStore?

    init(store: AppStore? = nil) {
        self.store = store
        self.isBubbleHubEnabled = UserDefaults.standard.object(forKey: "isBubbleHubEnabled") as? Bool ?? true
        super.init()
        let hub = BubbleHubController(windowManager: self, store: store)
        self.bubbleHub = hub
        if isBubbleHubEnabled {
            DispatchQueue.main.async {
                hub.show()
            }
        }
    }

    func openCount(for appID: String) -> Int {
        instances.filter { $0.appID == appID }.count
    }

    func open(_ app: WebAppConfig, store: AppStore, forceNewInstance: Bool = false) {
        store.recordAppOpened(app.id)

        let existingForApp = instances.filter { $0.appID == app.id }
        if !forceNewInstance && !existingForApp.isEmpty {
            // Bring latest existing instance to front
            if let latest = existingForApp.last {
                latest.controller.show()
                activeApp = app
                return
            }
        }

        let instanceNumber = existingForApp.count + 1
        let instanceID = "\(app.id)#\(UUID().uuidString.prefix(6))"
        let cascadeIndex = instances.count

        var controller: PhoneWindowController!
        controller = PhoneWindowController(
            config: app,
            instanceID: instanceID,
            instanceNumber: instanceNumber,
            cascadeIndex: cascadeIndex,
            spoofingEnabled: store.isLocationSpoofingEnabled,
            spoofedLocation: store.selectedSpoofedLocation,
            onFocus: { [weak self] focusedConfig in
                guard let self = self else { return }
                self.activeApp = focusedConfig
            },
            onConfigUpdate: { [weak store] updatedConfig in
                store?.update(app: updatedConfig)
            },
            onOpenInBrowser: { [weak store] targetApp in
                store?.openInBrowser(app: targetApp)
            },
            onNewInstance: { [weak self, weak store] targetApp in
                guard let self = self, let store = store else { return }
                self.open(targetApp, store: store, forceNewInstance: true)
            },
            onClose: { [weak self] closedInstanceID in
                guard let self = self else { return }
                self.cleanupInstance(id: closedInstanceID)
            }
        )

        let instance = WindowInstance(
            id: instanceID,
            app: app,
            instanceNumber: instanceNumber,
            controller: controller
        )

        // Create individual Menu Bar companion icon for this running phone
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "\(app.name)\(instanceNumber > 1 ? " (#\(instanceNumber))" : "") - Running Phone"

            let fallback = NSImage(systemSymbolName: "iphone", accessibilityDescription: app.name)
            fallback?.isTemplate = true
            button.image = fallback
            button.imagePosition = .imageOnly

            FaviconService.shared.loadFavicon(for: app) { img in
                guard let img = img else { return }
                let icon = FaviconService.shared.menuBarIcon(for: img)
                DispatchQueue.main.async {
                    button.image = icon
                }
            }
        }
        instance.statusItem = statusItem
        statusItemToInstanceID[ObjectIdentifier(statusItem)] = instanceID

        instanceMap[instanceID] = instance
        instances.append(instance)
        openIDs.insert(app.id)

        // Position before show() so targetFrame in show() is always non-zero.
        // Bug: without a positioning call the window frame stays NSRect(origin:.zero,...) from init,
        // so show() animates TO (0,0) — the bottom-left corner spawn bug.
        if store.pinUnderMenuBar {
            controller.positionUnderneathStatusItem(statusItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                controller.positionUnderneathStatusItem(statusItem)
            }
        } else {
            // Free-floating mode still needs a sane initial position.
            controller.positionUnderneathMenuBar(index: instances.count)
        }

        controller.show()
        activeApp = app

        // Ensure floating bubble hub is shown if enabled
        if isBubbleHubEnabled {
            bubbleHub?.show()
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let instance = instances.first(where: { $0.statusItem?.button == sender }) else {
            return
        }

        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Show instance context menu
            let menu = NSMenu()
            let titleItem = NSMenuItem(title: "\(instance.app.name)\(instance.instanceNumber > 1 ? " (#\(instance.instanceNumber))" : "")", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)
            menu.addItem(NSMenuItem.separator())

            let frontItem = NSMenuItem(title: "Bring to Front", action: #selector(menuBringToFront(_:)), keyEquivalent: "")
            frontItem.representedObject = instance.id
            frontItem.target = self
            menu.addItem(frontItem)

            let newItem = NSMenuItem(title: "Open Another Instance", action: #selector(menuNewInstance(_:)), keyEquivalent: "")
            newItem.representedObject = instance.id
            newItem.target = self
            menu.addItem(newItem)

            let reloadItem = NSMenuItem(title: "Clear Cache & Reload", action: #selector(menuClearCache(_:)), keyEquivalent: "")
            reloadItem.representedObject = instance.id
            reloadItem.target = self
            menu.addItem(reloadItem)

            menu.addItem(NSMenuItem.separator())

            let closeItem = NSMenuItem(title: "Close Phone", action: #selector(menuCloseInstance(_:)), keyEquivalent: "")
            closeItem.representedObject = instance.id
            closeItem.target = self
            menu.addItem(closeItem)

            instance.statusItem?.menu = menu
            instance.statusItem?.button?.performClick(nil)
            DispatchQueue.main.async {
                instance.statusItem?.menu = nil
            }
        } else {
            // Left click: toggle genie show/hide effect
            instance.controller.toggleVisibility()
        }
    }

    @objc private func menuBringToFront(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let instance = instanceMap[id] else { return }
        instance.controller.show()
    }

    @objc private func menuNewInstance(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let instance = instanceMap[id] else { return }
        instance.controller.onNewInstance?(instance.app)
    }

    @objc private func menuClearCache(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let instance = instanceMap[id] else { return }
        instance.controller.model.clearHostCacheAndReload()
    }

    @objc private func menuCloseInstance(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let instance = instanceMap[id] else { return }
        instance.controller.close()
    }

    private func cleanupInstance(id: String) {
        guard let instance = instanceMap[id] else { return }
        if let statusItem = instance.statusItem {
            statusItemToInstanceID.removeValue(forKey: ObjectIdentifier(statusItem))
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        instanceMap.removeValue(forKey: id)
        instances.removeAll { $0.id == id }

        // Update openIDs set
        let remainingAppIDs = Set(instances.map { $0.appID })
        openIDs = remainingAppIDs

        if let last = instances.last {
            activeApp = last.app
        } else {
            activeApp = nil
        }
    }

    func close(id: String) {
        let matching = instances.filter { $0.appID == id }
        for inst in matching {
            inst.controller.close()
        }
    }

    func closeInstance(instanceID: String) {
        instanceMap[instanceID]?.controller.close()
    }

    func closeAll() {
        let allControllers = instances.map { $0.controller }
        for controller in allControllers {
            controller.close()
        }
    }
}
