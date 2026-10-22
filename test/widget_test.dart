import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:block_quest/core/storage/storage.dart';
import 'package:block_quest/app/app.dart';
import 'package:block_quest/app/theme/app_colors.dart';
import 'package:block_quest/features/game/domain/block.dart';
import 'package:block_quest/features/game/domain/board.dart';
import 'package:block_quest/features/game/presentation/game_screen.dart';
import 'package:block_quest/features/game/presentation/interstitial_ad_service.dart';
import 'package:block_quest/features/game/presentation/game_viewmodel.dart';
import 'package:block_quest/features/game/presentation/line_clear_feedback.dart';
import 'package:block_quest/features/home/presentation/home_screen.dart';
import 'package:block_quest/features/settings/presentation/settings_screen.dart';
import 'package:block_quest/features/settings/presentation/legal_document_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('uses Baloo 2 and larger app-wide button targets', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const BlockQuestApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final context = tester.element(find.byType(HomeScreen));
    final theme = Theme.of(context);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Baloo2');
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({}),
      const Size(64, 52),
    );
    expect(
      theme.textButtonTheme.style?.minimumSize?.resolve({}),
      const Size(64, 48),
    );
  });

  testWidgets('places a block without changing the empty board cells', (
    tester,
  ) async {
    await _pumpGame(tester, Board.empty());

    await _dropAtCell(tester, 2, 2);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final state = container.read(gameProvider);

    expect(state.score, 1);
    expect(state.board.cells[2][2], isTrue);
    expect(
      state.board.cells.expand((row) => row).where((cell) => cell).length,
      1,
    );
  });

  testWidgets('places a block in the bottom-right board cell', (tester) async {
    await _pumpGame(tester, Board.empty());

    await _dropAtCell(tester, 7, 7, inset: .49);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final state = container.read(gameProvider);

    expect(state.score, 1);
    expect(state.board.cells[7][7], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('places a block on the landscape board', (tester) async {
    await _pumpGame(tester, Board.empty(), screenSize: const Size(844, 390));

    await _dropAtCell(tester, 2, 2);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final state = container.read(gameProvider);

    expect(state.score, 1);
    expect(state.board.cells[2][2], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts home, game, and settings across form factors', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final size in [
      const Size(320, 568),
      const Size(844, 390),
      const Size(1024, 768),
      const Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final screen in [
        const SplashScreen(),
        const HomeScreen(),
        const GameScreen(),
        const SettingsScreen(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              prefsProvider.overrideWithValue(prefs),
              gameProvider.overrideWith(
                () => _TestGameViewModel(Board.empty()),
              ),
            ],
            child: MaterialApp(theme: BlockQuestApp.appTheme, home: screen),
          ),
        );
        await tester.pump();
        if (screen is SplashScreen) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }
        if (screen is HomeScreen) {
          expect(find.text('Adventure'), findsOneWidget);
          expect(find.text('Classic'), findsOneWidget);
          expect(find.text('BEST SCORE'), findsOneWidget);
          final gameButtons = tester
              .widgetList<FilledButton>(find.byType(FilledButton))
              .toList();
          expect(gameButtons, hasLength(2));
          expect(
            gameButtons.every((button) => button.onPressed != null),
            isTrue,
          );
          expect(
            gameButtons[0].onPressed,
            isNot(same(gameButtons[1].onPressed)),
          );
        }
        if (screen is GameScreen && size.width > size.height) {
          expect(
            tester.getSize(find.byType(DragTarget<int>)).width,
            greaterThanOrEqualTo(250),
            reason: 'The landscape board should remain playable at $size',
          );
        }
        expect(tester.takeException(), isNull, reason: '$screen at $size');
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('home opens Adventure and Classic with their selected modes', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          gameProvider.overrideWith(() => _TestGameViewModel(Board.empty())),
        ],
        child: MaterialApp(
          theme: BlockQuestApp.appTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Classic'))
        .onPressed!
        .call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<GameScreen>(find.byType(GameScreen).last).mode,
      GameMode.classic,
    );

    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pump(const Duration(milliseconds: 350));
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Adventure'))
        .onPressed!
        .call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<GameScreen>(find.byType(GameScreen).last).mode,
      GameMode.adventure,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings opens the selected privacy and terms documents', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsNothing);
    expect(find.text('Privacy Policy'), findsOneWidget);
    final privacyText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join(' ');
    expect(privacyText, contains('This Privacy Policy explains how'));
    expect(privacyText, isNot(contains('Acceptance of Terms')));

    Navigator.of(tester.element(find.byType(LegalDocumentScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terms and Conditions'));
    await tester.pumpAndSettle();
    expect(find.text('Terms and Conditions'), findsOneWidget);
    final termsText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join(' ');
    expect(termsText, contains('By downloading, installing or playing'));
    expect(termsText, isNot(contains('1. Introduction')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('places a block and clears a completed horizontal row', (
    tester,
  ) async {
    await _pumpGame(tester, _boardMissingLastRowCell());

    await _dropAtCell(tester, 7, 7);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final state = container.read(gameProvider);

    expect(state.score, 11);
    expect(state.board.cells[7].every((cell) => !cell), isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears a completed vertical column', (tester) async {
    await _pumpGame(tester, _boardMissingLastColumnCell());

    await _dropAtCell(tester, 7, 7);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final state = container.read(gameProvider);

    expect(state.score, 11);
    expect(
      List.generate(8, (y) => state.board.cells[y][7]).every((cell) => !cell),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears crossing row and column together', (tester) async {
    await _pumpGame(tester, _boardMissingCrossCell());

    await _dropAtCell(tester, 7, 7);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    final state = container.read(gameProvider);

    expect(state.score, 26);
    expect(state.board.cells[7].every((cell) => !cell), isTrue);
    expect(
      List.generate(8, (y) => state.board.cells[y][7]).every((cell) => !cell),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  test(
    'combo increments once per clearing move and resets on a miss',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final board = _boardMissingLastRows(6, 7);
      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          gameProvider.overrideWith(() => _TestGameViewModel(board)),
        ],
      );
      addTearDown(container.dispose);
      final vm = container.read(gameProvider.notifier);

      expect(vm.placeBlock(0, 7, 7), isTrue);
      expect(container.read(gameProvider).combo, 1);
      expect(vm.placeBlock(1, 7, 6), isTrue);
      expect(container.read(gameProvider).combo, 2);
      expect(container.read(gameProvider).linesCleared, 2);

      expect(vm.placeBlock(2, 0, 7), isTrue);
      expect(container.read(gameProvider).combo, 0);
    },
  );

  test('one move clearing three lines increments combo only once', () async {
    final prefs = await SharedPreferences.getInstance();
    final board = Board(
      8,
      List.generate(8, (y) => List.generate(8, (x) => y >= 5 && x < 7)),
    );
    const verticalBlock = Block('vertical-three', [
      Point<int>(0, 0),
      Point<int>(0, 1),
      Point<int>(0, 2),
    ], 0);
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        gameProvider.overrideWith(
          () => _TestGameViewModel(
            board,
            initialState: GameState(
              board: board,
              availableBlocks: const [
                verticalBlock,
                _TestGameViewModel.singleBlock,
                _TestGameViewModel.singleBlock,
              ],
              status: GameStatus.playing,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final vm = container.read(gameProvider.notifier);

    expect(vm.placeBlock(0, 7, 5), isTrue);
    final state = container.read(gameProvider);
    expect(state.linesCleared, 3);
    expect(state.combo, 1);
  });

  test('line and combo feedback text follows arcade milestones', () {
    expect(
      [
        for (var lines = 1; lines <= 5; lines++)
          LineClearFeedback.messageForLines(lines),
      ],
      ['SMOOTH!', 'GREAT!', 'AWESOME!', 'AMAZING!', 'UNBELIEVABLE!'],
    );
    expect(LineClearFeedback.messageForCombo(0), isNull);
    expect(LineClearFeedback.messageForCombo(1), isNull);
    expect(LineClearFeedback.messageForCombo(2), 'COMBO x2');
    expect(LineClearFeedback.messageForCombo(3), 'COMBO x3');
    expect(LineClearFeedback.messageForCombo(4), 'COMBO x4');
    expect(LineClearFeedback.messageForCombo(5), 'ON FIRE!');
    expect(LineClearFeedback.messageForCombo(6), 'UNSTOPPABLE!');
    expect(LineClearFeedback.messageForCombo(10), 'UNSTOPPABLE!');
    expect(() => LineClearFeedback.messageForLines(0), throwsArgumentError);
  });

  test('restarting a game clears the combo', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        gameProvider.overrideWith(
          () => _ConfiguredGameViewModel(
            GameState(
              board: Board.empty(),
              availableBlocks: const [
                _TestGameViewModel.singleBlock,
                _TestGameViewModel.singleBlock,
                _TestGameViewModel.singleBlock,
              ],
              combo: 4,
              status: GameStatus.playing,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final vm = container.read(gameProvider.notifier);

    expect(container.read(gameProvider).combo, 4);
    vm.start();
    expect(container.read(gameProvider).combo, 0);
  });

  testWidgets(
    'shows line and milestone combo feedback without blocking input',
    (tester) async {
      await _pumpGame(
        tester,
        _boardMissingLastRowCell(),
        initialState: GameState(
          board: _boardMissingLastRowCell(),
          availableBlocks: const [
            _TestGameViewModel.singleBlock,
            _TestGameViewModel.singleBlock,
            _TestGameViewModel.singleBlock,
          ],
          combo: 4,
          status: GameStatus.playing,
        ),
      );

      await _dropAtCell(tester, 7, 7);
      expect(find.text('SMOOTH!'), findsNWidgets(2));
      expect(find.text('ON FIRE!'), findsNWidgets(2));
      final feedbackIgnorePointer = find.ancestor(
        of: find.text('SMOOTH!').last,
        matching: find.byType(IgnorePointer),
      );
      final feedbackCenter = tester.getRect(feedbackIgnorePointer.first).center;
      expect(feedbackCenter.dx, closeTo(195, 12));
      expect(feedbackCenter.dy, closeTo(422, 12));
      final outlinedMessage = tester.widget<Text>(find.text('SMOOTH!').first);
      expect(outlinedMessage.style?.foreground, isA<Paint>());
      expect(outlinedMessage.style!.foreground!.style, PaintingStyle.stroke);
      expect(
        tester.widget<IgnorePointer>(feedbackIgnorePointer.first).ignoring,
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('SMOOTH!'), findsNothing);
      expect(find.text('ON FIRE!'), findsNothing);
      expect(tester.takeException(), isNull);
      await _dropAtCell(tester, 0, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows best score left and current score centered above board', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      Board.empty(),
      initialState: GameState(
        board: Board.empty(),
        availableBlocks: const [
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
        ],
        score: 422,
        bestScore: 2081,
        status: GameStatus.playing,
      ),
    );

    expect(find.text('2081'), findsNWidgets(2));
    expect(find.text('422'), findsNWidgets(2));
    expect(find.byTooltip('Settings'), findsOneWidget);
    final bestScoreRect = tester.getRect(find.text('2081').first);
    final currentScoreRect = tester.getRect(find.text('422').first);
    expect(bestScoreRect.left, lessThan(currentScoreRect.left));
    expect(currentScoreRect.center.dx, closeTo(195, 10));
    expect([
      AppColors.gradientTop,
      AppColors.gradientMiddle,
      AppColors.gradientBottom,
    ], isNot(contains(AppColors.blocks[2])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('spaces level and lines at the sides and centers combo', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      Board.empty(),
      initialState: GameState(
        board: Board.empty(),
        availableBlocks: const [
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
        ],
        combo: 2,
        status: GameStatus.playing,
      ),
    );

    final levelRect = tester.getRect(find.text('LEVEL 1/30'));
    final comboRect = tester.getRect(find.text('COMBO ×2'));
    final linesRect = tester.getRect(find.text('LINES 0/3'));

    expect(levelRect.right, lessThan(comboRect.left));
    expect(linesRect.left, greaterThan(comboRect.right));
    expect(comboRect.center.dx, closeTo(195, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows celebration on level completion', (tester) async {
    await _pumpGame(
      tester,
      Board.empty(),
      screenSize: const Size(844, 390),
      initialState: GameState(
        board: Board.empty(),
        availableBlocks: const [
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
        ],
        level: 1,
        levelLinesCleared: 3,
        status: GameStatus.levelComplete,
      ),
    );

    expect(find.text('HURRAY!'), findsOneWidget);
    expect(find.textContaining('LEVEL 1 COMPLETE!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an interstitial before advancing to the next level', (
    tester,
  ) async {
    final adService = _TestInterstitialAdService(completeImmediately: false);
    await _pumpGame(
      tester,
      Board.empty(),
      adService: adService,
      initialState: GameState(
        board: Board.empty(),
        availableBlocks: const [
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
        ],
        level: 1,
        levelLinesCleared: 3,
        status: GameStatus.levelComplete,
      ),
    );

    await tester.tap(find.text('LEVEL 2'));
    await tester.pump();

    expect(adService.showCount, 1);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(GameScreen)),
      ).read(gameProvider).level,
      1,
    );

    adService.complete();
    await tester.pump();

    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(GameScreen)),
      ).read(gameProvider).level,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the score summary when no moves remain', (tester) async {
    await _pumpGame(
      tester,
      Board.empty(),
      initialState: GameState(
        board: Board.empty(),
        availableBlocks: const [
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
        ],
        score: 778,
        bestScore: 2081,
        status: GameStatus.gameOver,
      ),
    );

    expect(find.text('NO SPACE LEFT'), findsOneWidget);
    expect(find.text('GAME OVER'), findsNothing);
    expect(find.text('778'), findsNWidgets(4));
    expect(find.text('2081'), findsNWidgets(4));
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry waits for the interstitial completion before restarting', (
    tester,
  ) async {
    final adService = _TestInterstitialAdService();
    await _pumpGame(
      tester,
      Board.empty(),
      adService: adService,
      initialState: GameState(
        board: Board.empty(),
        availableBlocks: const [
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
        ],
        status: GameStatus.gameOver,
      ),
    );

    final viewModel = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    ).read(gameProvider.notifier) as _TestGameViewModel;
    expect(viewModel.startCount, 1);

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump();

    expect(adService.showCount, 1);
    expect(adService.completionCount, 1);
    expect(viewModel.startCount, 2);
  });

  testWidgets('classic shows retry without adventure level progress', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      Board.empty(),
      mode: GameMode.classic,
      initialState: GameState(
        board: Board.empty(),
        availableBlocks: const [
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
          _TestGameViewModel.singleBlock,
        ],
        score: 778,
        bestScore: 2081,
        mode: GameMode.classic,
        status: GameStatus.gameOver,
      ),
    );

    expect(find.text('NO SPACE LEFT'), findsOneWidget);
    expect(find.text('LEVEL 1/30'), findsNothing);
    expect(find.textContaining('LINES '), findsNothing);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('completes a level and unlocks the next level', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        gameProvider.overrideWith(
          () => _TestGameViewModel(
            _boardMissingLastRowCell(),
            initialState: GameState(
              board: _boardMissingLastRowCell(),
              availableBlocks: const [
                _TestGameViewModel.singleBlock,
                _TestGameViewModel.singleBlock,
                _TestGameViewModel.singleBlock,
              ],
              levelLinesCleared: 2,
              status: GameStatus.playing,
            ),
          ),
        ),
      ],
    );

    addTearDown(container.dispose);

    final viewModel = container.read(gameProvider.notifier);
    expect(viewModel.placeBlock(0, 7, 7), isTrue);
    expect(container.read(gameProvider).status, GameStatus.levelComplete);
    expect(prefs.getInt(Keys.unlockedLevel), 2);

    viewModel.nextLevel();
    final nextLevel = container.read(gameProvider);
    expect(nextLevel.level, 2);
    expect(nextLevel.levelLinesCleared, 0);
    expect(
      nextLevel.board.cells.expand((row) => row).every((cell) => !cell),
      isTrue,
    );
  });

  test(
    'classic play skips level completion and saves a separate best score',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final board = _boardMissingLastRowCell();
      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          gameProvider.overrideWith(
            () => _ConfiguredGameViewModel(
              GameState(
                board: board,
                availableBlocks: const [
                  _TestGameViewModel.singleBlock,
                  _TestGameViewModel.singleBlock,
                  _TestGameViewModel.singleBlock,
                ],
                levelLinesCleared: 100,
                mode: GameMode.classic,
                status: GameStatus.playing,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final vm = container.read(gameProvider.notifier);
      expect(vm.placeBlock(0, 7, 7), isTrue);
      final state = container.read(gameProvider);

      expect(state.status, GameStatus.playing);
      expect(state.levelLinesCleared, 0);
      expect(state.mode, GameMode.classic);
      expect(prefs.getInt(Keys.classicBestScore), 11);
      expect(prefs.getInt(Keys.bestScore), isNull);
      expect(prefs.getInt(Keys.unlockedLevel), isNull);
      expect(prefs.getBool(Keys.campaignComplete), isNull);
    },
  );

  test(
    'classic starts independently of the Adventure campaign and score',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(Keys.bestScore, 900);
      await prefs.setInt(Keys.classicBestScore, 120);
      await prefs.setInt(Keys.unlockedLevel, 8);
      await prefs.setBool(Keys.campaignComplete, true);
      final container = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container.read(gameProvider.notifier).start(mode: GameMode.classic);
      final state = container.read(gameProvider);

      expect(state.mode, GameMode.classic);
      expect(state.status, GameStatus.playing);
      expect(state.bestScore, 120);
      expect(state.level, 1);
    },
  );

  test(
    'completing level 30 finishes campaign without unlocking level 31',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(Keys.unlockedLevel, GameState.maxLevel);
      final board = _boardMissingLastRowCell();
      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          gameProvider.overrideWith(
            () => _TestGameViewModel(
              board,
              initialState: GameState(
                board: board,
                availableBlocks: const [
                  _TestGameViewModel.singleBlock,
                  _TestGameViewModel.singleBlock,
                  _TestGameViewModel.singleBlock,
                ],
                level: GameState.maxLevel,
                levelLinesCleared: GameState.maxLevel + 1,
                status: GameStatus.playing,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final viewModel = container.read(gameProvider.notifier);
      expect(viewModel.placeBlock(0, 7, 7), isTrue);
      expect(container.read(gameProvider).status, GameStatus.campaignComplete);
      expect(prefs.getBool(Keys.campaignComplete), isTrue);
      expect(prefs.getInt(Keys.unlockedLevel), GameState.maxLevel);
    },
  );
}

Future<void> _pumpGame(
  WidgetTester tester,
  Board board, {
  Size screenSize = const Size(390, 844),
  GameMode mode = GameMode.adventure,
  _TestInterstitialAdService? adService,
  GameState? initialState,
}) async {
  tester.view.physicalSize = screenSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        interstitialAdServiceProvider.overrideWithValue(
          adService ?? _TestInterstitialAdService(),
        ),
        gameProvider.overrideWith(
          () => _TestGameViewModel(board, initialState: initialState),
        ),
      ],
      child: MaterialApp(
        theme: BlockQuestApp.appTheme,
        home: GameScreen(mode: mode),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _dropAtCell(
  WidgetTester tester,
  int x,
  int y, {
  double inset = .1625,
}) async {
  final board = find.byWidgetPredicate(
    (widget) => widget is Container && widget.key is GlobalKey,
  );
  final draggable = find.byWidgetPredicate(
    (widget) => widget is Draggable<int>,
  );
  final boardRect = tester.getRect(board);
  final destination =
      boardRect.topLeft +
      Offset(
        (x + inset) * boardRect.width / 8 + boardRect.width / 16,
        (y + inset) * boardRect.height / 8 + boardRect.height / 16,
      );
  final start = tester.getCenter(draggable.first);
  await tester.dragFrom(start, destination - start);
  await tester.pump();
}

Board _boardMissingLastRowCell() =>
    Board(8, List.generate(8, (y) => List.generate(8, (x) => y == 7 && x < 7)));

Board _boardMissingLastRows(int firstRow, int lastRow) => Board(
  8,
  List.generate(
    8,
    (y) => List.generate(8, (x) => y >= firstRow && y <= lastRow && x < 7),
  ),
);

Board _boardMissingLastColumnCell() =>
    Board(8, List.generate(8, (y) => List.generate(8, (x) => x == 7 && y < 7)));

Board _boardMissingCrossCell() => Board(
  8,
  List.generate(
    8,
    (y) => List.generate(8, (x) => (y == 7 && x < 7) || (x == 7 && y < 7)),
  ),
);

class _TestGameViewModel extends GameViewModel {
  _TestGameViewModel(this.board, {this.initialState});

  final Board board;
  final GameState? initialState;
  var startCount = 0;
  static const singleBlock = Block('single', [Point<int>(0, 0)], 0);

  @override
  GameState build() =>
      initialState ??
      GameState(
        board: board,
        availableBlocks: const [singleBlock, singleBlock, singleBlock],
        status: GameStatus.playing,
      );

  @override
  void start({GameMode mode = GameMode.adventure}) {
    startCount++;
  }
}

class _TestInterstitialAdService implements InterstitialAdService {
  _TestInterstitialAdService({this.completeImmediately = true});

  final bool completeImmediately;
  var showCount = 0;
  var completionCount = 0;
  VoidCallback? _onComplete;

  @override
  Future<void> initialize() async {}

  @override
  void showInterstitial(VoidCallback onComplete) {
    showCount++;
    _onComplete = onComplete;
    if (completeImmediately) complete();
  }

  void complete() {
    final onComplete = _onComplete;
    if (onComplete == null) return;
    _onComplete = null;
    onComplete();
    completionCount++;
  }
}

class _ConfiguredGameViewModel extends GameViewModel {
  _ConfiguredGameViewModel(this.initialState);

  final GameState initialState;

  @override
  GameState build() => initialState;
}
