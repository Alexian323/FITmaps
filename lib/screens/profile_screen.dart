import 'package:flutter/material.dart';
import 'package:fitmaps/config/theme.dart';
// import 'package:fitmaps/screens/login_screen.dart'; // Commented out - navigating to splash instead
import 'package:fitmaps/screens/splash_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _handleLogout(BuildContext context) {
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
                MaterialPageRoute(builder: (context) => SplashScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 8),
            Image.asset('assets/images/logo.png', width: 100, height: 100),
            SizedBox(height: 16),
            Text(
              'Student User',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'student@fit.edu',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  _buildProfileItem(
                    context,
                    Icons.history,
                    'Search History',
                    'View your recent searches',
                    () {},
                  ),
                  Divider(height: 1),
                  _buildProfileItem(
                    context,
                    Icons.bookmark_outline,
                    'Saved Locations',
                    'Quick access to favorite places',
                    () {},
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _buildProfileItem(
                    context,
                    Icons.help_outline,
                    'Help & Support',
                    'Get assistance and FAQs',
                    () {},
                  ),
                  Divider(height: 1),
                  _buildProfileItem(
                    context,
                    Icons.info_outline,
                    'About',
                    'Version 1.0.0',
                    () {},
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Card(
              child: _buildProfileItem(
                context,
                Icons.logout,
                'Logout',
                'Sign out of your account',
                () => _handleLogout(context),
                isDestructive: true,
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : AppTheme.primaryLight.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
