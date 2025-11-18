/// Example code showing how to integrate path drawing into HomeScreen
/// 
/// This is a reference implementation - copy relevant parts into your actual code.

import 'package:flutter/material.dart';
import 'package:fitmaps/utils/map_path.dart';

// ============================================================================
// STEP 1: Add path data to HomeScreen state
// ============================================================================

class _HomeScreenState extends State<HomeScreen> {
  // ... existing state variables ...
  
  // NEW: Add path data
  List<MapPath> _navigationPaths = [];
  UserTrail _userTrail = UserTrail();

  // ... rest of existing code ...
}

// ============================================================================
// STEP 2: Update BuildingMapPainter to accept and draw paths
// ============================================================================

class BuildingMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> roomData;
  final List<Map<String, dynamic>> highlightedRooms;
  final double pulseValue;
  final double zoomLevel;
  final Rect mapBounds;
  
  // NEW: Add path parameters
  final List<MapPath> paths;
  final List<MapPath> trails;

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

  // NEW: Method to draw a path
  void _drawPath(Canvas canvas, MapPath path, Size canvasSize) {
    if (path.points.length < 2) return;

    // Map path points from pixel coordinates to canvas space
    final mappedPoints = path.points.map((point) {
      final mappedX = ((point.dx - mapBounds.left) / mapBounds.width) * canvasSize.width;
      final mappedY = ((point.dy - mapBounds.top) / mapBounds.height) * canvasSize.height;
      return Offset(mappedX, mappedY);
    }).toList();

    // Create path object
    final pathObj = Path();
    pathObj.moveTo(mappedPoints[0].dx, mappedPoints[0].dy);
    for (int i = 1; i < mappedPoints.length; i++) {
      pathObj.lineTo(mappedPoints[i].dx, mappedPoints[i].dy);
    }

    // Create paint
    final paint = Paint()
      ..color = path.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = path.width / zoomLevel.clamp(0.5, 3.0) // Scale with zoom
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw the path
    canvas.drawPath(pathObj, paint);

    // Draw direction arrows if enabled
    if (path.showArrows && mappedPoints.length >= 2) {
      _drawPathArrows(canvas, mappedPoints, path.color, path.width);
    }
  }

  // NEW: Draw direction arrows along path
  void _drawPathArrows(Canvas canvas, List<Offset> points, Color color, double pathWidth) {
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double arrowSize = 12.0;
    const double arrowSpacing = 50.0;

    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final distance = (end - start).distance;
      
      final numArrows = (distance / arrowSpacing).floor();
      
      for (int j = 0; j < numArrows; j++) {
        final t = (j + 1) / (numArrows + 1);
        final arrowPos = Offset.lerp(start, end, t)!;
        final angle = (end - start).direction;
        
        _drawArrow(canvas, arrowPos, angle, arrowSize, arrowPaint);
      }
    }
  }

  // NEW: Draw a single arrow
  void _drawArrow(Canvas canvas, Offset position, double angle, double size, Paint paint) {
    final path = Path();
    
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

  // ... rest of existing methods ...
}

// ============================================================================
// STEP 3: Update CustomPaint to pass paths
// ============================================================================

Widget _buildMapContent() {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Container(
        // ... existing container code ...
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                // ... existing gesture detector code ...
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
                        paths: _navigationPaths,                    // NEW
                        trails: _userTrail.isEmpty ? [] : [_userTrail.toMapPath()], // NEW
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

// ============================================================================
// STEP 4: Add methods to create and manage paths
// ============================================================================

// Method to set navigation path between two rooms
void setNavigationPath(Map<String, dynamic> startRoom, Map<String, dynamic> endRoom) {
  final pathPoints = PathUtils.generatePathBetweenRooms(startRoom, endRoom);
  setState(() {
    _navigationPaths = [
      MapPath.navigation(points: pathPoints),
    ];
  });
}

// Method to set multi-waypoint path
void setNavigationPathWithWaypoints(
  Map<String, dynamic> startRoom,
  List<Map<String, dynamic>> waypoints,
  Map<String, dynamic> endRoom,
) {
  final pathPoints = PathUtils.generatePathThroughWaypoints(startRoom, waypoints, endRoom);
  setState(() {
    _navigationPaths = [
      MapPath.navigation(points: pathPoints),
    ];
  });
}

// Method to clear all paths
void clearPaths() {
  setState(() {
    _navigationPaths = [];
  });
}

// Method to update user trail (call this when GPS position updates)
void updateUserTrail(Offset position) {
  _userTrail.addPosition(position);
  setState(() {}); // Trigger repaint
}

// Method to clear user trail
void clearUserTrail() {
  _userTrail.clear();
  setState(() {});
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

void exampleUsage() {
  // Example 1: Create navigation path between two rooms
  final startRoom = _allRoomsData.firstWhere((r) => r['id'] == 'D006');
  final endRoom = _allRoomsData.firstWhere((r) => r['id'] == 'D0201');
  setNavigationPath(startRoom, endRoom);

  // Example 2: Create path with waypoints
  final waypoint1 = _allRoomsData.firstWhere((r) => r['id'] == 'D0201');
  final waypoint2 = _allRoomsData.firstWhere((r) => r['id'] == 'D0202');
  setNavigationPathWithWaypoints(startRoom, [waypoint1, waypoint2], endRoom);

  // Example 3: Update user trail (from GPS)
  // When you get a GPS position, convert it to pixel coordinates first
  // Offset userPosition = convertGpsToPixelCoordinates(lat, lon);
  // updateUserTrail(userPosition);

  // Example 4: Clear paths
  clearPaths();
  clearUserTrail();
}

