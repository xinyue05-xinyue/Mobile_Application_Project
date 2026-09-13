import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class PasswordRecoveryService {
  PasswordRecoveryService._();

  static final instance = PasswordRecoveryService._();

  final ValueNotifier<bool> active = ValueNotifier<bool>(false);
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> initialize() async {
    try {
      _handleLink(await _appLinks.getInitialLink());
    } catch (_) {
    }
    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (_) {},
    );
  }

  void markActive() => active.value = true;

  void complete() => active.value = false;

  void _handleLink(Uri? uri) {
    if (uri == null) return;
    final isAppRecoveryLink =
        uri.scheme == 'io.supabase.mydarah' &&
        uri.host == 'reset-password';
    final isWebRecoveryLink =
        uri.queryParameters['type'] == 'recovery' ||
        uri.fragment.contains('type=recovery');
    if (isAppRecoveryLink || isWebRecoveryLink) markActive();
  }
}
