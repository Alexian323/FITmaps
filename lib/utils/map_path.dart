/// Path drawing utilities for FITmaps
/// 
/// This file contains classes and utilities for drawing paths on the floor plan.
/// Paths can represent navigation routes, user movement trails, or highlighted corridors.

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Style options for path drawing
enum PathStyle {
  solid,
  dashed,
  dotted,
}

/// Represents a path to be drawn on the map
class MapPath {
  /// Path coordinates in pixel space (same coordinate system as room coords)
  final List<Offset> points;
  
  /// Path color
  final Color color;
  
  /// Path width in pixels
  final double width;
  
  /// Path drawing style
  final PathStyle style;
  
  /// Whether to show direction arrows along the path
  final bool showArrows;
  
  /// Optional path identifier
  final String? id;

  const MapPath({
    required this.points,
    required this.color,
    this.width = 4.0,
    this.style = PathStyle.solid,
    this.showArrows = false,
    this.id,
  });

  /// Create a navigation path (blue, with arrows)
  factory MapPath.navigation({
    required List<Offset> points,
    String? id,
  }) {
    return MapPath(
      points: points,
      color: Colors.blue,
      width: 6.0,
      style: PathStyle.solid,
      showArrows: true,
      id: id,
    );
  }

  /// Create a user trail path (faded, no arrows)
  factory MapPath.trail({
    required List<Offset> points,
    String? id,
  }) {
    return MapPath(
      points: points,
      color: Colors.blue.withOpacity(0.5),
      width: 3.0,
      style: PathStyle.solid,
      showArrows: false,
      id: id,
    );
  }

  /// Create a highlighted corridor path
  factory MapPath.corridor({
    required List<Offset> points,
    String? id,
  }) {
    return MapPath(
      points: points,
      color: Colors.green,
      width: 5.0,
      style: PathStyle.dashed,
      showArrows: false,
      id: id,
    );
  }
}

/// Manages user movement trail
class UserTrail {
  final List<Offset> _positions = [];
  final int maxLength;

  UserTrail({this.maxLength = 100});

  /// Add a new position to the trail
  void addPosition(Offset position) {
    _positions.add(position);
    if (_positions.length > maxLength) {
      _positions.removeAt(0); // Remove oldest position
    }
  }

  /// Clear all trail positions
  void clear() {
    _positions.clear();
  }

  /// Get current trail as a MapPath
  MapPath toMapPath() {
    return MapPath.trail(
      points: List.from(_positions),
    );
  }

  /// Get number of positions in trail
  int get length => _positions.length;

  /// Check if trail is empty
  bool get isEmpty => _positions.isEmpty;
}

/// Utility functions for path generation
class PathUtils {
  /// Get the center point of a room from its coordinates
  static Offset getRoomCenter(List<dynamic> coords) {
    if (coords.isEmpty) return Offset.zero;

    double centerX = 0, centerY = 0;
    int count = 0;

    for (final coord in coords) {
      if (coord is List<dynamic> && coord.length >= 2) {
        centerX += (coord[0] as num).toDouble();
        centerY += (coord[1] as num).toDouble();
        count++;
      }
    }

    if (count == 0) return Offset.zero;
    return Offset(centerX / count, centerY / count);
  }

  /// Generate a simple straight-line path between two room centers
  /// This is a fallback method - use generatePathThroughCorridors for better routing
  static List<Offset> generatePathBetweenRooms(
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
  ) {
    final startCoords = startRoom['coords'] as List<dynamic>? ?? [];
    final endCoords = endRoom['coords'] as List<dynamic>? ?? [];

    final startCenter = getRoomCenter(startCoords);
    final endCenter = getRoomCenter(endCoords);

    return [startCenter, endCenter];
  }

