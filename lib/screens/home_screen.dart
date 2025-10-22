import 'package:flutter/material.dart';
import 'package:fitmaps/config/theme.dart';
import 'package:fitmaps/screens/profile_screen.dart';
import 'package:fitmaps/screens/splash_screen.dart';
import 'dart:convert';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String? _selectedFloor;
  bool _isSearching = false;
  List<Map<String, dynamic>> _roomData = [];

  @override
  void initState() {
    super.initState();
    _selectedFloor = '1ˢᵗ Floor';
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

      // Filter rooms for current floor
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

      // Extract room data for current floor and calculate bounds
      final floorRooms = <Map<String, dynamic>>[];
      double minX = double.infinity;
      double maxX = double.negativeInfinity;
      double minY = double.infinity;
      double maxY = double.negativeInfinity;

      for (final roomEntry in allRooms) {
        if (roomEntry is Map<String, dynamic>) {
          for (final entry in roomEntry.entries) {
            final roomId = entry.key;
            final roomData = entry.value as Map<String, dynamic>;
            if (roomData['floor_no']?.toString() == currentFloor) {
              final coords = roomData['coords'] ?? [];

              // Calculate bounds for this room
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

              floorRooms.add({
                'id': roomId,
                'title': roomData['title'] ?? '',
                'coords': coords,
                'room_tag': roomData['room_tag'] ?? '',
              });
            }
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
    } catch (e) {
      print('Error loading room data: $e');
      setState(() {
        _roomData = [];
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          minScale: 0.1, // Allow micro minimization
          maxScale: 10.0, // Allow more zoom
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
                child: CustomPaint(
                  painter: BuildingMapPainter(
                    roomData: _roomData,
                    mapBounds:
                        Rect.fromLTRB(_mapMinX, _mapMinY, _mapMaxX, _mapMaxY),
                  ),
                  child: Container(),
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
          // Search bar - minimized height
          Container(
            width: double.infinity,
            height: 45, // Fixed height
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
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search rooms, offices, facilities...',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                prefixIcon:
                    Icon(Icons.search, color: AppTheme.primaryColor, size: 20),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Colors.grey[600], size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _isSearching = false;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _isSearching = value.isNotEmpty;
                });
              },
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
                      _loadRoomData(); // Reload room data when floor changes
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
                      '${_roomData.length} rooms',
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
              _buildBottomNavItem(Icons.search, 'Search', false, () {}),
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
}

class BuildingMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> roomData;
  final Rect mapBounds;

  BuildingMapPainter({required this.roomData, required this.mapBounds});

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

    // Remove boundary checking to ensure all rooms are drawn
    // Let the canvas handle the drawing area naturally

    // Determine room color based on room type or ID
    Color roomColor = _getRoomColor(roomId, title);

    // Create room paint
    final roomPaint = Paint()
      ..color = roomColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0; // Thinner borders to reduce overlapping

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

    // Calculate final adaptive font size
    double adaptiveSize = baseFontSize * areaScale * canvasScale;

    // Ensure font size is within reasonable bounds
    return adaptiveSize.clamp(6.0, 24.0);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
