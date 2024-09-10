//
//  WeatherManager.swift
//  Moti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import Combine
import CoreLocation
import FirebaseRemoteConfig
import Foundation
import MapKit

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentTemperature: Double = 0.0
    @Published var forecast: [DayForecast] = []
    @Published var airQualityIndex: Int = 0
    @Published var selectedLocation: CLLocationCoordinate2D?
    @Published var locationName: String = "Current Location"
    @Published var currentWeatherIcon: String = "//cdn.weatherapi.com/weather/64x64/day/116.png"
    @Published var locationError: Bool = false
    @Published var locationSuggestions: [MKLocalSearchCompletion] = []
    @Published var locationServicesEnabled: Bool = false

    private let locationManager = CLLocationManager()
    private let searchCompleter = MKLocalSearchCompleter()
    private var apiKey: String = ""
    private var timer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        searchCompleter.delegate = self
        fetchApiKeyFromRemoteConfig()
        checkLocationAuthorization()
        startWeatherUpdateTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func fetchApiKeyFromRemoteConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        remoteConfig.fetch { [weak self] status, error in
            guard let self = self else { return }

            if status == .success {
                remoteConfig.activate { _, _ in
                    DispatchQueue.main.async {
                        self.apiKey = remoteConfig["weather_api"].stringValue ?? ""
//                        print("Fetched API Key: \(self.apiKey)")
                        self.fetchWeather() // Optionally, fetch weather after obtaining the API key
                    }
                }
            } else {
                print("Error fetching remote config: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func fetchCurrentLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.startUpdatingLocation()
    }

    func requestLocationAuthorization() {
        let authorizationStatus = getLocationAuthorizationStatus()
        handleAuthorizationStatus(authorizationStatus)
    }

    func fetchWeather() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = true
            return
        }

        if let selectedLocation = selectedLocation {
            fetchWeatherAt(latitude: selectedLocation.latitude, longitude: selectedLocation.longitude)
        } else if let location = locationManager.location {
            fetchWeatherAt(latitude: round(location.coordinate.latitude * 100) / 100.0,
                           longitude: round(location.coordinate.longitude * 100) / 100.0)
        } else {
            locationError = true
            print("No valid location found")
        }
    }

    func geocodeLocation(locationName: String) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = locationName

        MKLocalSearch(request: searchRequest).start { [weak self] response, error in
            guard let self = self else { return }

            if let error = error as? MKError {
                self.handleSearchError(error)
                return
            }

            if let mapItem = response?.mapItems.first, let location = mapItem.placemark.location {
                DispatchQueue.main.async {
                    self.selectedLocation = location.coordinate
                    self.locationName = mapItem.name ?? locationName
                    self.fetchWeatherAt(latitude: round(location.coordinate.latitude * 100) / 100.0,
                                        longitude: round(location.coordinate.longitude * 100) / 100.0)
                }
            } else {
                self.locationError = true
                print("No valid location found")
            }
        }
    }

    func fetchLocationSuggestions(query: String) {
        searchCompleter.queryFragment = query
    }

    func clearSelectedLocation() {
        selectedLocation = nil
    }

    private func startWeatherUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
    }

    private func checkLocationAuthorization() {
        let authorizationStatus = getLocationAuthorizationStatus()
        handleAuthorizationStatus(authorizationStatus)
    }

    private func getLocationAuthorizationStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, macOS 11.0, *) {
            return locationManager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            locationError = true
            print("Location services are restricted or denied. Please enable them in Settings.")
        case .authorizedWhenInUse, .authorizedAlways:
            locationError = false
            locationManager.startUpdatingLocation()
        @unknown default:
            locationError = true
            print("Unknown authorization status.")
        }
    }

    private func fetchWeatherAt(latitude: Double, longitude: Double) {
        let weatherURLString = "https://api.weatherapi.com/v1/forecast.json?key=\(apiKey)&q=\(latitude),\(longitude)&days=5&aqi=yes"
        guard let weatherURL = URL(string: weatherURLString) else {
            print("Error: Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: weatherURL) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("Error during data task: \(error.localizedDescription)")
                return
            }

            self.handleHTTPResponse(response)

            guard let data = data else {
                print("Error: No data received")
                return
            }

            self.decodeWeatherData(data)
        }.resume()
    }

    private func handleHTTPResponse(_ response: URLResponse?) {
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                print("Request succeeded with status code 200")
            case 400...499:
                print("Client error occurred: \(httpResponse.statusCode)")
            case 500...599:
                print("Server error occurred: \(httpResponse.statusCode)")
            default:
                print("Unhandled HTTP status code: \(httpResponse.statusCode)")
            }
        }
    }

    private func decodeWeatherData(_ data: Data) {
        do {
            let decodedData = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
            DispatchQueue.main.async {
                self.currentTemperature = decodedData.current.temp_c
                self.currentWeatherIcon = "https:" + decodedData.current.condition.icon
                self.forecast = decodedData.forecast.forecastday.map { forecastDay in
                    DayForecast(
                        date: Date(timeIntervalSince1970: TimeInterval(forecastDay.date_epoch)).formatted(.dateTime.weekday()),
                        weatherIcon: "https:" + forecastDay.day.condition.icon,
                        highTemp: forecastDay.day.maxtemp_c,
                        lowTemp: forecastDay.day.mintemp_c
                    )
                }
            }
        } catch {
            print("Failed to decode JSON: \(error)")
        }
    }

    private func reverseGeocode(location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.locationName = placemark.locality ?? "Unknown Location"
                    print("Location Name: \(self.locationName)")
                }
            } else {
                print("No placemarks found")
            }
        }
    }

    private func handleSearchError(_ error: MKError) {
        switch error.code {
        case .placemarkNotFound:
            print("No placemarks found.")
        case .serverFailure:
            print("The server encountered an error.")
        case .loadingThrottled:
            print("Data loading is being throttled by the system.")
        default:
            print("Search error: \(error.localizedDescription)")
        }
        locationError = true
    }

    // CLLocationManagerDelegate methods
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = getLocationAuthorizationStatus()
        handleAuthorizationStatus(status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            print("No location available.")
            return
        }

        fetchWeatherAt(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        reverseGeocode(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        locationError = true
    }
}

extension WeatherManager: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.locationSuggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Error completing search: \(error.localizedDescription)")
    }
}
