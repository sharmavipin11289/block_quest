import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/storage.dart';

class Settings {
  final bool sound, vibration;
  const Settings(this.sound, this.vibration);
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    final p = ref.read(prefsProvider);
    return Settings(p.getBool(Keys.sound) ?? true, p.getBool(Keys.vibration) ?? true);
  }

  void setSound(bool v) {
    ref.read(prefsProvider).setBool(Keys.sound, v);
    state = Settings(v, state.vibration);
  }

  void setVibration(bool v) {
    ref.read(prefsProvider).setBool(Keys.vibration, v);
    state = Settings(state.sound, v);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
