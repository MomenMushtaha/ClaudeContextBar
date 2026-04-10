import Cocoa
import SwiftUI
import Combine

class StatusBarManager: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let dataProvider: ClaudeDataProvider
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var noSessionTicks = 0
    private let quitAfterTicks = 20 // 20 * 3s = 60s with no sessions

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        dataProvider = ClaudeDataProvider()

        super.init()

        setupPopover()
        setupStatusItem()
        setupDataBinding()
        startRefreshTimer()
        dataProvider.refresh()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        updateIcon()
    }

    private func setupPopover() {
        let contentView = PopoverContentView(dataProvider: dataProvider)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.behavior = .transient
        popover.animates = true
    }

    private func setupDataBinding() {
        dataProvider.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateIcon()
            }
        }.store(in: &cancellables)
    }

    private func startRefreshTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dataProvider.refresh()

            // Auto-quit when no sessions for ~60s
            if self.dataProvider.hasActiveSession {
                self.noSessionTicks = 0
            } else {
                self.noSessionTicks += 1
                if self.noSessionTicks >= self.quitAfterTicks {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = IconRenderer.render(
            percentage: dataProvider.contextUsedPercentage,
            hasSession: dataProvider.hasActiveSession
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        dataProvider.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
