import 'dart:math';

class Block {
  final String id;
  final List<Point<int>> cells; // x = column, y = row
  final int colorIndex;
  const Block(this.id, this.cells, this.colorIndex);

  factory Block.fromPattern(String id, List<String> rows, int colorIndex) {
    final cells = <Point<int>>[];
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] == '#') cells.add(Point(x, y));
      }
    }
    return Block(id, cells, colorIndex);
  }

  int get width => cells.map((c) => c.x).reduce(max) + 1;
  int get height => cells.map((c) => c.y).reduce(max) + 1;
}
