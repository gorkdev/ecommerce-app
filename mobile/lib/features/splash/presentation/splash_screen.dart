import 'package:flutter/material.dart';

/// Shown only while the app decides whether a stored session is still valid.
/// The router redirects away as soon as that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const String path = '/splash';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
