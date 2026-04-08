import 'dart:async';
import 'package:flutter/material.dart';

import 'bootstrap/boot_app.dart';
import 'core/globals.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const BootApp());
    },
    (error, stack) {
      reportAppIssue('ZONED: $error\n\n$stack');
    },
  );
}
