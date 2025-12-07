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

  /// Create a navigation path (bright cyan/teal, distinct color for visibility)
  factory MapPath.navigation({
    required List<Offset> points,
    String? id,
  }) {
    return MapPath(
      points: points,
      color: const Color(
          0xFF00CED1), // Dark turquoise/cyan - distinct, professional, and eye-catching
      width: 8.0, // Increased from 6.0 for better visibility
      style: PathStyle.solid,
      showArrows: false, // Arrows disabled per user request
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

/// Navigation result containing path and instructions
class NavigationResult {
  final List<Offset> path;
  final List<String> instructions;
  final bool isMultiLevel;
  final List<Map<String, dynamic>>? staircases;
  final List<Map<String, dynamic>>? lifts;

  NavigationResult({
    required this.path,
    required this.instructions,
    this.isMultiLevel = false,
    this.staircases,
    this.lifts,
  });
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
  /// The path will stay within corridors when possible and avoid going through rooms
  static List<Offset> generatePathThroughCorridors(
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
    List<Map<String, dynamic>> allRooms,
  ) {
    final result = generatePathWithInstructions(startRoom, endRoom, allRooms);
    return result.path;
  }

  /// Generate path with navigation instructions and multi-level support
  static NavigationResult generatePathWithInstructions(
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
    List<Map<String, dynamic>> allRooms,
  ) {
    final startCoords = startRoom['coords'] as List<dynamic>? ?? [];
    final endCoords = endRoom['coords'] as List<dynamic>? ?? [];
    final startFloor = startRoom['floor_no']?.toString();
    final endFloor = endRoom['floor_no']?.toString();

    // Check if multi-level navigation is needed
    if (startFloor != endFloor) {
      return _generateMultiLevelPath(startRoom, endRoom, allRooms);
    }

    // Same floor - generate corridor-aware path
    final startCenter = getRoomCenter(startCoords);
    final endCenter = getRoomCenter(endCoords);

    // Find all corridors on the same floor
    final corridors = allRooms.where((room) {
      final title = room['title']?.toString().toLowerCase() ?? '';
      final roomFloor = room['floor_no']?.toString();
      return title.contains('corridor') && roomFloor == startFloor;
    }).toList();

    // Find all non-corridor rooms to avoid
    final nonCorridorRooms = allRooms.where((room) {
      final title = room['title']?.toString().toLowerCase() ?? '';
      final roomFloor = room['floor_no']?.toString();

      // Skip corridors, staircases, and lifts (these are passable)
      if (title.contains('corridor') ||
          title.contains('staircase') ||
          title.contains('elevator') ||
          title.contains('lift')) {
        return false;
      }

      // Skip start and end rooms
      if (room['id'] == startRoom['id'] || room['id'] == endRoom['id']) {
        return false;
      }

      return roomFloor == startFloor;
    }).toList();

    print('Found ${corridors.length} corridors on floor $startFloor');
    print('Found ${nonCorridorRooms.length} rooms to avoid');

    // Generate path that avoids rooms and stays in corridors
    final path = _findPathThroughCorridorsAvoidingRooms(
      startCenter,
      endCenter,
      corridors,
      nonCorridorRooms,
      startRoom,
      endRoom,
    );

    final instructions = _generateNavigationInstructions(
      startRoom,
      endRoom,
      path,
      false,
      null,
      null,
    );

    return NavigationResult(
      path: path,
      instructions: instructions,
      isMultiLevel: false,
    );
  }

  /// Generate multi-level navigation path with staircase/lift guidance
  static NavigationResult _generateMultiLevelPath(
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
    List<Map<String, dynamic>> allRooms,
  ) {
    final startFloor = startRoom['floor_no']?.toString();
    final endFloor = endRoom['floor_no']?.toString();

    // Find staircases and lifts on start floor
    final staircases = allRooms.where((room) {
      final title = room['title']?.toString().toLowerCase() ?? '';
      final roomFloor = room['floor_no']?.toString();
      return (title.contains('staircase') || title.contains('stairs')) &&
          roomFloor == startFloor;
    }).toList();

    final lifts = allRooms.where((room) {
      final title = room['title']?.toString().toLowerCase() ?? '';
      final roomFloor = room['floor_no']?.toString();
      return (title.contains('elevator') || title.contains('lift')) &&
          roomFloor == startFloor;
    }).toList();

    // Find nearest staircase/lift to start room
    final startCenter =
        getRoomCenter(startRoom['coords'] as List<dynamic>? ?? []);
    Map<String, dynamic>? nearestStaircase;
    Map<String, dynamic>? nearestLift;
    double minStaircaseDist = double.infinity;
    double minLiftDist = double.infinity;

    for (final staircase in staircases) {
      final staircaseCenter =
          getRoomCenter(staircase['coords'] as List<dynamic>? ?? []);
      final dist = distance(startCenter, staircaseCenter);
      if (dist < minStaircaseDist) {
        minStaircaseDist = dist;
        nearestStaircase = staircase;
      }
    }

    for (final lift in lifts) {
      final liftCenter = getRoomCenter(lift['coords'] as List<dynamic>? ?? []);
      final dist = distance(startCenter, liftCenter);
      if (dist < minLiftDist) {
        minLiftDist = dist;
        nearestLift = lift;
      }
    }

    // Generate path to nearest staircase/lift, then to destination
    final path = <Offset>[];
    final instructions = <String>[];

    // Path from start to staircase/lift
    if (nearestStaircase != null || nearestLift != null) {
      final verticalAccess =
          (nearestLift != null && minLiftDist < minStaircaseDist)
              ? nearestLift
              : nearestStaircase;

      if (verticalAccess == null) {
        // Fallback - shouldn't happen but handle it
        final endCenter =
            getRoomCenter(endRoom['coords'] as List<dynamic>? ?? []);
        path.addAll(_generateManhattanPath(startCenter, endCenter));
        instructions.add(
            '⚠️ No staircase or lift found. Please use the nearest staircase or lift to change floors.');
        return NavigationResult(
          path: _removeDuplicatePoints(path),
          instructions: instructions,
          isMultiLevel: true,
        );
      }

      final verticalAccessCenter =
          getRoomCenter(verticalAccess['coords'] as List<dynamic>? ?? []);

      // Path from start to vertical access point
      final startToVertical =
          _generateManhattanPath(startCenter, verticalAccessCenter);
      path.addAll(startToVertical);

      // Path from vertical access to destination (on destination floor)
      final endCenter =
          getRoomCenter(endRoom['coords'] as List<dynamic>? ?? []);
      path.add(endCenter);

      // Generate instructions
      instructions.addAll(_generateMultiLevelInstructions(
        startRoom,
        endRoom,
        verticalAccess,
        (nearestLift != null && minLiftDist < minStaircaseDist),
      ));
    } else {
      // No staircase/lift found - use direct path with warning
      final endCenter =
          getRoomCenter(endRoom['coords'] as List<dynamic>? ?? []);
      path.addAll(_generateManhattanPath(startCenter, endCenter));
      instructions.add(
          '⚠️ No staircase or lift found. Please use the nearest staircase or lift to change floors.');
      instructions.add(
          'Navigate from ${startRoom['id']} on Floor ${startFloor} to ${endRoom['id']} on Floor ${endFloor}');
    }

    return NavigationResult(
      path: _removeDuplicatePoints(path),
      instructions: instructions,
      isMultiLevel: true,
      staircases: staircases.isNotEmpty ? staircases : null,
      lifts: lifts.isNotEmpty ? lifts : null,
    );
  }

  /// Find a path through corridors, avoiding rooms and staying within corridor boundaries
  static List<Offset> _findPathThroughCorridorsAvoidingRooms(
    Offset start,
    Offset end,
    List<Map<String, dynamic>> corridors,
    List<Map<String, dynamic>> roomsToAvoid,
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
  ) {
    // First try the original corridor pathfinding
    final corridorPath = _findPathThroughCorridors(start, end, corridors);

    // Check if path goes through any rooms (excluding start/end)
    // Validate by checking multiple points along each segment, not just endpoints
    bool pathIsValid = true;
    for (final room in roomsToAvoid) {
      final roomCoords = room['coords'] as List<dynamic>? ?? [];
      if (roomCoords.isEmpty) continue;

      // Check if any path segment intersects with or goes through this room
      for (int i = 0; i < corridorPath.length - 1; i++) {
        final segmentStart = corridorPath[i];
        final segmentEnd = corridorPath[i + 1];

        // Check segment intersection (includes endpoint and midpoint checks)
        if (_segmentIntersectsRoom(segmentStart, segmentEnd, roomCoords)) {
          pathIsValid = false;
          break;
        }

        // Also check intermediate points along the segment to catch paths that go through rooms
        final segmentLength = distance(segmentStart, segmentEnd);
        if (segmentLength > 10) {
          // Sample points along the segment (every 20 pixels or at least 2 samples)
          final numSamples = (segmentLength / 20).ceil().clamp(2, 10);
          for (int j = 1; j < numSamples; j++) {
            final t = j / numSamples;
            final samplePoint = Offset(
              segmentStart.dx + (segmentEnd.dx - segmentStart.dx) * t,
              segmentStart.dy + (segmentEnd.dy - segmentStart.dy) * t,
            );
            if (_isPointInRoom(samplePoint, roomCoords)) {
              pathIsValid = false;
              break;
            }
          }
        }

        if (!pathIsValid) break;
      }

      if (!pathIsValid) break;
    }

    // If path is valid (doesn't go through rooms), return it
    if (pathIsValid) {
      return corridorPath;
    }

    // Otherwise, generate a safer path that explicitly avoids rooms
    return _generateSafePathAvoidingRooms(
      start,
      end,
      corridors,
      roomsToAvoid,
      startRoom,
      endRoom,
    );
  }

  /// Check if a line segment intersects with or goes through a room polygon
  static bool _segmentIntersectsRoom(
      Offset p1, Offset p2, List<dynamic> roomCoords) {
    if (roomCoords.length < 3) return false;

    // First check if either endpoint is inside the room
    if (_isPointInRoom(p1, roomCoords) || _isPointInRoom(p2, roomCoords)) {
      return true;
    }

    // Check if segment intersects any edge of the room
    for (int i = 0; i < roomCoords.length; i++) {
      final coord1 = roomCoords[i] as List<dynamic>;
      final coord2 = roomCoords[(i + 1) % roomCoords.length] as List<dynamic>;

      if (coord1.length >= 2 && coord2.length >= 2) {
        final roomP1 = Offset(
          (coord1[0] as num).toDouble(),
          (coord1[1] as num).toDouble(),
        );
        final roomP2 = Offset(
          (coord2[0] as num).toDouble(),
          (coord2[1] as num).toDouble(),
        );

        if (_segmentsIntersect(p1, p2, roomP1, roomP2)) {
          return true;
        }
      }
    }

    // Check if midpoint of segment is inside room (catches paths that go through middle)
    final midpoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    if (_isPointInRoom(midpoint, roomCoords)) {
      return true;
    }

    return false;
  }

  /// Check if two line segments intersect
  static bool _segmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1 =
        (p4.dx - p3.dx) * (p1.dy - p3.dy) - (p4.dy - p3.dy) * (p1.dx - p3.dx);
    final d2 =
        (p4.dx - p3.dx) * (p2.dy - p3.dy) - (p4.dy - p3.dy) * (p2.dx - p3.dx);
    final d3 =
        (p2.dx - p1.dx) * (p3.dy - p1.dy) - (p2.dy - p1.dy) * (p3.dx - p1.dx);
    final d4 =
        (p2.dx - p1.dx) * (p4.dy - p1.dy) - (p2.dy - p1.dy) * (p4.dx - p1.dx);

    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  /// Generate a safe path that avoids rooms by routing around them
  static List<Offset> _generateSafePathAvoidingRooms(
    Offset start,
    Offset end,
    List<Map<String, dynamic>> corridors,
    List<Map<String, dynamic>> roomsToAvoid,
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
  ) {
    // Find corridors near start and end
    Map<String, dynamic>? startCorridor;
    Map<String, dynamic>? endCorridor;
    Offset? startExitPoint;
    Offset? endEntryPoint;

    // Find nearest corridor to start
    double minStartDist = double.infinity;
    for (final corridor in corridors) {
      final corridorCoords = corridor['coords'] as List<dynamic>? ?? [];
      if (corridorCoords.isEmpty) continue;

      final closestPoint = _findClosestPointOnRoom(start, corridorCoords);
      final dist = distance(start, closestPoint);
      if (dist < minStartDist) {
        minStartDist = dist;
        startCorridor = corridor;
        startExitPoint = closestPoint;
      }
    }

    // Find nearest corridor to end
    double minEndDist = double.infinity;
    for (final corridor in corridors) {
      final corridorCoords = corridor['coords'] as List<dynamic>? ?? [];
      if (corridorCoords.isEmpty) continue;

      final closestPoint = _findClosestPointOnRoom(end, corridorCoords);
      final dist = distance(end, closestPoint);
      if (dist < minEndDist) {
        minEndDist = dist;
        endCorridor = corridor;
        endEntryPoint = closestPoint;
      }
    }

    // Build path through corridors
    final path = <Offset>[start];

    if (startCorridor != null && startExitPoint != null) {
      // Path from start to corridor
      if (startExitPoint != start) {
        final startToCorridor = _generateManhattanPath(start, startExitPoint);
        if (startToCorridor.length > 1) {
          path.addAll(startToCorridor.sublist(1));
        }
      }

      // Route through corridor centers
      if (startCorridor == endCorridor &&
          endCorridor != null &&
          endEntryPoint != null) {
        // Same corridor - route through center
        final corridorCenter =
            getRoomCenter(startCorridor['coords'] as List<dynamic>? ?? []);
        final currentPoint = path.isNotEmpty ? path.last : startExitPoint;

        if (distance(currentPoint, corridorCenter) > 5.0) {
          final toCenter = _generateManhattanPath(currentPoint, corridorCenter);
          if (toCenter.length > 1) {
            path.addAll(toCenter.sublist(1));
          }
        }

        if (endEntryPoint != end) {
          final centerToEntry =
              _generateManhattanPath(corridorCenter, endEntryPoint);
          if (centerToEntry.length > 1) {
            path.addAll(centerToEntry.sublist(1));
          }
        }
      } else if (endCorridor != null && endEntryPoint != null) {
        // Different corridors - route through both centers
        final startCorridorCenter =
            getRoomCenter(startCorridor['coords'] as List<dynamic>? ?? []);
        final endCorridorCenter =
            getRoomCenter(endCorridor['coords'] as List<dynamic>? ?? []);
        final currentPoint = path.isNotEmpty ? path.last : startExitPoint;

        // To start corridor center
        if (distance(currentPoint, startCorridorCenter) > 5.0) {
          final toStartCenter =
              _generateManhattanPath(currentPoint, startCorridorCenter);
          if (toStartCenter.length > 1) {
            path.addAll(toStartCenter.sublist(1));
          }
        }

        // Between corridor centers
        final corridorToCorridor =
            _generateManhattanPath(startCorridorCenter, endCorridorCenter);
        if (corridorToCorridor.length > 1) {
          path.addAll(corridorToCorridor.sublist(1));
        }

        // To end entry point
        if (endEntryPoint != end) {
          final centerToEntry =
              _generateManhattanPath(endCorridorCenter, endEntryPoint);
          if (centerToEntry.length > 1) {
            path.addAll(centerToEntry.sublist(1));
          }
        }
      }

      // Path from corridor to end
      if (endEntryPoint != null && endEntryPoint != end) {
        final corridorToEnd = _generateManhattanPath(endEntryPoint, end);
        if (corridorToEnd.length > 1) {
          path.addAll(corridorToEnd.sublist(1));
        }
      }
    }

    path.add(end);
    return _removeDuplicatePoints(path);
  }

  /// Find a path through corridors, staying within corridor boundaries when possible
  static List<Offset> _findPathThroughCorridors(
    Offset start,
    Offset end,
    List<Map<String, dynamic>> corridors,
  ) {
    final path = <Offset>[start];

    // Find corridors that contain or are near the start and end points
    Map<String, dynamic>? startCorridor;
    Map<String, dynamic>? endCorridor;
    Offset? startExitPoint;
    Offset? endEntryPoint;

    // Find corridor containing or nearest to start
    double minStartDist = double.infinity;
    for (final corridor in corridors) {
      final corridorCoords = corridor['coords'] as List<dynamic>? ?? [];
      if (corridorCoords.isEmpty) continue;

      // Check if start is inside corridor
      if (_isPointInRoom(start, corridorCoords)) {
        startCorridor = corridor;
        startExitPoint = start; // Use start point directly if inside corridor
        break;
      }

      // Otherwise find closest point on corridor
      final closestPoint = _findClosestPointOnRoom(start, corridorCoords);
      final dist = _manhattanDistance(start, closestPoint);
      if (dist < minStartDist) {
        minStartDist = dist;
        startCorridor = corridor;
        startExitPoint = closestPoint;
      }
    }

    // Find corridor containing or nearest to end
    double minEndDist = double.infinity;
    for (final corridor in corridors) {
      final corridorCoords = corridor['coords'] as List<dynamic>? ?? [];
      if (corridorCoords.isEmpty) continue;

      // Check if end is inside corridor
      if (_isPointInRoom(end, corridorCoords)) {
        endCorridor = corridor;
        endEntryPoint = end; // Use end point directly if inside corridor
        break;
      }

      // Otherwise find closest point on corridor
      final closestPoint = _findClosestPointOnRoom(end, corridorCoords);
      final dist = _manhattanDistance(end, closestPoint);
      if (dist < minEndDist) {
        minEndDist = dist;
        endCorridor = corridor;
        endEntryPoint = closestPoint;
      }
    }

    print(
        'Start corridor: ${startCorridor != null ? startCorridor['id'] : 'null'}');
    print('End corridor: ${endCorridor != null ? endCorridor['id'] : 'null'}');

    // Build path through corridors
    if (startCorridor != null && startExitPoint != null) {
      // Path from start to corridor entry
      if (startExitPoint != start) {
        final startToCorridor = _generateManhattanPath(start, startExitPoint);
        if (startToCorridor.length > 1) {
          path.addAll(startToCorridor.sublist(1));
        }
      }

      // If both start and end are in the same corridor, route through it
      if (startCorridor == endCorridor &&
          endCorridor != null &&
          endEntryPoint != null) {
        // Route through the corridor center to stay within it
        final corridorCenter =
            getRoomCenter(startCorridor['coords'] as List<dynamic>? ?? []);
        final currentPoint = path.isNotEmpty ? path.last : startExitPoint;

        // Route to corridor center, then to end entry point
        if (_manhattanDistance(currentPoint, corridorCenter) > 5.0) {
          final toCenter = _generateManhattanPath(currentPoint, corridorCenter);
          if (toCenter.length > 1) {
            path.addAll(toCenter.sublist(1));
          }
        }

        if (endEntryPoint != end) {
          final centerToEntry =
              _generateManhattanPath(corridorCenter, endEntryPoint);
          if (centerToEntry.length > 1) {
            path.addAll(centerToEntry.sublist(1));
          }
        }
      } else if (endCorridor != null && endEntryPoint != null) {
        // Different corridors - route through corridor centers
        final startCorridorCenter =
            getRoomCenter(startCorridor['coords'] as List<dynamic>? ?? []);
        final endCorridorCenter =
            getRoomCenter(endCorridor['coords'] as List<dynamic>? ?? []);
        final currentPoint = path.isNotEmpty ? path.last : startExitPoint;

        // Route to start corridor center
        if (_manhattanDistance(currentPoint, startCorridorCenter) > 5.0) {
          final toStartCenter =
              _generateManhattanPath(currentPoint, startCorridorCenter);
          if (toStartCenter.length > 1) {
            path.addAll(toStartCenter.sublist(1));
          }
        }

        // Route from start corridor center to end corridor center
        final corridorToCorridor =
            _generateManhattanPath(startCorridorCenter, endCorridorCenter);
        if (corridorToCorridor.length > 1) {
          path.addAll(corridorToCorridor.sublist(1));
        }

        // Route from end corridor center to end entry point
        if (endEntryPoint != end) {
          final centerToEntry =
              _generateManhattanPath(endCorridorCenter, endEntryPoint);
          if (centerToEntry.length > 1) {
            path.addAll(centerToEntry.sublist(1));
          }
        }
      }

      // Path from corridor exit to end
      if (endEntryPoint != null && endEntryPoint != end) {
        final corridorToEnd = _generateManhattanPath(endEntryPoint, end);
        if (corridorToEnd.length > 1) {
          path.addAll(corridorToEnd.sublist(1));
        }
      }
    } else {
      // No corridors found nearby, use direct Manhattan path
      final directPath = _generateManhattanPath(start, end);
      if (directPath.length > 1) {
        path.addAll(directPath.sublist(1));
      }
    }

    path.add(end);

    // Remove duplicate consecutive points
    return _removeDuplicatePoints(path);
  }

  /// Check if a point is inside a room (using ray casting algorithm)
  static bool _isPointInRoom(Offset point, List<dynamic> roomCoords) {
    if (roomCoords.length < 3) return false;

    int intersections = 0;
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

        // Ray casting: check if horizontal ray from point intersects edge
        if ((p1.dy > point.dy) != (p2.dy > point.dy)) {
          final xIntersect =
              (point.dy - p1.dy) * (p2.dx - p1.dx) / (p2.dy - p1.dy) + p1.dx;
          if (point.dx < xIntersect) {
            intersections++;
          }
        }
      }
    }

    return intersections % 2 ==
        1; // Odd number of intersections means point is inside
  }

  /// Generate a Manhattan path (only horizontal/vertical movements, right-angle corners)
  /// This ensures strictly right-angled paths with no diagonals
  static List<Offset> _generateManhattanPath(Offset start, Offset end) {
    final path = <Offset>[start];

    // Manhattan distance: move horizontally first, then vertically (or vice versa)
    // Strategy: move in the direction with larger difference first

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // If both movements are needed, create right angle
    if (dx.abs() > 0.1 && dy.abs() > 0.1) {
      // Determine which direction to move first based on larger distance
      if (dx.abs() > dy.abs()) {
        // Move horizontally first, then vertically
        path.add(Offset(end.dx, start.dy)); // Horizontal move
        path.add(end); // Vertical move
      } else {
        // Move vertically first, then horizontally
        path.add(Offset(start.dx, end.dy)); // Vertical move
        path.add(end); // Horizontal move
      }
    } else if (dx.abs() > 0.1) {
      // Only horizontal movement
      path.add(end);
    } else if (dy.abs() > 0.1) {
      // Only vertical movement
      path.add(end);
    }
    // If both are zero or very small, just return start point

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
      if ((current.dx - last.dx).abs() > 0.1 ||
          (current.dy - last.dy).abs() > 0.1) {
        cleaned.add(current);
      }
    }

    return cleaned;
  }

  /// Find the closest point on a room's perimeter to a given point
  static Offset _findClosestPointOnRoom(
      Offset point, List<dynamic> roomCoords) {
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
  static Offset _closestPointOnLineSegment(
      Offset point, Offset lineStart, Offset lineEnd) {
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

  /// Generate navigation instructions for same-floor navigation
  static List<String> _generateNavigationInstructions(
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
    List<Offset> path,
    bool isMultiLevel,
    List<Map<String, dynamic>>? staircases,
    List<Map<String, dynamic>>? lifts,
  ) {
    final instructions = <String>[];

    if (isMultiLevel) {
      return instructions; // Multi-level instructions handled separately
    }

    // Calculate approximate distance
    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += distance(path[i], path[i + 1]);
    }

    // Convert to approximate meters (assuming 1 pixel ≈ 0.1 meters, adjust based on your scale)
    final approximateMeters = (totalDistance * 0.1).round();

    instructions.add('📍 Starting from ${startRoom['id']}');
    instructions.add('🎯 Destination: ${endRoom['id']}');

    if (approximateMeters > 0) {
      instructions.add('📏 Approximate distance: ~$approximateMeters meters');
    }

    instructions.add('🚶 Follow the path through corridors');

    return instructions;
  }

  /// Generate instructions for multi-level navigation
  static List<String> _generateMultiLevelInstructions(
    Map<String, dynamic> startRoom,
    Map<String, dynamic> endRoom,
    Map<String, dynamic> verticalAccess,
    bool isLift,
  ) {
    final instructions = <String>[];
    final startFloor = startRoom['floor_no']?.toString();
    final endFloor = endRoom['floor_no']?.toString();

    instructions
        .add('📍 Starting from ${startRoom['id']} on Floor ${startFloor}');
    instructions.add('🎯 Destination: ${endRoom['id']} on Floor ${endFloor}');
    instructions.add('');

    if (isLift) {
      instructions.add(
          '🛗 Step 1: Navigate to ${verticalAccess['id']} (Elevator/Lift)');
      instructions.add(
          '   → Use the elevator to go from Floor ${startFloor} to Floor ${endFloor}');
    } else {
      instructions
          .add('🪜 Step 1: Navigate to ${verticalAccess['id']} (Staircase)');
      instructions.add(
          '   → Use the staircase to go from Floor ${startFloor} to Floor ${endFloor}');
    }

    instructions.add('');
    instructions.add(
        '🚶 Step 2: Once on Floor ${endFloor}, follow the path to ${endRoom['id']}');

    // Determine if going up or down
    try {
      final startFloorNum =
          int.parse(startFloor?.replaceAll(RegExp(r'[^0-9-]'), '') ?? '0');
      final endFloorNum =
          int.parse(endFloor?.replaceAll(RegExp(r'[^0-9-]'), '') ?? '0');

      if (endFloorNum > startFloorNum) {
        instructions.add('⬆️ Going UP ${endFloorNum - startFloorNum} floor(s)');
      } else if (endFloorNum < startFloorNum) {
        instructions
            .add('⬇️ Going DOWN ${startFloorNum - endFloorNum} floor(s)');
      }
    } catch (e) {
      // Floor numbers might not be numeric, skip direction hint
    }

    return instructions;
  }
}
