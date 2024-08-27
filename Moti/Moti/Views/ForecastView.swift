//
//  ForecastView.swift
//  Moti
//
//  Created by Petros Dhespollari on 26/8/24.
//

import SwiftUI

struct ForecastView: View {
    let forecast: [DayForecast]

    var body: some View {
        VStack(spacing: 8) {
            Text("5-Day Forecast")
                .font(.headline)
                .padding(.bottom, 5)

            ForEach(forecast) { dayForecast in
                HStack(spacing: 8) { // Adjusted spacing between elements
                    Text(dayForecast.date)
                        .font(.system(size: 14))
                        .frame(width: 40, alignment: .leading) // Added some width to ensure padding to the left
                        .padding(.leading, 16) // Added padding to the left

                    if let iconURL = URL(string: dayForecast.weatherIcon) {
                        AsyncImage(url: iconURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 25, height: 25)
                        } placeholder: {
                            ProgressView()
                        }
                    }

                    Text("▲ \(dayForecast.highTemp, specifier: "%.0f")°C")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                        .frame(width: 70, alignment: .trailing)

                    Text("▼ \(dayForecast.lowTemp, specifier: "%.0f")°C")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                        .frame(width: 70, alignment: .leading)
                        .padding(.trailing, 5) // Added padding to the right to reduce extra space
                }
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            Spacer()
        }
        .padding(.horizontal)
        .frame(height: 280) // Adjust the height to fit the content better
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// Sample data for preview
struct ForecastView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleForecast = [
            DayForecast(date: "Mon", weatherIcon: "https://cdn.weatherapi.com/weather/64x64/day/116.png", highTemp: 25.0, lowTemp: 18.0),
            DayForecast(date: "Tue", weatherIcon: "https://cdn.weatherapi.com/weather/64x64/day/116.png", highTemp: 27.0, lowTemp: 19.0),
            DayForecast(date: "Wed", weatherIcon: "https://cdn.weatherapi.com/weather/64x64/day/116.png", highTemp: 26.0, lowTemp: 17.0),
            DayForecast(date: "Thu", weatherIcon: "https://cdn.weatherapi.com/weather/64x64/day/116.png", highTemp: 28.0, lowTemp: 20.0),
            DayForecast(date: "Fri", weatherIcon: "https://cdn.weatherapi.com/weather/64x64/day/116.png", highTemp: 29.0, lowTemp: 21.0)
        ]

        ForecastView(forecast: sampleForecast)
    }
}
