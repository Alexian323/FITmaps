import 'package:flutter/material.dart';
import 'package:fitmaps/config/theme.dart';
// import 'package:fitmaps/screens/login_screen.dart'; // Commented out - navigating directly to home
import 'package:fitmaps/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome(); // Changed from _navigateToLogin to _navigateToHome
  }

  Future<void> _navigateToHome() async {
    // Changed method name and navigation target
    await Future.delayed(Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                HomeScreen()), // Navigate directly to HomeScreen
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 32),
            Text(
              'FITMaps',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'FIT Faculty Navigation App',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
