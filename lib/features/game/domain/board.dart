class Board {
  final int size;
  final List<List<bool>> cells; // cells[row][col], true = filled
  Board(this.size, this.cells);
  factory Board.empty([int size = 8]) =>
      Board(size, List.generate(size, (_) => List.filled(size, false)));
  Board copy() => Board(size, [for (final r in cells) List<bool>.from(r)]);
}
