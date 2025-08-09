import 'package:flutter/material.dart';
import 'dart:async';
import 'home/dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Row with car and radio icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car, size: 72, color: theme.colorScheme.onBackground),
                const SizedBox(width: 24),
                Icon(Icons.radio, size: 72, color: theme.colorScheme.onBackground),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              "BenshiDash",
              style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onBackground,
                  fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 12),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onBackground),
            ),
          ],
        ),
      ),
    );
  }
}