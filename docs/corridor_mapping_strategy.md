# Corridor Mapping Strategy

## Current State

### What We Have
- **29+ corridors** identified by title containing "corridor"
- Each corridor has:
  - Polygon coordinates (like rooms)
  - GPS coordinates
  - Floor number
  - Room ID

### Current Limitations
- **No connectivity information**: We don't know which corridors connect to each other
- **No room-to-corridor mapping**: We don't know which rooms connect to which corridors
- **Simple proximity-based routing**: Just finds nearest corridor, doesn't understand corridor network
- **No optimal pathfinding**: Can't find shortest path through corridor network

## Mapping Strategy Options

### Option 1: Geometric Analysis (Recommended for Start)

**Approach**: Analyze corridor and room polygons to determine connections geometrically.

#### A. Corridor-to-Corridor Connections

**Method**: Two corridors are connected if:
1. **Edge adjacency**: Their polygons share an edge or are very close (< threshold)
2. **Overlap detection**: Their bounding boxes overlap significantly
3. **Proximity**: Centers are close and corridors are aligned

**Algorithm**:
```dart
// For each corridor pair on same floor:
1. Calculate bounding boxes
2. Check if edges are close (< 20 pixels)
3. Check if corridors are aligned (horizontal or vertical)
4. If both true → corridors are connected
```

**Advantages**:
- Automatic, no manual data entry
- Works with existing coordinate data
- Can be computed once and cached

**Challenges**:
- May miss some connections if corridors are close but not touching
- Need to handle threshold tuning

#### B. Room-to-Corridor Connections

**Method**: A room connects to a corridor if:
1. **Edge adjacency**: Room polygon edge is close to corridor polygon edge
2. **Proximity**: Room center is within threshold distance of corridor edge
3. **Alignment**: Room door/entrance aligns with corridor

**Algorithm**:
```dart
// For each room on same floor as corridor:
1. Find closest point on room perimeter to corridor
2. Find closest point on corridor perimeter to room
3. If Manhattan distance < threshold (e.g., 30 pixels) → connected
4. Store connection point (where room meets corridor)
```

**Advantages**:
- Automatic detection
- Provides connection points for routing
- Works with existing data

**Challenges**:
- May connect rooms to wrong corridors if multiple are nearby
- Need to handle rooms that don't connect to corridors (isolated)

### Option 2: Graph-Based Network

**Approach**: Build a graph where:
- **Nodes**: Corridors, rooms, intersections
- **Edges**: Connections between nodes
- **Weights**: Manhattan distances

**Structure**:
```dart
class CorridorNetwork {
  Map<String, CorridorNode> corridors;  // corridor_id -> node
  Map<String, List<String>> connections; // corridor_id -> [connected_corridor_ids]
  Map<String, List<String>> roomConnections; // room_id -> [connected_corridor_ids]
  Map<String, Offset> connectionPoints; // connection_id -> point
}
```

**Pathfinding**:
- Use A* or Dijkstra's algorithm
- Find optimal path through corridor network
- Route: Room → Corridor → Corridor → ... → Corridor → Room

### Option 3: Hybrid Approach (Best)

**Combine**:
1. **Geometric analysis** to build initial network
2. **Manual refinement** for critical connections
3. **Graph algorithms** for optimal routing

## Implementation Plan

### Phase 1: Corridor Identification & Analysis

1. **Extract all corridors**:
   - Filter rooms with "corridor" in title
   - Group by floor
   - Store corridor metadata (ID, center, bounds, polygon)

2. **Analyze corridor properties**:
   - Orientation (horizontal/vertical/mixed)
   - Length and width
   - Position relative to building

### Phase 2: Connection Detection

1. **Corridor-to-Corridor**:
   ```dart
   // For each floor:
   for (corridor1 in corridors) {
     for (corridor2 in corridors) {
       if (corridor1 != corridor2) {
         if (areCorridorsConnected(corridor1, corridor2)) {
           // Add edge to graph
         }
       }
     }
   }
   ```

2. **Room-to-Corridor**:
   ```dart
   // For each room:
   for (room in rooms) {
     for (corridor in corridors_on_same_floor) {
       if (isRoomConnectedToCorridor(room, corridor)) {
         // Store connection
       }
     }
   }
   ```

### Phase 3: Network Graph Construction

1. **Build graph structure**:
   - Nodes: corridors + rooms
   - Edges: connections with weights (Manhattan distance)
   - Store connection points

