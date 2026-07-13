import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global messenger handle, wired into `MaterialApp.scaffoldMessengerKey`,
/// so non-widget layers (foreground push banners) can show snackbars
/// without a BuildContext.
final Provider<GlobalKey<ScaffoldMessengerState>>
scaffoldMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (_) => GlobalKey<ScaffoldMessengerState>(),
);
