//
//  ContentView.swift
//  Tempethera
//
//  Created by Petros Dhespollari on 25/8/24.
//

import Cocoa
import SwiftUI

class ContentViewState: ObservableObject {
    @Published var locationInput: String = ""
    @Published var showWeatherInfo: Bool = false
}

struct ContentView: View {
    @ObservedObject var weatherManager: WeatherManager
    @ObservedObject var state: ContentViewState // Inject the state

    var body: some View {
        VStack(spacing: 0) {
            if !state.showWeatherInfo {
                // Location Detection and Search
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            weatherManager.geocodeLocation(locationName: state.locationInput)
                            state.showWeatherInfo = true // Show weather info after search
                        }
                    }) {
                        Image(systemName: "mappin.and.ellipse")
                            .cornerRadius(8)
                    }
                    .padding(.leading, 10) // Adjusted left padding

                    TextField("Search Location", text: $state.locationInput, onCommit: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            if !state.locationInput.isEmpty {
                                weatherManager.geocodeLocation(locationName: state.locationInput)
                                state.showWeatherInfo = true // Show weather info after search
                            }
                        }
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: state.locationInput) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            if newValue.isEmpty {
                                weatherManager.locationSuggestions = [] // Clear suggestions
                                state.showWeatherInfo = false // Hide weather info
                            } else {
                                weatherManager.fetchLocationSuggestions(query: newValue)
                                state.showWeatherInfo = false // Hide weather info when typing
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            if !state.locationInput.isEmpty && !weatherManager.locationSuggestions.isEmpty {
                // Show location suggestions if user is typing and suggestions are available
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(weatherManager.locationSuggestions.prefix(3), id: \.title) { suggestion in
                            Text(suggestion.title)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        state.locationInput = suggestion.title
                                        weatherManager.geocodeLocation(locationName: suggestion.title)
                                        state.showWeatherInfo = true
                                    }
                                }
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 70) // Show only three suggestions
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 10) 
                .padding(.top, 10)
            }

            if state.showWeatherInfo {
                // Current Location and Temperature
                VStack(spacing: 5) {
                    Text(weatherManager.locationName)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.top, 30)

                    HStack(alignment: .top, spacing: 8) {
                        if let iconURL = URL(string: weatherManager.currentWeatherIcon) {
                            AsyncImage(url: iconURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                            } placeholder: {
                                ProgressView()
                            }
                        }
                        Text("\(weatherManager.currentTemperature, specifier: "%.0f")°C")
                            .font(.system(size: 45))
                            .fontWeight(.light)
                            .foregroundColor(.primary)
                    }
                }

                // Use the separated ForecastView here
                ForecastView(forecast: weatherManager.forecast)
                    .padding(.top, 5)
            }
        }
        // Adjust the frame height dynamically based on the content
        .frame(width: 280, height: calculateHeight())
        .cornerRadius(10)
        .shadow(radius: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                weatherManager.fetchWeather()
            }
        }
    }

    // Function to calculate the height of the view dynamically
    private func calculateHeight() -> CGFloat {
        if state.showWeatherInfo {
            return 355
        } else if !state.locationInput.isEmpty && !weatherManager.locationSuggestions.isEmpty {
            return 150 // Height to fit the suggestions
        } else {
            return 30 // Default height when only the search bar is shown
        }
    }

    func showAboutAlert() {
        let alert = NSAlert()
        alert.messageText = "About Tempethera"
        alert.informativeText = "Tempethera is a weather app that shows local weather information."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
