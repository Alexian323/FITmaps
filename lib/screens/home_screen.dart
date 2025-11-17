import 'package:flutter/material.dart';
import 'package:fitmaps/config/theme.dart';
import 'package:fitmaps/screens/profile_screen.dart';
import 'package:fitmaps/screens/splash_screen.dart';
import 'package:fitmaps/utils/map_path.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _interactiveController = TransformationController();
  final _mapViewKey = GlobalKey();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  VoidCallback? _zoomAnimationListener;
  String? _selectedFloor;
  bool _isSearching = false;
  List<Map<String, dynamic>> _roomData = [];
  List<Map<String, dynamic>> _allRoomsData = []; // All rooms from all floors
  List<Map<String, dynamic>> _highlightedRooms = [];
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;

  // Drawer state
  bool _isDrawerOpen = false;
  Map<String, dynamic>? _selectedRoom;
  bool _isDrawerExpanded = false;
  List<String> _roomPhotos = [];
  bool _isLoadingPhotos = false;

  // Path drawing state
  List<MapPath> _navigationPaths = [];
  UserTrail _userTrail = UserTrail();
  
  // Current location (for testing - A101 is the default source)
  Map<String, dynamic>? _currentLocationRoom;

  @override
  void initState() {
    super.initState();
    _selectedFloor = '1ˢᵗ Floor';

    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Initialize zoom animation controller
    _zoomAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _loadRoomData();
  }

  double _mapMinX = 0;
  double _mapMaxX = 640;
  double _mapMinY = 0;
  double _mapMaxY = 920;

  Future<void> _loadRoomData() async {
    try {
      // Load room data from merged JSON file (contains both coords and gps_coords)
      // Falls back to original file if merged file doesn't exist for backward compatibility
      String jsonString;
      try {
        jsonString = await DefaultAssetBundle.of(context)
            .loadString('data/parsed_data/maps_data_merged.json');
      } catch (e) {
        // Fallback to original file if merged doesn't exist
        print('Merged file not found, using original maps_data.json');
        jsonString = await DefaultAssetBundle.of(context)
            .loadString('data/parsed_data/maps_data.json');
      }
      
      final List<dynamic> allRooms = json.decode(jsonString);

      // Load all rooms from all floors
      final allRoomsList = <Map<String, dynamic>>[];
      for (final roomEntry in allRooms) {
        if (roomEntry is Map<String, dynamic>) {
          for (final entry in roomEntry.entries) {
            final roomId = entry.key;
            final roomData = entry.value as Map<String, dynamic>;
            allRoomsList.add({
              'id': roomId,
              'title': roomData['title'] ?? '',
              'coords': roomData['coords'] ?? [], // Pixel coordinates for rendering
              'gps_coords': roomData['gps_coords'], // GPS coordinates (optional, for location tracking)
              'room_tag': roomData['room_tag'] ?? '',
              'onclick': roomData['onclick'] ?? '',
              'floor_no': roomData['floor_no'] ?? '',
            });
          }
        }
      }

      // Store all rooms data
      setState(() {
        _allRoomsData = allRoomsList;
      });

      print('Loaded ${_allRoomsData.length} total rooms from all floors');

      // Set A101 as the default current location (for testing)
      // Do this after rooms are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setCurrentLocation('A101');
      });

      // Load current floor data
      _loadCurrentFloorData();
    } catch (e) {
      print('Error loading room data: $e');
      setState(() {
        _roomData = [];
        _allRoomsData = [];
      });
    }
  }

  void _loadCurrentFloorData() {
    if (_allRoomsData.isEmpty) return;

    // Get current floor identifier
    String currentFloor;
    switch (_selectedFloor) {
      case '1ˢᵗ Floor':
        currentFloor = '+1';
        break;
      case '2ⁿᵈ Floor':
        currentFloor = '+2';
        break;
      case '3ʳᵈ Floor':
        currentFloor = '+3';
        break;
      case '-1ˢᵗ Floor':
        currentFloor = '-1';
        break;
      case '-2ⁿᵈ Floor':
        currentFloor = '-2';
        break;
      default:
        currentFloor = '+1';
    }

    // Filter rooms for current floor
    final floorRooms = _allRoomsData
        .where((room) => room['floor_no']?.toString() == currentFloor)
        .toList();
    
    // Ensure current location room is always highlighted if on current floor
    if (_currentLocationRoom != null) {
      final currentLocationFloor = _currentLocationRoom!['floor_no']?.toString();
      if (currentLocationFloor == currentFloor) {
        // Current location is on this floor - ensure it's visible
        if (!_highlightedRooms.any((r) => r['id'] == _currentLocationRoom!['id'])) {
          _highlightedRooms.add(_currentLocationRoom!);
        }
      }
    }

    // Calculate bounds for current floor
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final room in floorRooms) {
      final coords = room['coords'] as List<dynamic>;
      for (final coord in coords) {
        if (coord is List<dynamic> && coord.length >= 2) {
          final x = (coord[0] as num).toDouble();
          final y = (coord[1] as num).toDouble();

          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
      }
    }

    // Set map bounds with some padding
    setState(() {
      _roomData = floorRooms;
      _mapMinX = minX - 50; // Add padding
      _mapMaxX = maxX + 50; // Add padding
      _mapMinY = minY - 50; // Add padding
      _mapMaxY = maxY + 50; // Add padding
    });

    print('Loaded ${_roomData.length} rooms for floor $currentFloor');
    print(
        'Map bounds: X(${_mapMinX.toStringAsFixed(1)} - ${_mapMaxX.toStringAsFixed(1)}), Y(${_mapMinY.toStringAsFixed(1)} - ${_mapMaxY.toStringAsFixed(1)})');
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();

      if (_searchQuery.isEmpty) {
        _highlightedRooms = [];
        _resetZoom();
        _pulseController.stop();
      } else {
        // Search across all floors
        final allMatchingRooms = _allRoomsData.where((room) {
          final roomId = room['id'].toString().toLowerCase();
          final title = room['title'].toString().toLowerCase();
          return roomId.contains(_searchQuery) || title.contains(_searchQuery);
        }).toList();

        if (allMatchingRooms.isNotEmpty) {
          // Check if any matching rooms are on the current floor
          final currentFloorRooms = allMatchingRooms
              .where((room) =>
                  room['floor_no']?.toString() == _getCurrentFloorId())
              .toList();

          if (currentFloorRooms.isNotEmpty) {
            // Room found on current floor - highlight matching rooms
            // Also include current location room if it exists and is on this floor
            _highlightedRooms = List.from(currentFloorRooms);
            if (_currentLocationRoom != null) {
              final currentFloorId = _currentLocationRoom!['floor_no']?.toString();
              if (currentFloorId == _getCurrentFloorId()) {
                // Add current location if not already in highlighted rooms
                if (!_highlightedRooms.any((r) => r['id'] == _currentLocationRoom!['id'])) {
                  _highlightedRooms.add(_currentLocationRoom!);
                }
              }
            }
            _zoomToRooms(_highlightedRooms);
            _pulseController.repeat(reverse: true);
          } else {
            // Room found on different floor - switch to that floor
            final firstMatch = allMatchingRooms.first;
            final targetFloor = firstMatch['floor_no']?.toString();
            _switchToFloor(targetFloor);

            // Filter to show only matching rooms on the target floor
            final targetFloorRooms = allMatchingRooms
                .where((room) => room['floor_no']?.toString() == targetFloor)
                .toList();
            _highlightedRooms = List.from(targetFloorRooms);
            _zoomToRooms(_highlightedRooms);
            _pulseController.repeat(reverse: true);
          }
        } else {
          // No matches found
          _highlightedRooms = [];
        }
      }
    });
  }

  String _getCurrentFloorId() {
    switch (_selectedFloor) {
      case '1ˢᵗ Floor':
        return '+1';
      case '2ⁿᵈ Floor':
        return '+2';
      case '3ʳᵈ Floor':
        return '+3';
      case '-1ˢᵗ Floor':
        return '-1';
      case '-2ⁿᵈ Floor':
        return '-2';
      default:
        return '+1';
    }
  }

  void _switchToFloor(String? floorId) {
    String? targetFloorName;
    switch (floorId) {
      case '+1':
        targetFloorName = '1ˢᵗ Floor';
        break;
      case '+2':
        targetFloorName = '2ⁿᵈ Floor';
        break;
      case '+3':
        targetFloorName = '3ʳᵈ Floor';
        break;
      case '-1':
        targetFloorName = '-1ˢᵗ Floor';
        break;
      case '-2':
        targetFloorName = '-2ⁿᵈ Floor';
        break;
    }

    if (targetFloorName != null && targetFloorName != _selectedFloor) {
      setState(() {
        _selectedFloor = targetFloorName;
      });
      _loadCurrentFloorData();
    }
  }

  /// Set navigation path between two rooms
  /// 
  /// Example usage:
  /// ```dart
  /// final startRoom = getRoomById('D006');
  /// final endRoom = getRoomById('D0201');
  /// if (startRoom != null && endRoom != null) {
  ///   setNavigationPath(startRoom, endRoom);
  /// }
  /// ```
  void setNavigationPath(Map<String, dynamic> startRoom, Map<String, dynamic> endRoom) {
    // Use corridor-aware routing for better paths
    final pathPoints = PathUtils.generatePathThroughCorridors(
      startRoom,
      endRoom,
      _allRoomsData,
    );
    setState(() {
      _navigationPaths = [
        MapPath.navigation(points: pathPoints),
      ];
    });
  }

  /// Set navigation path with waypoints
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

  /// Clear all navigation paths
  void clearNavigationPaths() {
    setState(() {
      _navigationPaths = [];
    });
  }

  /// Update user trail with a new position (for GPS tracking)
  void updateUserTrail(Offset position) {
    _userTrail.addPosition(position);
    setState(() {}); // Trigger repaint
  }

  /// Clear user trail
  void clearUserTrail() {
    _userTrail.clear();
    setState(() {});
  }

  /// Get room by ID from all rooms data
  Map<String, dynamic>? getRoomById(String roomId) {
    try {
      return _allRoomsData.firstWhere((room) => room['id'] == roomId);
    } catch (e) {
      return null;
    }
  }

  /// Set the current location room (for testing)
  void _setCurrentLocation(String roomId) {
    final room = getRoomById(roomId);
    if (room != null) {
      setState(() {
        _currentLocationRoom = room;
      });
      print('Current location set to: $roomId');
      
      // Switch to the floor where the current location is
      final floorNo = room['floor_no']?.toString();
      if (floorNo != null) {
        _switchToFloor(floorNo);
      }
    } else {
      print('Room $roomId not found for current location');
    }
  }

  /// Navigate to a destination room from current location
  void _navigateToRoom(Map<String, dynamic> destinationRoom) {
    if (_currentLocationRoom == null) {
      // If no current location, set A101 as default
      _setCurrentLocation('A101');
    }
    
    if (_currentLocationRoom != null) {
      final startRoom = _currentLocationRoom!;
      final endRoom = destinationRoom;
      
      // Check if rooms are on the same floor
      final startFloor = startRoom['floor_no']?.toString();
      final endFloor = endRoom['floor_no']?.toString();
      
      if (startFloor == endFloor) {
        // Same floor - use corridor-aware routing
        final pathPoints = PathUtils.generatePathThroughCorridors(
          startRoom,
          endRoom,
          _allRoomsData,
        );
        setState(() {
          _navigationPaths = [
            MapPath.navigation(points: pathPoints),
          ];
        });
        print('Navigation path created from ${startRoom['id']} to ${endRoom['id']} through corridors');
      } else {
        // Different floors - switch to destination floor and draw path
        _switchToFloor(endFloor);
        // Wait for floor switch to complete, then draw path
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pathPoints = PathUtils.generatePathThroughCorridors(
            startRoom,
            endRoom,
            _allRoomsData,
          );
          setState(() {
            _navigationPaths = [
              MapPath.navigation(points: pathPoints),
            ];
          });
          print('Navigation path created from ${startRoom['id']} to ${endRoom['id']} (cross-floor)');
        });
      }
      
      // Zoom to show both rooms and path
      _zoomToRooms([startRoom, endRoom]);
    }
  }

  /// Clear navigation path
  void _clearNavigation() {
    clearNavigationPaths();
    print('Navigation path cleared');
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final suggestions = _allRoomsData
        .where((room) {
          final roomId = room['id'].toString().toLowerCase();
          final title = room['title'].toString().toLowerCase();
          final searchQuery = query.toLowerCase();

          return roomId.contains(searchQuery) || title.contains(searchQuery);
        })
        .take(10)
        .toList(); // Limit to 10 suggestions for better UX

    setState(() {
      _searchSuggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  Widget _buildSuggestionItem(Map<String, dynamic> room) {
    final roomId = room['id'] as String;
    final title = room['title'] as String;
    final floorNo = room['floor_no'] as String;

    // Format floor display name
    String floorDisplay;
    switch (floorNo) {
      case '+1':
        floorDisplay = '1st Floor';
        break;
      case '+2':
        floorDisplay = '2nd Floor';
        break;
      case '+3':
        floorDisplay = '3rd Floor';
        break;
      case '-1':
        floorDisplay = '-1st Floor';
        break;
      case '-2':
        floorDisplay = '-2nd Floor';
        break;
      default:
        floorDisplay = '$floorNo Floor';
    }

    return InkWell(
      onTap: () {
        _searchController.text = roomId;
        setState(() {
          _showSuggestions = false;
          _isSearching = true;
        });
        _performSearch(roomId);
        
        // Automatically draw navigation path when clicking on search suggestion
        _navigateToRoom(room);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.room,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomId,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (title.isNotEmpty && title != roomId)
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                floorDisplay,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _zoomToRooms(List<Map<String, dynamic>> rooms) {
    if (rooms.isEmpty) return;

    // Wait for next frame to ensure viewport size is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get viewport size using MediaQuery
      final mediaQuery = MediaQuery.of(this.context);
      final screenWidth = mediaQuery.size.width;
      final screenHeight = mediaQuery.size.height;
      
      // Account for top padding and bottom navigation
      final topPadding = mediaQuery.padding.top + 120;
      final bottomPadding = 80;
      final viewportWidth = screenWidth;
      final viewportHeight = screenHeight - topPadding - bottomPadding;

      // Calculate bounds of highlighted rooms
      double minX = double.infinity;
      double maxX = double.negativeInfinity;
      double minY = double.infinity;
      double maxY = double.negativeInfinity;

      for (final room in rooms) {
        final coords = room['coords'] as List<dynamic>;
        for (final coord in coords) {
          if (coord is List<dynamic> && coord.length >= 2) {
            final x = (coord[0] as num).toDouble();
            final y = (coord[1] as num).toDouble();

            minX = math.min(minX, x);
            maxX = math.max(maxX, x);
            minY = math.min(minY, y);
            maxY = math.max(maxY, y);
          }
        }
      }

      // Calculate center point of highlighted rooms (in map coordinates)
      final centerX = (minX + maxX) / 2;
      final centerY = (minY + maxY) / 2;

      // Calculate room bounds with padding (more padding for better view)
      final roomWidth = maxX - minX + 300; // Add more padding
      final roomHeight = maxY - minY + 300; // Add more padding

      // Get the current map bounds
      final mapWidth = _mapMaxX - _mapMinX;
      final mapHeight = _mapMaxY - _mapMinY;

      // Calculate scale to fit the highlighted rooms (zoom in but not too close)
      final scaleX = mapWidth / roomWidth;
      final scaleY = mapHeight / roomHeight;
      final targetScale = math.min(math.min(scaleX, scaleY), 1.5); // Cap at 1.5x zoom (not too close)

      // Get the actual content size from the map (as rendered in SizedBox)
      // This is calculated in _buildFullSizeMap and matches the aspect ratio
      final mapAspectRatio = mapWidth / mapHeight;
      double actualContentWidth = viewportWidth;
      double actualContentHeight = viewportWidth / mapAspectRatio;
      
      if (actualContentHeight > viewportHeight) {
        actualContentHeight = viewportHeight;
        actualContentWidth = viewportHeight * mapAspectRatio;
      }

      // Convert room center from map coordinates to content pixel coordinates
      // Map coordinates are in the range [_mapMinX, _mapMaxX] x [_mapMinY, _mapMaxY]
      // Content coordinates are in the range [0, actualContentWidth] x [0, actualContentHeight]
      final normalizedX = (centerX - _mapMinX) / mapWidth;
      final normalizedY = (centerY - _mapMinY) / mapHeight;
      
      // Convert to content pixel coordinates (relative to content's top-left)
      final contentPixelX = normalizedX * actualContentWidth;
      final contentPixelY = normalizedY * actualContentHeight;

      // In InteractiveViewer, transformations are relative to the child's center
      // The content is centered in the viewport, so we need to work in content-centered coordinates
      // Content center is at (actualContentWidth/2, actualContentHeight/2)
      final contentCenterX = actualContentWidth / 2;
      final contentCenterY = actualContentHeight / 2;

      // Calculate position relative to content center (where origin is for InteractiveViewer)
      final relativeX = contentPixelX - contentCenterX;
      final relativeY = contentPixelY - contentCenterY;

      // To center the room: after transformation, the room center should be at (0, 0)
      // Transformation: scale * point + translation = 0
      // So: translation = -scale * point
      final translationX = -targetScale * relativeX;
      final translationY = -targetScale * relativeY;

      // Create transformation matrix: scale first, then translate
      final targetMatrix = Matrix4.identity()
        ..scale(targetScale)
        ..translate(translationX / targetScale, translationY / targetScale);

      // Get current matrix for smooth animation
      final startMatrix = _interactiveController.value;

      // Create smooth animation
      _zoomAnimation = Matrix4Tween(
        begin: startMatrix,
        end: targetMatrix,
      ).animate(CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutCubic,
      ));

      // Listen to animation and update controller
      _zoomAnimationController.reset();
      if (_zoomAnimationListener != null && _zoomAnimation != null) {
        _zoomAnimation!.removeListener(_zoomAnimationListener!);
      }
      _zoomAnimationListener = () {
        _interactiveController.value = _zoomAnimation!.value;
      };
      _zoomAnimation!.addListener(_zoomAnimationListener!);

      // Start animation
      _zoomAnimationController.forward();
    });
  }

  void _zoomToRoom(Map<String, dynamic> room) {
    final coords = room['coords'] as List<dynamic>;
    if (coords.isEmpty) return;

    // Wait for next frame to ensure viewport size is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get viewport size using MediaQuery
      final mediaQuery = MediaQuery.of(this.context);
      final screenWidth = mediaQuery.size.width;
      final screenHeight = mediaQuery.size.height;
      
      // Account for top padding and bottom navigation
      final topPadding = mediaQuery.padding.top + 120;
      final bottomPadding = 80;
      final viewportWidth = screenWidth;
      final viewportHeight = screenHeight - topPadding - bottomPadding;

      // Calculate room center
      double centerX = 0, centerY = 0;
      for (final coord in coords) {
        if (coord is List<dynamic> && coord.length >= 2) {
          centerX += (coord[0] as num).toDouble();
          centerY += (coord[1] as num).toDouble();
        }
      }
      centerX /= coords.length;
      centerY /= coords.length;

      // Get the current map bounds
      final mapWidth = _mapMaxX - _mapMinX;
      final mapHeight = _mapMaxY - _mapMinY;

      // Calculate room bounds with padding for better view
      double minX = double.infinity;
      double maxX = double.negativeInfinity;
      double minY = double.infinity;
      double maxY = double.negativeInfinity;

      for (final coord in coords) {
        if (coord is List<dynamic> && coord.length >= 2) {
          final x = (coord[0] as num).toDouble();
          final y = (coord[1] as num).toDouble();
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
      }

      final roomWidth = maxX - minX + 400; // Generous padding
      final roomHeight = maxY - minY + 400; // Generous padding

      // Calculate scale (zoom in but not too close)
      final scaleX = mapWidth / roomWidth;
      final scaleY = mapHeight / roomHeight;
      final targetScale = math.min(math.min(scaleX, scaleY), 1.5); // Cap at 1.5x zoom

      // Get the actual content size from the map (as rendered in SizedBox)
      // This is calculated in _buildFullSizeMap and matches the aspect ratio
      final mapAspectRatio = mapWidth / mapHeight;
      double actualContentWidth = viewportWidth;
      double actualContentHeight = viewportWidth / mapAspectRatio;
      
      if (actualContentHeight > viewportHeight) {
        actualContentHeight = viewportHeight;
        actualContentWidth = viewportHeight * mapAspectRatio;
      }

      // Convert room center from map coordinates to content pixel coordinates
      // Map coordinates are in the range [_mapMinX, _mapMaxX] x [_mapMinY, _mapMaxY]
      // Content coordinates are in the range [0, actualContentWidth] x [0, actualContentHeight]
      final normalizedX = (centerX - _mapMinX) / mapWidth;
      final normalizedY = (centerY - _mapMinY) / mapHeight;
      
      // Convert to content pixel coordinates (relative to content's top-left)
      final contentPixelX = normalizedX * actualContentWidth;
      final contentPixelY = normalizedY * actualContentHeight;

      // In InteractiveViewer, transformations are relative to the child's center
      // The content is centered in the viewport, so we need to work in content-centered coordinates
      // Content center is at (actualContentWidth/2, actualContentHeight/2)
      final contentCenterX = actualContentWidth / 2;
      final contentCenterY = actualContentHeight / 2;

      // Calculate position relative to content center (where origin is for InteractiveViewer)
      final relativeX = contentPixelX - contentCenterX;
      final relativeY = contentPixelY - contentCenterY;

      // To center the room: after transformation, the room center should be at (0, 0)
      // Transformation: scale * point + translation = 0
      // So: translation = -scale * point
      final translationX = -targetScale * relativeX;
      final translationY = -targetScale * relativeY;

      // Create transformation matrix: scale first, then translate
      final targetMatrix = Matrix4.identity()
        ..scale(targetScale)
        ..translate(translationX / targetScale, translationY / targetScale);

      // Get current matrix for smooth animation
      final startMatrix = _interactiveController.value;

      // Create smooth animation
      _zoomAnimation = Matrix4Tween(
        begin: startMatrix,
        end: targetMatrix,
      ).animate(CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutCubic,
      ));

      // Listen to animation and update controller
      _zoomAnimationController.reset();
      if (_zoomAnimationListener != null && _zoomAnimation != null) {
        _zoomAnimation!.removeListener(_zoomAnimationListener!);
      }
      _zoomAnimationListener = () {
        _interactiveController.value = _zoomAnimation!.value;
      };
      _zoomAnimation!.addListener(_zoomAnimationListener!);

      // Start animation
      _zoomAnimationController.forward();
    });
  }

  void _resetZoom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _interactiveController.value = Matrix4.identity();
    });
  }

  void _handleMapTap(Offset tapPosition) {
    print('Tap detected at: $tapPosition');
    print('Map bounds: X($_mapMinX - $_mapMaxX), Y($_mapMinY - $_mapMaxY)');

    // Get the actual canvas size (approximate from the map container)
    final canvasSize = Size(400, 600); // This should match the actual map size

    // Check if tap is on any highlighted room marker
    for (final room in _highlightedRooms) {
      final coords = room['coords'] as List<dynamic>;
      if (coords.isEmpty) continue;

      // Calculate room center using the same logic as the painter
      double centerX = 0, centerY = 0;
      for (final coord in coords) {
        final coordList = coord as List<dynamic>;
        if (coordList.length >= 2) {
          final x = (coordList[0] as num).toDouble();
          final y = (coordList[1] as num).toDouble();

          // Map coordinates to canvas space (same as painter)
          final mappedX =
              ((x - _mapMinX) / (_mapMaxX - _mapMinX)) * canvasSize.width;
          final mappedY =
              ((y - _mapMinY) / (_mapMaxY - _mapMinY)) * canvasSize.height;

          centerX += mappedX;
          centerY += mappedY;
        }
      }
      centerX /= coords.length;
      centerY /= coords.length;

      // Calculate marker size (same logic as in painter)
      const baseMarkerSize = 20.0;
      final zoomAdjustedSize = baseMarkerSize /
          _interactiveController.value.getMaxScaleOnAxis().clamp(0.5, 3.0);
      final markerSize = zoomAdjustedSize * _pulseAnimation.value;

      print(
          'Room ${room['id']}: center=($centerX, $centerY), markerSize=$markerSize');

      // Check if tap is within marker bounds - use much larger clickable area
      final distance = (tapPosition - Offset(centerX, centerY)).distance;
      const clickableRadius =
          80.0; // Very large clickable area for easy clicking
      print(
          'Distance to ${room['id']}: $distance (threshold: $clickableRadius)');

      if (distance <= clickableRadius) {
        print('Marker clicked: ${room['id']}');
        _onMarkerClicked(room);
        return;
      }
    }

    print('No marker clicked');
  }

  void _onMarkerClicked(Map<String, dynamic> room) {
    setState(() {
      _selectedRoom = room;
      _isDrawerOpen = true;
      _isDrawerExpanded = false;
      _roomPhotos = [];
      _isLoadingPhotos = true;
    });

    // Smoothly zoom to the selected room
    _zoomToRoom(room);

    // Load room photos
    _loadRoomPhotos(room);
  }

  void _loadRoomPhotos(Map<String, dynamic> room) async {
    try {
      final roomId = room['id'] as String;
      final roomUrl = room['onclick'] as String?;

      print('Loading photos for room $roomId from: $roomUrl');

      if (roomUrl == null || roomUrl.isEmpty) {
        print('No room URL available for $roomId');
        setState(() {
          _roomPhotos = [];
          _isLoadingPhotos = false;
        });
        return;
      }

      // Extract photo URLs from the FIT website
      final photoUrls = await _extractRoomPhotos(roomUrl);

      setState(() {
        _roomPhotos = photoUrls;
        _isLoadingPhotos = false;
      });

      if (photoUrls.isNotEmpty) {
        print('Found ${photoUrls.length} photo(s) for room $roomId');
      } else {
        print('No photos found for room $roomId');
      }
    } catch (e) {
      print('Error loading photos: $e');
      setState(() {
        _roomPhotos = [];
        _isLoadingPhotos = false;
      });
    }
  }

  /// Extract room photo URLs from the FIT website HTML
  /// Photos are found after <h3>Photo</h3> tag
  /// Extracts all <img> tags that appear after the Photo heading
  Future<List<String>> _extractRoomPhotos(String roomUrl) async {
    try {
      print('Fetching room page: $roomUrl');
      
      // Make HTTP request with headers and timeout
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(roomUrl));
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      });
      
      final response = await client
          .send(request)
          .timeout(Duration(seconds: 15))
          .then((streamedResponse) => http.Response.fromStream(streamedResponse));
      
      client.close();
      
      if (response.statusCode != 200) {
        print('Failed to fetch room page: ${response.statusCode}');
        return [];
      }

      final htmlContent = response.body;
      print('Successfully fetched HTML (${htmlContent.length} bytes)');
      
      // Parse HTML using the html parser
      final document = html_parser.parse(htmlContent);
      
      // Find the Photo heading
      var photoHeading = document.querySelector('h3');
      if (photoHeading == null || !photoHeading.text.toLowerCase().contains('photo')) {
        // Try to find it by searching all h3 elements
        final allH3s = document.querySelectorAll('h3');
        var foundPhotoHeading = false;
        for (final h3 in allH3s) {
          if (h3.text.toLowerCase().trim() == 'photo') {
            photoHeading = h3;
            foundPhotoHeading = true;
            break;
          }
        }
        if (!foundPhotoHeading || photoHeading == null) {
          print('No Photo section found in HTML');
          return [];
        }
      }
      
      print('Found Photo heading, searching for images...');
      
      final photoUrls = <String>[];
      
      // Get all elements after the Photo heading
      // We'll search for img tags in the same parent or following siblings
      var parentElement = photoHeading.parent;
      
      // Search in the parent's children after the Photo heading
      if (parentElement != null) {
        bool foundPhotoHeading = false;
        for (final child in parentElement.children) {
          if (foundPhotoHeading) {
            // Look for img tags in this element and its descendants
            final images = child.querySelectorAll('img');
            for (final img in images) {
              final src = img.attributes['src'];
              if (src != null && src.isNotEmpty) {
                // Convert relative URLs to absolute
                String absoluteUrl;
                if (src.startsWith('http://') || src.startsWith('https://')) {
                  absoluteUrl = src;
                } else if (src.startsWith('//')) {
                  absoluteUrl = 'https:$src';
                } else if (src.startsWith('/')) {
                  absoluteUrl = 'https://www.fit.vut.cz$src';
                } else {
                  absoluteUrl = 'https://www.fit.vut.cz/$src';
                }
                
                final cleanUrl = absoluteUrl.trim();
                if (!photoUrls.contains(cleanUrl)) {
                  photoUrls.add(cleanUrl);
                  print('Found photo URL: $cleanUrl');
                }
              }
            }
            
            // Also check if this element itself is an img tag
            if (child.localName == 'img') {
              final src = child.attributes['src'];
              if (src != null && src.isNotEmpty) {
                String absoluteUrl;
                if (src.startsWith('http://') || src.startsWith('https://')) {
                  absoluteUrl = src;
                } else if (src.startsWith('//')) {
                  absoluteUrl = 'https:$src';
                } else if (src.startsWith('/')) {
                  absoluteUrl = 'https://www.fit.vut.cz$src';
                } else {
                  absoluteUrl = 'https://www.fit.vut.cz/$src';
                }
                
                final cleanUrl = absoluteUrl.trim();
                if (!photoUrls.contains(cleanUrl)) {
                  photoUrls.add(cleanUrl);
                  print('Found photo URL: $cleanUrl');
                }
              }
            }
            
            // Stop if we hit another h3 heading
            if (child.localName == 'h3' || child.localName == 'h2' || child.localName == 'h1') {
              break;
            }
          }
          
          if (child == photoHeading) {
            foundPhotoHeading = true;
          }
        }
      }
      
      // Fallback: Use regex if HTML parsing didn't find images
      if (photoUrls.isEmpty) {
        print('HTML parsing found no images, trying regex fallback...');
        
        // Find the Photo section: look for <h3>Photo</h3>
        final photoSectionPattern = RegExp(
          r'<h3[^>]*>\s*Photo\s*</h3>',
          caseSensitive: false,
        );
        
        final photoSectionMatch = photoSectionPattern.firstMatch(htmlContent);
        if (photoSectionMatch != null) {
          // Get the content after the Photo header
          final photoSectionStart = photoSectionMatch.end;
          final photoSectionContent = htmlContent.substring(photoSectionStart);
          
          // Find the next section (look for next <h3> or </section> to limit scope)
          final nextSectionPattern = RegExp(
            r'<h[1-6][^>]*>|</section>',
            caseSensitive: false,
          );
          final nextSectionMatch = nextSectionPattern.firstMatch(photoSectionContent);
          
          // Limit search to content between Photo header and next section (or 20000 chars max)
          final searchLimit = nextSectionMatch != null
              ? math.min(nextSectionMatch.start, 20000)
              : math.min(photoSectionContent.length, 20000);
          final photoSection = photoSectionContent.substring(0, searchLimit);
          
          // Extract all img tags - try both double and single quotes
          final imgPatternDouble = RegExp(
            r'<img[^>]*src="([^"]+)"',
            caseSensitive: false,
          );
          final imgPatternSingle = RegExp(
            r"<img[^>]*src='([^']+)'",
            caseSensitive: false,
          );
          
          final matchesDouble = imgPatternDouble.allMatches(photoSection);
          final matchesSingle = imgPatternSingle.allMatches(photoSection);
          
          for (final match in matchesDouble) {
            final photoUrl = match.group(1);
            if (photoUrl != null && photoUrl.isNotEmpty) {
              // Convert relative URLs to absolute
              String absoluteUrl;
              if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
                absoluteUrl = photoUrl;
              } else if (photoUrl.startsWith('//')) {
                absoluteUrl = 'https:$photoUrl';
              } else if (photoUrl.startsWith('/')) {
                absoluteUrl = 'https://www.fit.vut.cz$photoUrl';
              } else {
                absoluteUrl = 'https://www.fit.vut.cz/$photoUrl';
              }
              
              final cleanUrl = absoluteUrl.trim();
              if (!photoUrls.contains(cleanUrl)) {
                photoUrls.add(cleanUrl);
                print('Found photo URL (regex): $cleanUrl');
              }
            }
          }
          
          for (final match in matchesSingle) {
            final photoUrl = match.group(1);
            if (photoUrl != null && photoUrl.isNotEmpty) {
              // Convert relative URLs to absolute
              String absoluteUrl;
              if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
                absoluteUrl = photoUrl;
              } else if (photoUrl.startsWith('//')) {
                absoluteUrl = 'https:$photoUrl';
              } else if (photoUrl.startsWith('/')) {
                absoluteUrl = 'https://www.fit.vut.cz$photoUrl';
              } else {
                absoluteUrl = 'https://www.fit.vut.cz/$photoUrl';
              }
              
              final cleanUrl = absoluteUrl.trim();
              if (!photoUrls.contains(cleanUrl)) {
                photoUrls.add(cleanUrl);
                print('Found photo URL (regex): $cleanUrl');
              }
            }
          }
        }
      }
      
      // Debug: Print a sample of the photo section HTML if no photos found
      if (photoUrls.isEmpty) {
        print('No photos found. Checking HTML structure...');
        final photoSectionPattern = RegExp(
          r'<h3[^>]*>\s*Photo\s*</h3>',
          caseSensitive: false,
        );
        final photoSectionMatch = photoSectionPattern.firstMatch(htmlContent);
        if (photoSectionMatch != null) {
          final sampleStart = photoSectionMatch.end;
          final sampleLength = math.min(1000, htmlContent.length - sampleStart);
          print('Photo section sample (first $sampleLength chars): ${htmlContent.substring(sampleStart, sampleStart + sampleLength)}');
        }
      }

      print('Extracted ${photoUrls.length} photo URL(s)');
      return photoUrls;
    } on http.ClientException catch (e) {
      print('Network error fetching room photos: $e');
      print('URL: $roomUrl');
      print('This might be due to network connectivity, server blocking, or invalid URL');
      return [];
    } on TimeoutException catch (e) {
      print('Timeout error fetching room photos: $e');
      print('URL: $roomUrl');
      return [];
    } on Exception catch (e) {
      print('Error extracting room photos: $e');
      print('URL: $roomUrl');
      return [];
    }
  }

  void _closeDrawer() {
    setState(() {
      _isDrawerOpen = false;
      _selectedRoom = null;
      _isDrawerExpanded = false;
    });
  }

  void _toggleDrawerExpansion() {
    setState(() {
      _isDrawerExpanded = !_isDrawerExpanded;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _interactiveController.dispose();
    _pulseController.dispose();
    if (_zoomAnimationListener != null && _zoomAnimation != null) {
      _zoomAnimation!.removeListener(_zoomAnimationListener!);
    }
    _zoomAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          _buildFullPageMap(),

          // Search overlay
          _buildSearchOverlay(),

          // Bottom navigation
          _buildBottomNavigationBar(),

          // Room details drawer
          if (_isDrawerOpen) _buildRoomDetailsDrawer(),
        ],
      ),
    );
  }

  Widget _buildFullPageMap() {
    return Positioned(
      top: MediaQuery.of(context).padding.top +
          120, // Start immediately under inputs
      left: 0,
      right: 0,
      bottom: 80, // End just before bottom menu
      child: Container(
        color: Colors.white,
        child: _buildFullSizeMap(),
      ),
    );
  }

  Widget _buildFullSizeMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use all available space with no margins to prevent truncation
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Calculate actual map dimensions from JSON data bounds
        final mapDataWidth = _mapMaxX - _mapMinX;
        final mapDataHeight = _mapMaxY - _mapMinY;
        final mapAspectRatio = mapDataWidth / mapDataHeight;

        // Scale map to fit available space while maintaining aspect ratio
        double mapWidth = availableWidth;
        double mapHeight = availableWidth / mapAspectRatio;

        // If height exceeds available space, scale down based on height
        if (mapHeight > availableHeight) {
          mapHeight = availableHeight;
          mapWidth = availableHeight * mapAspectRatio;
        }

        return InteractiveViewer(
          key: _mapViewKey,
          transformationController: _interactiveController,
          minScale: 0.1, // Allow micro minimization
          maxScale: 10.0, // Allow more zoom
          onInteractionStart: (details) {
            // Optional: Clear highlighting when user starts interacting
            // This can be enabled if you want highlighting to clear on manual interaction
          },
          child: Center(
            child: SizedBox(
              width: mapWidth,
              height: mapHeight,
              child: _buildMapContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the available space for the map content
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Building map with rooms
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: (details) {
                    _handleMapTap(details.localPosition);
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: BuildingMapPainter(
                          roomData:
                              _roomData, // Always show all rooms on current floor
                          highlightedRooms: _highlightedRooms,
                          pulseValue: _pulseAnimation.value,
                          zoomLevel:
                              _interactiveController.value.getMaxScaleOnAxis(),
                          mapBounds: Rect.fromLTRB(
                              _mapMinX, _mapMinY, _mapMaxX, _mapMaxY),
                          paths: _navigationPaths,
                          trails: _userTrail.isEmpty ? [] : [_userTrail.toMapPath()],
                          currentLocationRoom: _currentLocationRoom,
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

  Widget _buildSearchOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Column(
        children: [
          // Autocomplete search field
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search input field
                SizedBox(
                  height: 45,
                  child: TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Type room name or ID to search...',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.primaryColor, size: 20),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey[600], size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _isSearching = false;
                                  _showSuggestions = false;
                                  _searchSuggestions = [];
                                });
                                _performSearch(''); // Clear search results
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _isSearching = value.isNotEmpty;
                        _showSuggestions = value.isNotEmpty;
                      });
                      _updateSuggestions(value);
                    },
                    onTap: () {
                      setState(() {
                        _showSuggestions = _searchController.text.isNotEmpty;
                      });
                    },
                  ),
                ),

                // Suggestions dropdown
                if (_showSuggestions && _searchSuggestions.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final room = _searchSuggestions[index];
                        return _buildSuggestionItem(room);
                      },
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 8),

          // Floor selection - matching search design
          Container(
            width: double.infinity,
            height: 45, // Match search bar height
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(20), // Match search bar corners exactly
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Floor selection on the left
                  Icon(Icons.layers, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Floor:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedFloor,
                    items: [
                      '-2ⁿᵈ Floor',
                      '-1ˢᵗ Floor',
                      '1ˢᵗ Floor',
                      '2ⁿᵈ Floor',
                      '3ʳᵈ Floor',
                    ].map((String floor) {
                      return DropdownMenuItem<String>(
                        value: floor,
                        child: Text(
                          floor,
                          style: TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedFloor = newValue;
                      });
                      _loadCurrentFloorData(); // Reload current floor data
                    },
                    underline: Container(),
                    icon: Icon(Icons.keyboard_arrow_down, size: 20),
                    isExpanded: false,
                  ),

                  // Spacer to push Current Location to the right
                  Spacer(),

                  // Current Location - Compact icon with tooltip
                  Tooltip(
                    message: 'Current Location',
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _searchQuery.isEmpty
                          ? '${_roomData.length} rooms'
                          : '${_highlightedRooms.length} found',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.map, 'Map', true, () {}),
              _buildBottomNavItem(Icons.person, 'Profile', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              }),
              _buildBottomNavItem(Icons.menu, 'Menu', false, () {
                _showBottomMenu();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
      IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.help_outline),
              title: Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                _showHelpDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About FITMaps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FIT Faculty Navigation App'),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text(
                'Navigate the FIT building with ease using interactive maps and search functionality.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to use FITMaps:'),
            SizedBox(height: 8),
            Text('• Use the search bar to find rooms, offices, or facilities'),
            Text('• Select different floors using the dropdown'),
            Text('• Tap on the map to explore different areas'),
            Text('• Use the bottom navigation to access profile and menu'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SplashScreen()),
      (route) => false,
    );
  }

  Widget _buildRoomDetailsDrawer() {
    if (_selectedRoom == null) return Container();

    final screenHeight = MediaQuery.of(context).size.height;
    final drawerHeight = _isDrawerExpanded ? screenHeight : screenHeight * 0.5;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: drawerHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drawer handle
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Drawer header
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  // Room icon
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.room,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),

                  SizedBox(width: 16),

                  // FIT Logo
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),

                  SizedBox(width: 16),

                  // Room info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRoom!['id'] ?? '',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _selectedRoom!['title'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.layers,
                                size: 16, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Text(
                              'Floor ${_selectedRoom!['floor_no'] ?? ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      IconButton(
                        onPressed: _toggleDrawerExpansion,
                        icon: Icon(
                          _isDrawerExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      IconButton(
                        onPressed: _closeDrawer,
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1),

            // Drawer content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room details section
                    _buildRoomDetailsSection(),

                    SizedBox(height: 20),

                    // Room photos section
                    _buildRoomPhotosSection(),

                    SizedBox(height: 20),

                    // Room information section
                    _buildRoomInfoSection(),

                    SizedBox(height: 20),

                    // Action buttons section
                    _buildActionButtonsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),

        // Room type
        _buildDetailRow('Type', _getRoomType(_selectedRoom!['title'] ?? '')),

        // Floor
        _buildDetailRow('Floor', 'Floor ${_selectedRoom!['floor_no'] ?? ''}'),

        // Accessibility
        if (_selectedRoom!['room_tag']?.isNotEmpty == true)
          _buildDetailRow('Accessibility', _selectedRoom!['room_tag']),
      ],
    );
  }

  Widget _buildRoomPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room Photos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        if (_isLoadingPhotos)
          Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_roomPhotos.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No Photos Available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Photos will be loaded from FIT website',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _roomPhotos.length == 1
                  ? Image.network(
                      _roomPhotos.first,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.grey[600], size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load photo',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : PageView.builder(
                      itemCount: _roomPhotos.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          _roomPhotos[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.grey[600], size: 32),
                                    SizedBox(height: 8),
                                    Text(
                                      'Failed to load photo',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoomInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                'Detailed room information is available on the official FIT website.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsSection() {
    final isCurrentLocation = _currentLocationRoom != null && 
        _selectedRoom != null &&
        _currentLocationRoom!['id'] == _selectedRoom!['id'];
    final hasNavigationPath = _navigationPaths.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        // Navigation button (only show if not current location)
        if (!isCurrentLocation)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToRoom(_selectedRoom!);
                  _closeDrawer();
                },
                icon: Icon(Icons.navigation),
                label: Text('Navigate To This Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        // Clear navigation button (only show if navigation path exists)
        if (hasNavigationPath)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _clearNavigation();
                },
                icon: Icon(Icons.clear),
                label: Text('Clear Navigation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        // Current location indicator
        if (isCurrentLocation)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.my_location, color: Colors.green[700], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are here',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 12),
        // Share button
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Share room information
                  print('Sharing room: ${_selectedRoom!['id']}');
                },
                icon: Icon(Icons.share),
                label: Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoomType(String title) {
    if (title.toLowerCase().contains('office')) return 'Office';
    if (title.toLowerCase().contains('lecture')) return 'Lecture Room';
    if (title.toLowerCase().contains('lab')) return 'Laboratory';
    if (title.toLowerCase().contains('staircase')) return 'Staircase';
    if (title.toLowerCase().contains('corridor')) return 'Corridor';
    if (title.toLowerCase().contains('elevator')) return 'Elevator';
    if (title.toLowerCase().contains('toilet')) return 'Restroom';
    if (title.toLowerCase().contains('technology')) return 'Technology Room';
    if (title.toLowerCase().contains('aircondition')) return 'Technical Room';
    return 'Room';
  }
}

class BuildingMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> roomData;
  final List<Map<String, dynamic>> highlightedRooms;
  final double pulseValue;
  final double zoomLevel;
  final Rect mapBounds;
  final List<MapPath> paths;
  final List<MapPath> trails;
  final Map<String, dynamic>? currentLocationRoom;

  BuildingMapPainter({
    required this.roomData,
    required this.highlightedRooms,
    required this.pulseValue,
    required this.zoomLevel,
    required this.mapBounds,
    this.paths = const [],
    this.trails = const [],
    this.currentLocationRoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Remove clipping and building outline to prevent overlapping and truncation issues
    // Just draw the rooms directly on the white background

    // First pass: Draw all rooms (polygons, borders, labels) WITHOUT markers
    for (final room in roomData) {
      _drawRoom(canvas, room, size, drawMarker: false);
    }

    // Second pass: Draw paths (after rooms, before markers)
    for (final path in paths) {
      _drawPath(canvas, path, size);
    }
    
    for (final trail in trails) {
      _drawPath(canvas, trail, size);
    }

    // Third pass: Draw all markers on top (ensures markers are always visible)
    for (final room in roomData) {
      final roomId = room['id'] as String;
      final isHighlighted = highlightedRooms
          .any((highlightedRoom) => highlightedRoom['id'] == roomId);
      final isCurrentLocation = currentLocationRoom != null &&
          currentLocationRoom!['id'] == roomId;
      
      if (isHighlighted || isCurrentLocation) {
        final coords = room['coords'] as List<dynamic>;
        if (isCurrentLocation) {
          // Draw current location with green marker
          _drawCurrentLocationMarker(canvas, coords, size);
        } else {
          // Draw regular highlighted marker
          _drawGoogleMarker(canvas, coords, size);
        }
      }
    }
  }

  void _drawRoom(Canvas canvas, Map<String, dynamic> room, Size canvasSize, {bool drawMarker = true}) {
    final coords = room['coords'] as List<dynamic>;
    final roomId = room['id'] as String;
    final title = room['title'] as String;

    if (coords.isEmpty) return;

    // Check if this room is highlighted
    final isHighlighted = highlightedRooms
        .any((highlightedRoom) => highlightedRoom['id'] == roomId);

    // Determine room color based on room type or ID
    Color roomColor = _getRoomColor(roomId, title);

    // If highlighted, use a brighter/more prominent color with pulse effect
    if (isHighlighted) {
      roomColor = _getHighlightedRoomColor(roomId, title);
      // Apply pulse effect to opacity
      roomColor = roomColor.withValues(alpha: pulseValue);
    }

    // Create room paint
    final roomPaint = Paint()
      ..color = roomColor
      ..style = PaintingStyle.fill;

    // Create border paint - thicker and more prominent for highlighted rooms with pulse
    final borderPaint = Paint()
      ..color = isHighlighted
          ? Colors.red[700]!.withValues(alpha: pulseValue)
          : Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighlighted ? (3.0 * pulseValue) : 1.0;

    // Draw room polygon with proper coordinate mapping
    final path = Path();
    for (int i = 0; i < coords.length; i++) {
      final coord = coords[i] as List<dynamic>;
      if (coord.length >= 2) {
        final x = (coord[0] as num).toDouble();
        final y = (coord[1] as num).toDouble();

        // Map coordinates to canvas space
        final mappedX =
            ((x - mapBounds.left) / mapBounds.width) * canvasSize.width;
        final mappedY =
            ((y - mapBounds.top) / mapBounds.height) * canvasSize.height;

        if (i == 0) {
          path.moveTo(mappedX, mappedY);
        } else {
          path.lineTo(mappedX, mappedY);
        }
      }
    }
    path.close();

    canvas.drawPath(path, roomPaint);
    canvas.drawPath(path, borderPaint);

    // Draw room label with adaptive sizing
    _drawRoomLabel(canvas, roomId, title, coords, canvasSize);

    // Draw Google-style marker for highlighted rooms (only if drawMarker is true)
    if (drawMarker && isHighlighted) {
      _drawGoogleMarker(canvas, coords, canvasSize);
    }
  }

  Color _getRoomColor(String roomId, String title) {
    // Determine color based on room type
    if (title.toLowerCase().contains('staircase')) return Colors.red[600]!;
    if (title.toLowerCase().contains('office')) return Colors.green[500]!;
    if (title.toLowerCase().contains('lab')) return Colors.orange[500]!;
    if (title.toLowerCase().contains('lecture')) return Colors.blue[500]!;
    if (title.toLowerCase().contains('library')) return Colors.purple[500]!;
    if (title.toLowerCase().contains('corridor')) return Colors.grey[200]!;
    if (title.toLowerCase().contains('elevator')) return Colors.brown[600]!;
    if (title.toLowerCase().contains('toilet')) return Colors.cyan[500]!;
    if (title.toLowerCase().contains('technology')) return Colors.indigo[500]!;
    if (title.toLowerCase().contains('aircondition')) return Colors.teal[500]!;

    // Default color based on room ID pattern
    if (roomId.contains('D')) return Colors.green[500]!;
    if (roomId.contains('C')) return Colors.blue[500]!;
    if (roomId.contains('B')) return Colors.orange[500]!;
    if (roomId.contains('A')) return Colors.purple[500]!;

    return Colors.grey[400]!;
  }

  Color _getHighlightedRoomColor(String roomId, String title) {
    // Use brighter, more vibrant colors for highlighted rooms
    if (title.toLowerCase().contains('staircase')) return Colors.red[400]!;
    if (title.toLowerCase().contains('office')) return Colors.green[300]!;
    if (title.toLowerCase().contains('lab')) return Colors.orange[300]!;
    if (title.toLowerCase().contains('lecture')) return Colors.blue[300]!;
    if (title.toLowerCase().contains('library')) return Colors.purple[300]!;
    if (title.toLowerCase().contains('corridor')) return Colors.grey[100]!;
    if (title.toLowerCase().contains('elevator')) return Colors.brown[400]!;
    if (title.toLowerCase().contains('toilet')) return Colors.cyan[300]!;
    if (title.toLowerCase().contains('technology')) return Colors.indigo[300]!;
    if (title.toLowerCase().contains('aircondition')) return Colors.teal[300]!;

    // Default highlighted color based on room ID pattern
    if (roomId.contains('D')) return Colors.green[300]!;
    if (roomId.contains('C')) return Colors.blue[300]!;
    if (roomId.contains('B')) return Colors.orange[300]!;
    if (roomId.contains('A')) return Colors.purple[300]!;

    return Colors.yellow[200]!; // Default highlight color
  }

  void _drawRoomLabel(Canvas canvas, String roomId, String title,
      List<dynamic> coords, Size canvasSize) {
    if (coords.isEmpty) return;

    // Calculate center point and bounding box of the room in canvas pixels
    double centerX = 0, centerY = 0;
    double minMappedX = double.infinity;
    double maxMappedX = double.negativeInfinity;
    double minMappedY = double.infinity;
    double maxMappedY = double.negativeInfinity;
    
    for (final coord in coords) {
      final coordList = coord as List<dynamic>;
      if (coordList.length >= 2) {
        final x = (coordList[0] as num).toDouble();
        final y = (coordList[1] as num).toDouble();

        // Map coordinates to canvas space
        final mappedX =
            ((x - mapBounds.left) / mapBounds.width) * canvasSize.width;
        final mappedY =
            ((y - mapBounds.top) / mapBounds.height) * canvasSize.height;

        centerX += mappedX;
        centerY += mappedY;
        
        // Track bounding box in canvas pixels
        minMappedX = math.min(minMappedX, mappedX);
        maxMappedX = math.max(maxMappedX, mappedX);
        minMappedY = math.min(minMappedY, mappedY);
        maxMappedY = math.max(maxMappedY, mappedY);
      }
    }
    centerX /= coords.length;
    centerY /= coords.length;

    // Calculate room's actual visual dimensions in canvas pixels
    final roomWidthInPixels = maxMappedX - minMappedX;
    final roomHeightInPixels = maxMappedY - minMappedY;
    final roomSizeInPixels = math.sqrt(roomWidthInPixels * roomHeightInPixels);
    
    // Calculate font size that maintains constant ratio to room size
    // Font scales with zoom because canvas scales with zoom (InteractiveViewer scales everything)
    // So we base font size directly on room's pixel dimensions to maintain ratio
    const fontToRoomRatio = 0.15; // Font size as ratio of room's linear dimension
    double adaptiveFontSize = roomSizeInPixels * fontToRoomRatio;
    
    // Ensure readable bounds
    adaptiveFontSize = adaptiveFontSize.clamp(8.0, 36.0);

    // Draw room ID with adaptive font size
    final textPainter = TextPainter(
      text: TextSpan(
        text: roomId,
        style: TextStyle(
          color: Colors.white,
          fontSize: adaptiveFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
            centerX - textPainter.width / 2, centerY - textPainter.height / 2));
  }

  double _calculateRoomArea(List<dynamic> coords) {
    if (coords.length < 3) return 0;

    double area = 0;
    for (int i = 0; i < coords.length; i++) {
      final coord1 = coords[i] as List<dynamic>;
      final coord2 = coords[(i + 1) % coords.length] as List<dynamic>;

      if (coord1.length >= 2 && coord2.length >= 2) {
        double x1 = (coord1[0] as num).toDouble();
        double y1 = (coord1[1] as num).toDouble();
        double x2 = (coord2[0] as num).toDouble();
        double y2 = (coord2[1] as num).toDouble();

        // Use original coordinates for area calculation (not mapped)
        area += (x1 * y2 - x2 * y1);
      }
    }
    return (area / 2).abs();
  }


  void _drawGoogleMarker(Canvas canvas, List<dynamic> coords, Size canvasSize) {
    if (coords.isEmpty) return;

    // Calculate center point of the room
    double centerX = 0, centerY = 0;
    for (final coord in coords) {
      final coordList = coord as List<dynamic>;
      if (coordList.length >= 2) {
        final x = (coordList[0] as num).toDouble();
        final y = (coordList[1] as num).toDouble();

        // Map coordinates to canvas space
        final mappedX =
            ((x - mapBounds.left) / mapBounds.width) * canvasSize.width;
        final mappedY =
            ((y - mapBounds.top) / mapBounds.height) * canvasSize.height;

        centerX += mappedX;
        centerY += mappedY;
      }
    }
    centerX /= coords.length;
    centerY /= coords.length;

    // Marker size based on pulse animation and zoom level
    const baseMarkerSize = 40.0; // Google Maps standard size
    final zoomAdjustedSize = baseMarkerSize / zoomLevel.clamp(0.5, 3.0);
    final markerSize = zoomAdjustedSize * pulseValue;
    
    // Pin tip is at the actual location point (exact Google Maps behavior)
    final pinTipX = centerX;
    final pinTipY = centerY;
    
    // Google Maps pin dimensions - circular head is ~2/3, triangle is ~1/3
    final pinRadius = markerSize * 0.25; // Radius of the circular head
    final pinHeight = markerSize * 0.65; // Total height from tip to top of circle
    final pinHeadCenterY = pinTipY - pinHeight + pinRadius; // Center of circular head
    final triangleWidth = pinRadius * 0.5; // Width of triangle base

    // Draw shadow (Google Maps style - offset down and right)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25 * pulseValue)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, markerSize * 0.15)
      ..style = PaintingStyle.fill;

    // Create teardrop shadow path (offset slightly)
    final shadowPath = Path();
    // Shadow circular head
    shadowPath.addOval(Rect.fromCircle(
      center: Offset(pinTipX + 1, pinHeadCenterY + 1),
      radius: pinRadius,
    ));
    // Shadow triangle
    shadowPath.moveTo(pinTipX + 1, pinHeadCenterY + 1 + pinRadius);
    shadowPath.lineTo(pinTipX + 1 + triangleWidth, pinTipY + 1);
    shadowPath.lineTo(pinTipX + 1 - triangleWidth, pinTipY + 1);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw pin body - Red color (Google Maps red marker style)
    final pinPaint = Paint()
      ..color = Color(0xFFEA4335).withValues(alpha: pulseValue) // Google Maps red
      ..style = PaintingStyle.fill;

    // Create exact Google Maps teardrop/pin path
    final pinPath = Path();
    
    // Circular head (top part) - forms the main body
    pinPath.addOval(Rect.fromCircle(
      center: Offset(pinTipX, pinHeadCenterY),
      radius: pinRadius,
    ));
    
    // Triangular point (bottom) - connects circle to tip
    // The triangle is narrower than the circle for that classic Google pin look
    pinPath.moveTo(pinTipX, pinHeadCenterY + pinRadius);
    pinPath.lineTo(pinTipX + triangleWidth, pinTipY);
    pinPath.lineTo(pinTipX - triangleWidth, pinTipY);
    pinPath.close();
    
    canvas.drawPath(pinPath, pinPaint);

    // Draw white border (Google Maps style - subtle but visible)
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Border for circular head
    canvas.drawCircle(
      Offset(pinTipX, pinHeadCenterY),
      pinRadius,
      borderPaint,
    );

    // Border for triangular point
    final borderPath = Path();
    borderPath.moveTo(pinTipX, pinHeadCenterY + pinRadius);
    borderPath.lineTo(pinTipX + triangleWidth, pinTipY);
    borderPath.lineTo(pinTipX - triangleWidth, pinTipY);
    borderPath.close();
    canvas.drawPath(borderPath, borderPaint);

    // Draw white center dot in circular head (Google Maps signature feature)
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: pulseValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pinTipX, pinHeadCenterY),
      pinRadius * 0.4, // Proportionally sized white dot
      dotPaint,
    );

    // Draw subtle highlight/shine on top-left of circular head (Google Maps style)
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.4 * pulseValue),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(pinTipX - pinRadius * 0.4, pinHeadCenterY - pinRadius * 0.4),
        radius: pinRadius * 0.8,
      ))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pinTipX - pinRadius * 0.4, pinHeadCenterY - pinRadius * 0.4),
      pinRadius * 0.6,
      highlightPaint,
    );
  }

  /// Draw current location marker (green pin)
  void _drawCurrentLocationMarker(Canvas canvas, List<dynamic> coords, Size canvasSize) {
    if (coords.isEmpty) return;

    // Calculate center point of the room
    double centerX = 0, centerY = 0;
    for (final coord in coords) {
      final coordList = coord as List<dynamic>;
      if (coordList.length >= 2) {
        final x = (coordList[0] as num).toDouble();
        final y = (coordList[1] as num).toDouble();

        // Map coordinates to canvas space
        final mappedX =
            ((x - mapBounds.left) / mapBounds.width) * canvasSize.width;
        final mappedY =
            ((y - mapBounds.top) / mapBounds.height) * canvasSize.height;

        centerX += mappedX;
        centerY += mappedY;
      }
    }
    centerX /= coords.length;
    centerY /= coords.length;

    // Marker size based on zoom level
    const baseMarkerSize = 40.0;
    final zoomAdjustedSize = baseMarkerSize / zoomLevel.clamp(0.5, 3.0);
    final markerSize = zoomAdjustedSize * pulseValue;
    
    final pinTipX = centerX;
    final pinTipY = centerY;
    final pinRadius = markerSize * 0.25;
    final pinHeight = markerSize * 0.65;
    final pinHeadCenterY = pinTipY - pinHeight + pinRadius;
    final triangleWidth = pinRadius * 0.5;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25 * pulseValue)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, markerSize * 0.15)
      ..style = PaintingStyle.fill;

    final shadowPath = Path();
    shadowPath.addOval(Rect.fromCircle(
      center: Offset(pinTipX + 1, pinHeadCenterY + 1),
      radius: pinRadius,
    ));
    shadowPath.moveTo(pinTipX + 1, pinHeadCenterY + 1 + pinRadius);
    shadowPath.lineTo(pinTipX + 1 + triangleWidth, pinTipY + 1);
    shadowPath.lineTo(pinTipX + 1 - triangleWidth, pinTipY + 1);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw green pin (current location)
    final pinPaint = Paint()
      ..color = Colors.green.withValues(alpha: pulseValue)
      ..style = PaintingStyle.fill;

    final pinPath = Path();
    pinPath.addOval(Rect.fromCircle(
      center: Offset(pinTipX, pinHeadCenterY),
      radius: pinRadius,
    ));
    pinPath.moveTo(pinTipX, pinHeadCenterY + pinRadius);
    pinPath.lineTo(pinTipX + triangleWidth, pinTipY);
    pinPath.lineTo(pinTipX - triangleWidth, pinTipY);
    pinPath.close();
    
    canvas.drawPath(pinPath, pinPaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(
      Offset(pinTipX, pinHeadCenterY),
      pinRadius,
      borderPaint,
    );

    final borderPath = Path();
    borderPath.moveTo(pinTipX, pinHeadCenterY + pinRadius);
    borderPath.lineTo(pinTipX + triangleWidth, pinTipY);
    borderPath.lineTo(pinTipX - triangleWidth, pinTipY);
    borderPath.close();
    canvas.drawPath(borderPath, borderPaint);

    // Draw white center dot
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: pulseValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pinTipX, pinHeadCenterY),
      pinRadius * 0.4,
      dotPaint,
    );
  }

  /// Draw a path on the map
  void _drawPath(Canvas canvas, MapPath path, Size canvasSize) {
    if (path.points.length < 2) return;

    // Map path points from pixel coordinates to canvas space
    final mappedPoints = path.points.map((point) {
      final mappedX =
          ((point.dx - mapBounds.left) / mapBounds.width) * canvasSize.width;
      final mappedY =
          ((point.dy - mapBounds.top) / mapBounds.height) * canvasSize.height;
      return Offset(mappedX, mappedY);
    }).toList();

    // Create path object
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

    // Handle dashed style (Flutter doesn't have built-in dashed lines, so we draw line segments)
    if (path.style == PathStyle.dashed) {
      _drawDashedPath(canvas, mappedPoints, paint);
    } else if (path.style == PathStyle.dotted) {
      _drawDottedPath(canvas, mappedPoints, paint);
    } else {
      // Draw solid path
      canvas.drawPath(pathObj, paint);
    }

    // Draw direction arrows if enabled
    if (path.showArrows && mappedPoints.length >= 2) {
      _drawPathArrows(canvas, mappedPoints, path.color, path.width);
    }
  }

  /// Draw a dashed path by drawing line segments
  void _drawDashedPath(Canvas canvas, List<Offset> points, Paint paint) {
    const double dashLength = 10.0;
    const double gapLength = 5.0;

    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final distance = (end - start).distance;
      
      if (distance == 0) continue; // Skip zero-length segments
      
      final direction = (end - start) / distance;

      double currentDistance = 0.0;
      bool drawDash = true;

      while (currentDistance < distance) {
        final segmentLength = drawDash ? dashLength : gapLength;
        final nextDistance = (currentDistance + segmentLength).clamp(0.0, distance);

        if (drawDash) {
          final segmentStart = start + direction * currentDistance;
          final segmentEnd = start + direction * nextDistance;
          canvas.drawLine(segmentStart, segmentEnd, paint);
        }

        currentDistance = nextDistance;
        drawDash = !drawDash;
      }
    }
  }

  /// Draw a dotted path
  void _drawDottedPath(Canvas canvas, List<Offset> points, Paint paint) {
    paint.strokeCap = StrokeCap.round;
    const double dotSpacing = 8.0;

    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final distance = (end - start).distance;
      
      if (distance == 0) continue; // Skip zero-length segments
      
      final direction = (end - start) / distance;

      double currentDistance = 0.0;
      while (currentDistance < distance) {
        final dotPosition = start + direction * currentDistance;
        canvas.drawCircle(dotPosition, paint.strokeWidth / 2, paint);
        currentDistance += dotSpacing;
      }
    }
  }

  /// Draw direction arrows along a path
  void _drawPathArrows(
      Canvas canvas, List<Offset> points, Color color, double pathWidth) {
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double arrowSize = 12.0;
    const double arrowSpacing = 50.0;

    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final distance = (end - start).distance;

      if (distance < arrowSpacing) {
        // Draw arrow at midpoint if segment is short
        final midpoint = Offset.lerp(start, end, 0.5)!;
        final angle = (end - start).direction;
        _drawArrow(canvas, midpoint, angle, arrowSize, arrowPaint);
      } else {
        // Draw multiple arrows along longer segments
        final numArrows = (distance / arrowSpacing).floor();
        for (int j = 0; j < numArrows; j++) {
          final t = (j + 1) / (numArrows + 1);
          final arrowPos = Offset.lerp(start, end, t)!;
          final angle = (end - start).direction;
          _drawArrow(canvas, arrowPos, angle, arrowSize, arrowPaint);
        }
      }
    }
  }

  /// Draw a single arrow at a position with a given angle
  void _drawArrow(
      Canvas canvas, Offset position, double angle, double size, Paint paint) {
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

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
