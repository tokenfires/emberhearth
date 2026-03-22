# HomeKit Integration Research

**Status:** Complete
**Priority:** Medium
**Last Updated:** February 2, 2026

---

## Overview

HomeKit enables control of smart home devices. Integration would allow EmberHearth users to control lights, thermostats, locks, and other accessories through conversational iMessage commands.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Device control | "Turn off the living room lights" |
| Scene activation | "Set the house to movie mode" |
| Status queries | "Is the front door locked?" |
| Automation | "Turn on lights when I get home" |
| Climate control | "Set thermostat to 72°" |

---

## Technical Approach: HomeKit Framework

HomeKit is Apple's framework for smart home control, with Matter support for cross-platform compatibility.

### Platform Support

| Platform | Support |
|----------|---------|
| macOS | 10.14+ (Mojave) |
| iOS | 8.0+ |
| watchOS | 2.0+ |
| tvOS | 10.0+ |

### Matter Support

Apple added Matter support in:
- iOS 16.1
- macOS Ventura
- watchOS 9.1
- tvOS 16.1

Matter enables cross-platform compatibility with Amazon, Google, Samsung, and other ecosystems.

### Key Classes

| Class | Purpose |
|-------|---------|
| `HMHomeManager` | Access homes and rooms |
| `HMHome` | A single home |
| `HMRoom` | Room within a home |
| `HMAccessory` | A smart device |
| `HMService` | A capability of a device |
| `HMCharacteristic` | A property (on/off, brightness) |
| `HMActionSet` | A scene |
| `HMTrigger` | Automation trigger |

---

## Implementation

### Setup

```swift
import HomeKit

class HomeKitService: NSObject, HMHomeManagerDelegate {
    private var homeManager: HMHomeManager!
    private var primaryHome: HMHome?

    override init() {
        super.init()
        homeManager = HMHomeManager()
        homeManager.delegate = self
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        primaryHome = manager.primaryHome
    }
}
```

### Querying Devices

```swift
func getAllAccessories() -> [HMAccessory] {
    return primaryHome?.accessories ?? []
}

func getAccessoriesInRoom(named roomName: String) -> [HMAccessory] {
    guard let room = primaryHome?.rooms.first(where: { $0.name.lowercased() == roomName.lowercased() }) else {
        return []
    }
    return room.accessories
}

func findAccessory(named name: String) -> HMAccessory? {
    return primaryHome?.accessories.first { accessory in
        accessory.name.lowercased().contains(name.lowercased())
    }
}
```

### Controlling Devices

```swift
func setLightState(accessoryName: String, on: Bool) async throws {
    guard let accessory = findAccessory(named: accessoryName) else {
        throw HomeKitError.accessoryNotFound
    }

    // Find the lightbulb service
    guard let lightService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }) else {
        throw HomeKitError.serviceNotFound
    }

    // Find the power characteristic
    guard let powerCharacteristic = lightService.characteristics.first(where: {
        $0.characteristicType == HMCharacteristicTypePowerState
    }) else {
        throw HomeKitError.characteristicNotFound
    }

    try await powerCharacteristic.writeValue(on)
}

func setLightBrightness(accessoryName: String, brightness: Int) async throws {
    guard let accessory = findAccessory(named: accessoryName) else {
        throw HomeKitError.accessoryNotFound
    }

    guard let lightService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }) else {
        throw HomeKitError.serviceNotFound
    }

    guard let brightnessCharacteristic = lightService.characteristics.first(where: {
        $0.characteristicType == HMCharacteristicTypeBrightness
    }) else {
        throw HomeKitError.characteristicNotFound
    }

    // Brightness is 0-100
    let clampedBrightness = max(0, min(100, brightness))
    try await brightnessCharacteristic.writeValue(clampedBrightness)
}

func setThermostat(temperature: Double) async throws {
    guard let thermostat = primaryHome?.accessories.first(where: { accessory in
        accessory.services.contains { $0.serviceType == HMServiceTypeThermostat }
    }) else {
        throw HomeKitError.accessoryNotFound
    }

    guard let thermostatService = thermostat.services.first(where: {
        $0.serviceType == HMServiceTypeThermostat
    }) else {
        throw HomeKitError.serviceNotFound
    }

    // Target temperature characteristic
    guard let tempCharacteristic = thermostatService.characteristics.first(where: {
        $0.characteristicType == HMCharacteristicTypeTargetTemperature
    }) else {
        throw HomeKitError.characteristicNotFound
    }

    try await tempCharacteristic.writeValue(temperature)
}
```

### Reading Device Status

```swift
func getLightStatus(accessoryName: String) async throws -> (isOn: Bool, brightness: Int?) {
    guard let accessory = findAccessory(named: accessoryName) else {
        throw HomeKitError.accessoryNotFound
    }

    guard let lightService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }) else {
        throw HomeKitError.serviceNotFound
    }

    var isOn = false
    var brightness: Int?

    for characteristic in lightService.characteristics {
        try await characteristic.readValue()

        if characteristic.characteristicType == HMCharacteristicTypePowerState {
            isOn = characteristic.value as? Bool ?? false
        }
        if characteristic.characteristicType == HMCharacteristicTypeBrightness {
            brightness = characteristic.value as? Int
        }
    }

    return (isOn, brightness)
}

func isDoorLocked(accessoryName: String) async throws -> Bool {
    guard let accessory = findAccessory(named: accessoryName) else {
        throw HomeKitError.accessoryNotFound
    }

    guard let lockService = accessory.services.first(where: {
        $0.serviceType == HMServiceTypeLockMechanism
    }) else {
        throw HomeKitError.serviceNotFound
    }

    guard let lockState = lockService.characteristics.first(where: {
        $0.characteristicType == HMCharacteristicTypeCurrentLockMechanismState
    }) else {
        throw HomeKitError.characteristicNotFound
    }

    try await lockState.readValue()

    // 1 = secured/locked, 0 = unsecured/unlocked
    return (lockState.value as? Int) == 1
}
```

