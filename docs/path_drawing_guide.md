# Path Drawing Implementation Guide

## Overview
This guide explains how to draw paths on the FITmaps floor plan. Paths can be used for:
- Navigation routes between rooms
- User movement trails
- Highlighted corridors/hallways
- Multi-segment wayfinding paths

## Architecture

### 1. Path Data Structure

Paths are represented as lists of coordinate points in pixel space (same coordinate system as room `coords`):

```dart
// Simple path: list of [x, y] coordinates
List<List<double>> pathPoints = [
  [100.0, 200.0],  // Start point
  [150.0, 250.0],  // Waypoint
  [200.0, 300.0],  // End point
];

// Path with metadata
class MapPath {
  final List<Offset> points;      // Path coordinates in pixel space
  final Color color;              // Path color
  final double width;             // Path width
  final PathStyle style;           // solid, dashed, dotted
  final bool showArrows;          // Show direction arrows
  final String? id;               // Optional path identifier
}

enum PathStyle { solid, dashed, dotted }
```

### 2. Adding Paths to BuildingMapPainter

Modify `BuildingMapPainter` to accept and draw paths:

```dart
class BuildingMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> roomData;
  final List<Map<String, dynamic>> highlightedRooms;
  final double pulseValue;
  final double zoomLevel;
  final Rect mapBounds;
  
  // NEW: Add path data
  final List<MapPath> paths;  // Navigation paths
  final List<MapPath> trails; // User movement trails

  BuildingMapPainter({
    required this.roomData,
    required this.highlightedRooms,
    required this.pulseValue,
    required this.zoomLevel,
    required this.mapBounds,
    this.paths = const [],      // Default empty
    this.trails = const [],      // Default empty
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw all rooms (existing code)
    for (final room in roomData) {
      _drawRoom(canvas, room, size, drawMarker: false);
    }

    // 2. NEW: Draw paths (after rooms, before markers)
    for (final path in paths) {
      _drawPath(canvas, path, size);
    }
    
    for (final trail in trails) {
      _drawPath(canvas, trail, size);
    }

    // 3. Draw markers on top (existing code)
    for (final room in roomData) {
      final roomId = room['id'] as String;
      final isHighlighted = highlightedRooms
          .any((highlightedRoom) => highlightedRoom['id'] == roomId);
      
      if (isHighlighted) {
        final coords = room['coords'] as List<dynamic>;
        _drawGoogleMarker(canvas, coords, size);
      }
    }
  }
}
```

### 3. Path Drawing Method

```dart
void _drawPath(Canvas canvas, MapPath path, Size canvasSize) {
  if (path.points.length < 2) return;

  // Map path points from pixel coordinates to canvas space
  final mappedPoints = path.points.map((point) {
    final mappedX = ((point.dx - mapBounds.left) / mapBounds.width) * canvasSize.width;
    final mappedY = ((point.dy - mapBounds.top) / mapBounds.height) * canvasSize.height;
    return Offset(mappedX, mappedY);
  }).toList();

  // Create path
  final pathObj = Path();
  pathObj.moveTo(mappedPoints[0].dx, mappedPoints[0].dy);
  for (int i = 1; i < mappedPoints.length; i++) {
    pathObj.lineTo(mappedPoints[i].dx, mappedPoints[i].dy);
  }

  // Create paint based on style
  final paint = Paint()
    ..color = path.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = path.width / zoomLevel.clamp(0.5, 3.0) // Scale with zoom
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // Apply style (dashed, dotted, etc.)
  if (path.style == PathStyle.dashed) {
    paint.strokeWidth = path.width / zoomLevel.clamp(0.5, 3.0);
    // Flutter doesn't have built-in dashed lines, use path_effects package
    // Or draw manually with line segments
  }

  // Draw the path
  canvas.drawPath(pathObj, paint);

  // Draw direction arrows if enabled
  if (path.showArrows && mappedPoints.length >= 2) {
    _drawPathArrows(canvas, mappedPoints, path.color, path.width);
  }
}
```

### 4. Drawing Direction Arrows

