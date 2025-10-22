# FITMaps

A Flutter navigation app for the FIT Faculty to help navigate through different floors and find locations.

## Features

- Interactive floor maps with zoom and pan
- Location search functionality
- Multi-floor support (Ground to Fourth Floor)
- User authentication
- Default map display on Ground Floor

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- Git

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd FITmaps
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify Flutter setup**
   ```bash
   flutter doctor
   ```

## How to Run

### Web Browser
```bash
flutter run -d chrome
```

### Windows Desktop
```bash
flutter create --platforms=windows .
flutter run -d windows
```

### Mobile Device
```bash
flutter devices
flutter run -d <device_id>
```

## App Structure

```
lib/
├── main.dart                 # App entry point
├── config/
│   └── theme.dart           # App theme configuration
└── screens/
    ├── splash_screen.dart   # Loading screen
    ├── login_screen.dart    # Authentication
    ├── home_screen.dart     # Main navigation interface
    └── profile_screen.dart  # User profile management

assets/
├── images/
│   └── logo.png            # App logo
└── floors/
    ├── 1stfloor.svg        # Ground Floor
    ├── 2ndfloor.svg        # First Floor
    ├── 3rdfloor.svg        # Second Floor
    ├── 4thfloor.svg        # Third Floor
    ├── -1stfloor.svg       # Basement Level -1
    └── -2stfloor.svg       # Basement Level -2
```

## Usage

1. Launch the app - splash screen appears
2. Login with credentials (simulated)
3. Ground Floor map loads by default
4. Search for locations and select floors
5. Use pinch to zoom, drag to pan on maps

## Map Controls

- Zoom: Pinch gesture or mouse wheel (0.5x to 4.0x)
- Pan: Drag to move around
- Close: Tap X button to hide map

## Troubleshooting

No devices found:
```bash
flutter devices
flutter run -d chrome
```

Platform not supported:
```bash
flutter create --platforms=windows,web .
```

Dependencies issues:
```bash
flutter clean && flutter pub get
```