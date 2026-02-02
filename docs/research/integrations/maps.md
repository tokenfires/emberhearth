# Maps Integration Research

**Status:** Complete
**Priority:** Medium
**Last Updated:** February 2, 2026

---

## Overview

MapKit provides directions, location search, and place information. Integration enables EmberHearth to help with navigation, travel planning, and location-based queries.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Directions | "How do I get to the airport?" |
| Place search | "Find coffee shops nearby" |
| Travel time | "How long to drive to work?" |
| Itinerary planning | Build multi-stop routes |
| Points of interest | Discover places along routes |

---

## Technical Approach: MapKit

MapKit is Apple's mapping framework with comprehensive APIs for search, directions, and place information.

### Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| macOS | 10.9+ | Full support |
| iOS | 3.0+ | Full support |
| watchOS | 9.0+ | Directions API new in watchOS 9 |

### Key Classes

| Class | Purpose |
|-------|---------|
| `MKLocalSearch` | Search for places |
| `MKDirections` | Calculate routes |
| `MKMapItem` | Represents a place |
| `MKPlacemark` | Address information |
| `MKRoute` | A single route with steps |

---

## Implementation

### Place Search

```swift
import MapKit

class MapsService {

    func searchPlaces(query: String, near location: CLLocation? = nil) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        if let location = location {
            // Search within 10km radius
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
    }

    func searchNearby(category: MKPointOfInterestCategory, near location: CLLocation) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
    }
}
```

### Getting Directions

```swift
func getDirections(
    from source: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D,
    transportType: MKDirectionsTransportType = .automobile
) async throws -> MKDirections.Response {

    let sourcePlacemark = MKPlacemark(coordinate: source)
    let destPlacemark = MKPlacemark(coordinate: destination)

    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: sourcePlacemark)
    request.destination = MKMapItem(placemark: destPlacemark)
    request.transportType = transportType
    request.requestsAlternateRoutes = true

    let directions = MKDirections(request: request)
    return try await directions.calculate()
}

func getDirectionsFromAddress(
    from sourceAddress: String,
    to destAddress: String,
    transportType: MKDirectionsTransportType = .automobile
) async throws -> MKDirections.Response {

    // Geocode addresses
    let geocoder = CLGeocoder()

    async let sourcePlacemarks = geocoder.geocodeAddressString(sourceAddress)
    async let destPlacemarks = geocoder.geocodeAddressString(destAddress)

    guard let sourceLocation = try await sourcePlacemarks.first?.location,
          let destLocation = try await destPlacemarks.first?.location else {
        throw MapsError.geocodingFailed
    }

    return try await getDirections(
        from: sourceLocation.coordinate,
        to: destLocation.coordinate,
        transportType: transportType
    )
}
```

### Travel Time Estimation

```swift
func getETA(
    from source: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D,
    transportType: MKDirectionsTransportType = .automobile
) async throws -> TimeInterval {

    let sourcePlacemark = MKPlacemark(coordinate: source)
    let destPlacemark = MKPlacemark(coordinate: destination)

    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: sourcePlacemark)
    request.destination = MKMapItem(placemark: destPlacemark)
    request.transportType = transportType

    let directions = MKDirections(request: request)
    let eta = try await directions.calculateETA()

    return eta.expectedTravelTime
}

func formatTravelTime(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60

    if hours > 0 {
        return "\(hours) hr \(minutes) min"
    } else {
        return "\(minutes) min"
    }
}
```

### Route Steps (Turn-by-Turn)

```swift
func getRouteSteps(response: MKDirections.Response) -> [String] {
    guard let route = response.routes.first else { return [] }

    return route.steps.compactMap { step in
        guard !step.instructions.isEmpty else { return nil }
        let distance = formatDistance(step.distance)
        return "\(step.instructions) (\(distance))"
    }
}

func formatDistance(_ meters: CLLocationDistance) -> String {
    let miles = meters / 1609.34
    if miles < 0.1 {
        let feet = meters * 3.28084
        return "\(Int(feet)) ft"
    } else {
        return String(format: "%.1f mi", miles)
    }
}
```

### WWDC25 Updates: Cycling Directions

```swift
// New in macOS 26 / iOS 26
func getCyclingDirections(
    from source: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D
) async throws -> MKDirections.Response {

    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    request.transportType = .cycling  // New transport type

    let directions = MKDirections(request: request)
    return try await directions.calculate()
}
```