```dart
void _drawPathArrows(Canvas canvas, List<Offset> points, Color color, double pathWidth) {
  final arrowPaint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  const double arrowSize = 12.0;
  const double arrowSpacing = 50.0; // Distance between arrows

  for (int i = 0; i < points.length - 1; i++) {
    final start = points[i];
    final end = points[i + 1];
    final distance = (end - start).distance;
    
    // Calculate number of arrows for this segment
    final numArrows = (distance / arrowSpacing).floor();
    
    for (int j = 0; j < numArrows; j++) {
      final t = (j + 1) / (numArrows + 1);
      final arrowPos = Offset.lerp(start, end, t)!;
      final angle = (end - start).direction;
      
      _drawArrow(canvas, arrowPos, angle, arrowSize, arrowPaint);
    }
  }
}

void _drawArrow(Canvas canvas, Offset position, double angle, double size, Paint paint) {
  final path = Path();
  
  // Arrow shape (triangle pointing in direction)
  path.moveTo(position.dx, position.dy);
  path.lineTo(
    position.dx - size * math.cos(angle - math.pi / 6),
    position.dy - size * math.sin(angle - math.pi / 6),
  );
  path.lineTo(
    position.dx - size * math.cos(angle + math.pi / 6),
    position.dy - size * math.sin(angle + math.pi / 6),
  );
  path.close();
  
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(angle);
  canvas.translate(-position.dx, -position.dy);
  canvas.drawPath(path, paint);
  canvas.restore();
}
```

### 5. Path Generation Methods

#### A. Path Between Two Rooms (Center-to-Center)

```dart
List<Offset> generatePathBetweenRooms(
  Map<String, dynamic> startRoom,
  Map<String, dynamic> endRoom,
) {
  // Get room centers
  final startCenter = _getRoomCenter(startRoom['coords'] as List<dynamic>);
  final endCenter = _getRoomCenter(endRoom['coords'] as List<dynamic>);
  
  // Simple straight line (can be enhanced with waypoints)
  return [startCenter, endCenter];
}

Offset _getRoomCenter(List<dynamic> coords) {
  double centerX = 0, centerY = 0;
  for (final coord in coords) {
    if (coord is List<dynamic> && coord.length >= 2) {
      centerX += (coord[0] as num).toDouble();
      centerY += (coord[1] as num).toDouble();
    }
  }
  return Offset(centerX / coords.length, centerY / coords.length);
}
```

#### B. Path Through Corridors (Multi-Waypoint)

```dart
List<Offset> generatePathThroughCorridors(
  Map<String, dynamic> startRoom,
  Map<String, dynamic> endRoom,
  List<Map<String, dynamic>> waypointRooms,
) {
  final path = <Offset>[];
  
  // Start from first room center
  path.add(_getRoomCenter(startRoom['coords'] as List<dynamic>));
  
  // Add waypoint room centers
  for (final waypoint in waypointRooms) {
    path.add(_getRoomCenter(waypoint['coords'] as List<dynamic>));
  }
  
  // End at destination room center
  path.add(_getRoomCenter(endRoom['coords'] as List<dynamic>));
  
  return path;
}
```

#### C. User Movement Trail

```dart
class UserTrail {
  final List<Offset> positions = [];
  final int maxLength = 100; // Maximum trail points
  
  void addPosition(Offset position) {
    positions.add(position);
    if (positions.length > maxLength) {
      positions.removeAt(0); // Remove oldest
    }
  }
  
  void clear() {
    positions.clear();
  }
  
  MapPath toMapPath() {
    return MapPath(
      points: List.from(positions),
      color: Colors.blue.withOpacity(0.6),
      width: 4.0,
      style: PathStyle.solid,
      showArrows: false,
    );
  }
}
```

### 6. Integration with HomeScreen

