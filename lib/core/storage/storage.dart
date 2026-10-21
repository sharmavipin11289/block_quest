import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() once SharedPreferences is ready.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

class Keys {
  static const bestScore = 'bestScore';
  static const classicBestScore = 'classicBestScore';
  static const sound = 'soundEnabled';
  static const vibration = 'vibrationEnabled';
  static const gamesPlayed = 'gamesPlayed';
  static const totalLines = 'totalLinesCleared';
  static const unlockedLevel = 'unlockedLevel';
  static const campaignComplete = 'campaignComplete';
}
