//
//  MotiApp.swift
//  Moti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import AppKit
import Combine
import SwiftUI

@main
struct MotiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil) // Display the menu
        statusItem.menu = nil // Clear the menu after it's used
    }

    @objc func refreshWeather() {
        // Set the loading icon while refreshing
        if let button = statusItem.button {
            updateStatusButton(button: button, showLoading: true)
        }

        // Fetch the weather data again with a completion handler
        weatherManager.fetchWeather()
        DispatchQueue.main.async {
            let button = self.statusItem.button
            let temperature = self.weatherManager.currentTemperature
            let icon = self.weatherManager.currentWeatherIcon
            self.updateStatusButton(button: button!, temperature: temperature, icon: icon, showLoading: false)
        }
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
            newSize = NSSize(width: image.size.width * widthRatio, height: image.size.height * widthRatio)
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
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Moti"
        alert.informativeText = "Moti is a weather app that shows local weather information."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
