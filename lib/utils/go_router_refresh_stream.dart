import 'dart:async';
import 'package:flutter/foundation.dart';

/// A minimal Listenable that triggers GoRouter refreshes from any Stream.
/// Use it in GoRouter.refreshListenable to rebuild routes on auth/role changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}