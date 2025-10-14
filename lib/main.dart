import 'package:flutter/material.dart';
import 'package:fitmaps/config/theme.dart';
import 'package:fitmaps/screens/splash_screen.dart';

void main() {
  runApp(const FITMapsApp());
}

class FITMapsApp extends StatelessWidget {
  const FITMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FITMaps',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(),
    );
  }
}
