import 'package:flutter/foundation.dart';

// PLATFORM SUPPORT: Enables SQLite only on supported Android and iOS devices.

bool get supportsMobileSqlite =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