  /// Generate a path that routes through corridors using Manhattan distance
  /// (only horizontal/vertical movements, right-angle corners, no diagonals)
  static List<Offset> generatePathThroughCorridors(
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
    List<Map<String, dynamic>> allRooms,
  ) {
    final startCoords = startRoom['coords'] as List<dynamic>? ?? [];
    final endCoords = endRoom['coords'] as List<dynamic>? ?? [];
    final startFloor = startRoom['floor_no']?.toString();
    final endFloor = endRoom['floor_no']?.toString();

    // If different floors, return simple Manhattan path (cross-floor routing needs stairs/elevators)
    if (startFloor != endFloor) {
      return _generateManhattanPath(
        getRoomCenter(startCoords),
        getRoomCenter(endCoords),
      );
    }

    // Get start and end centers
    final startCenter = getRoomCenter(startCoords);
    final endCenter = getRoomCenter(endCoords);

    // Find all corridors on the same floor
    final corridors = allRooms.where((room) {
      final title = room['title']?.toString().toLowerCase() ?? '';
      final roomFloor = room['floor_no']?.toString();
      return title.contains('corridor') && roomFloor == startFloor;
    }).toList();

    // If no corridors found, use Manhattan path directly
    if (corridors.isEmpty) {
      return _generateManhattanPath(startCenter, endCenter);
    }

    // Find nearest corridor to start room
    Map<String, dynamic>? nearestStartCorridor;
    double minStartDistance = double.infinity;
    Offset? startCorridorPoint;

    for (final corridor in corridors) {
      final corridorCoords = corridor['coords'] as List<dynamic>? ?? [];
      if (corridorCoords.isEmpty) continue;

      // Check if we can use a point on the corridor edge (closer to start)
      final closestPoint = _findClosestPointOnRoom(startCenter, corridorCoords);
      final closestDist = _manhattanDistance(startCenter, closestPoint);

      if (closestDist < minStartDistance) {
        minStartDistance = closestDist;
        nearestStartCorridor = corridor;
        startCorridorPoint = closestPoint;
      }
    }

    // Find nearest corridor to end room
    Map<String, dynamic>? nearestEndCorridor;
    double minEndDistance = double.infinity;
    Offset? endCorridorPoint;

    for (final corridor in corridors) {
      final corridorCoords = corridor['coords'] as List<dynamic>? ?? [];
      if (corridorCoords.isEmpty) continue;

      final closestPoint = _findClosestPointOnRoom(endCenter, corridorCoords);
      final closestDist = _manhattanDistance(endCenter, closestPoint);

      if (closestDist < minEndDistance) {
        minEndDistance = closestDist;
        nearestEndCorridor = corridor;
        endCorridorPoint = closestPoint;
      }
    }

    // Build path with Manhattan distance (only horizontal/vertical movements)
    final path = <Offset>[];
    path.add(startCenter);

    // Add corridor waypoints if found
    if (nearestStartCorridor != null && startCorridorPoint != null) {
      // Connect start to corridor using Manhattan path
      final startToCorridor = _generateManhattanPath(startCenter, startCorridorPoint);
      if (startToCorridor.length > 1) {
        path.addAll(startToCorridor.sublist(1)); // Skip first point (already added)
      }

      // If start and end corridors are different, route through corridors
      if (nearestStartCorridor != nearestEndCorridor && nearestEndCorridor != null) {
        // Route from start corridor to end corridor through corridor centers
        final startCorridorCenter = getRoomCenter(
          nearestStartCorridor['coords'] as List<dynamic>? ?? []
        );
        final endCorridorCenter = getRoomCenter(
          nearestEndCorridor['coords'] as List<dynamic>? ?? []
        );
        
        // Connect through corridor centers using Manhattan path
        final corridorToCorridor = _generateManhattanPath(startCorridorCenter, endCorridorCenter);
        if (corridorToCorridor.length > 1) {
          path.addAll(corridorToCorridor.sublist(1)); // Skip first point
        }
      }

      if (endCorridorPoint != null) {
        // Connect from corridor to end using Manhattan path
        final lastPoint = path.isNotEmpty ? path.last : startCorridorPoint;
        final corridorToEnd = _generateManhattanPath(
          lastPoint,
          endCorridorPoint,
        );
        if (corridorToEnd.length > 1) {
          path.addAll(corridorToEnd.sublist(1)); // Skip first point
        }
      }
    } else {
      // No corridors found, use direct Manhattan path
      final directPath = _generateManhattanPath(startCenter, endCenter);
      if (directPath.length > 1) {
        path.addAll(directPath.sublist(1)); // Skip first point (already added)
      }
    }

    path.add(endCenter);

    // Remove duplicate consecutive points
    return _removeDuplicatePoints(path);
  }

  /// Generate a Manhattan path (only horizontal/vertical movements, right-angle corners)
  static List<Offset> _generateManhattanPath(Offset start, Offset end) {
    final path = <Offset>[start];
    
    // Manhattan distance: move horizontally first, then vertically (or vice versa)
    // Strategy: move in the direction with larger difference first
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    
    // Determine which direction to move first
    if (dx.abs() > dy.abs()) {
      // Move horizontally first, then vertically
      path.add(Offset(end.dx, start.dy)); // Horizontal move
      path.add(end); // Vertical move
    } else {
      // Move vertically first, then horizontally
      path.add(Offset(start.dx, end.dy)); // Vertical move
      path.add(end); // Horizontal move
    }
    
    return path;
  }

