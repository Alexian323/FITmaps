/// Graph-based pathfinding using Dijkstra's algorithm
/// Integrates with the graph data (nodes.csv and edges.csv) for optimal routing

import 'package:flutter/services.dart';

/// Represents a graph edge with distance
class GraphEdge {
  final String room1;
  final String room2;
  final double distance;

  GraphEdge({
    required this.room1,
    required this.room2,
    required this.distance,
  });
}

/// Represents a node in the graph
class GraphNode {
  final String id;
  final String name;
  final String floor;

  GraphNode({
    required this.id,
    required this.name,
    required this.floor,
  });
}

/// Graph pathfinding result
class GraphPathResult {
  final List<String> path; // List of room IDs in format "ROOM__FLOOR"
  final double totalDistance; // Total distance in graph units
  final double estimatedTimeMinutes; // ETX - Estimated Time in minutes
  final int numberOfSteps;

  GraphPathResult({
    required this.path,
    required this.totalDistance,
    required this.estimatedTimeMinutes,
    required this.numberOfSteps,
  });
}

/// Graph-based pathfinder using Dijkstra's algorithm
class GraphPathfinder {
  // Graph as adjacency list: nodeId -> [(neighborId, distance), ...]
  final Map<String, List<(String, double)>> _graph = {};
  
  // Node metadata: nodeId -> GraphNode
  final Map<String, GraphNode> _nodes = {};
  
  bool _isLoaded = false;

  /// Load graph data from assets
  Future<void> loadGraph() async {
    if (_isLoaded) return;

    try {
      // Load nodes
      final nodesString = await rootBundle.loadString('graph/nodes.csv');
      final nodesLines = nodesString.split('\n');
      
      // Skip header
      for (int i = 1; i < nodesLines.length; i++) {
        final line = nodesLines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length >= 3) {
          final id = parts[0].trim();
          final name = parts[1].trim();
          final floor = parts[2].trim();
          
          _nodes[id] = GraphNode(id: id, name: name, floor: floor);
          _graph[id] = []; // Initialize adjacency list
        }
      }

      // Load edges
      final edgesString = await rootBundle.loadString('graph/edges.csv');
      final edgesLines = edgesString.split('\n');
      
      // Skip header
      for (int i = 1; i < edgesLines.length; i++) {
        final line = edgesLines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length >= 3) {
          final room1 = parts[0].trim();
          final room2 = parts[2].trim();
          final dist = double.tryParse(parts[1].trim()) ?? 0.0;
          
          if (dist > 0 && _graph.containsKey(room1) && _graph.containsKey(room2)) {
            // Undirected graph: add both directions
            _graph[room1]!.add((room2, dist));
            _graph[room2]!.add((room1, dist));
          }
        }
      }

      _isLoaded = true;
      print('Graph loaded: ${_nodes.length} nodes, ${_graph.values.fold<int>(0, (sum, list) => sum + list.length) ~/ 2} edges');
    } catch (e) {
      print('Error loading graph: $e');
      _isLoaded = false;
    }
  }

  /// Convert room ID and floor to graph node ID format
  /// Format: "ROOM__FLOOR" (e.g., "A109__+1")
  String _toGraphNodeId(String roomId, String floor) {
    // Normalize floor format: +1, +2, -1, -2, etc.
    String normalizedFloor = floor;
    if (!normalizedFloor.startsWith('+') && !normalizedFloor.startsWith('-')) {
      // If floor is just a number, add + prefix
      normalizedFloor = '+$normalizedFloor';
    }
    return '${roomId}__$normalizedFloor';
  }

  /// Find shortest path using Dijkstra's algorithm
  GraphPathResult? findShortestPath(
    String startRoomId,
    String startFloor,
    String endRoomId,
    String endFloor,
  ) {
    if (!_isLoaded) {
      print('Graph not loaded yet');
      return null;
    }

    final startNodeId = _toGraphNodeId(startRoomId, startFloor);
    final endNodeId = _toGraphNodeId(endRoomId, endFloor);

    if (!_graph.containsKey(startNodeId)) {
      print('Start node not found: $startNodeId');
      return null;
    }

    if (!_graph.containsKey(endNodeId)) {
      print('End node not found: $endNodeId');
      return null;
    }

    // Dijkstra's algorithm
    final distances = <String, double>{};
    final previous = <String, String?>{};
    final unvisited = <String>{};
    
    // Initialize distances
    for (final nodeId in _graph.keys) {
      distances[nodeId] = double.infinity;
      previous[nodeId] = null;
      unvisited.add(nodeId);
    }
    
    distances[startNodeId] = 0.0;

    // Priority queue simulation using a list (simpler than importing a heap)
    while (unvisited.isNotEmpty) {
      // Find unvisited node with smallest distance
      String? currentNode;
      double minDist = double.infinity;
      
      for (final node in unvisited) {
        final dist = distances[node]!;
        if (dist < minDist) {
          minDist = dist;
          currentNode = node;
        }
      }

      if (currentNode == null || minDist == double.infinity) {
        break; // No path found
      }

      if (currentNode == endNodeId) {
        break; // Reached destination
      }

      unvisited.remove(currentNode);

      // Update distances to neighbors
      for (final (neighbor, weight) in _graph[currentNode]!) {
        if (!unvisited.contains(neighbor)) continue;

        final alt = distances[currentNode]! + weight;
        if (alt < distances[neighbor]!) {
          distances[neighbor] = alt;
          previous[neighbor] = currentNode;
        }
      }
    }

    // Reconstruct path
    if (distances[endNodeId] == double.infinity) {
      print('No path found from $startNodeId to $endNodeId');
      return null;
    }

    final path = <String>[];
    String? current = endNodeId;
    
    while (current != null) {
      path.insert(0, current);
      current = previous[current];
    }

    if (path.isEmpty || path.first != startNodeId) {
      print('Path reconstruction failed');
      return null;
    }

    final totalDistance = distances[endNodeId]!;
    
    // Calculate ETX (Estimated Time in minutes)
    // Conversion: graph units to meters (based on test script: *20000)
    // Walking speed: ~1.4 m/s (5 km/h average walking speed)
    final distanceInMeters = totalDistance * 20000;
    final walkingSpeedMps = 1.4; // meters per second
    final timeInSeconds = distanceInMeters / walkingSpeedMps;
    final estimatedTimeMinutes = timeInSeconds / 60.0;

    return GraphPathResult(
      path: path,
      totalDistance: totalDistance,
      estimatedTimeMinutes: estimatedTimeMinutes,
      numberOfSteps: path.length - 1,
    );
  }

  /// Get node information by ID
  GraphNode? getNode(String nodeId) {
    return _nodes[nodeId];
  }

  /// Check if graph is loaded
  bool get isLoaded => _isLoaded;

  /// Get total number of nodes
  int get nodeCount => _nodes.length;
}