2. **Validate network**:
   - Check for isolated corridors
   - Verify connectivity
   - Identify main corridors vs. branches

### Phase 4: Pathfinding Integration

1. **A* Algorithm**:
   - Start: Room or corridor
   - Goal: Room or corridor
   - Heuristic: Manhattan distance
   - Cost: Manhattan distance through corridors

2. **Path generation**:
   - Convert graph path to coordinate waypoints
   - Use Manhattan distance for segments
   - Route through corridor centers/edges

## Data Structure Proposal

```dart
class CorridorNode {
  final String id;
  final String title;
  final String floorNo;
  final List<Offset> polygon;
  final Offset center;
  final Rect bounds;
  final CorridorOrientation orientation;
}

enum CorridorOrientation {
  horizontal,  // Mainly horizontal
  vertical,    // Mainly vertical
  mixed,       // Both directions
}

class CorridorConnection {
  final String fromCorridorId;
  final String toCorridorId;
  final Offset connectionPoint;  // Where they meet
  final double distance;
}

class RoomCorridorConnection {
  final String roomId;
  final String corridorId;
  final Offset roomConnectionPoint;  // Where room meets corridor
  final Offset corridorConnectionPoint;  // Where corridor meets room
}

class CorridorNetwork {
  final Map<String, CorridorNode> corridors;
  final Map<String, List<CorridorConnection>> corridorConnections;
  final Map<String, List<RoomCorridorConnection>> roomConnections;
  final Map<String, List<String>> adjacencyList;  // corridor_id -> [connected_ids]
}
```

## Geometric Analysis Functions Needed

### 1. Check if corridors are adjacent
```dart
bool areCorridorsConnected(CorridorNode c1, CorridorNode c2) {
  // Check if edges are close
  // Check if aligned (horizontal/vertical)
  // Return true if connected
}
```

### 2. Check if room connects to corridor
```dart
bool isRoomConnectedToCorridor(Room room, CorridorNode corridor) {
  // Find closest points
  // Check distance threshold
  // Return true if connected
}
```

### 3. Find connection point
```dart
Offset findConnectionPoint(Polygon1, Polygon2) {
  // Find closest edge points
  // Return midpoint or closest point
}
```

## Benefits of Proper Corridor Mapping

1. **Optimal routing**: Find shortest path through corridor network
2. **Realistic paths**: Routes follow actual building layout
3. **Multi-corridor routing**: Navigate through complex corridor networks
4. **Better UX**: Paths look natural and follow corridors
5. **Scalable**: Can add more sophisticated routing later

## Challenges & Solutions

### Challenge 1: Corridor Detection Accuracy
- **Problem**: May miss some connections or create false positives
- **Solution**: Use conservative thresholds, allow manual override

### Challenge 2: Performance
- **Problem**: Checking all corridor pairs is O(n²)
- **Solution**: 
  - Spatial indexing (grid/quadtree)
  - Only check nearby corridors
  - Cache results

### Challenge 3: Complex Corridor Shapes
- **Problem**: Some corridors are L-shaped or irregular
- **Solution**: 
  - Handle multiple segments
  - Use corridor center for routing
  - Consider corridor orientation

## Recommended Implementation Order

1. **Step 1**: Create corridor analysis script (Python)
   - Extract all corridors
   - Analyze properties
   - Generate corridor network JSON

2. **Step 2**: Build connection detection
   - Corridor-to-corridor adjacency
   - Room-to-corridor connections
   - Store in structured format

3. **Step 3**: Create corridor network data file
   - JSON structure with connections
   - Load in Flutter app
   - Cache for performance

4. **Step 4**: Implement graph pathfinding
   - A* algorithm
   - Convert graph path to coordinates
   - Integrate with existing routing

5. **Step 5**: Test and refine
   - Test on various routes
   - Adjust thresholds
   - Handle edge cases

## Cost-Benefit Analysis

### Effort Required
- **Medium**: 2-3 days of development
- **Complexity**: Moderate (geometric algorithms + graph theory)

### Benefits
- **High**: Much better routing quality
- **User Experience**: Significantly improved
- **Maintainability**: Easier to extend later

### Recommendation
**Yes, it's worth it!** Proper corridor mapping will make navigation much more realistic and useful.

## Next Steps

1. Create Python script to analyze corridors and build network
2. Generate corridor network JSON file
3. Load network in Flutter app
4. Implement A* pathfinding
5. Test and refine

Would you like me to start implementing the corridor mapping system?


