# Tempethéra

**Tempethéra** is a macOS menu bar application designed with SwiftUI, leveraging Apple's WeatherKit API to provide real-time weather updates. This lightweight and user-friendly app displays the current temperature and weather conditions directly in your menu bar, with an intuitive icon for quick reference. When clicked, it opens a detailed 5-day weather forecast.

## Features

- **Real-Time Weather Updates**: Displays the current temperature and weather conditions directly in the menu bar.
- **5-Day Weather Forecast**: View detailed weather predictions for the next 5 days, including high and low temperatures.
- **Weather Icons**: The menu bar icon changes based on the current weather (e.g., sun, cloud, rain, snow).
- **Customizable Location**: Automatically fetches weather based on your current location, or set a custom location.
- **User Preferences**: Access preferences for setting refresh intervals, units of measurement, and more.
- **Lightweight and Efficient**: Runs seamlessly in the background without interrupting your workflow.

## Screenshots

*(Include screenshots of the app running in the menu bar and the detailed weather forecast view.)*

## Installation

### Prerequisites

- macOS 13 or later
- Xcode 14 or later
- An Apple Developer account with WeatherKit enabled

### Clone the Repository

```bash
git clone https://github.com/peterdsp/Tempethera-App.git
cd Tempethera-App
```

### Configure the Project

1. Open `Tempethera.xcodeproj` in Xcode.
2. Ensure the WeatherKit capability is enabled for your target.
3. Replace placeholders in the code with your WeatherKit API credentials if necessary.
4. Set the `Signing & Capabilities` to your developer account.

### Run the App

1. Build and run the project in Xcode.
2. The app will appear in the menu bar with the current weather conditions.

## Usage

- **Menu Bar Icon**: Click the temperature or weather icon in the menu bar to view the 5-day weather forecast.
- **Preferences**: Right-click on the menu bar icon to access the preferences, where you can adjust settings like location, units, and refresh intervals.
- **About**: Right-click on the menu bar icon to view information about the app.

## Contributing

Contributions are welcome! Please fork this repository, create a new branch, and submit a pull request with your changes.

### Steps to Contribute

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeature`).
3. Make your changes and commit them (`git commit -m 'Add some feature'`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Open a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- Inspired by the need for a clean, efficient way to check the weather without opening a full app.
- Thanks to Apple's WeatherKit for providing robust weather data.