# FITMaps System Flow Analysis

## System Architecture Overview

The FITMaps application is a Flutter-based navigation system for the FIT faculty building. Here's the complete system flow:

```mermaid
graph TB
    %% Data Sources (Already Extracted)
    JSON[maps_data.json<br/>27,018 lines of room data<br/>Already extracted and ready]
    
    %% Flutter App Structure
    JSON --> FLUTTER[Flutter App<br/>FITMaps]
    
    %% App Initialization
    FLUTTER --> SPLASH[SplashScreen<br/>3-second loading]
    SPLASH --> HOME[HomeScreen<br/>Main Map Interface]
    
    %% Data Loading Process
    HOME --> LOAD[_loadRoomData<br/>Load JSON from assets]
    LOAD --> PARSE[Parse JSON<br/>Extract room data]
    PARSE --> STORE[Store in _allRoomsData<br/>All floors data]
    STORE --> FILTER[_loadCurrentFloorData<br/>Filter by selected floor]
    
    %% UI Components
    FILTER --> MAP[Interactive Map<br/>CustomPainter + InteractiveViewer]
    FILTER --> SEARCH[Search Interface<br/>Autocomplete + Suggestions]
    FILTER --> FLOOR[Floor Selector<br/>Dropdown navigation]
    
    %% Search Functionality
    SEARCH --> SEARCH_LOGIC[_performSearch<br/>Search across all floors]
    SEARCH_LOGIC --> MATCH{Match Found?}
    MATCH -->|Yes| HIGHLIGHT[Highlight Rooms<br/>Pulse Animation]
    MATCH -->|No| CLEAR[Clear Highlights]
    HIGHLIGHT --> ZOOM[_zoomToRooms<br/>Auto-zoom to results]
    
    %% Room Interaction
    MAP --> TAP[Map Tap Detection<br/>_handleMapTap]
    TAP --> MARKER{Marker Clicked?}
    MARKER -->|Yes| DRAWER[Room Details Drawer<br/>_buildRoomDetailsDrawer]
    MARKER -->|No| CONTINUE[Continue Interaction]
    
    %% Room Details
    DRAWER --> DETAILS[Room Information<br/>ID, Title, Floor, Accessibility]
    DRAWER --> PHOTOS[Room Photos<br/>Load from FIT website]
    DRAWER --> ACTIONS[Action Buttons<br/>Share, Navigate]
    
    %% Navigation
    HOME --> PROFILE[ProfileScreen<br/>User settings]
    HOME --> MENU[Bottom Menu<br/>About, Help, Logout]
    
    %% Data Structure Details
    subgraph "JSON Data Structure"
        ROOM_STRUCT[Room Object:<br/>- id: Room identifier<br/>- title: Room name<br/>- onclick: FIT website URL<br/>- floor_no: Floor number<br/>- room_tag: Accessibility info<br/>- coords: Polygon coordinates]
    end
    
    %% Map Rendering Process
    subgraph "Map Rendering"
        PAINTER[BuildingMapPainter<br/>CustomPainter]
        PAINTER --> ROOM_COLOR[Room Color Logic<br/>Based on room type]
        PAINTER --> ROOM_LABEL[Room Labels<br/>Adaptive font sizing]
        PAINTER --> MARKERS[Google-style Markers<br/>For highlighted rooms]
    end
    
    %% Search Suggestions
    subgraph "Search Suggestions"
        SUGGEST[_updateSuggestions<br/>Real-time suggestions]
        SUGGEST --> FILTER_SUGGEST[Filter by query<br/>Limit to 10 results]
        FILTER_SUGGEST --> DISPLAY[Display Suggestions<br/>Room ID + Title + Floor]
    end
    
    %% Floor Management
    subgraph "Floor Management"
        FLOOR_SELECT[Floor Selection<br/>-2nd to 3rd Floor]
        FLOOR_SELECT --> SWITCH[_switchToFloor<br/>Change active floor]
        SWITCH --> RELOAD[_loadCurrentFloorData<br/>Reload floor data]
        RELOAD --> BOUNDS[Calculate Map Bounds<br/>Min/Max X/Y coordinates]
    end
    
    %% Styling
    classDef dataSource fill:#e1f5fe
    classDef flutter fill:#f3e5f5
    classDef process fill:#e8f5e8
    classDef ui fill:#fff3e0
    classDef search fill:#fce4ec
    
    class HTML,EXTRACT,JSON dataSource
    class FLUTTER,SPLASH,HOME flutter
    class LOAD,PARSE,STORE,FILTER process
    class MAP,SEARCH,FLOOR,DRAWER ui
    class SEARCH_LOGIC,SUGGEST,HIGHLIGHT search
```

## Key System Components

### 1. Data Pipeline
- **Source**: Pre-extracted JSON data (`maps_data.json`) in `parsed_data` folder
- **Content**: Structured JSON with 27,018 lines of room information
- **Format**: Each room contains ID, title, coordinates, floor number, and accessibility info
- **Ready-to-use**: No processing needed - directly loaded by Flutter app

### 2. Flutter App Architecture
- **Main App**: MaterialApp with custom theme
- **Splash Screen**: 3-second loading with FIT logo
- **Home Screen**: Primary interface with interactive map
- **Profile Screen**: User settings and navigation

### 3. Map Implementation
- **Custom Painter**: `BuildingMapPainter` renders rooms as polygons
- **Interactive Viewer**: Zoom, pan, and tap interactions
- **Room Colors**: Dynamic coloring based on room type (office, lab, staircase, etc.)
- **Adaptive Labels**: Font size adjusts based on room area and zoom level

### 4. Search System
- **Real-time Search**: Searches across all floors simultaneously
- **Autocomplete**: Shows up to 10 suggestions as user types
- **Smart Navigation**: Automatically switches floors if room found elsewhere
- **Visual Feedback**: Highlights matching rooms with pulse animation

### 5. Room Interaction
- **Tap Detection**: Calculates distance to room markers for click detection
- **Details Drawer**: Slides up from bottom with room information
- **Photo Loading**: Attempts to load photos from FIT website
- **Action Buttons**: Share functionality and external links

### 6. Floor Management
- **Multi-floor Support**: -2nd to 3rd floor navigation
- **Dynamic Loading**: Loads only current floor data for performance
- **Bound Calculation**: Automatically calculates map bounds for each floor
- **Smooth Transitions**: Animated floor switching

## Data Flow Summary

1. **Initialization**: App loads pre-extracted JSON data from `data/parsed_data/maps_data.json` into memory
2. **Floor Selection**: User selects floor, app filters and loads floor-specific data from the loaded JSON
3. **Map Rendering**: Custom painter draws rooms with appropriate colors and labels using coordinate data
4. **Search Interaction**: User types query, system searches all floors and highlights matches
5. **Room Selection**: User taps room marker, drawer opens with detailed information
6. **Navigation**: User can switch floors, search again, or access profile

The system efficiently handles large datasets (27K+ rooms) using pre-processed JSON data while providing smooth, interactive navigation with real-time search capabilities.
