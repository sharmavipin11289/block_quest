import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage.dart';
import '../domain/block.dart';
import '../domain/board.dart';
import '../domain/game_engine.dart';

enum GameStatus {
  idle,
  playing,
  paused,
  gameOver,
  levelComplete,
  campaignComplete,
}

enum GameMode { adventure, classic }

class GameState {
  static const maxLevel = 30;

  final Board board;
  final List<Block?> availableBlocks;
  final int score, bestScore, combo, linesCleared, level, levelLinesCleared;
  final GameStatus status;
  final GameMode mode;
  final bool newBest;
  int get linesRequired => level + 2;

  const GameState({
    required this.board,
    required this.availableBlocks,
    this.score = 0,
    this.bestScore = 0,
    this.combo = 0,
    this.linesCleared = 0,
    this.level = 1,
    this.levelLinesCleared = 0,
    this.status = GameStatus.idle,
    this.mode = GameMode.adventure,
    this.newBest = false,
  });
}

class GameViewModel extends Notifier<GameState> {
  final _engine = GameEngine();
  final _rng = Random();

  @override
  GameState build() => GameState(
    board: Board.empty(),
    availableBlocks: const [null, null, null],
    bestScore: ref.read(prefsProvider).getInt(Keys.bestScore) ?? 0,
    level: _savedLevel,
  );

  GameEngine get engine => _engine;

  String _bestScoreKey(GameMode mode) => switch (mode) {
    GameMode.adventure => Keys.bestScore,
    GameMode.classic => Keys.classicBestScore,
  };

  int get _savedLevel =>
      (ref.read(prefsProvider).getInt(Keys.unlockedLevel) ?? 1)
          .clamp(1, GameState.maxLevel)
          .toInt();

  void start({GameMode mode = GameMode.adventure}) {
    final board = Board.empty();
    final prefs = ref.read(prefsProvider);
    prefs.setInt(Keys.gamesPlayed, (prefs.getInt(Keys.gamesPlayed) ?? 0) + 1);
    final level = mode == GameMode.adventure ? _savedLevel : 1;
    if (mode == GameMode.adventure &&
        (prefs.getBool(Keys.campaignComplete) ?? false)) {
      state = GameState(
        board: board,
        availableBlocks: const [null, null, null],
        bestScore: prefs.getInt(_bestScoreKey(mode)) ?? 0,
        level: GameState.maxLevel,
        mode: mode,
        status: GameStatus.campaignComplete,
      );
      return;
    }
    state = GameState(
      board: board,
      availableBlocks: _engine.generateBlocks(board, _rng),
      bestScore: prefs.getInt(_bestScoreKey(mode)) ?? 0,
      level: level,
      mode: mode,
      status: GameStatus.playing,
    );
  }

  void nextLevel() {
    final s = state;
    if (s.status != GameStatus.levelComplete) return;

    final nextLevel = s.level + 1;
    final board = Board.empty();
    state = GameState(
      board: board,
      availableBlocks: _engine.generateBlocks(board, _rng),
      score: s.score,
      bestScore: s.bestScore,
      level: nextLevel,
      mode: s.mode,
      status: GameStatus.playing,
    );
  }

  void replayCampaign() {
    final prefs = ref.read(prefsProvider);
    prefs.setInt(Keys.unlockedLevel, 1);
    prefs.setBool(Keys.campaignComplete, false);
    prefs.setInt(Keys.gamesPlayed, (prefs.getInt(Keys.gamesPlayed) ?? 0) + 1);
    final board = Board.empty();
    state = GameState(
      board: board,
      availableBlocks: _engine.generateBlocks(board, _rng),
      bestScore: state.bestScore,
      mode: GameMode.adventure,
      status: GameStatus.playing,
    );
  }

  /// Returns true if the block was placed.
  bool placeBlock(int index, int x, int y) {
    final s = state;
    if (s.status != GameStatus.playing) return false;
    final block = s.availableBlocks[index];
    if (block == null || !_engine.canPlace(s.board, block, x, y)) return false;

    final placed = _engine.placeBlock(s.board, block, x, y);
    final result = _engine.clearLines(placed);
    final combo = result.lines > 0 ? s.combo + 1 : 0;
    final score =
        s.score +
        _engine.calculateScore(block.cells.length, result.lines, combo);
    final levelLinesCleared = s.mode == GameMode.adventure
        ? s.levelLinesCleared + result.lines
        : 0;

    var blocks = [...s.availableBlocks]..[index] = null;
    if (blocks.every((b) => b == null)) {
      blocks = _engine.generateBlocks(result.board, _rng);
    }
    final over = !_engine.hasAvailableMove(
      result.board,
      blocks.whereType<Block>(),
    );

    final newBest = s.newBest || (score > s.bestScore && s.bestScore > 0);
    final best = max(score, s.bestScore);
    final prefs = ref.read(prefsProvider);
    if (best > s.bestScore) {
      prefs.setInt(_bestScoreKey(s.mode), best);
    }
    if (result.lines > 0) {
      prefs.setInt(
        Keys.totalLines,
        (prefs.getInt(Keys.totalLines) ?? 0) + result.lines,
      );
    }
    final levelComplete =
        s.mode == GameMode.adventure && levelLinesCleared >= s.linesRequired;
    final campaignComplete =
        s.mode == GameMode.adventure &&
        levelComplete &&
        s.level == GameState.maxLevel;
    if (levelComplete && !campaignComplete) {
      prefs.setInt(Keys.unlockedLevel, max(_savedLevel, s.level + 1));
    }
    if (campaignComplete) {
      prefs.setBool(Keys.campaignComplete, true);
    }

    state = GameState(
      board: result.board,
      availableBlocks: blocks,
      score: score,
      bestScore: best,
      combo: combo,
      linesCleared: s.linesCleared + result.lines,
      level: s.level,
      levelLinesCleared: levelLinesCleared,
      mode: s.mode,
      status: campaignComplete
          ? GameStatus.campaignComplete
          : levelComplete
          ? GameStatus.levelComplete
          : over
          ? GameStatus.gameOver
          : GameStatus.playing,
      newBest: newBest,
    );
    return true;
  }
}

final gameProvider = NotifierProvider<GameViewModel, GameState>(
  GameViewModel.new,
);
