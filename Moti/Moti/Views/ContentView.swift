//
//  ContentView.swift
//  Moti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import Cocoa
import MapKit
import SwiftUI

class ContentViewState: ObservableObject {
    @Published var locationInput: String = ""
    @Published var showWeatherInfo: Bool = false
}

struct ContentView: View {
    @ObservedObject var weatherManager: WeatherManager
    @ObservedObject var state: ContentViewState

    var body: some View {
        VStack(spacing: 0) {
            locationSearchView()

            if shouldShowSuggestions {
                locationSuggestionsView()
            }

            if state.showWeatherInfo {
                weatherInfoView()
            }
        }
        .frame(width: 280, height: calculateHeight())
        .cornerRadius(10)
        .shadow(radius: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                weatherManager.fetchWeather()
            }
        }
    }

    private var shouldShowSuggestions: Bool {
        !state.locationInput.isEmpty && !weatherManager.locationSuggestions.isEmpty
    }

    @ViewBuilder
    private func locationSearchView() -> some View {
        if !state.showWeatherInfo {
            HStack {
                locationButton()
                locationTextField()
            }
            .padding(.horizontal)
        }
    }

    private func locationButton() -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.5)) {
                weatherManager.clearSelectedLocation()
                weatherManager.fetchCurrentLocation()
                state.showWeatherInfo = true
            }
        }) {
            Image(systemName: "mappin.and.ellipse")
                .cornerRadius(8)
        }
        .padding(.leading, 10)
    }

    private func locationTextField() -> some View {
        TextField("Search Location", text: $state.locationInput, onCommit: {
            performLocationSearch()
        })
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .onChange(of: state.locationInput, perform: handleLocationInputChange)
    }

    private func performLocationSearch() {
        withAnimation(.easeInOut(duration: 0.5)) {
            if !state.locationInput.isEmpty {
                weatherManager.geocodeLocation(locationName: state.locationInput)
                state.showWeatherInfo = true
            }
        }
    }

    private func handleLocationInputChange(_ newValue: String) {
        withAnimation(.easeInOut(duration: 0.5)) {
            if newValue.isEmpty {
                weatherManager.locationSuggestions = []
                state.showWeatherInfo = false
            } else {
                weatherManager.fetchLocationSuggestions(query: newValue)
                state.showWeatherInfo = false
            }
        }
    }

    @ViewBuilder
    private func locationSuggestionsView() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(weatherManager.locationSuggestions.prefix(3), id: \.title) { suggestion in
                    Text(suggestion.title)
                        .onTapGesture {
                            selectLocationSuggestion(suggestion)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxHeight: 70)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }

    private func selectLocationSuggestion(_ suggestion: MKLocalSearchCompletion) {
        withAnimation(.easeInOut(duration: 0.5)) {
            state.locationInput = suggestion.title
            weatherManager.geocodeLocation(locationName: suggestion.title)
            state.showWeatherInfo = true
        }
    }

    @ViewBuilder
    private func weatherInfoView() -> some View {
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

        ForecastView(forecast: weatherManager.forecast)
            .padding(.top, 5)
    }

    private func calculateHeight() -> CGFloat {
        if state.showWeatherInfo {
            return 355
        } else if shouldShowSuggestions {
            return 150
        } else {
            return 30
        }
    }
}
