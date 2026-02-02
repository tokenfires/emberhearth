# Weather Integration Research

**Status:** Complete
**Priority:** Medium
**Last Updated:** February 2, 2026

---

## Overview

Weather information is a common assistant query. Apple provides WeatherKit, a robust API that powers the native Weather app, giving developers access to the same high-quality forecast data.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Current conditions | "What's the weather like?" |
| Forecasts | "Will it rain tomorrow?" |
| Travel planning | Weather at destination cities |
| Activity planning | "Good day for hiking?" |
| Severe weather alerts | Proactive storm warnings |

---

## Technical Approach: WeatherKit

WeatherKit is Apple's official weather API, replacing the discontinued Dark Sky API.

### Platform Requirements

| Platform | Minimum Version |
|----------|-----------------|
| macOS | 13 (Ventura) |
| iOS | 16 |
| watchOS | 9 |
| tvOS | 16 |

### API Limits

| Tier | Monthly Calls | Cost |
|------|---------------|------|
| Included | 500,000 | Free (with Apple Developer membership) |
| Additional | Varies | Subscription in Developer app |

For a personal assistant, 500K calls/month is more than sufficient.

---

## Implementation

### Setup

1. **Apple Developer Account:** Required for WeatherKit access
2. **Xcode Capability:** Add WeatherKit capability to your app
3. **App ID Configuration:** Enable WeatherKit in Apple Developer portal

### Basic Weather Request

```swift
import WeatherKit
import CoreLocation

class WeatherService {
    private let weatherService = WeatherService()

    func getCurrentWeather(for location: CLLocation) async throws -> CurrentWeather {
        let weather = try await weatherService.weather(for: location)
        return weather.currentWeather
    }

    func getDailyForecast(for location: CLLocation, days: Int = 7) async throws -> [DayWeather] {
        let weather = try await weatherService.weather(for: location)
        return Array(weather.dailyForecast.prefix(days))
    }

    func getHourlyForecast(for location: CLLocation, hours: Int = 24) async throws -> [HourWeather] {
        let weather = try await weatherService.weather(for: location)
        return Array(weather.hourlyForecast.prefix(hours))
    }
}
```

### Weather Data Types

```swift
// Current conditions
let current = weather.currentWeather
print("Temperature: \(current.temperature)")
print("Feels like: \(current.apparentTemperature)")
print("Condition: \(current.condition.description)")
print("Humidity: \(current.humidity)")
print("Wind: \(current.wind.speed) from \(current.wind.direction)")
print("UV Index: \(current.uvIndex.value)")

// Daily forecast
for day in weather.dailyForecast {
    print("Date: \(day.date)")
    print("High: \(day.highTemperature)")
    print("Low: \(day.lowTemperature)")
    print("Precipitation chance: \(day.precipitationChance)")
    print("Condition: \(day.condition)")
}

// Minute-by-minute precipitation (next hour)
if let minuteForecast = weather.minuteForecast {
    for minute in minuteForecast {
        print("\(minute.date): \(minute.precipitationIntensity)")
    }
}
```

### Severe Weather Alerts

```swift
func getWeatherAlerts(for location: CLLocation) async throws -> [WeatherAlert] {
    let weather = try await weatherService.weather(
        for: location,
        including: .alerts
    )
    return weather.weatherAlerts ?? []
}

// Process alerts
for alert in alerts {
    print("Summary: \(alert.summary)")
    print("Severity: \(alert.severity)")
    print("Source: \(alert.source)")
    print("Effective: \(alert.effectiveDate)")
    print("Expires: \(alert.expiresDate)")
}
```

### Location from City Name

```swift
import CoreLocation

func geocodeCity(_ cityName: String) async throws -> CLLocation? {
    let geocoder = CLGeocoder()
    let placemarks = try await geocoder.geocodeAddressString(cityName)
    return placemarks.first?.location
}

// Usage
if let location = try await geocodeCity("San Francisco, CA") {
    let weather = try await getCurrentWeather(for: location)
}
```

### WeatherKit REST API (Alternative)

For server-side or cross-platform use:

```
GET https://weatherkit.apple.com/api/v1/weather/{language}/{latitude}/{longitude}
```

Requires JWT authentication with Apple Developer credentials.

---

## Permissions Required

| Permission | Key | Purpose |
|------------|-----|---------|
| Location (optional) | `NSLocationWhenInUseUsageDescription` | Current location weather |

