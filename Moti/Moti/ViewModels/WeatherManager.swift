//
//  WeatherManager.swift
//  Moti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import Combine
import CoreLocation
import Foundation
import MapKit

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentTemperature: Double = 0.0
    @Published var forecast: [DayForecast] = []
    @Published var airQualityIndex: Int = 0
    @Published var locationName: String = "Current Location"
    @Published var currentWeatherIcon: String = "//cdn.weatherapi.com/weather/64x64/day/116.png"
    @Published var locationError: Bool = false
    @Published var locationSuggestions: [MKLocalSearchCompletion] = []
    @Published var locationServicesEnabled: Bool = false

    private let locationManager = CLLocationManager()
    private let searchCompleter = MKLocalSearchCompleter()
    private let apiKey = "7ec4d2d9f9924cb18d301120242508"
    private var timer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        searchCompleter.delegate = self
        checkLocationAuthorization()
        startWeatherUpdateTimer()
    }

    private func startWeatherUpdateTimer() {
        // Schedule the timer to fire every 29 minutes (29 * 60 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 29 * 60, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
    }

    deinit {
        // Invalidate the timer when the WeatherManager is deallocated
        timer?.invalidate()
    }

    public func requestLocationAuthorization() {
        let authorizationStatus: CLAuthorizationStatus

        if #available(iOS 14.0, macOS 11.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }

        switch authorizationStatus {
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

    private func checkLocationAuthorization() {
        let authorizationStatus: CLAuthorizationStatus

        if #available(iOS 14.0, macOS 11.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }

        switch authorizationStatus {
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus

        if #available(macOS 11.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            fetchWeather() // Proceed with weather fetching now that authorization is granted
        case .denied, .restricted:
            locationError = true
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            locationError = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            print("No location found")
            return
        }
        reverseGeocode(location: location) // Perform reverse geocoding to get the location name
        fetchWeatherAt(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        locationError = true
    }

    func fetchWeather() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = true
            return
        }

        if #available(macOS 11.0, *) {
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
                return
            }
        } else {
            let status = CLLocationManager.authorizationStatus()
            if status == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
                return
            }
        }

        guard !locationError, let location = locationManager.location else {
            locationError = true
            return
        }

        let latitude = round(location.coordinate.latitude * 100) / 100.0
        let longitude = round(location.coordinate.longitude * 100) / 100.0

        reverseGeocode(location: location) // Perform reverse geocoding to get the location name
        fetchWeatherAt(latitude: latitude, longitude: longitude)
    }

    func geocodeLocation(locationName: String) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = locationName

        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] response, error in
            if let error = error {
                print("Failed to search location: \(error.localizedDescription)")
                self?.locationError = true
                return
            }

            guard let self = self,
                  let mapItem = response?.mapItems.first,
                  let location = mapItem.placemark.location
            else {
                self?.locationError = true
                print("No valid location found")
                return
            }

            DispatchQueue.main.async {
                self.locationName = mapItem.name ?? locationName
                let latitude = round(location.coordinate.latitude * 100) / 100.0
                let longitude = round(location.coordinate.longitude * 100) / 100.0
                self.fetchWeatherAt(latitude: latitude, longitude: longitude)
            }
        }
    }

    func fetchLocationSuggestions(query: String) {
        searchCompleter.queryFragment = query
    }

    private func fetchWeatherAt(latitude: Double, longitude: Double) {
        let weatherURLString = "https://api.weatherapi.com/v1/forecast.json?key=\(apiKey)&q=\(latitude),\(longitude)&days=5&aqi=yes"

        guard let weatherURL = URL(string: weatherURLString) else {
            print("Error: Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: weatherURL) { data, response, error in
            if let error = error {
                print("Error during data task: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    print("Request succeeded with status code 200")
                case 400:
                    print("Bad Request: The server could not understand the request due to invalid syntax.")
                case 401:
                    print("Unauthorized: Access is denied due to invalid credentials.")
                case 403:
                    print("Forbidden: The server understood the request but refuses to authorize it.")
                case 404:
                    print("Not Found: The server can not find the requested resource.")
                case 500:
                    print("Internal Server Error: The server has encountered a situation it doesn't know how to handle.")
                default:
                    print("Unhandled HTTP status code: \(httpResponse.statusCode)")
                }
            }

            guard let data = data else {
                print("Error: No data received")
                return
            }

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

        task.resume()
    }

    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first else {
                print("No placemarks found")
                return
            }

            DispatchQueue.main.async {
                self.locationName = placemark.locality ?? "Unknown Location"
            }
        }
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
