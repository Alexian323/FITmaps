# Navigation and Path Drawing Testing Guide

## Overview
This guide explains how to test the navigation and path drawing functionality in FITmaps. The app is configured to use **A101** as the default current location (user's position) for testing purposes.

## Features Implemented

### 1. Current Location (A101)
- **A101** is automatically set as the current location when the app loads
- Current location is displayed with a **green pin marker** on the map
- Current location is always visible on its floor
- When viewing A101's room details, shows "You are here" indicator

### 2. Navigation Paths
- Draw navigation paths from current location (A101) to any destination room
- Paths are displayed as **blue lines with direction arrows**
- Paths automatically switch floors if destination is on a different floor
- Paths zoom to show both start and end points

### 3. Room Drawer Actions
- **"Navigate To This Room"** button appears for any room that's not the current location
- **"Clear Navigation"** button appears when a navigation path is active
- **"You are here"** indicator shows when viewing current location room details

## How to Test

### Test 1: View Current Location (A101)
1. **Launch the app**
   - A101 should be automatically set as current location
   - App should switch to A101's floor automatically
   - Green pin should appear on A101

2. **Search for A101**
   - Use search bar to find "A101"
   - A101 should be highlighted with green pin
   - Click on A101 to open room drawer
   - Should see "You are here" indicator

### Test 2: Navigate to Another Room (Same Floor)
1. **Search for a room on the same floor as A101**
   - Example: Search for "A102" or any room on A101's floor
   - Click on the room to open room drawer

2. **Create navigation path**
   - Click **"Navigate To This Room"** button
   - Blue path with arrows should appear from A101 to destination
   - Map should zoom to show both rooms and path

3. **Clear navigation**
   - Click **"Clear Navigation"** button
   - Path should disappear

### Test 3: Navigate to Room on Different Floor
1. **Search for a room on a different floor**
   - Example: Search for "D006" (usually on floor -2)
   - Click on the room to open room drawer

2. **Create navigation path**
   - Click **"Navigate To This Room"** button
   - App should switch to destination floor
   - Blue path with arrows should appear from A101 to destination
   - Map should zoom to show both rooms and path

### Test 4: Multiple Navigation Tests
1. **Test with different room types**
   - Navigate to offices, labs, lecture rooms, etc.
   - Each should create a valid path

2. **Test path clearing**
   - Create navigation path
   - Close room drawer
   - Open another room drawer
   - Click "Clear Navigation" to remove path

## Visual Indicators

### Current Location Marker
- **Color**: Green pin
- **Shape**: Google Maps style pin
- **Behavior**: Always visible, pulses with animation
- **Location**: Center of room A101

### Navigation Path
- **Color**: Blue
- **Width**: 6 pixels (scales with zoom)
- **Style**: Solid line
- **Arrows**: Direction arrows along path
- **Visibility**: Above rooms, below markers

### Destination Room Marker
- **Color**: Red pin (standard highlighted marker)
- **Shape**: Google Maps style pin
- **Behavior**: Pulses with animation

## Code Locations

### Current Location Setup
- **File**: `lib/screens/home_screen.dart`
- **Method**: `_setCurrentLocation()` (line ~357)
- **Initialization**: Called in `_loadRoomData()` after rooms are loaded

### Navigation Methods
- **File**: `lib/screens/home_screen.dart`
- **Method**: `_navigateToRoom()` (line ~376)
- **Method**: `setNavigationPath()` (line ~303)
- **Method**: `_clearNavigation()` (line ~410)

### Path Drawing
- **File**: `lib/screens/home_screen.dart`
- **Class**: `BuildingMapPainter`
- **Method**: `_drawPath()` (line ~2522)
- **Method**: `_drawPathArrows()` (line ~2627)

### UI Buttons
- **File**: `lib/screens/home_screen.dart`
- **Method**: `_buildActionButtonsSection()` (line ~1842)
- Shows "Navigate To This Room" and "Clear Navigation" buttons

## Changing Current Location

To change the current location from A101 to another room:

1. **Temporary change** (for testing):
   ```dart
   // In _loadRoomData() method, change:
   _setCurrentLocation('A101');
   // To:
   _setCurrentLocation('D006'); // or any other room ID
   ```

2. **Programmatic change**:
   ```dart
   // Call _setCurrentLocation() with any room ID
   _setCurrentLocation('B205');
   ```

3. **Future GPS integration**:
   - Replace `_setCurrentLocation('A101')` with GPS-based location
   - Convert GPS coordinates to room location
   - Update `_currentLocationRoom` based on GPS position

## Troubleshooting

### Issue: A101 not showing as current location
- **Check**: Verify A101 exists in `maps_data_merged.json`
- **Solution**: Check console logs for "Current location set to: A101"
- **Fix**: Ensure A101 room data is loaded correctly

### Issue: Navigation path not appearing
- **Check**: Verify both rooms exist and have valid coordinates
- **Solution**: Check console logs for navigation path creation
- **Fix**: Ensure `setNavigationPath()` is called correctly

### Issue: Path appears on wrong floor
- **Check**: Verify floor switching logic
- **Solution**: Check `_switchToFloor()` method
- **Fix**: Ensure floor switch completes before drawing path

### Issue: Current location not visible
- **Check**: Verify current location is on current floor
- **Solution**: Check `_loadCurrentFloorData()` method
- **Fix**: Ensure current location is added to highlighted rooms

## Next Steps

1. **GPS Integration**: Replace A101 with real GPS-based location
2. **Path Routing**: Implement A* or Dijkstra's algorithm for optimal paths
3. **Multi-floor Navigation**: Add elevator/staircase waypoints for cross-floor paths
4. **Path Animation**: Animate path drawing for better UX
5. **Turn-by-turn Directions**: Add step-by-step navigation instructions

## Summary

- ✅ A101 is set as default current location
- ✅ Green pin shows current location
- ✅ Blue path shows navigation route
- ✅ Direction arrows indicate path direction
- ✅ Cross-floor navigation works
- ✅ Room drawer shows navigation buttons
- ✅ Path can be cleared
- ✅ Current location indicator in room drawer

The navigation system is ready for testing! Use the room drawer to navigate from A101 to any destination room.

