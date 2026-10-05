import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum GameSound {
  blockSelected,
  blockPlaced,
  invalidDrop,
  lineCleared,
  doubleLineCleared,
  multipleLinesCleared,
  combo,
  gameOver,
  levelComplete,
}

class GameSoundService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(GameSound sound, {required bool enabled}) async {
    if (!enabled) return;

    final asset = switch (sound) {
      GameSound.blockSelected => 'audio/block_selected.wav',
      GameSound.blockPlaced => 'audio/block_placed.wav',
      GameSound.invalidDrop => 'audio/invalid_drop.wav',
      GameSound.lineCleared => 'audio/line_cleared.wav',
      GameSound.doubleLineCleared => 'audio/double_line_cleared.wav',
      GameSound.multipleLinesCleared => 'audio/multiple_lines_cleared.wav',
      GameSound.combo => 'audio/combo.wav',
      GameSound.gameOver => 'audio/game_over.wav',
      GameSound.levelComplete => 'audio/level_complete.wav',
    };

    try {
      await _player.stop();
      await _player.play(AssetSource(asset), volume: .75);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'game sound',
          context: ErrorDescription('while playing $asset'),
        ),
      );
    }
  }

  Future<void> dispose() => _player.dispose();
}
