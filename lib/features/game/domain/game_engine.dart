import 'dart:math';
import 'block.dart';
import 'board.dart';
import 'shapes.dart';

class ClearResult {
  final Board board;
  final int lines;
  const ClearResult(this.board, this.lines);
}

/// Pure game logic - no Flutter, no Riverpod.
class GameEngine {
  static const _lineBonus = [0, 10, 25, 45, 70];

  bool canPlace(Board b, Block k, int x, int y) {
    for (final c in k.cells) {
      final tx = x + c.x, ty = y + c.y;
      if (tx < 0 || ty < 0 || tx >= b.size || ty >= b.size) return false;
      if (b.cells[ty][tx]) return false;
    }
    return true;
  }

  Board placeBlock(Board b, Block k, int x, int y) {
    final n = b.copy();
    for (final c in k.cells) {
      n.cells[y + c.y][x + c.x] = true;
    }
    return n;
  }

  List<int> findCompletedRows(Board b) =>
      [for (var y = 0; y < b.size; y++) if (b.cells[y].every((c) => c)) y];

  List<int> findCompletedColumns(Board b) =>
      [for (var x = 0; x < b.size; x++) if (List.generate(b.size, (y) => b.cells[y][x]).every((c) => c)) x];

  ClearResult clearLines(Board b) {
    final rows = findCompletedRows(b), cols = findCompletedColumns(b);
    final n = b.copy();
    for (final y in rows) {
      for (var x = 0; x < n.size; x++) { n.cells[y][x] = false; }
    }
    for (final x in cols) {
      for (var y = 0; y < n.size; y++) { n.cells[y][x] = false; }
    }
    return ClearResult(n, rows.length + cols.length);
  }

  /// combo >= 1 when lines were cleared. e.g. base 20 x combo 3 = 60.
  int calculateScore(int cellsPlaced, int lines, int combo) {
    final base = lines < _lineBonus.length ? _lineBonus[lines] : 70 + (lines - 4) * 30;
    return cellsPlaced + base * (combo < 1 ? 1 : combo);
  }

  bool blockFitsAnywhere(Board b, Block k) {
    for (var y = 0; y < b.size; y++) {
      for (var x = 0; x < b.size; x++) {
        if (canPlace(b, k, x, y)) return true;
      }
    }
    return false;
  }

  bool hasAvailableMove(Board b, Iterable<Block> blocks) =>
      blocks.any((k) => blockFitsAnywhere(b, k));

  /// Random 3 blocks; retries so at least one is playable.
  List<Block> generateBlocks(Board b, Random rng) {
    List<Block> pick() => List.generate(3, (_) {
          final i = rng.nextInt(blockShapes.length);
          return Block.fromPattern('$i-${rng.nextInt(1 << 30)}', blockShapes[i], i % 6);
        });
    for (var i = 0; i < 30; i++) {
      final set = pick();
      if (hasAvailableMove(b, set)) return set;
    }
    return List.generate(3, (_) => Block.fromPattern('s-${rng.nextInt(1 << 30)}', ['#'], 0));
  }
}
