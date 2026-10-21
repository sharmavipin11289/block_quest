import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../settings/data/settings_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/block.dart';
import '../domain/board.dart';
import 'game_viewmodel.dart';
import 'game_sound_service.dart';
import 'line_clear_feedback.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.mode = GameMode.adventure});

  final GameMode mode;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  final _boardKey = GlobalKey();
  late final AnimationController _gelMotion;
  late final AnimationController _feedbackMotion;
  late final Animation<double> _feedbackScale;
  late final Animation<double> _feedbackOpacity;
  late final Animation<double> _feedbackLift;
  late final GameSoundService _soundService;
  double _cell = 40;
  ({int x, int y, int i})? _ghost;
  final Map<int, Color> _cellColors = {};
  final List<_ClearEffect> _clearEffects = [];
  String? _lineClearMessage;
  String? _comboMessage;

  @override
  void initState() {
    super.initState();
    _soundService = GameSoundService();
    _gelMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _feedbackMotion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() {
              _lineClearMessage = null;
              _comboMessage = null;
            });
          }
        });
    _feedbackScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: .65,
          end: 1.14,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.14,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 11,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 75),
    ]).animate(_feedbackMotion);
    _feedbackOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _feedbackMotion,
        curve: const Interval(.6, 1, curve: Curves.easeIn),
      ),
    );
    _feedbackLift = Tween<double>(
      begin: 0.0,
      end: -18.0,
    ).animate(CurvedAnimation(parent: _feedbackMotion, curve: Curves.easeIn));
    Future.microtask(
      () => ref.read(gameProvider.notifier).start(mode: widget.mode),
    );
  }

  @override
  void dispose() {
    _gelMotion.dispose();
    _feedbackMotion.dispose();
    unawaited(_soundService.dispose());
    for (final effect in _clearEffects) {
      effect.controller.dispose();
    }
    super.dispose();
  }

  (int, int)? _toCell(Offset global, int boardSize) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || boardSize == 0) return null;
    final p = box.globalToLocal(global);
    if (p.dx < 0 ||
        p.dy < 0 ||
        p.dx >= box.size.width ||
        p.dy >= box.size.height) {
      return null;
    }
    final cellWidth = box.size.width / boardSize;
    final cellHeight = box.size.height / boardSize;
    return (
      (p.dx / cellWidth).round().clamp(0, boardSize - 1),
      (p.dy / cellHeight).round().clamp(0, boardSize - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final vm = ref.read(gameProvider.notifier);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gradientTop,
              AppColors.gradientMiddle,
              AppColors.gradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 600;
              final wideLayout =
                  constraints.maxWidth > constraints.maxHeight &&
                  constraints.maxWidth >= 700;
              final horizontalPadding = constraints.maxWidth < 420
                  ? 16.0
                  : 32.0;
              final maxBoardWidth = constraints.maxWidth >= 900 ? 560.0 : 480.0;
              final widthSide = wideLayout
                  ? min(maxBoardWidth, constraints.maxWidth * .56)
                  : min(
                      maxBoardWidth,
                      constraints.maxWidth - horizontalPadding,
                    );
              final heightSide = wideLayout
                  ? max(0.0, constraints.maxHeight - 32)
                  : max(0.0, constraints.maxHeight - (compact ? 260 : 372));
              final side = min(widthSide, heightSide);
              final trayExtent = min(110.0, max(58.0, side * .27));
              final dragPadding = wideLayout
                  ? 8.0
                  : compact
                  ? 20.0
                  : 56.0;
              _cell = side / g.board.size;

              final ghostBlock = _ghost == null
                  ? null
                  : g.availableBlocks[_ghost!.i];
              final ghostValid =
                  ghostBlock != null &&
                  vm.engine.canPlace(g.board, ghostBlock, _ghost!.x, _ghost!.y);

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wideLayout ? 1100 : 760,
                  ),
                  child: Stack(
                    children: [
                      wideLayout
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          compact ? 12 : 20,
                                          compact ? 0 : 8,
                                          compact ? 12 : 20,
                                          0,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.emoji_events_rounded,
                                              color: AppColors.accent,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 6),
                                            _OutlinedArcadeText(
                                              '${g.bestScore}',
                                              style: const TextStyle(
                                                color: AppColors.accent,
                                                fontSize: 27,
                                                fontWeight: FontWeight.w900,
                                              ),
                                              outlineColor: const Color(
                                                0xFF123B8D,
                                              ),
                                              outlineWidth: 2.5,
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              tooltip: 'Settings',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: const Icon(
                                                Icons.settings_rounded,
                                                color: AppColors.filled,
                                                size: 30,
                                              ),
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SettingsScreen(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: compact ? 0 : 4,
                                        ),
                                        child: Column(
                                          children: [
                                            _OutlinedArcadeText(
                                              '${g.score}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: compact ? 52 : 66,
                                                fontWeight: FontWeight.w900,
                                                height: 1,
                                                shadows: [
                                                  Shadow(
                                                    color: AppColors.gradientTop
                                                        .withValues(alpha: .5),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              outlineColor: const Color(
                                                0xFF123B8D,
                                              ),
                                              outlineWidth: 3.5,
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'SCORE',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: _progressHeader(
                                          g,
                                          height: compact ? 24 : 28,
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          for (var i = 0; i < 3; i++)
                                            _slot(
                                              g.availableBlocks[i],
                                              i,
                                              trayExtent,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildBoard(
                                  g,
                                  vm,
                                  side,
                                  dragPadding,
                                  ghostBlock,
                                  ghostValid,
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    compact ? 12 : 20,
                                    compact ? 0 : 8,
                                    compact ? 12 : 20,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        color: AppColors.accent,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 6),
                                      _OutlinedArcadeText(
                                        '${g.bestScore}',
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 27,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        outlineColor: const Color(0xFF123B8D),
                                        outlineWidth: 2.5,
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Settings',
                                        visualDensity: compact
                                            ? VisualDensity.compact
                                            : VisualDensity.standard,
                                        icon: const Icon(
                                          Icons.settings_rounded,
                                          color: AppColors.filled,
                                          size: 30,
                                        ),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SettingsScreen(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: compact ? 0 : 4,
                                  ),
                                  child: Column(
                                    children: [
                                      _OutlinedArcadeText(
                                        '${g.score}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: compact ? 52 : 66,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                          shadows: [
                                            Shadow(
                                              color: AppColors.gradientTop
                                                  .withValues(alpha: .5),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        outlineColor: const Color(0xFF123B8D),
                                        outlineWidth: 3.5,
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'SCORE',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: _progressHeader(
                                    g,
                                    height: compact ? 24 : 28,
                                  ),
                                ),
                                _buildBoard(
                                  g,
                                  vm,
                                  side,
                                  dragPadding,
                                  ghostBlock,
                                  ghostValid,
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    for (var i = 0; i < 3; i++)
                                      _slot(
                                        g.availableBlocks[i],
                                        i,
                                        trayExtent,
                                      ),
                                  ],
                                ),
                                SizedBox(height: compact ? 8 : 24),
                              ],
                            ),
                      if (g.status == GameStatus.gameOver) _gameOver(g, vm),
                      if (widget.mode == GameMode.adventure &&
                          g.status == GameStatus.levelComplete)
                        _levelComplete(g, vm),
                      if (widget.mode == GameMode.adventure &&
                          g.status == GameStatus.campaignComplete)
                        _campaignComplete(g, vm),
                      if (_lineClearMessage case final lineMessage?)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _feedbackMotion,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _feedbackOpacity.value,
                                  child: Transform.translate(
                                    offset: Offset(0, _feedbackLift.value),
                                    child: Transform.scale(
                                      scale: _feedbackScale.value,
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: _OutlinedArcadeText(
                                          lineMessage,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: compact ? 42 : 54,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xCC08276E),
                                                blurRadius: 12,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          outlineColor: const Color(0xFF123B8D),
                                          outlineWidth: compact ? 5 : 6,
                                        ),
                                      ),
                                      if (_comboMessage
                                          case final comboMessage?)
                                        _ComboArcadeText(
                                          comboMessage,
                                          compact: compact,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(
    GameState g,
    GameViewModel vm,
    double side,
    double dragPadding,
    Block? ghostBlock,
    bool ghostValid,
  ) => DragTarget<int>(
    onWillAcceptWithDetails: (_) => true,
    onLeave: (_) => setState(() => _ghost = null),
    onMove: (d) {
      final c = _toCell(d.offset, g.board.size);
      if (c != null) {
        setState(() => _ghost = (x: c.$1, y: c.$2, i: d.data));
      }
    },
    onAcceptWithDetails: (d) {
      final c = _toCell(d.offset, g.board.size);
      final block = g.availableBlocks[d.data];
      final placement =
          c != null &&
              block != null &&
              vm.engine.canPlace(g.board, block, c.$1, c.$2)
          ? vm.engine.placeBlock(g.board, block, c.$1, c.$2)
          : null;
      final canPlace = placement != null;
      final rows = placement == null
          ? <int>[]
          : vm.engine.findCompletedRows(placement);
      final columns = placement == null
          ? <int>[]
          : vm.engine.findCompletedColumns(placement);
      final clearEffect = placement == null || (rows.isEmpty && columns.isEmpty)
          ? null
          : _makeClearEffect(placement, rows, columns, block!, c!.$1, c.$2);
      final ok = canPlace && vm.placeBlock(d.data, c!.$1, c.$2);
      if (ok && ref.read(settingsProvider).vibration) {
        HapticFeedback.lightImpact();
      }
      final soundEnabled = ref.read(settingsProvider).sound;
      if (ok) {
        final next = ref.read(gameProvider);
        final linesCleared = next.linesCleared - g.linesCleared;
        if (linesCleared > 0) {
          _showLineClearFeedback(linesCleared, next.combo);
        }
        final sound =
            next.status == GameStatus.levelComplete ||
                next.status == GameStatus.campaignComplete
            ? GameSound.levelComplete
            : next.status == GameStatus.gameOver
            ? GameSound.gameOver
            : linesCleared >= 3
            ? GameSound.multipleLinesCleared
            : linesCleared == 2
            ? GameSound.doubleLineCleared
            : linesCleared == 1 && next.combo > 1
            ? GameSound.combo
            : linesCleared == 1
            ? GameSound.lineCleared
            : GameSound.blockPlaced;
        unawaited(_soundService.play(sound, enabled: soundEnabled));
      } else {
        unawaited(
          _soundService.play(GameSound.invalidDrop, enabled: soundEnabled),
        );
      }
      if (ok && block != null) {
        setState(() {
          for (final point in block.cells) {
            _cellColors[(c.$2 + point.y) * g.board.size + c.$1 + point.x] =
                AppColors.blocks[block.colorIndex];
          }
          if (clearEffect != null) {
            for (var y = 0; y < g.board.size; y++) {
              for (var x = 0; x < g.board.size; x++) {
                if (rows.contains(y) || columns.contains(x)) {
                  _cellColors.remove(y * g.board.size + x);
                }
              }
            }
            _startClearEffect(clearEffect);
          }
        });
      }
      setState(() => _ghost = null);
    },
    builder: (_, _, _) => Padding(
      padding: EdgeInsets.only(bottom: dragPadding),
      child: Container(
        key: _boardKey,
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _BoardPainter(
                  g.board,
                  ghostBlock,
                  _ghost?.x ?? 0,
                  _ghost?.y ?? 0,
                  ghostValid,
                  _cellColors,
                  _gelMotion,
                ),
              ),
              for (final effect in _clearEffects)
                CustomPaint(
                  painter: _ClearPainter(
                    effect.cells,
                    g.board.size,
                    effect.controller,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _progressHeader(GameState g, {required double height}) => SizedBox(
    height: height,
    width: double.infinity,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (widget.mode == GameMode.adventure)
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(right: g.combo > 1 ? 64 : 0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'LEVEL ${g.level}/${GameState.maxLevel}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(left: g.combo > 1 ? 64 : 0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'LINES ${g.levelLinesCleared}/${g.linesRequired}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (g.combo > 1)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'COMBO ×${g.combo}',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _slot(Block? b, int i, double extent) {
    final small = b == null
        ? _cell * .55
        : min(_cell * .55, extent / max(b.width, b.height));
    return SizedBox(
      width: extent,
      height: extent,
      child: Center(
        child: b == null
            ? null
            : Draggable<int>(
                data: i,
                onDragStarted: () => unawaited(
                  _soundService.play(
                    GameSound.blockSelected,
                    enabled: ref.read(settingsProvider).sound,
                  ),
                ),
                dragAnchorStrategy: (d, ctx, pos) =>
                    Offset(b.width * _cell / 2, b.height * _cell / 2),
                feedback: Material(
                  color: Colors.transparent,
                  child: BlockView(b, _cell, _gelMotion),
                ),
                childWhenDragging: Opacity(
                  opacity: .25,
                  child: BlockView(b, small, _gelMotion),
                ),
                child: BlockView(b, small, _gelMotion),
              ),
      ),
    );
  }

  _ClearEffect _makeClearEffect(
    Board board,
    List<int> rows,
    List<int> columns,
    Block placedBlock,
    int placeX,
    int placeY,
  ) {
    final placedCells = {
      for (final point in placedBlock.cells)
        (placeY + point.y) * board.size + placeX + point.x,
    };
    final cells = <_ClearCell>[];
    for (var y = 0; y < board.size; y++) {
      for (var x = 0; x < board.size; x++) {
        final inRow = rows.contains(y);
        final inColumn = columns.contains(x);
        if (!inRow && !inColumn) continue;
        final key = y * board.size + x;
        cells.add(
          _ClearCell(
            x,
            y,
            _cellColors[key] ??
                (placedCells.contains(key)
                    ? AppColors.blocks[placedBlock.colorIndex]
                    : AppColors.filled),
            inRow,
            inColumn,
          ),
        );
      }
    }
    return _ClearEffect(cells);
  }

  void _startClearEffect(_ClearEffect effect) {
    late final AnimationController controller;
    controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 460),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _clearEffects.remove(effect));
            controller.dispose();
          }
        });
    effect.controller = controller;
    _clearEffects.add(effect);
    controller.forward();
  }

  void _restart(GameViewModel vm) {
    _clearVisuals();
    vm.start(mode: widget.mode);
  }

  void _clearVisuals() {
    setState(() {
      _cellColors.clear();
      _lineClearMessage = null;
      _comboMessage = null;
      _feedbackMotion.stop();
      _feedbackMotion.reset();
      for (final effect in _clearEffects) {
        effect.controller.dispose();
      }
      _clearEffects.clear();
    });
  }

  void _showLineClearFeedback(int linesCleared, int combo) {
    setState(() {
      _lineClearMessage = LineClearFeedback.messageForLines(linesCleared);
      _comboMessage = LineClearFeedback.messageForCombo(combo);
      _feedbackMotion
        ..stop()
        ..reset()
        ..forward();
    });
  }

  void _advanceLevel(GameViewModel vm) {
    _clearVisuals();
    vm.nextLevel();
  }

  Widget _levelComplete(GameState g, GameViewModel vm) => _CelebrationOverlay(
    title: 'HURRAY!',
    subtitle:
        'LEVEL ${g.level} COMPLETE!\nYou cleared ${g.levelLinesCleared} lines.',
    buttonLabel: 'LEVEL ${g.level + 1}',
    onPressed: () => _advanceLevel(vm),
    onHome: () => Navigator.pop(context),
  );

  Widget _campaignComplete(GameState g, GameViewModel vm) =>
      _CelebrationOverlay(
        title: 'HURRAY!',
        subtitle:
            'ALL LEVELS COMPLETE!\nYou beat all ${GameState.maxLevel} levels.',
        buttonLabel: 'PLAY AGAIN',
        onPressed: () {
          _clearVisuals();
          vm.replayCampaign();
        },
        onHome: () => Navigator.pop(context),
      );

  Widget _gameOver(GameState g, GameViewModel vm) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 520;
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientTop, AppColors.gradientBottom],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max(0, constraints.maxHeight - 32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NO SPACE LEFT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: compact ? 34 : 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  if (g.newBest) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'NEW BEST!',
                      style: TextStyle(
                        color: AppColors.filled,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                  SizedBox(height: compact ? 20 : 32),
                  const Text(
                    'SCORE',
                    style: TextStyle(
                      color: AppColors.filled,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  _OutlinedArcadeText(
                    '${g.score}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 68 : 82,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                    outlineColor: const Color(0xFF123B8D),
                    outlineWidth: 4,
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  const Text(
                    'BEST SCORE',
                    style: TextStyle(
                      color: AppColors.filled,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  _OutlinedArcadeText(
                    '${g.bestScore}',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: compact ? 40 : 48,
                      fontWeight: FontWeight.w900,
                    ),
                    outlineColor: const Color(0xFF123B8D),
                    outlineWidth: 3,
                  ),
                  SizedBox(height: compact ? 20 : 32),
                  SizedBox(
                    width: min(360, constraints.maxWidth - 48),
                    height: 64,
                    child: FilledButton.icon(
                      onPressed: () => _restart(vm),
                      icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      label: const Text(
                        'PLAY AGAIN',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blocks[1],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('HOME'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    required this.onHome,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final VoidCallback onHome;

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.gradientTop, AppColors.gradientBottom],
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 520;
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) =>
                  CustomPaint(painter: _ConfettiPainter(_controller.value)),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: max(
                      0,
                      constraints.maxHeight - (compact ? 32 : 48),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final bounce =
                              sin(_controller.value * pi * 4) *
                              (1 - _controller.value) *
                              .12;
                          return Transform.scale(
                            scale: 1 + bounce,
                            child: Text(
                              '🎉',
                              style: TextStyle(fontSize: compact ? 48 : 68),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: compact ? 4 : 8),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: compact ? 34 : 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 18 : 21,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: compact ? 16 : 28),
                      FilledButton(
                        onPressed: widget.onPressed,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 10,
                          ),
                          child: Text(widget.buttonLabel),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onHome,
                        child: const Text('HOME'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);

  final double progress;
  static const _colors = [
    Color(0xFFFFCA28),
    Color(0xFFFF7043),
    Color(0xFFAB47BC),
    Color(0xFF29B6F6),
    Color(0xFF66BB6A),
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - progress * .78).clamp(0.0, 1.0).toDouble();
    for (var i = 0; i < 64; i++) {
      final seed = i + 1;
      final startX = ((sin(seed * 12.9898) + 1) * .5) * size.width;
      final startY = -20 - ((sin(seed * 7.123) + 1) * .5) * size.height * .35;
      final drift = cos(seed * 4.321) * size.width * .12;
      final travel = progress * (size.height + 80);
      final center = Offset(startX + drift * progress, startY + travel);
      final rotation = progress * (seed.isEven ? 8 : -8) + seed.toDouble();
      final width = 5 + (seed % 4) * 2.0;
      final height = 7 + (seed % 3) * 3.0;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(2),
        ),
        Paint()..color = _colors[seed % _colors.length].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _OutlinedArcadeText extends StatelessWidget {
  const _OutlinedArcadeText(
    this.text, {
    required this.style,
    required this.outlineColor,
    required this.outlineWidth,
  });

  final String text;
  final TextStyle style;
  final Color outlineColor;
  final double outlineWidth;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      ExcludeSemantics(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            color: null,
            shadows: null,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = outlineWidth
              ..color = outlineColor,
          ),
        ),
      ),
      Text(
        text,
        textAlign: TextAlign.center,
        style: style.copyWith(foreground: null),
      ),
    ],
  );
}

class _ComboArcadeText extends StatelessWidget {
  const _ComboArcadeText(this.message, {required this.compact});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (message.startsWith('COMBO x')) {
      final number = message.substring('COMBO x'.length);
      return Semantics(
        label: message,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _OutlinedArcadeText(
                'COMBO x',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 23 : 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
                outlineColor: const Color(0xFF123B8D),
                outlineWidth: 3,
              ),
              const SizedBox(width: 3),
              _OutlinedArcadeText(
                number,
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: compact ? 44 : 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: const [
                    Shadow(
                      color: Color(0xAA08276E),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                outlineColor: const Color(0xFF123B8D),
                outlineWidth: 4,
              ),
            ],
          ),
        ),
      );
    }

    return _OutlinedArcadeText(
      message,
      style: TextStyle(
        color: AppColors.filled,
        fontSize: compact ? 24 : 29,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
      outlineColor: const Color(0xFF123B8D),
      outlineWidth: 3,
    );
  }
}

class BlockView extends StatelessWidget {
  const BlockView(this.block, this.cell, this.motion, {super.key});
  final Block block;
  final double cell;
  final Animation<double> motion;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(block.width * cell, block.height * cell),
    painter: _BlockPainter(block, cell, motion),
  );
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(
    this.board,
    this.ghost,
    this.gx,
    this.gy,
    this.valid,
    this.cellColors,
    this.motion,
  ) : super(repaint: motion);
  final Board board;
  final Block? ghost;
  final int gx, gy;
  final bool valid;
  final Map<int, Color> cellColors;
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / board.size;
    final phase = motion.value;
    for (var y = 0; y < board.size; y++) {
      for (var x = 0; x < board.size; x++) {
        final rect = Rect.fromLTWH(x * cs, y * cs, cs, cs).deflate(1.5);
        if (board.cells[y][x]) {
          _paintGelCell(
            canvas,
            rect,
            cellColors[y * board.size + x] ?? AppColors.filled,
            phase,
          );
        } else {
          final empty = RRect.fromRectAndRadius(
            rect,
            Radius.circular(cs * .16),
          );
          canvas.drawRRect(
            empty,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.empty.withValues(alpha: .74),
                  AppColors.empty.withValues(alpha: .42),
                ],
              ).createShader(rect),
          );
          canvas.drawRRect(
            empty,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = .7
              ..color = Colors.white.withValues(alpha: .035),
          );
        }
      }
    }
    if (ghost != null) {
      final col = (valid ? Colors.greenAccent : Colors.redAccent).withValues(
        alpha: .48,
      );
      for (final p in ghost!.cells) {
        final x = gx + p.x, y = gy + p.y;
        if (x >= 0 && y >= 0 && x < board.size && y < board.size) {
          _paintGelCell(
            canvas,
            Rect.fromLTWH(x * cs, y * cs, cs, cs).deflate(1.5),
            col,
            phase,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      board != old.board ||
      ghost != old.ghost ||
      gx != old.gx ||
      gy != old.gy ||
      valid != old.valid ||
      !identical(cellColors, old.cellColors);
}

class _BlockPainter extends CustomPainter {
  _BlockPainter(this.block, this.cell, this.motion) : super(repaint: motion);

  final Block block;
  final double cell;
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = motion.value;
    final color = AppColors.blocks[block.colorIndex];
    for (final point in block.cells) {
      _paintGelCell(
        canvas,
        Rect.fromLTWH(
          point.x * cell,
          point.y * cell,
          cell,
          cell,
        ).deflate(cell * .045),
        color,
        phase,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlockPainter old) =>
      block != old.block || cell != old.cell;
}

class _ClearCell {
  const _ClearCell(this.x, this.y, this.color, this.inRow, this.inColumn);

  final int x;
  final int y;
  final Color color;
  final bool inRow;
  final bool inColumn;
}

class _ClearEffect {
  _ClearEffect(this.cells);

  final List<_ClearCell> cells;
  late AnimationController controller;
}

class _ClearPainter extends CustomPainter {
  _ClearPainter(this.cells, this.boardSize, this.animation)
    : super(repaint: animation);

  final List<_ClearCell> cells;
  final int boardSize;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final cellSize = size.width / boardSize;

    final rows = cells
        .where((cell) => cell.inRow)
        .map((cell) => cell.y)
        .toSet();
    final columns = cells
        .where((cell) => cell.inColumn)
        .map((cell) => cell.x)
        .toSet();
    final flash = (1 - progress / .26).clamp(0.0, 1.0).toDouble();
    for (final row in rows) {
      _paintFirecrackerLine(
        canvas,
        Offset(0, (row + .5) * cellSize),
        Offset(size.width, (row + .5) * cellSize),
        cellSize,
        flash,
      );
    }
    for (final column in columns) {
      _paintFirecrackerLine(
        canvas,
        Offset((column + .5) * cellSize, 0),
        Offset((column + .5) * cellSize, size.height),
        cellSize,
        flash,
      );
    }

    for (final cell in cells) {
      final rect = Rect.fromLTWH(
        cell.x * cellSize,
        cell.y * cellSize,
        cellSize,
        cellSize,
      ).deflate(1.5);

      final dissolve = ((progress - .08) / .34).clamp(0.0, 1.0).toDouble();
      if (dissolve < 1) {
        final scale = 1 - dissolve * .22 + sin(progress * pi * 8) * .025;
        final fired = Rect.fromCenter(
          center: rect.center,
          width: rect.width * scale,
          height: rect.height * scale,
        );
        _paintGelCell(
          canvas,
          fired,
          cell.color,
          progress,
          opacity: 1 - dissolve,
        );
      }

      _paintFirecrackerSparks(canvas, cell, rect.center, cellSize, progress);
    }
  }

  @override
  bool shouldRepaint(covariant _ClearPainter old) =>
      cells != old.cells || boardSize != old.boardSize;
}

void _paintFirecrackerLine(
  Canvas canvas,
  Offset start,
  Offset end,
  double cellSize,
  double strength,
) {
  if (strength <= 0) return;
  final glowColor = Color.lerp(
    const Color(0xFFFF542E),
    const Color(0xFFFFF2A6),
    .55,
  )!;
  canvas.drawLine(
    start,
    end,
    Paint()
      ..color = glowColor.withValues(alpha: strength * .18)
      ..strokeWidth = cellSize * .88
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    start,
    end,
    Paint()
      ..color = Colors.white.withValues(alpha: strength * .72)
      ..strokeWidth = cellSize * .12
      ..strokeCap = StrokeCap.round,
  );
}

void _paintFirecrackerSparks(
  Canvas canvas,
  _ClearCell cell,
  Offset origin,
  double cellSize,
  double progress,
) {
  final flight = ((progress - .12) / .78).clamp(0.0, 1.0).toDouble();
  if (flight <= 0) return;

  final count = cell.inRow && cell.inColumn ? 4 : 3;
  for (var i = 0; i < count; i++) {
    final seed = cell.x * 37 + cell.y * 61 + i * 19;
    final random = (sin(seed * 12.9898) * 43758.5453) % 1;
    final angle = random * pi * 2;
    final speed = .35 + ((sin(seed * 7.123) + 1) * .5) * 1.15;
    final distance = cellSize * speed * flight;
    final gravity = cellSize * .5 * flight * flight;
    final direction = Offset(cos(angle), sin(angle));
    final tip = origin + direction * distance + Offset(0, gravity);
    final tail = tip - direction * cellSize * .16;
    final alpha = (1 - flight).clamp(0.0, 1.0).toDouble();
    final ember = i.isEven ? const Color(0xFFFFE68A) : const Color(0xFFFF7043);
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = ember.withValues(alpha: alpha * .9)
        ..strokeWidth = cellSize * .055
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      tip,
      cellSize * .035,
      Paint()..color = Colors.white.withValues(alpha: alpha * .85),
    );
  }
}

void _paintGelCell(
  Canvas canvas,
  Rect bounds,
  Color color,
  double phase, {
  double opacity = 1,
}) {
  final rect = bounds.deflate(bounds.width * .035);
  final bevel = min(rect.width, rect.height) * .17;
  final radius = Radius.circular(min(rect.width, rect.height) * .055);
  final shape = RRect.fromRectAndRadius(rect, radius);
  final base = color.withValues(alpha: opacity);
  final bright = Color.lerp(color, Colors.white, .38)!;
  final mid = Color.lerp(color, Colors.white, .12)!;
  final dark = Color.lerp(color, Colors.black, .3)!;

  canvas.drawRRect(
    shape.shift(Offset(0, max(1, rect.height * .045))),
    Paint()
      ..color = Color.lerp(
        color,
        Colors.black,
        .58,
      )!.withValues(alpha: .8 * opacity),
  );
  canvas.drawRRect(
    shape,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + phase * .16, -1),
        end: const Alignment(1, 1),
        colors: [bright, base, dark],
        stops: const [0, .48, 1],
      ).createShader(rect),
  );

  final topFacet = Path()
    ..moveTo(rect.left, rect.top + radius.y)
    ..quadraticBezierTo(rect.left, rect.top, rect.left + radius.x, rect.top)
    ..lineTo(rect.right - radius.x, rect.top)
    ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + radius.y)
    ..lineTo(rect.right - bevel, rect.top + bevel)
    ..lineTo(rect.left + bevel, rect.top + bevel)
    ..close();
  canvas.drawPath(
    topFacet,
    Paint()..color = bright.withValues(alpha: .96 * opacity),
  );

  final leftFacet = Path()
    ..moveTo(rect.left, rect.top + radius.y)
    ..lineTo(rect.left + bevel, rect.top + bevel)
    ..lineTo(rect.left + bevel, rect.bottom - bevel)
    ..lineTo(rect.left + radius.x, rect.bottom)
    ..quadraticBezierTo(
      rect.left,
      rect.bottom,
      rect.left,
      rect.bottom - radius.y,
    )
    ..close();
  canvas.drawPath(
    leftFacet,
    Paint()..color = mid.withValues(alpha: .72 * opacity),
  );

  final bottomFacet = Path()
    ..moveTo(rect.left + bevel, rect.bottom - bevel)
    ..lineTo(rect.right - bevel, rect.bottom - bevel)
    ..lineTo(rect.right - radius.x, rect.bottom)
    ..lineTo(rect.left + radius.x, rect.bottom)
    ..close();
  canvas.drawPath(
    bottomFacet,
    Paint()..color = dark.withValues(alpha: .8 * opacity),
  );

  final rightFacet = Path()
    ..moveTo(rect.right - bevel, rect.top + bevel)
    ..lineTo(rect.right, rect.top + radius.y)
    ..lineTo(rect.right, rect.bottom - radius.y)
    ..quadraticBezierTo(
      rect.right,
      rect.bottom,
      rect.right - radius.x,
      rect.bottom,
    )
    ..lineTo(rect.right - bevel, rect.bottom - bevel)
    ..close();
  canvas.drawPath(
    rightFacet,
    Paint()..color = dark.withValues(alpha: .68 * opacity),
  );

  final face = Rect.fromLTRB(
    rect.left + bevel,
    rect.top + bevel,
    rect.right - bevel,
    rect.bottom - bevel,
  );
  canvas.drawRect(
    face,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + phase * .16, -1),
        end: const Alignment(1, 1),
        colors: [mid, base, dark],
        stops: const [0, .5, 1],
      ).createShader(face),
  );
  canvas.drawLine(
    Offset(rect.left + rect.width * .13, rect.top + rect.height * .12),
    Offset(rect.right - rect.width * .15, rect.top + rect.height * .12),
    Paint()
      ..color = Colors.white.withValues(alpha: .62 * opacity)
      ..strokeWidth = max(1, rect.width * .025)
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(rect.left + rect.width * .12, rect.top + rect.height * .17),
    Offset(rect.left + rect.width * .12, rect.bottom - rect.height * .16),
    Paint()
      ..color = bright.withValues(alpha: .62 * opacity)
      ..strokeWidth = max(1, rect.width * .028)
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawRRect(
    shape,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(.7, rect.width * .025)
      ..color = dark.withValues(alpha: .85 * opacity),
  );
}