### Executing Scenes

```swift
func getScenes() -> [HMActionSet] {
    return primaryHome?.actionSets ?? []
}

func executeScene(named sceneName: String) async throws {
    guard let scene = primaryHome?.actionSets.first(where: {
        $0.name.lowercased() == sceneName.lowercased()
    }) else {
        throw HomeKitError.sceneNotFound
    }

    try await primaryHome?.executeActionSet(scene)
}
```

---

## Permissions Required

| Permission | Purpose |
|------------|---------|
| HomeKit Capability | Access Home data |

**Entitlements:**
```xml
<key>com.apple.developer.homekit</key>
<true/>
```

**Info.plist:**
```xml
<key>NSHomeKitUsageDescription</key>
<string>EmberHearth needs HomeKit access to control your smart home devices.</string>
```

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "Turn off all the lights"
**EmberHearth:** "Turning off all lights in your home...
- Living Room Light: Off
- Bedroom Light: Off
- Kitchen Light: Off
- Porch Light: Off

All 4 lights are now off."

**User:** "Is the front door locked?"
**EmberHearth:** "The front door is currently **locked**."

**User:** "Set the thermostat to 72 degrees"
**EmberHearth:** "Setting thermostat to 72°F. Current temperature is 68°F—it should reach 72°F in about 20 minutes."

**User:** "Turn on movie mode"
**EmberHearth:** "Activating 'Movie Mode' scene:
- Living room lights dimmed to 20%
- TV backlight on
- Blinds closed

Enjoy your movie!"

**User:** "What's the status of my home?"
**EmberHearth:** "Here's your home status:

**Lights:**
- Living Room: On (75%)
- Bedroom: Off
- Kitchen: On (100%)

**Climate:**
- Thermostat: 70°F (target: 72°F)
- Humidity: 45%

**Security:**
- Front Door: Locked
- Garage: Closed
- Motion Sensor: No activity"

### Safety Confirmations

For security-sensitive operations, require confirmation:

```
User: "Unlock the front door"
EmberHearth: "Are you sure you want to unlock the front door? Reply 'yes' to confirm."
User: "Yes"
EmberHearth: "Front door unlocked."
```

### Room-Based Commands

```swift
func parseRoomCommand(_ command: String) -> (room: String?, action: String)? {
    // "Turn off the living room lights"
    // "Dim the bedroom to 50%"
    // Pattern matching to extract room and action
}
```

---

## Device Categories

| Category | Service Type | Common Actions |
|----------|-------------|----------------|
| Lights | `HMServiceTypeLightbulb` | On/off, brightness, color |
| Thermostats | `HMServiceTypeThermostat` | Temperature, mode |
| Locks | `HMServiceTypeLockMechanism` | Lock/unlock |
| Garage Doors | `HMServiceTypeGarageDoorOpener` | Open/close |
| Blinds/Shades | `HMServiceTypeWindowCovering` | Open/close, position |
| Fans | `HMServiceTypeFan` | On/off, speed |
| Switches | `HMServiceTypeSwitch` | On/off |
| Sensors | Various | Read-only status |
| Cameras | `HMServiceTypeCameraStreamManagement` | View stream |

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Hub required | Need Apple TV/HomePod | Document requirement |
| Remote access | Requires hub | Local-only fallback |
| Camera streams | Complex to handle | Link to Home app |
| Automations | Can't create via API | Guide user to Home app |
| Device setup | Can't add devices | Use Home app |

---

## Security Considerations

1. **Lock Operations:** Always require confirmation before unlocking
2. **Garage Doors:** Confirm before opening
3. **Audit Log:** Log all security-related actions
4. **Away Mode:** Be careful about revealing home status

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| List devices/rooms | High | Low |
| Control lights | High | Medium |
| Execute scenes | High | Low |
| Read sensor status | Medium | Low |
| Thermostat control | Medium | Medium |
| Lock control | Medium | Medium (security) |
| Garage door | Low | Medium (security) |

---

## Testing Checklist

- [ ] List all homes
- [ ] List rooms in home
- [ ] List accessories
- [ ] Turn light on/off
- [ ] Set brightness
- [ ] Read light status
- [ ] Execute scene
- [ ] Read thermostat
- [ ] Set thermostat
- [ ] Check lock status
- [ ] Lock/unlock with confirmation

---

## Resources

- [HomeKit Documentation](https://developer.apple.com/documentation/homekit)
- [Developing for the Home](https://developer.apple.com/apple-home/)
- [HMCatalog Sample Code](https://developer.apple.com/documentation/homekit/configuring-a-home-automation-device)
- [Matter Overview](https://developer.apple.com/apple-home/matter/)

---

## Recommendation

**Feasibility: HIGH**

HomeKit has a comprehensive, well-documented API. Benefits:

1. Official Apple framework
2. Works with thousands of devices
3. Matter support for future-proofing
4. Scenes simplify complex operations

**Target User Segment:** Users with smart home setups who want conversational control without opening apps or using voice assistants.

**Implementation Strategy:**
1. Phase 1: Read-only status queries + light control
2. Phase 2: Scenes + thermostat
3. Phase 3: Security devices with confirmation flow
