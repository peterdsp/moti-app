//
//  MotiApp.swift
//  Moti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import AppKit
import Combine
import FirebaseCore
import FirebaseRemoteConfig
import SwiftUI

@main
struct MotiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Initialize Firebase in the App's initializer
    init() {
        FirebaseApp.configure() // Ensure Firebase is configured immediately
    }

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var weatherManager = WeatherManager()
    var contentViewState = ContentViewState() // Shared state for ContentView
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var isAlwaysOnTop = false // Track the "Always on Top" state

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSApplication.shared.setActivationPolicy(.prohibited)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // Set an initial loading image
            updateStatusButton(button: button, showLoading: true)
        }

        popover.contentViewController = NSHostingController(rootView: ContentView(weatherManager: weatherManager, state: contentViewState))

        weatherManager.$currentTemperature
            .combineLatest(weatherManager.$currentWeatherIcon)
            .receive(on: RunLoop.main)
            .sink { [weak self] temperature, icon in
                if let button = self?.statusItem.button {
                    self?.updateStatusButton(button: button, temperature: temperature, icon: icon)
                }
            }
            .store(in: &cancellables)

        weatherManager.fetchWeather()
    }

    func isNewVersionAvailable(localVersion: String, remoteVersion: String) -> Bool {
        return remoteVersion.compare(localVersion, options: .numeric) == .orderedDescending
    }

    @objc func handleStatusBarClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            // Right-click detected, hide the popover if it's shown
            if popover.isShown {
                popover.performClose(sender)
            }
            // Show context menu
            showContextMenu(sender)
        } else {
            // Left-click detected, toggle popover
            togglePopover(sender)
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        // Add "Refresh" option
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshWeather), keyEquivalent: "r"))

        // Add "Search Another Location" option
        menu.addItem(NSMenuItem(title: "Search Another Location", action: #selector(searchAnotherLocation), keyEquivalent: ""))

        // Add "Always on Top" option with a checkmark toggle
        let alwaysOnTopItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem.state = isAlwaysOnTop ? .on : .off
        menu.addItem(alwaysOnTopItem)

        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil) // Display the menu
        statusItem.menu = nil // Clear the menu after it's used
    }

    @objc private func toggleAlwaysOnTop() {
        isAlwaysOnTop.toggle() // Toggle the state

        // Update the popover behavior based on the new state
        if isAlwaysOnTop {
            removeGlobalClickMonitor() // Stop closing on outside click
        } else {
            addGlobalClickMonitor() // Start closing on outside click
        }
    }

    @objc func refreshWeather() {
        if let button = statusItem.button {
            updateStatusButton(button: button, showLoading: true)
        }

        weatherManager.fetchWeather()

        // Observe changes from the weatherManager
        weatherManager.$currentTemperature
            .combineLatest(weatherManager.$currentWeatherIcon)
            .receive(on: RunLoop.main)
            .sink { [weak self] temperature, icon in
                if let button = self?.statusItem.button {
                    self?.updateStatusButton(button: button, temperature: temperature, icon: icon)
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton(button: NSStatusBarButton, temperature: Double = 0.0, icon: String? = nil, showLoading: Bool = false) {
        if showLoading {
            // Create and configure a spinner (NSProgressIndicator)
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.sizeToFit()

            // Add the spinner to the status bar button and start animating
            button.subviews.forEach { $0.removeFromSuperview() } // Clear any existing subviews
            button.addSubview(spinner)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            spinner.startAnimation(nil)
            button.title = "" // Clear any existing title

        } else {
            // Remove any existing spinner
            button.subviews.forEach { $0.removeFromSuperview() }

            // Display the temperature and weather icon
            let formattedTemperature = String(format: "%.0f°C", temperature)
            button.title = formattedTemperature

            if let icon = icon, let iconURL = URL(string: icon) {
                // Load the image from the URL asynchronously
                DispatchQueue.global().async {
                    if let data = try? Data(contentsOf: iconURL), let image = NSImage(data: data) {
                        DispatchQueue.main.async {
                            // Resize the image while maintaining the aspect ratio
                            let resizedImage = self.resizeImage(image: image, toFit: CGSize(width: 18, height: 18))
                            button.image = resizedImage
                        }
                    } else {
                        DispatchQueue.main.async {
                            button.image = self.createDefaultIcon()
                        }
                    }
                }
            } else {
                button.image = createDefaultIcon()
            }
        }
    }

    private func resizeImage(image: NSImage, toFit targetSize: CGSize) -> NSImage? {
        let newSize: NSSize
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height

        if widthRatio > heightRatio {
            newSize = NSSize(width: image.size.width * heightRatio, height: image.size.height * heightRatio)
        } else {
            newSize = NSSize(width: image.size.width * widthRatio, height: image.size.width * widthRatio)
        }

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()

        return newImage
    }

    private func createDefaultIcon() -> NSImage? {
        let questionMarkIcon = NSImage(systemSymbolName: "questionmark", accessibilityDescription: "Unknown Weather Icon")
        return resizeImage(image: questionMarkIcon ?? NSImage(), toFit: CGSize(width: 18, height: 18))
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
            removeGlobalClickMonitor() // Stop monitoring clicks when popover closes
        } else {
            if let button = statusItem.button {
                popover.behavior = isAlwaysOnTop ? .applicationDefined : .semitransient // Custom behavior based on the setting
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                if !isAlwaysOnTop {
                    addGlobalClickMonitor() // Start monitoring clicks outside the popover only if "Always on Top" is disabled
                }
            }
        }
    }

    private func addGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            if !self.isAlwaysOnTop {
                self.popover.performClose(event)
                self.removeGlobalClickMonitor() // Stop monitoring once the popover is closed
            }
        }
    }

    private func removeGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    @objc func showAbout() {
        // Create the alert
        let alert = NSAlert()
        alert.messageText = "About Moti"

        // Retrieve the app version from the Info.plist
        let localVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let localBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        // Initial informative text
        alert.informativeText = "Moti is a weather app that shows local weather information.\nVersion: \(localVersion)"

        alert.alertStyle = .informational

        // Add "OK" button
        alert.addButton(withTitle: "OK")

        // Add "Check for Update" button
        alert.addButton(withTitle: "Check for Update")

        // Set the alert window to appear above all other apps
        let window = alert.window
        window.level = .statusBar

        // Run the alert as a modal and get the user's choice
        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            // The "Check for Update" button was clicked, so check Remote Config
            checkForUpdate(remoteConfig: RemoteConfig.remoteConfig(), alert: alert, localVersion: localVersion, localBuild: localBuild)
        }
    }

    func checkForUpdate(remoteConfig: RemoteConfig, alert: NSAlert, localVersion: String, localBuild: String) {
        // Fetch the version from Remote Config
        remoteConfig.fetchAndActivate { _, error in
            if let error = error {
                print("Error fetching remote config: \(error.localizedDescription)")
                alert.informativeText = """
                Moti is a weather app that shows local weather information.
                Version: \(localVersion)
                Error checking for updates: \(error.localizedDescription)
                """
            } else {
                let remoteVersion = remoteConfig["latest_app_version"].stringValue ?? "Unknown"

                // Compare local and remote versions
                if remoteVersion != "Unknown" && self.isNewVersionAvailable(localVersion: localVersion, remoteVersion: remoteVersion) {
                    alert.informativeText = """
                    Moti is a weather app that shows local weather information.
                    Version: \(localVersion)

                    A newer version (\(remoteVersion)) is available! You can download it from the link below.
                    """

                    // Add a "Download" button
                    alert.addButton(withTitle: "Download")
                } else {
                    alert.informativeText = """
                    Moti is a weather app that shows local weather information.
                    Version: \(localVersion)

                    You have the latest version.
                    """
                }
            }

            // Show the updated alert modally above all other windows
            alert.window.level = .statusBar
            let response = alert.runModal()

            // If the user clicked the "Download" button, open the download link
            if response == .alertThirdButtonReturn {
                if let url = URL(string: "https://peterdsp.gumroad.com/l/moti") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func searchAnotherLocation() {
        // Hide the popover and reset the UI for a new location search
        popover.performClose(nil)

        // Reset the state for a new search
        contentViewState.locationInput = "" // Accessing locationInput from contentViewState
        contentViewState.showWeatherInfo = false // Accessing showWeatherInfo from contentViewState

        if let button = statusItem.button {
            popover.behavior = .transient // or use .semitransient for slightly different behavior
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