**Note:** Location permission is only needed for "weather here" queries. Named locations don't require permission.

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "What's the weather like?"
**EmberHearth:** "Currently in San Francisco:
- 62°F, Partly Cloudy
- Feels like 60°F
- Humidity: 72%
- Wind: 12 mph from the west

Today's forecast: High 68°F, Low 54°F, 10% chance of rain."

**User:** "Will I need an umbrella tomorrow?"
**EmberHearth:** "Tomorrow's forecast shows a 75% chance of rain in the afternoon. I'd recommend bringing an umbrella. Rain is expected between 2 PM and 8 PM."

**User:** "What's the weather in Tokyo next week?"
**EmberHearth:** "Here's the 7-day forecast for Tokyo:
- Mon: 72°F, Sunny
- Tue: 70°F, Partly Cloudy
- Wed: 68°F, Rain (80%)
- Thu: 65°F, Cloudy
- Fri: 67°F, Sunny
- Sat: 71°F, Sunny
- Sun: 73°F, Partly Cloudy

Pack layers and an umbrella for Wednesday!"

**User:** "Good day for a picnic?"
**EmberHearth:** "Today looks great for a picnic!
- Sunny with a high of 75°F
- Low humidity (45%)
- Light breeze (5 mph)
- No rain expected
- UV Index: Moderate (wear sunscreen)

The best window is between 11 AM and 4 PM."

### Proactive Weather Alerts

```swift
func checkForAlerts(userLocations: [CLLocation]) async {
    for location in userLocations {
        let alerts = try? await getWeatherAlerts(for: location)
        for alert in alerts ?? [] {
            if alert.severity == .severe || alert.severity == .extreme {
                // Notify user via iMessage
                sendWeatherAlert(alert)
            }
        }
    }
}
```

### Integration with Other Features

- **Calendar:** Add weather to event briefings
- **Maps/Travel:** Weather at destination
- **Reminders:** "Remind me to bring umbrella if rain is forecast"

---

## Data Available

| Data Type | Availability |
|-----------|-------------|
| Current conditions | All locations |
| Hourly forecast | 10 days |
| Daily forecast | 10 days |
| Minute-by-minute | Select regions (next hour) |
| Severe alerts | Select regions |
| Historical data | Available with date range |

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| API calls limited | 500K/month free | Cache responses |
| Minute forecast | Not all regions | Fall back to hourly |
| Alerts | Not all regions | Note availability |
| Historical data | Costs additional | Cache needed data |

---

## Caching Strategy

```swift
class WeatherCache {
    private var cache: [String: (weather: Weather, timestamp: Date)] = [:]
    private let maxAge: TimeInterval = 15 * 60  // 15 minutes

    func getCachedWeather(for locationKey: String) -> Weather? {
        guard let cached = cache[locationKey],
              Date().timeIntervalSince(cached.timestamp) < maxAge else {
            return nil
        }
        return cached.weather
    }

    func cacheWeather(_ weather: Weather, for locationKey: String) {
        cache[locationKey] = (weather, Date())
    }
}
```

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Current weather | High | Low |
| Daily forecast | High | Low |
| City lookup | High | Low |
| Hourly forecast | Medium | Low |
| Severe alerts | Medium | Low |
| Activity suggestions | Low | Medium |
| Travel weather | Low | Medium |

---

## Testing Checklist

- [ ] Current weather for user location
- [ ] Current weather for named city
- [ ] 7-day forecast
- [ ] Hourly forecast
- [ ] Handle location permission denied
- [ ] Handle network errors
- [ ] Cache hit/miss scenarios
- [ ] Multiple locations
- [ ] International cities
- [ ] Weather alerts (if available in region)

---

## Resources

- [WeatherKit Documentation](https://developer.apple.com/documentation/weatherkit)
- [WeatherKit REST API](https://developer.apple.com/documentation/weatherkitrestapi)
- [WWDC22: Meet WeatherKit](https://developer.apple.com/videos/play/wwdc2022/10003/)
- [Fetching weather forecasts sample](https://developer.apple.com/documentation/weatherkit/fetching_weather_forecasts_with_weatherkit)

---

## Recommendation

**Feasibility: HIGH**

WeatherKit is a well-designed, official Apple API with generous free tier limits. Benefits:

1. Same data quality as native Weather app
2. Simple Swift API with async/await
3. No external dependencies
4. Privacy-preserving (location not stored)

This is an easy integration that adds immediate user value. Implement as a utility service that other features (Calendar, Maps, daily briefings) can leverage.
