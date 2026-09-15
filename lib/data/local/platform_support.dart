import 'package:flutter/foundation.dart';


bool get supportsMobileSqlite =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