```dart
class _HomeScreenState extends State<HomeScreen> {
  // ... existing code ...
  
  // NEW: Path data
  List<MapPath> _navigationPaths = [];
  UserTrail _userTrail = UserTrail();
  
  // Method to set navigation path
  void setNavigationPath(Map<String, dynamic> startRoom, Map<String, dynamic> endRoom) {
    final pathPoints = generatePathBetweenRooms(startRoom, endRoom);
    setState(() {
      _navigationPaths = [
        MapPath(
          points: pathPoints.map((p) => Offset(p.dx, p.dy)).toList(),
          color: Colors.blue,
          width: 6.0,
          style: PathStyle.solid,
          showArrows: true,
        ),
      ];
    });
  }
  
  // Method to clear paths
  void clearPaths() {
    setState(() {
      _navigationPaths = [];
    });
  }
  
  // Update map painter to include paths
  Widget _buildMapContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          // ... existing code ...
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  // ... existing code ...
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: BuildingMapPainter(
                          roomData: _roomData,
                          highlightedRooms: _highlightedRooms,
                          pulseValue: _pulseAnimation.value,
                          zoomLevel: _interactiveController.value.getMaxScaleOnAxis(),
                          mapBounds: Rect.fromLTRB(_mapMinX, _mapMinY, _mapMaxX, _mapMaxY),
                          paths: _navigationPaths,           // NEW
                          trails: [_userTrail.toMapPath()],  // NEW
                        ),
                        child: Container(),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Usage Examples

### Example 1: Simple Navigation Path

```dart
// Find rooms
final startRoom = _allRoomsData.firstWhere((r) => r['id'] == 'D006');
final endRoom = _allRoomsData.firstWhere((r) => r['id'] == 'D0201');

// Generate and set path
setNavigationPath(startRoom, endRoom);
```

### Example 2: Multi-Waypoint Path

```dart
final start = _allRoomsData.firstWhere((r) => r['id'] == 'D006');
final waypoint1 = _allRoomsData.firstWhere((r) => r['id'] == 'D0201');
final waypoint2 = _allRoomsData.firstWhere((r) => r['id'] == 'D0202');
final end = _allRoomsData.firstWhere((r) => r['id'] == 'D0203');

final pathPoints = generatePathThroughCorridors(start, end, [waypoint1, waypoint2]);
setState(() {
  _navigationPaths = [
    MapPath(
      points: pathPoints,
      color: Colors.green,
      width: 8.0,
      style: PathStyle.dashed,
      showArrows: true,
    ),
  ];
});
```

### Example 3: User Movement Trail

```dart
// When user position updates (from GPS)
void onUserPositionUpdate(Offset position) {
  _userTrail.addPosition(position);
  setState(() {}); // Trigger repaint
}
```

## Advanced Features

### 1. Smooth Curved Paths

Use Bezier curves for smoother navigation:

```dart
Path createCurvedPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  
  path.moveTo(points[0].dx, points[0].dy);
  
  for (int i = 0; i < points.length - 1; i++) {
    final current = points[i];
    final next = points[i + 1];
    final controlPoint = Offset(
      (current.dx + next.dx) / 2,
      (current.dy + next.dy) / 2,
    );
    path.quadraticBezierTo(
      controlPoint.dx, controlPoint.dy,
      next.dx, next.dy,
    );
  }
  
  return path;
}
```

### 2. Path Animation

Animate path drawing for better UX:

```dart
class AnimatedPathPainter extends CustomPainter {
  final double animationProgress; // 0.0 to 1.0
  
  @override
  void paint(Canvas canvas, Size size) {
    final visibleLength = (path.points.length * animationProgress).floor();
    final visiblePath = path.points.sublist(0, visibleLength);
    // Draw only visible portion
  }
}
```

### 3. Path Obstacle Avoidance

For more sophisticated routing, implement A* or Dijkstra's algorithm using room connections/graph.

## Performance Considerations

1. **Path Caching**: Cache computed paths to avoid recalculation
2. **LOD (Level of Detail)**: Simplify paths at low zoom levels
3. **Path Simplification**: Use Douglas-Peucker algorithm for long paths
4. **Batch Drawing**: Draw multiple paths in single canvas operation

## Summary

- Paths use the same pixel coordinate system as rooms
- Draw paths after rooms but before markers
- Support multiple path types (navigation, trails, etc.)
- Use `Path` and `Paint` objects for drawing
- Map coordinates to canvas space using existing transformation
- Consider performance for complex paths

