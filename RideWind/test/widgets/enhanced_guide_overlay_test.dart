import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewind/widgets/enhanced_guide_overlay.dart';
import 'package:ridewind/models/guide_models.dart';

/// EnhancedGuideOverlay Widget 测试
///
/// 重构后的 overlay 使用 GestureValidatorWidget 进行手势验证推进，
/// 不再有"下一步"/"完成"按钮。跳过按钮文本为"跳过引导"。
/// 步骤指示器格式为 "N / M"。手指指针使用 emoji '👆'。
///
/// **Validates: Requirements 2.1, 2.3, 2.4, 2.5, 5.1, 5.2, 10.1, 10.4**
void main() {
  group('EnhancedGuideOverlay', () {
    late GlobalKey targetKey1;
    late GlobalKey targetKey2;
    late GlobalKey targetKey3;

    setUp(() {
      targetKey1 = GlobalKey();
      targetKey2 = GlobalKey();
      targetKey3 = GlobalKey();
    });

    /// Helper: pump enough frames for the fade animation (300ms) + post-frame callback
    Future<void> pumpForAnimations(WidgetTester tester) async {
      // First pump triggers the post-frame callback
      await tester.pump();
      // Pump 500ms to complete fade-in (300ms) with margin
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Helper: pump enough time for _waitForTarget timeout (2000ms per step) + animations
    Future<void> pumpForWaitTimeout(WidgetTester tester, {int steps = 1}) async {
      for (int i = 0; i < steps; i++) {
        for (int j = 0; j < 22; j++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Helper: pump for step transition (fade out 300ms + fade in 300ms)
    Future<void> pumpForTransition(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
    }

    Widget createTestWidget({
      required List<GuideStep> steps,
      required VoidCallback onComplete,
      VoidCallback? onSkip,
      bool canSkip = true,
      List<GlobalKey>? targetKeys,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              if (targetKeys != null)
                ...targetKeys.asMap().entries.map((entry) {
                  final index = entry.key;
                  final key = entry.value;
                  return Positioned(
                    left: 50.0 + index * 100,
                    top: 100.0,
                    child: Container(
                      key: key,
                      width: 80,
                      height: 80,
                      color: Colors.blue,
                      child: Center(child: Text('Target ${index + 1}')),
                    ),
                  );
                }),
              EnhancedGuideOverlay(
                steps: steps,
                onComplete: onComplete,
                onSkip: onSkip,
                canSkip: canSkip,
              ),
            ],
          ),
        ),
      );
    }

    // ============================================================
    // 手势验证推进测试
    // The overlay now uses GestureValidatorWidget for step advancement.
    // Tapping the target area triggers gesture validation → step advance.
    // ============================================================
    group('Gesture-based Step Navigation', () {
      testWidgets('tapping target area advances to next step via gesture validation', (tester) async {
        final keys = [targetKey1, targetKey2];
        final steps = [
          GuideStep(targetKey: keys[0], title: '步骤 1', description: '描述 1', gestureType: GestureType.tap),
          GuideStep(targetKey: keys[1], title: '步骤 2', description: '描述 2', gestureType: GestureType.tap),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () {},
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        // Step 1: description and step indicator visible
        expect(find.text('描述 1'), findsOneWidget);
        expect(find.text('1 / 2'), findsOneWidget);

        // Tap the target area to trigger gesture match and advance
        // Target 1 is at (50, 100) size 80x80, center at (90, 140)
        await tester.tapAt(const Offset(90, 140));
        await pumpForTransition(tester);
        // Extra pump to ensure rebuild
        await tester.pump(const Duration(milliseconds: 100));

        // Step 2
        expect(find.text('描述 2'), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
      });

      testWidgets('single step shows description and completes on tap', (tester) async {
        bool completed = false;
        final keys = [targetKey1];
        final steps = [
          GuideStep(targetKey: keys[0], title: '唯一步骤', description: '描述', gestureType: GestureType.tap),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () => completed = true,
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        expect(find.text('描述'), findsOneWidget);
        expect(find.text('1 / 1'), findsOneWidget);

        // Tap target to complete (last step → onComplete)
        await tester.tapAt(const Offset(90, 140));
        await pumpForTransition(tester);

        expect(completed, true);
      });
    });

    // ============================================================
    // 跳过回调测试
    // Skip button text is now "跳过引导"
    // Validates: Requirements 10.1
    // ============================================================
    group('Skip Callback', () {
      testWidgets('skip button calls onSkip callback', (tester) async {
        bool skipped = false;
        bool completed = false;
        final keys = [targetKey1, targetKey2];
        final steps = [
          GuideStep(targetKey: keys[0], title: '步骤 1', description: '描述 1'),
          GuideStep(targetKey: keys[1], title: '步骤 2', description: '描述 2'),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () => completed = true,
          onSkip: () => skipped = true,
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        await tester.tap(find.text('跳过引导'));
        await pumpForTransition(tester);

        expect(skipped, true);
        expect(completed, false);
      });

      testWidgets('skip button calls onComplete when onSkip is null', (tester) async {
        bool completed = false;
        final keys = [targetKey1, targetKey2];
        final steps = [
          GuideStep(targetKey: keys[0], title: '步骤 1', description: '描述 1'),
          GuideStep(targetKey: keys[1], title: '步骤 2', description: '描述 2'),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () => completed = true,
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        await tester.tap(find.text('跳过引导'));
        await pumpForTransition(tester);

        expect(completed, true);
      });

      testWidgets('skip button hidden when canSkip is false', (tester) async {
        final keys = [targetKey1, targetKey2];
        final steps = [
          GuideStep(targetKey: keys[0], title: '步骤 1', description: '描述 1'),
          GuideStep(targetKey: keys[1], title: '步骤 2', description: '描述 2'),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () {},
          canSkip: false,
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        expect(find.text('跳过引导'), findsNothing);
      });

      testWidgets('skip button hidden on last step', (tester) async {
        final keys = [targetKey1, targetKey2];
        final steps = [
          GuideStep(targetKey: keys[0], title: '步骤 1', description: '描述 1', gestureType: GestureType.tap),
          GuideStep(targetKey: keys[1], title: '步骤 2', description: '描述 2', gestureType: GestureType.tap),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () {},
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        expect(find.text('跳过引导'), findsOneWidget);

        // Tap target to advance to last step
        await tester.tapAt(const Offset(90, 140));
        await pumpForTransition(tester);
        await tester.pump(const Duration(milliseconds: 100));

        // On last step, skip button should be hidden
        expect(find.text('跳过引导'), findsNothing);
      });
    });

    // ============================================================
    // 完成回调测试
    // Validates: Requirements 10.2
    // ============================================================
    group('Complete Callback', () {
      testWidgets('tapping last step target calls onComplete', (tester) async {
        bool completed = false;
        final keys = [targetKey1, targetKey2];
        final steps = [
          GuideStep(targetKey: keys[0], title: '步骤 1', description: '描述 1', gestureType: GestureType.tap),
          GuideStep(targetKey: keys[1], title: '步骤 2', description: '描述 2', gestureType: GestureType.tap),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () => completed = true,
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        // Advance to last step by tapping target 1 center (90, 140)
        await tester.tapAt(const Offset(90, 140));
        // Pump generously for the full transition cycle
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Verify we're on step 2
        expect(find.text('描述 2'), findsOneWidget);

        // Tap last step target center (190, 140) to complete
        await tester.tapAt(const Offset(190, 140));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(completed, true);
      });
    });

    // ============================================================
    // 步骤跳过逻辑测试（不可定位步骤）
    // Validates: Requirements 2.4, 9.3
    // ============================================================
    group('Step Skipping', () {
      testWidgets('skips steps with non-locatable targets', (tester) async {
        final orphanKey = GlobalKey();
        final keys = [targetKey1, targetKey2];
        final steps = [
          GuideStep(targetKey: keys[0], title: '可见步骤 1', description: '描述 1', gestureType: GestureType.tap),
          GuideStep(targetKey: orphanKey, title: '不可见步骤', description: '应被跳过'),
          GuideStep(targetKey: keys[1], title: '可见步骤 2', description: '描述 2'),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () {},
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        // First step should be visible
        expect(find.text('描述 1'), findsOneWidget);
        expect(find.text('1 / 3'), findsOneWidget);

        // Tap the target area to trigger gesture match and advance
        await tester.tapAt(const Offset(90, 140));
        // Pump for fade out animation
        await tester.pump(const Duration(milliseconds: 350));
        // Pump through the wait timeout for the orphan step (2000ms)
        await pumpForWaitTimeout(tester, steps: 1);
        // Pump for fade in animation
        await tester.pump(const Duration(milliseconds: 350));

        // Should have skipped the orphan step and landed on step 3
        expect(find.text('描述 2'), findsOneWidget);
        expect(find.text('3 / 3'), findsOneWidget);
      });

      testWidgets('calls onComplete when all steps are non-locatable', (tester) async {
        bool completed = false;
        final orphanKey1 = GlobalKey();
        final orphanKey2 = GlobalKey();
        final steps = [
          GuideStep(targetKey: orphanKey1, title: '不可见 1', description: '描述'),
          GuideStep(targetKey: orphanKey2, title: '不可见 2', description: '描述'),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () => completed = true,
        ));
        // Pump initial frame to trigger post-frame callback
        await tester.pump();
        // Pump through wait timeouts for both orphan steps (2000ms each)
        await pumpForWaitTimeout(tester, steps: 2);

        expect(completed, true);
      });
    });

    // ============================================================
    // 动画组件集成测试
    // Validates: Requirements 2.3
    // ============================================================
    group('Animation Components', () {
      testWidgets('renders ripple effect and finger pointer emoji', (tester) async {
        final keys = [targetKey1];
        final steps = [
          GuideStep(targetKey: keys[0], title: '步骤 1', description: '描述'),
        ];

        await tester.pumpWidget(createTestWidget(
          steps: steps,
          onComplete: () {},
          targetKeys: keys,
        ));
        await pumpForAnimations(tester);

        // FingerPointerWidget now uses emoji '👆'
        expect(find.text('👆'), findsOneWidget);

        // RippleEffectPainter is rendered via CustomPaint
        expect(find.byType(CustomPaint), findsWidgets);
      });
    });

    // ============================================================
    // showEnhancedGuideOverlay 便捷方法测试
    // ============================================================
    group('showEnhancedGuideOverlay', () {
      testWidgets('empty steps calls onComplete immediately', (tester) async {
        bool completed = false;

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showEnhancedGuideOverlay(
                    context: context,
                    steps: [],
                    onComplete: () => completed = true,
                  );
                },
                child: const Text('Show'),
              );
            },
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(completed, true);
      });
    });
  });

  // ============================================================
  // Tooltip 定位逻辑单元测试
  // Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5
  // ============================================================
  group('calculateTooltipPosition', () {
    const tooltipSize = Size(300, 120);
    const screenSize = Size(400, 800);

    test('target in upper half → tooltip below target', () {
      final position = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(100, 100, 80, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
      );
      expect(position.dy, greaterThan(140.0));
    });

    test('target in lower half → tooltip above target', () {
      final position = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(100, 600, 80, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
      );
      expect(position.dy + tooltipSize.height, lessThan(600.0));
    });

    test('tooltip horizontally centered on target', () {
      final position = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(150, 100, 80, 40),
        screenSize: screenSize,
        tooltipSize: const Size(100, 80),
      );
      expect(position.dx + 50, closeTo(190.0, 0.1));
    });

    test('tooltip clamped to left screen edge', () {
      final position = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(0, 100, 20, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
      );
      expect(position.dx, greaterThanOrEqualTo(16.0));
    });

    test('tooltip clamped to right screen edge', () {
      final position = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(380, 100, 20, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
      );
      expect(position.dx + tooltipSize.width, lessThanOrEqualTo(400 - 16.0));
    });

    test('tooltip stays within screen bounds vertically', () {
      final position = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(100, 100, 80, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
      );
      expect(position.dy, greaterThanOrEqualTo(16.0));
      expect(position.dy + tooltipSize.height, lessThanOrEqualTo(800 - 16.0));
    });

    test('minimum spacing maintained between tooltip and target', () {
      const minSpacing = 80.0;

      final posBelow = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(100, 100, 80, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
        minSpacing: minSpacing,
      );
      expect(posBelow.dy - 140.0, greaterThanOrEqualTo(minSpacing));

      final posAbove = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(100, 600, 80, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
        minSpacing: minSpacing,
      );
      expect(600.0 - (posAbove.dy + tooltipSize.height), greaterThanOrEqualTo(minSpacing));
    });

    test('target exactly at screen center → tooltip below', () {
      final position = calculateTooltipPosition(
        targetRect: const Rect.fromLTWH(160, 380, 80, 40),
        screenSize: screenSize,
        tooltipSize: tooltipSize,
      );
      expect(position.dy, greaterThan(420.0));
    });
  });
}
