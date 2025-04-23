//
//  WeatherData.swift
//  myMoti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import Foundation

// Define the struct to match the JSON structure from WeatherAPI
struct WeatherAPIResponse: Codable {
    let location: Location
    let current: CurrentWeather
    let forecast: ForecastData
    let alerts: Alerts?

    struct Location: Codable {
        let name: String
        let region: String
        let country: String
        let lat: Double
        let lon: Double
        let tz_id: String
        let localtime_epoch: Int
        let localtime: String
    }

    struct CurrentWeather: Codable {
        let last_updated_epoch: Int
        let last_updated: String
        let temp_c: Double
        let temp_f: Double
        let is_day: Int
        let condition: WeatherCondition
        let wind_mph: Double
        let wind_kph: Double
        let wind_degree: Int
        let wind_dir: String
        let pressure_mb: Double
        let pressure_in: Double
        let precip_mm: Double
        let precip_in: Double
        let humidity: Int
        let cloud: Int
        let feelslike_c: Double
        let feelslike_f: Double
        let windchill_c: Double?
        let windchill_f: Double?
        let heatindex_c: Double?
        let heatindex_f: Double?
        let dewpoint_c: Double
        let dewpoint_f: Double
        let vis_km: Double
        let vis_miles: Double
        let uv: Double
        let gust_mph: Double
        let gust_kph: Double
    }

    struct WeatherCondition: Codable {
        let text: String
        let icon: String
        let code: Int
    }

    struct AirQuality: Codable {
        let co: Double?
        let no2: Double?
        let o3: Double?
        let so2: Double?
        let pm2_5: Double?
        let pm10: Double?
        let us_epa_index: Int?
        let gb_defra_index: Int?

        enum CodingKeys: String, CodingKey {
            case co
            case no2
            case o3
            case so2
            case pm2_5
            case pm10
            case us_epa_index = "us-epa-index"
            case gb_defra_index = "gb-defra-index"
        }
    }

    struct ForecastData: Codable {
        let forecastday: [DailyForecast]
    }

    struct DailyForecast: Codable, Identifiable {
        var id: UUID { UUID() }  // Computed property to generate a new UUID each time
        let date: String
        let date_epoch: Int
        let day: DayWeather
        let astro: Astro
        let hour: [HourlyForecast]

        struct DayWeather: Codable {
            let maxtemp_c: Double
            let maxtemp_f: Double
            let mintemp_c: Double
            let mintemp_f: Double
            let avgtemp_c: Double
            let avgtemp_f: Double
            let maxwind_mph: Double
            let maxwind_kph: Double
            let totalprecip_mm: Double
            let totalprecip_in: Double
            let totalsnow_cm: Double
            let avgvis_km: Double
            let avgvis_miles: Double
            let avghumidity: Int
            let daily_will_it_rain: Int
            let daily_chance_of_rain: Int
            let daily_will_it_snow: Int
            let daily_chance_of_snow: Int
            let condition: WeatherCondition
            let uv: Double
        }

        struct Astro: Codable {
            let sunrise: String
            let sunset: String
            let moonrise: String
            let moonset: String
            let moon_phase: String
            let moon_illumination: String

            enum CodingKeys: String, CodingKey {
                case sunrise, sunset, moonrise, moonset, moon_phase, moon_illumination
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                sunrise = try container.decode(String.self, forKey: .sunrise)
                sunset = try container.decode(String.self, forKey: .sunset)
                moonrise = try container.decode(String.self, forKey: .moonrise)
                moonset = try container.decode(String.self, forKey: .moonset)
                moon_phase = try container.decode(String.self, forKey: .moon_phase)

                // Try to decode moon_illumination as a String first, then as a Number if that fails
                if let illuminationString = try? container.decode(
                    String.self, forKey: .moon_illumination)
                {
                    moon_illumination = illuminationString
                } else if let illuminationNumber = try? container.decode(
                    Int.self, forKey: .moon_illumination)
                {
                    moon_illumination = String(illuminationNumber)
                } else if let illuminationDouble = try? container.decode(
                    Double.self, forKey: .moon_illumination)
                {
                    moon_illumination = String(illuminationDouble)
                } else {
                    throw DecodingError.typeMismatch(
                        String.self,
                        DecodingError.Context(
                            codingPath: container.codingPath,
                            debugDescription: "Expected String or Number for moon_illumination"
                        )
                    )
                }
            }
        }

        struct HourlyForecast: Codable, Identifiable {
            var id: UUID { UUID() }  // Computed property to generate a new UUID each time

            let time_epoch: Int
            let time: String
            let temp_c: Double
            let temp_f: Double
            let is_day: Int
            let condition: WeatherCondition
            let wind_mph: Double
            let wind_kph: Double
            let wind_degree: Int
            let wind_dir: String
            let pressure_mb: Double
            let pressure_in: Double
            let precip_mm: Double
            let precip_in: Double
            let snow_cm: Double
            let humidity: Int
            let cloud: Int
            let feelslike_c: Double
            let feelslike_f: Double
            let windchill_c: Double?
            let windchill_f: Double?
            let heatindex_c: Double?
            let heatindex_f: Double?
            let dewpoint_c: Double
            let dewpoint_f: Double
            let will_it_rain: Int
            let chance_of_rain: Int
            let will_it_snow: Int
            let chance_of_snow: Int
            let vis_km: Double
            let vis_miles: Double
            let gust_mph: Double
            let gust_kph: Double
            let uv: Double
        }
    }

    struct Alerts: Codable {
        let alert: [Alert]  // This can be expanded with more details about the alerts if needed
    }

    struct Alert: Codable {
        // Define properties for the alert if there are any in your API response
    }
}

// Updated DayForecast struct for use in SwiftUI views
struct DayForecast: Codable, Identifiable {
    var id: UUID { UUID() }  // Computed property to generate a new UUID each time
    let date: String
    let weatherIcon: String
    let highTemp: Double
    let lowTemp: Double

    enum CodingKeys: String, CodingKey {
        case date
        case weatherIcon = "icon"
        case highTemp = "maxtemp_c"
        case lowTemp = "mintemp_c"
    }

    // Custom initializer for manual decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        weatherIcon = try container.decode(String.self, forKey: .weatherIcon)
        highTemp = try container.decode(Double.self, forKey: .highTemp)
        lowTemp = try container.decode(Double.self, forKey: .lowTemp)
    }

    // Default initializer for manual creation
    init(date: String, weatherIcon: String, highTemp: Double, lowTemp: Double) {
        self.date = date
        self.weatherIcon = weatherIcon
        self.highTemp = highTemp
        self.lowTemp = lowTemp
    }
}

extension DayForecast {
    /// Formats the `date` string to `dd/MM` format.
    func formattedDate(format: String = "dd/MM") -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"  // Input date format from the API
        inputFormatter.locale = Locale(identifier: Locale.current.identifier)

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = format  // Desired output format
        outputFormatter.locale = Locale.current

        if let parsedDate = inputFormatter.date(from: date) {
            return outputFormatter.string(from: parsedDate)
        } else {
            return date  // Return the original date if parsing fails
        }
    }
}
