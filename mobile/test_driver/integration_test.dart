import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Receives the screenshots taken by integration_test/screenshots_test.dart
/// and writes them into the repo's docs/screenshots folder.
Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final File file = File('../docs/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
