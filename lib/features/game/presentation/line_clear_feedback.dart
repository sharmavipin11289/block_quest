class LineClearFeedback {
  const LineClearFeedback._();

  static String messageForLines(int linesCleared) {
    if (linesCleared <= 0) {
      throw ArgumentError.value(linesCleared, 'linesCleared', 'Must be positive');
    }
    return switch (linesCleared) {
      1 => 'SMOOTH!',
      2 => 'GREAT!',
      3 => 'AWESOME!',
      4 => 'AMAZING!',
      _ => 'UNBELIEVABLE!',
    };
  }

  static String? messageForCombo(int combo) => switch (combo) {
    >= 6 => 'UNSTOPPABLE!',
    5 => 'ON FIRE!',
    >= 2 => 'COMBO x$combo',
    _ => null,
  };
}
