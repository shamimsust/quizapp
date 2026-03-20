import 'package:firebase_database/firebase_database.dart';

class ServerTime {
  /// Streams the clock offset between the device and Firebase servers.
  /// Positive means device is ahead, negative means device is behind.
  static Stream<int> offsetStream() {
    return FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue
        .map((e) => (e.snapshot.value as int?) ?? 0);
  }

  /// Helper to get the current synchronized Unix timestamp in milliseconds.
  /// Use this for comparing against 'expiresAt' or 'durationMs'.
  static int now(int offset) {
    return DateTime.now().millisecondsSinceEpoch + offset;
  }
}