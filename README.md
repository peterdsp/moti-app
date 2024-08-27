# Moti

**Moti** is a macOS menu bar application designed with SwiftUI, leveraging WeatherApi to provide real-time weather updates. This lightweight and user-friendly app displays the current temperature and weather conditions directly in your menu bar, with an intuitive icon for quick reference. When clicked, it opens a detailed 5-day weather forecast.

## Features

- **Real-Time Weather Updates**: Displays the current temperature and weather conditions directly in the menu bar.
- **5-Day Weather Forecast**: View detailed weather predictions for the next 5 days, including high and low temperatures.
- **Weather Icons**: The menu bar icon changes based on the current weather (e.g., sun, cloud, rain, snow).
- **Customizable Location**: Automatically fetches weather based on your current location, or set a custom location.
- **Lightweight and Efficient**: Runs seamlessly in the background without interrupting your workflow.

## Screenshots

| Menu Bar Icon with Current Weather | Search Location |
|-----------------------------------|-----------------|
| <img src="https://github.com/user-attachments/assets/be44f179-4bfd-4c35-84ee-11cc7b03cc60" width="100%" alt="Menu Bar Icon with Current Weather"> | <img src="https://github.com/user-attachments/assets/d4386844-d221-4745-8654-3950f485244d" width="100%" alt="Search Location"> |

| Location Suggestions | Context Menu |
|----------------------|--------------|
| <img src="https://github.com/user-attachments/assets/d65e5c4d-fc79-48bb-821f-ccb747c60c6a" width="100%" alt="Location Suggestions"> | <img src="https://github.com/user-attachments/assets/7c62fe5f-b088-4348-b902-e09f181e01b4" width="100%" alt="Context Menu"> |

## Installation

### Prerequisites

- macOS 13 or later
- Xcode 14 or later

### Clone the Repository

```bash
git clone https://github.com/peterdsp/moti-app.git
cd moti-app
```

### Configure the Project

1. Open `Moti.xcodeproj` in Xcode.
2. Replace placeholders in the code with your WeatherApi API, go to WeatherManager.swift-> private let apiKey = **HERE PUT YOUR API KEY**.
3. Set the `Signing & Capabilities` to your developer account.

### Run the App from GitHub

1. Build and run the project in Xcode.
2. Enable Location Services for the app. This allows the app to fetch weather data based on your current location.
3. The app will appear in the menu bar with the current weather conditions. 

### Run the App from Gumroad

1. Download the app from Gumroad.
2. Move the app to your Applications folder.
3. Open the app. It will appear in the menu bar.
4. Enable Location Services for the app. This allows the app to fetch weather data based on your current location.
5. Close the app and reopen it to ensure that all settings are applied.
6. Optionally, you can add the app to your Login Items so that it starts automatically when you log in to your Mac.

## Usage

- **Menu Bar Icon**: Click the temperature or weather icon in the menu bar to view the 5-day weather forecast.
- **Refresh**: Right-click on the menu bar icon and select “Refresh” to manually update the weather information immediately.
- **About**: Right-click on the menu bar icon to view information about the app.

## Contributing

Contributions are welcome! Please fork this repository, create a new branch, and submit a pull request with your changes.

### Steps to Contribute

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeature`).
3. Push to the branch (`git push origin feature/YourFeature`).
4. Open a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- Inspired by the need for a clean, efficient way to check the weather without opening a full app.
- Thanks to Apple's WeatherKit for providing robust weather data.
