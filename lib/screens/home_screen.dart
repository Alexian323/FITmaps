import 'package:flutter/material.dart';
import 'package:fitmaps/config/theme.dart';
import 'package:fitmaps/screens/profile_screen.dart';
import 'package:fitmaps/screens/splash_screen.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _interactiveController = TransformationController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
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

    _loadRoomData();
  }

  double _mapMinX = 0;
  double _mapMaxX = 640;
  double _mapMinY = 0;
  double _mapMaxY = 920;

  Future<void> _loadRoomData() async {
    try {
      // Load room data from JSON file
      final jsonString = await DefaultAssetBundle.of(context)
          .loadString('data/parsed_data/maps_data.json');
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
              'coords': roomData['coords'] ?? [],
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
            _highlightedRooms = List.from(currentFloorRooms);
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

    // Calculate center point of highlighted rooms
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    // Calculate room bounds with padding
    final roomWidth = maxX - minX + 200; // Add padding
    final roomHeight = maxY - minY + 200; // Add padding

    // Get the current map bounds
    final mapWidth = _mapMaxX - _mapMinX;
    final mapHeight = _mapMaxY - _mapMinY;

    // Calculate scale to fit the highlighted rooms
    final scaleX = mapWidth / roomWidth;
    final scaleY = mapHeight / roomHeight;
    final scale = math.min(math.min(scaleX, scaleY), 2.0); // Cap at 2x zoom

    // Calculate the offset to center the rooms
    final offsetX = (centerX - _mapMinX) / mapWidth;
    final offsetY = (centerY - _mapMinY) / mapHeight;

    // Apply transformation to the InteractiveViewer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final matrix = Matrix4.identity()
        ..translate(-offsetX * mapWidth, -offsetY * mapHeight)
        ..scale(scale);

      _interactiveController.value = matrix;
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
      final baseMarkerSize = 20.0;
      final zoomAdjustedSize = baseMarkerSize /
          _interactiveController.value.getMaxScaleOnAxis().clamp(0.5, 3.0);
      final markerSize = zoomAdjustedSize * _pulseAnimation.value;

      print(
          'Room ${room['id']}: center=($centerX, $centerY), markerSize=$markerSize');

      // Check if tap is within marker bounds - use much larger clickable area
      final distance = (tapPosition - Offset(centerX, centerY)).distance;
      final clickableRadius =
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

      // Try to fetch photos from the FIT website
      // For now, we'll simulate checking for photos
      await Future.delayed(Duration(seconds: 2));

      // Check if photos exist for this room
      // In a real implementation, you would parse the HTML from roomUrl
      // and look for image tags or photo links
      final hasPhotos = await _checkForRoomPhotos(roomUrl);

      if (hasPhotos) {
        // In a real implementation, you would extract actual photo URLs
        // For now, we'll use empty list to show no photos placeholder
        setState(() {
          _roomPhotos = [];
          _isLoadingPhotos = false;
        });
        print('No photos found for room $roomId');
      } else {
        setState(() {
          _roomPhotos = [];
          _isLoadingPhotos = false;
        });
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

  Future<bool> _checkForRoomPhotos(String roomUrl) async {
    try {
      // In a real implementation, you would:
      // 1. Make HTTP request to roomUrl
      // 2. Parse the HTML response
      // 3. Look for image tags or photo links
      // 4. Return true if photos are found

      // For now, simulate checking (most rooms don't have photos)
      await Future.delayed(Duration(milliseconds: 500));
      return false; // Most rooms don't have photos
    } catch (e) {
      print('Error checking for photos: $e');
      return false;
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
          transformationController: _interactiveController,
          minScale: 0.1, // Allow micro minimization
          maxScale: 10.0, // Allow more zoom
          onInteractionStart: (details) {
            // Optional: Clear highlighting when user starts interacting
            // This can be enabled if you want highlighting to clear on manual interaction
          },
          child: Center(
            child: Container(
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
                Container(
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

                  // Current Location on the right
                  Icon(Icons.my_location,
                      color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Current Location',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 16,
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
              child: Image.network(
                _roomPhotos.first, // Show only the first photo
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

  BuildingMapPainter(
      {required this.roomData,
      required this.highlightedRooms,
      required this.pulseValue,
      required this.zoomLevel,
      required this.mapBounds});

  @override
  void paint(Canvas canvas, Size size) {
    // Remove clipping and building outline to prevent overlapping and truncation issues
    // Just draw the rooms directly on the white background

    // Draw each room
    for (final room in roomData) {
      _drawRoom(canvas, room, size);
    }
  }

  void _drawRoom(Canvas canvas, Map<String, dynamic> room, Size canvasSize) {
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

    // Draw Google-style marker for highlighted rooms
    if (isHighlighted) {
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

    // Calculate center point of the room using mapped coordinates
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

    // Calculate adaptive font size based on canvas size and room area
    double roomArea = _calculateRoomArea(coords);
    double adaptiveFontSize = _calculateAdaptiveFontSize(roomArea, canvasSize);

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

  double _calculateAdaptiveFontSize(double roomArea, Size canvasSize) {
    // Base font size
    double baseFontSize = 8.0;

    // Scale based on room area (larger rooms get larger fonts)
    double areaScale = (roomArea / 10000).clamp(0.5, 3.0);

    // Scale based on canvas size (larger canvas gets larger fonts)
    double canvasScale = (canvasSize.width / 640).clamp(0.8, 2.0);

    // Scale based on zoom level (more zoom = larger fonts for better readability)
    double zoomScale = zoomLevel.clamp(0.8, 2.5);

    // Calculate final adaptive font size
    double adaptiveSize = baseFontSize * areaScale * canvasScale * zoomScale;

    // Ensure font size is within reasonable bounds
    return adaptiveSize.clamp(6.0, 32.0);
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
    // When zoomed in (zoomLevel > 1.0), make markers smaller
    // When zoomed out (zoomLevel < 1.0), make markers larger
    final baseMarkerSize = 20.0;
    final zoomAdjustedSize = baseMarkerSize / zoomLevel.clamp(0.5, 3.0);
    final markerSize = zoomAdjustedSize * pulseValue;

    // Draw marker shadow (slightly offset)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX + 2, centerY + 2),
      markerSize * 0.6,
      shadowPaint,
    );

    // Draw marker pin (red circle)
    final pinPaint = Paint()
      ..color = Colors.red[600]!.withValues(alpha: pulseValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      markerSize * 0.6,
      pinPaint,
    );

    // Draw marker border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(
      Offset(centerX, centerY),
      markerSize * 0.6,
      borderPaint,
    );

    // Draw inner white dot
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: pulseValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      markerSize * 0.2,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
