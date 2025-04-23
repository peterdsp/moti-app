//
//  myMotiApp.swift
//  myMoti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import AppKit
import Combine
import FirebaseCore
import FirebaseRemoteConfig
import SwiftUI

@main
struct myMotiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        FirebaseApp.configure()  // Ensures Firebase is configured immediately at launch
    }

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var weatherManager = WeatherManager()
    var contentViewState = ContentViewState()
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var isAlwaysOnTop = false
    @Published var currentLanguage: String = "en"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopoverContent()
        bindWeatherUpdates()
        weatherManager.fetchWeather()
    }

    func isNewVersionAvailable(localVersion: String, remoteVersion: String) -> Bool {
        return remoteVersion.compare(localVersion, options: .numeric) == .orderedDescending
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSApplication.shared.setActivationPolicy(.prohibited)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateStatusButton(button: button, showLoading: true)
        }
    }

    private func setupPopoverContent() {
        popover.contentViewController = NSHostingController(
            rootView: ContentView(weatherManager: weatherManager, state: contentViewState))
    }

    private func bindWeatherUpdates() {
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

    @objc func handleStatusBarClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            if popover.isShown { popover.performClose(sender) }
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        // Refresh option
        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("refresh", comment: ""), action: #selector(refreshWeather),
                keyEquivalent: "r"))

        // Search Another Location option
        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("search_another_location", comment: ""),
                action: #selector(searchAnotherLocation),
                keyEquivalent: ""))

        // Language submenu with emoji flags
        let languageMenuItem = NSMenuItem(
            title: NSLocalizedString("change_language", comment: ""), action: nil, keyEquivalent: ""
        )
        let languageSubMenu = NSMenu()

        let englishItem = NSMenuItem(
            title: "English", action: #selector(setLanguage(_:)), keyEquivalent: "")
        englishItem.tag = 0

        let greekItem = NSMenuItem(
            title: "Ελληνικά", action: #selector(setLanguage(_:)), keyEquivalent: "")
        greekItem.tag = 1

        let albanianItem = NSMenuItem(
            title: "Shqip", action: #selector(setLanguage(_:)), keyEquivalent: "")
        albanianItem.tag = 2

        languageSubMenu.addItem(englishItem)
        languageSubMenu.addItem(greekItem)
        languageSubMenu.addItem(albanianItem)
        languageMenuItem.submenu = languageSubMenu
        menu.addItem(languageMenuItem)

        // About and Quit options
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("about", comment: ""), action: #selector(showAbout),
                keyEquivalent: ""))
        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("quit", comment: ""), action: #selector(quitApp),
                keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleAlwaysOnTop() {
        isAlwaysOnTop.toggle()  // Toggle the state

        // Update the popover behavior based on the new state
        if isAlwaysOnTop {
            removeGlobalClickMonitor()  // Stop closing on outside click
        } else {
            addGlobalClickMonitor()  // Start closing on outside click
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

    private func updateStatusButton(
        button: NSStatusBarButton, temperature: Double = 0.0, icon: String? = nil,
        showLoading: Bool = false
    ) {
        button.subviews.forEach { $0.removeFromSuperview() }

        if showLoading {
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            button.addSubview(spinner)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            ])
            spinner.startAnimation(nil)
        } else {
            let formattedTemperature = String(format: "%.0f°C", temperature)
            button.title = formattedTemperature
            if let iconURL = URL(string: icon ?? "") {
                loadImage(from: iconURL) { image in
                    button.image = self.resizeImage(
                        image: image, toFit: CGSize(width: 18, height: 18))
                }
            }
        }
    }

    private func loadImage(from url: URL, completion: @escaping (NSImage) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else if let error = error {
                print("Failed to load image from \(url): \(error.localizedDescription)")
            }
        }
        task.priority = URLSessionTask.highPriority  // Set a high priority if necessary
        task.resume()
    }

    private func resizeImage(image: NSImage, toFit targetSize: CGSize) -> NSImage {
        let newSize: NSSize
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        newSize =
            (widthRatio > heightRatio)
            ? NSSize(width: image.size.width * heightRatio, height: image.size.height * heightRatio)
            : NSSize(width: image.size.width * widthRatio, height: image.size.height * widthRatio)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        return newImage
    }

    private func createDefaultIcon() -> NSImage? {
        let questionMarkIcon = NSImage(
            systemSymbolName: "questionmark", accessibilityDescription: "Unknown Weather Icon")
        return resizeImage(
            image: questionMarkIcon ?? NSImage(), toFit: CGSize(width: 18, height: 18))
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
            removeGlobalClickMonitor()  // Stop monitoring clicks when popover closes
        } else {
            if let button = statusItem.button {
                popover.behavior = .semitransient  // Optional, to allow better interaction
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                addGlobalClickMonitor()  // Start monitoring clicks outside the popover
            }
        }
    }

    private func addGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown,
        ]) { [weak self] event in
            self?.popover.performClose(event)
            self?.removeGlobalClickMonitor()  // Stop monitoring once the popover is closed
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
        alert.messageText = "About myMoti"

        // Retrieve the app version from the Info.plist
        let localVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let localBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        // Initial informative text
        alert.informativeText =
            "myMoti is a weather app that shows local weather information.\nVersion: \(localVersion)"

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
            // Create a new instance of NSAlert for the update check
            let updateAlert = NSAlert()
            updateAlert.messageText = "Checking for Updates..."
            checkForUpdate(
                remoteConfig: RemoteConfig.remoteConfig(), alert: updateAlert,
                localVersion: localVersion, localBuild: localBuild)
        }
    }

    func checkForUpdate(
        remoteConfig: RemoteConfig, alert: NSAlert, localVersion: String, localBuild: String
    ) {
        // Store the index of the "Download" button
        var downloadButtonIndex: NSApplication.ModalResponse? = nil

        // Fetch the version from Remote Config
        remoteConfig.fetch(withExpirationDuration: 0) { _, error in
            if let error = error {
                print("Error fetching remote config: \(error.localizedDescription)")
                alert.informativeText = """
                    myMoti is a weather app that shows local weather information.
                    Version: \(localVersion)
                    Error checking for updates: \(error.localizedDescription)
                    """
            } else {
                remoteConfig.activate(completion: nil)
                let remoteVersion = remoteConfig["latest_app_version"].stringValue ?? "Unknown"
                print("Fetched remote version: \(remoteVersion)")  // Debugging output

                if remoteVersion != "Unknown"
                    && self.isNewVersionAvailable(
                        localVersion: localVersion, remoteVersion: remoteVersion)
                {
                    alert.informativeText = """
                        myMoti is a weather app that shows local weather information.
                        Version: \(localVersion)

                        A newer version (\(remoteVersion)) is available! You can download it from the link below.
                        """

                    // Calculate the index for the "Download" button
                    downloadButtonIndex = NSApplication.ModalResponse(
                        rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
                            + alert.buttons.count)

                    // Add a "Download" button
                    alert.addButton(withTitle: "Download")
                } else {
                    alert.informativeText = """
                        myMoti is a weather app that shows local weather information.
                        Version: \(localVersion)

                        You have the latest version.
                        """
                }
            }

            alert.window.level = .statusBar
            let response = alert.runModal()

            // Check if the user clicked the "Download" button
            if response == downloadButtonIndex {
                if let url = URL(string: "https://peterdsp.gumroad.com/l/moti") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        switch sender.tag {
        case 0:
            currentLanguage = "en"
        case 1:
            currentLanguage = "el"
        case 2:
            currentLanguage = "sq"
        default:
            break
        }
        // print("Current language set to: \(currentLanguage)")  // Print the current language
        updateLanguage()
    }

    private func updateLanguage() {
        print("Updating UI language to: \(currentLanguage)")  // Print the language during update
        Bundle.setLanguage(currentLanguage)

        // Reload the app's UI with the new language setting
        popover.contentViewController = NSHostingController(
            rootView: ContentView(weatherManager: weatherManager, state: contentViewState))
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func searchAnotherLocation() {
        // Hide the popover and reset the UI for a new location search
        popover.performClose(nil)

        // Reset the state for a new search
        contentViewState.locationInput = ""  // Accessing locationInput from contentViewState
        contentViewState.showWeatherInfo = false  // Accessing showWeatherInfo from contentViewState

        if let button = statusItem.button {
            popover.behavior = .transient  // or use .semitransient for slightly different behavior
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

// MARK: - Bundle Extension for Language Switching

extension Bundle {
    private static var onLanguageDispatchOnce: () -> Void = {
        object_setClass(Bundle.main, LanguageBundle.self)
    }

    static func setLanguage(_ language: String) {
        onLanguageDispatchOnce()
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}

private class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?)
        -> String
    {
        let language = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "en"

        // Check if the language-specific bundle path is available
        guard let bundlePath = Bundle.main.path(forResource: language, ofType: "lproj"),
            let languageBundle = Bundle(path: bundlePath)
        else {
            print("Fallback to main bundle for language: \(language)")  // Debugging output
            return super.localizedString(forKey: key, value: value, table: tableName)
        }

        return languageBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}