  /// Calculate Manhattan distance (sum of horizontal and vertical distances)
  static double _manhattanDistance(Offset a, Offset b) {
    return (a.dx - b.dx).abs() + (a.dy - b.dy).abs();
  }

  /// Remove duplicate consecutive points from path
  static List<Offset> _removeDuplicatePoints(List<Offset> path) {
    if (path.length <= 1) return path;
    
    final cleaned = <Offset>[path.first];
    for (int i = 1; i < path.length; i++) {
      final current = path[i];
      final last = cleaned.last;
      
      // Only add if point is different (with small threshold for floating point)
      if ((current.dx - last.dx).abs() > 0.1 || (current.dy - last.dy).abs() > 0.1) {
        cleaned.add(current);
      }
    }
    
    return cleaned;
  }

  /// Find the closest point on a room's perimeter to a given point
  static Offset _findClosestPointOnRoom(Offset point, List<dynamic> roomCoords) {
    if (roomCoords.isEmpty) return point;

    double minDistance = double.infinity;
    Offset closestPoint = point;

    // Check each edge of the room
    for (int i = 0; i < roomCoords.length; i++) {
      final coord1 = roomCoords[i] as List<dynamic>;
      final coord2 = roomCoords[(i + 1) % roomCoords.length] as List<dynamic>;

      if (coord1.length >= 2 && coord2.length >= 2) {
        final p1 = Offset(
          (coord1[0] as num).toDouble(),
          (coord1[1] as num).toDouble(),
        );
        final p2 = Offset(
          (coord2[0] as num).toDouble(),
          (coord2[1] as num).toDouble(),
        );

        // Find closest point on line segment
        final closestOnEdge = _closestPointOnLineSegment(point, p1, p2);
        final dist = distance(point, closestOnEdge);

        if (dist < minDistance) {
          minDistance = dist;
          closestPoint = closestOnEdge;
        }
      }
    }

    return closestPoint;
  }

  /// Find the closest point on a line segment to a given point
  static Offset _closestPointOnLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final line = lineEnd - lineStart;
    final dx = line.dx;
    final dy = line.dy;
    final lineLengthSq = dx * dx + dy * dy;
    
    if (lineLengthSq == 0) return lineStart;

    final pointToStart = point - lineStart;
    final dotProduct = pointToStart.dx * dx + pointToStart.dy * dy;
    final t = (dotProduct / lineLengthSq).clamp(0.0, 1.0);
    return Offset(
      lineStart.dx + dx * t,
      lineStart.dy + dy * t,
    );
  }

  /// Simplify path by removing points that are too close together
  /// This is kept for backward compatibility but may not be needed with Manhattan paths
  static List<Offset> _simplifyPath(List<Offset> path, {double threshold = 30.0}) {
    if (path.length <= 2) return path;

    final simplified = <Offset>[path.first];

    for (int i = 1; i < path.length - 1; i++) {
      final prev = simplified.last;
      final current = path[i];
      final next = path[i + 1];

      // Keep point if Manhattan distance is large
      final distToPrev = _manhattanDistance(prev, current);
      final distToNext = _manhattanDistance(current, next);

      if (distToPrev > threshold || distToNext > threshold) {
        simplified.add(current);
      }
    }

    simplified.add(path.last);
    return simplified;
  }

  /// Generate a path through multiple waypoint rooms
  static List<Offset> generatePathThroughWaypoints(
    Map<String, dynamic> startRoom,
    List<Map<String, dynamic>> waypointRooms,
    Map<String, dynamic> endRoom,
  ) {
    final path = <Offset>[];

    // Start from first room center
    final startCoords = startRoom['coords'] as List<dynamic>? ?? [];
    path.add(getRoomCenter(startCoords));

    // Add waypoint room centers
    for (final waypoint in waypointRooms) {
      final waypointCoords = waypoint['coords'] as List<dynamic>? ?? [];
      path.add(getRoomCenter(waypointCoords));
    }

    // End at destination room center
    final endCoords = endRoom['coords'] as List<dynamic>? ?? [];
    path.add(getRoomCenter(endCoords));

    return path;
  }

  /// Create a curved path using quadratic Bezier curves
  static Path createCurvedPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      
      // Use midpoint as control point for smooth curve
      final controlPoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      
      path.quadraticBezierTo(
        controlPoint.dx,
        controlPoint.dy,
        next.dx,
        next.dy,
      );
    }

    return path;
  }

  /// Calculate distance between two points
  static double distance(Offset a, Offset b) {
    return math.sqrt(
      math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2),
    );
  }
}

