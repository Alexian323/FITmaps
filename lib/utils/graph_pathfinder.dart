import 'package:flutter/services.dart';

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

class GraphPathResult {
  final List<String> path; // format: "ROOM__FLOOR"
  final double totalDistance;
  final double estimatedTimeMinutes;
  final int numberOfSteps;

  GraphPathResult({
    required this.path,
    required this.totalDistance,
    required this.estimatedTimeMinutes,
    required this.numberOfSteps,
  });
}

class GraphPathfinder {
  final Map<String, List<(String, double)>> _graph = {};
  final Map<String, GraphNode> _nodes = {};
  bool _isLoaded = false;

  Future<void> loadGraph() async {
    if (_isLoaded) return;

    try {
      final nodesString = await rootBundle.loadString('graph/nodes.csv');
      final nodesLines = nodesString.split('\n');
      
      for (int i = 1; i < nodesLines.length; i++) {
        final line = nodesLines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length >= 3) {
          final id = parts[0].trim();
          final name = parts[1].trim();
          final floor = parts[2].trim();
          
          _nodes[id] = GraphNode(id: id, name: name, floor: floor);
          _graph[id] = [];
        }
      }

      final edgesString = await rootBundle.loadString('graph/edges.csv');
      final edgesLines = edgesString.split('\n');
      
      for (int i = 1; i < edgesLines.length; i++) {
        final line = edgesLines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length >= 3) {
          final room1 = parts[0].trim();
          final room2 = parts[2].trim();
          final dist = double.tryParse(parts[1].trim()) ?? 0.0;
          
          if (dist > 0 && _graph.containsKey(room1) && _graph.containsKey(room2)) {
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

  String _toGraphNodeId(String roomId, String floor) {
    String normalizedFloor = floor;
    if (!normalizedFloor.startsWith('+') && !normalizedFloor.startsWith('-')) {
      normalizedFloor = '+$normalizedFloor';
    }
    return '${roomId}__$normalizedFloor';
  }

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

    final distances = <String, double>{};
    final previous = <String, String?>{};
    final unvisited = <String>{};
    
    for (final nodeId in _graph.keys) {
      distances[nodeId] = double.infinity;
      previous[nodeId] = null;
      unvisited.add(nodeId);
    }
    
    distances[startNodeId] = 0.0;

    while (unvisited.isNotEmpty) {
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
        break;
      }

      if (currentNode == endNodeId) {
        break;
      }

      unvisited.remove(currentNode);

      for (final (neighbor, weight) in _graph[currentNode]!) {
        if (!unvisited.contains(neighbor)) continue;

        final alt = distances[currentNode]! + weight;
        if (alt < distances[neighbor]!) {
          distances[neighbor] = alt;
          previous[neighbor] = currentNode;
        }
      }
    }
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
    
    // Convert to meters and calculate time (20000 is the scale factor)
    final distanceInMeters = totalDistance * 20000;
    final walkingSpeedMps = 1.4;
    final timeInSeconds = distanceInMeters / walkingSpeedMps;
    final estimatedTimeMinutes = timeInSeconds / 60.0;

    return GraphPathResult(
      path: path,
      totalDistance: totalDistance,
      estimatedTimeMinutes: estimatedTimeMinutes,
      numberOfSteps: path.length - 1,
    );
  }

  GraphNode? getNode(String nodeId) {
    return _nodes[nodeId];
  }

  bool get isLoaded => _isLoaded;

  int get nodeCount => _nodes.length;
}