---

## Server-Side API

Apple Maps Server API provides REST endpoints for server-side operations:

```
# Geocoding
GET https://maps-api.apple.com/v1/geocode

# Directions
GET https://maps-api.apple.com/v1/directions

# Search
GET https://maps-api.apple.com/v1/search
```

Requires JWT authentication with Apple Developer credentials.

---

## Permissions Required

| Permission | Key | Purpose |
|------------|-----|---------|
| Location (optional) | `NSLocationWhenInUseUsageDescription` | Current location |

**Note:** Location is only needed for "near me" queries. Named addresses don't require permission.

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "How do I get to SFO airport?"
**EmberHearth:** "From your current location to San Francisco International Airport:

**By car:** 25 min (18 miles) via US-101 S
**By transit:** 45 min via BART

Would you like turn-by-turn directions?"

**User:** "Find coffee shops near me"
**EmberHearth:** "Here are 5 coffee shops nearby:
1. **Blue Bottle Coffee** - 0.3 mi - Open until 6 PM
2. **Starbucks** - 0.4 mi - Open 24 hours
3. **Philz Coffee** - 0.5 mi - Open until 7 PM
4. **Peet's Coffee** - 0.6 mi - Open until 8 PM
5. **Local Brew** - 0.8 mi - Open until 5 PM

Want directions to any of these?"

**User:** "Plan a road trip from LA to San Francisco with stops for food"
**EmberHearth:** "Here's a suggested itinerary:

**Los Angeles → San Francisco** (380 miles, ~6 hours driving)

Suggested stops:
1. **Santa Barbara** (1.5 hr) - In-N-Out Burger, beach break
2. **San Luis Obispo** (3 hr) - Firestone Grill, stretch legs
3. **Gilroy** (5 hr) - Garlic Farm, last stop

Total trip: ~7.5 hours with stops

Want me to add these to your calendar?"

### Integration with Calendar

```swift
// When user asks about commute time for a meeting
func getCommuteInfo(for event: EKEvent) async -> String? {
    guard let location = event.location else { return nil }

    let geocoder = CLGeocoder()
    guard let destPlacemarks = try? await geocoder.geocodeAddressString(location),
          let destination = destPlacemarks.first?.location else {
        return nil
    }

    // Get user's home/current location
    let source = getCurrentLocation()

    let eta = try? await getETA(
        from: source.coordinate,
        to: destination.coordinate
    )

    if let travelTime = eta {
        let departureTime = event.startDate.addingTimeInterval(-travelTime - 600) // 10 min buffer
        return "Leave by \(formatTime(departureTime)) to arrive on time"
    }

    return nil
}
```

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| No real-time traffic on macOS | ETA may be off | Note estimate nature |
| Transit limited regions | Not all cities | Fall back to driving |
| API rate limits | Heavy use throttled | Cache common routes |
| Cycling directions | New, limited regions | Fall back to walking |

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Place search | High | Low |
| Driving directions | High | Low |
| Travel time estimate | High | Low |
| Address geocoding | High | Low |
| Nearby POI search | Medium | Low |
| Multi-stop routes | Low | Medium |
| Transit directions | Low | Low |

---

## Testing Checklist

- [ ] Search for named place
- [ ] Search near current location
- [ ] Get driving directions
- [ ] Get walking directions
- [ ] Get transit directions
- [ ] Calculate ETA
- [ ] Geocode address
- [ ] Handle invalid addresses
- [ ] Handle no results
- [ ] Multiple route alternatives

---

## Resources

- [MapKit Documentation](https://developer.apple.com/documentation/mapkit)
- [MKDirections Documentation](https://developer.apple.com/documentation/mapkit/mkdirections)
- [WWDC25: Go further with MapKit](https://developer.apple.com/videos/play/wwdc2025/204/)
- [Apple Maps Server API](https://developer.apple.com/documentation/applemapsserverapi)

---

## Recommendation

**Feasibility: HIGH**

MapKit is a mature, well-documented API. Benefits:

1. Same data as Apple Maps
2. No additional API costs
3. Privacy-preserving
4. Cross-platform

Great utility feature that integrates naturally with Calendar (commute times) and Weather (trip planning).
