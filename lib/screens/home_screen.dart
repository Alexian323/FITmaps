import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fitmaps/config/theme.dart';
import 'package:fitmaps/screens/profile_screen.dart';
import 'package:fitmaps/screens/login_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String? _selectedFloor;
  bool _isSearching = false;
  bool _showMap = false;

  // Interactive map features
  List<LatLng> _pathPoints = [];
  LatLng? _userLocation;
  List<LatLng> _routePath = [];

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  final List<String> _floors = [
    'Basement -2',
    'Basement -1',
    '1ˢᵗ Floor',
    '2ⁿᵈ Floor',
    '3ʳᵈ Floor',
    '4ᵗʰ Floor',
  ];

  final Map<String, String> _floorAssets = {
    'Basement -2': 'assets/floors/-2stfloor.svg',
    'Basement -1': 'assets/floors/-1stfloor.svg',
    '1ˢᵗ Floor': 'assets/floors/1stfloor.svg',
    '2ⁿᵈ Floor': 'assets/floors/2ndfloor.svg',
    '3ʳᵈ Floor': 'assets/floors/3rdfloor.svg',
    '4ᵗʰ Floor': 'assets/floors/4thfloor.svg',
  };

  @override
  void initState() {
    super.initState();
    // Set 1st Floor as default
    _selectedFloor = '1ˢᵗ Floor';
    _showMap = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.isEmpty) {
      _showSnackBar('Please enter a location to search', Colors.orange);
      return;
    }

    if (_selectedFloor == null) {
      _showSnackBar('Please select a floor', Colors.orange);
      return;
    }

    setState(() {
      _isSearching = true;
    });

    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isSearching = false;
      _showMap = true;
    });

    if (mounted) {
      _showSnackBar(
        'Route to ${_searchController.text} on $_selectedFloor',
        AppTheme.primaryColor,
      );
    }
  }

  void _onFloorChanged(String? value) {
    setState(() {
      _selectedFloor = value;
      if (value != null) {
        _showMap = true;
      }
    });
  }

  Widget _buildColoredMap() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Container(
        padding: EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildSvgMap(),
        ),
      ),
    );
  }

  Widget _buildSvgMap() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildInteractiveMap(),
      ),
    );
  }

  Widget _buildInteractiveMap() {
    return InteractiveViewer(
      boundaryMargin: EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4.0,
      child: Stack(
        children: [
          // SVG background with WebView for proper color rendering
          Positioned.fill(
            child: _buildWebViewSvg(),
          ),
          // Interactive overlay for gestures and markers
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _handleMapTap,
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // User location marker
                    if (_userLocation != null)
                      Positioned(
                        left: _userLocation!.longitude - 10,
                        top: _userLocation!.latitude - 10,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Path point markers
                    ..._pathPoints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final point = entry.value;
                      return Positioned(
                        left: point.longitude - 8,
                        top: point.latitude - 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    // Path lines between points
                    if (_pathPoints.length >= 2)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: PathPainter(_pathPoints),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMapTap(TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    // Convert tap position to map coordinates
    final mapPoint = LatLng(
      localPosition.dy, // Y coordinate
      localPosition.dx, // X coordinate
    );

    setState(() {
      _pathPoints.add(mapPoint);
      if (_pathPoints.length >= 2) {
        _routePath = List.from(_pathPoints);
      }
    });
  }

  void _setUserLocation() {
    // Set user location to a default position (you can modify this)
    setState(() {
      _userLocation = LatLng(300, 200); // Example position
    });
  }

  void _clearPath() {
    setState(() {
      _pathPoints.clear();
      _routePath.clear();
    });
  }

  void _debugSvgContent() async {
    try {
      final svgContent = await DefaultAssetBundle.of(context)
          .loadString(_floorAssets[_selectedFloor!]!);
      print('SVG Content Length: ${svgContent.length}');
      print(
          'SVG First 500 chars: ${svgContent.substring(0, svgContent.length > 500 ? 500 : svgContent.length)}');

      // Check for color definitions
      if (svgContent.contains('fill=')) {
        print('SVG contains fill attributes');
      }
      if (svgContent.contains('style=')) {
        print('SVG contains style attributes');
      }
      if (svgContent.contains('#')) {
        print('SVG contains color codes');
      }
    } catch (e) {
      print('Error loading SVG: $e');
    }
  }

  Widget _buildWebViewSvg() {
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context)
          .loadString(_floorAssets[_selectedFloor!]!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final htmlContent = '''
          <!DOCTYPE html>
          <html>
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                  body {
                      margin: 0;
                      padding: 0;
                      background-color: white;
                      overflow: hidden;
                      display: flex;
                      justify-content: center;
                      align-items: center;
                      height: 100vh;
                  }
                  svg {
                      max-width: 100%;
                      max-height: 100%;
                      width: auto;
                      height: auto;
                  }
              </style>
          </head>
          <body>
              ${snapshot.data!}
          </body>
          </html>
          ''';

          return WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadHtmlString(htmlContent),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading SVG: ${snapshot.error}',
              style: TextStyle(color: Colors.red),
            ),
          );
        } else {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
              ),
            ),
            SizedBox(width: 10),
            Text('FITMaps'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Student User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'student@fit.edu',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_outlined, color: AppTheme.primaryColor),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: AppTheme.primaryColor),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.history, color: AppTheme.primaryColor),
              title: Text('Search History'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.bookmark_outline,
                color: AppTheme.primaryColor,
              ),
              title: Text('Saved Locations'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(
                Icons.settings_outlined,
                color: AppTheme.primaryColor,
              ),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.help_outline, color: AppTheme.primaryColor),
              title: Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Divider(),
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: AppTheme.primaryColor,
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Search Location',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              hintText: 'e.g., Room 101, Hall A',
                              prefixIcon: Icon(Icons.room_outlined, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.layers,
                                color: AppTheme.primaryColor,
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Select Floor',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedFloor,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.stairs_outlined, size: 20),
                              hintText: 'Choose a floor',
                            ),
                            items: _floors.map((floor) {
                              return DropdownMenuItem(
                                value: floor,
                                child: Text(floor),
                              );
                            }).toList(),
                            onChanged: _onFloorChanged,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty &&
                      _selectedFloor != null) ...[
                    SizedBox(height: 12),
                    Card(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Search Summary',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                            Divider(height: 16),
                            _buildSummaryRow(
                              Icons.location_on,
                              'Location',
                              _searchController.text,
                            ),
                            SizedBox(height: 8),
                            _buildSummaryRow(
                              Icons.layers,
                              'Floor',
                              _selectedFloor!,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!_showMap && _selectedFloor != null) ...[
                    SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_selectedFloor Map Available',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Click to view the floor plan',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showMap = true;
                                });
                              },
                              icon: Icon(Icons.visibility, size: 16),
                              label: Text('Show Map'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_showMap && _selectedFloor != null) ...[
                    SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  color: AppTheme.primaryColor,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '$_selectedFloor Map',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _showMap = false;
                                    });
                                  },
                                  tooltip: 'Hide Map',
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Container(
                              height: 400,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.dividerColor,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    _buildColoredMap(),
                                    // Control buttons
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Column(
                                        children: [
                                          FloatingActionButton.small(
                                            onPressed: _setUserLocation,
                                            backgroundColor: Colors.blue,
                                            child: Icon(Icons.person_pin,
                                                color: Colors.white, size: 16),
                                            tooltip: 'Set User Location',
                                          ),
                                          SizedBox(height: 8),
                                          FloatingActionButton.small(
                                            onPressed: _clearPath,
                                            backgroundColor: Colors.red,
                                            child: Icon(Icons.clear,
                                                color: Colors.white, size: 16),
                                            tooltip: 'Clear Path',
                                          ),
                                          SizedBox(height: 8),
                                          FloatingActionButton.small(
                                            onPressed: _debugSvgContent,
                                            backgroundColor: Colors.orange,
                                            child: Icon(Icons.bug_report,
                                                color: Colors.white, size: 16),
                                            tooltip: 'Debug SVG',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _showMap
                                ? 'Use the map above to navigate or search for specific locations'
                                : 'Enter your destination and floor to start navigation',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSearching ? null : _handleSearch,
                  icon: _isSearching
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.navigation, size: 20),
                  label: Text(
                    _isSearching ? 'Searching...' : 'Start Navigation',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for drawing paths between points
class PathPainter extends CustomPainter {
  final List<LatLng> points;

  PathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = ui.Path();
    path.moveTo(points[0].longitude, points[0].latitude);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].longitude, points[i].latitude);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
