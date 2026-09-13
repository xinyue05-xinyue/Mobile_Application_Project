import 'package:flutter/material.dart';

/// Gives app-wide flows, such as password recovery deep links, access to the
/// visible route stack without relying on a screen's local BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
