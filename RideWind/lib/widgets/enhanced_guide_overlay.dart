import 'package:flutter/material.dart';
import '../models/guide_models.dart';
import 'ripple_effect_painter.dart';
import 'finger_pointer_widget.dart';
import 'gesture_validator_widget.dart';
import 'guide_overlay.dart' show HighlightMaskPainter;
import 'guide_tooltip_styles.dart';

/// 增强引导覆盖层组件
/// 手指指针 + 水波纹 + 文字提示框联动的分步交互式引导
/// 使用 GestureValidatorWidget 进行手势验证推进，而非点击任意位置推进
///
/// Requirements: 2.1, 2.2, 2.3, 2.5, 5.1, 5.2
class EnhancedGuideOverlay extends StatefulWidget {
  final List<GuideStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final bool canSkip;

  /// 提示框样式：整个引导流程统一使用一种样式
  /// Running Mode 用 glassmorphism，Colorize Mode 用 glowBorder
  final GuideTooltipStyle tooltipStyle;

  const EnhancedGuideOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
    this.canSkip = true,
    this.tooltipStyle = GuideTooltipStyle.glassmorphism,
  });

  @override
  State<EnhancedGuideOverlay> createState() => EnhancedGuideOverlayState();
}

@visibleForTesting
class EnhancedGuideOverlayState extends State<EnhancedGuideOverlay>
    with TickerProviderStateMixin {
  int _currentVisibleIndex = 0;
  List<GuideStep> _visibleSteps = [];

  late AnimationController _fadeController;
  late AnimationController _fingerController;
  late AnimationController _rippleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _fingerAnimation;

  Rect? _targetRect;
  static const double _highlightPadding = 8.0;

  /// Tooltip size estimate for positioning calculation
  static const double _tooltipWidth = 280.0;
  static const double _tooltipHeight = 80.0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fingerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fingerAnimation = CurvedAnimation(
      parent: _fingerController,
      curve: Curves.easeInOut,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _filterVisibleSteps();
      if (_visibleSteps.isEmpty) {
        widget.onComplete();
        return;
      }
      // Find the first step with an available target (Requirement 2.4)
      await _advanceToFirstAvailableStep();
      if (!mounted) return;
      if (_visibleSteps.isEmpty || _currentVisibleIndex >= _visibleSteps.length) {
        widget.onComplete();
        return;
      }
      _updateTargetRect();
      _fadeController.forward();
      _fingerController.repeat(reverse: true);
      _rippleController.repeat();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fingerController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _filterVisibleSteps() {
    _visibleSteps = List.from(widget.steps);
  }

  /// Find the first step whose target is available, starting from _currentVisibleIndex.
  /// Uses _waitForTarget to poll for each step's target.
  /// Skips steps whose targets are unavailable after timeout.
  ///
  /// Requirements: 2.4, 9.1, 9.2, 9.3
  Future<void> _advanceToFirstAvailableStep() async {
    while (_currentVisibleIndex < _visibleSteps.length) {
      final step = _visibleSteps[_currentVisibleIndex];
      final renderBox = _getRenderBox(step);
      if (renderBox != null && renderBox.hasSize) {
        return; // Target is available
      }
      // Wait for target to become available
      final available = await _waitForTarget(step.targetKey);
      if (!mounted) return;
      if (available) {
        return;
      }
      // Timeout — skip this step
      _currentVisibleIndex++;
    }
  }

  RenderBox? _getRenderBox(GuideStep step) {
    try {
      return step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    } catch (e) {
      return null;
    }
  }

  GuideStep? get _currentStep =>
      _visibleSteps.isNotEmpty ? _visibleSteps[_currentVisibleIndex] : null;

  bool get _isLastStep =>
      _currentVisibleIndex >= _visibleSteps.length - 1;

  void _updateTargetRect() {
    final step = _currentStep;
    if (step == null) {
      setState(() => _targetRect = null);
      return;
    }
    try {
      final renderBox = _getRenderBox(step);
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        setState(() {
          _targetRect = Rect.fromLTWH(
            position.dx, position.dy, size.width, size.height,
          );
        });
      } else {
        // Target element not available — skip this step (Requirement 2.4)
        setState(() => _targetRect = null);
      }
    } catch (e) {
      debugPrint('Error updating target rect: $e');
      setState(() => _targetRect = null);
    }
  }

  /// Wait for a target element's RenderBox to become available.
  /// Polls every [pollInterval] up to [timeout].
  /// Returns true if the target became available, false on timeout.
  ///
  /// Requirements: 9.1, 9.2
  Future<bool> _waitForTarget(GlobalKey targetKey, {
    Duration pollInterval = const Duration(milliseconds: 100),
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    final maxAttempts = timeout.inMilliseconds ~/ pollInterval.inMilliseconds;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        return true;
      }
      await Future.delayed(pollInterval);
      if (!mounted) return false;
    }
    return false; // timeout
  }

  /// Advance to the next step (triggered by GestureValidatorWidget)
  /// Uses fade out/in animation for smooth transitions (Requirement 2.5)
  /// If the next step's target is not available, waits for it via polling.
  /// If waiting times out, skips that step and tries subsequent ones.
  ///
  /// Requirements: 2.4, 2.5, 9.1, 9.2, 9.3
  Future<void> _nextStep() async {
    if (_isLastStep) {
      await _complete();
      return;
    }
    // Fade out current step
    await _fadeController.reverse();
    if (!mounted) return;

    // Advance index and find a step with an available target
    int nextIndex = _currentVisibleIndex + 1;
    while (nextIndex < _visibleSteps.length) {
      final nextStep = _visibleSteps[nextIndex];
      final renderBox = _getRenderBox(nextStep);
      if (renderBox != null && renderBox.hasSize) {
        // Target is already available
        break;
      }
      // Target not available — wait for it (Requirement 9.1, 9.2)
      final available = await _waitForTarget(nextStep.targetKey);
      if (!mounted) return;
      if (available) {
        break;
      }
      // Timeout — skip this step (Requirement 9.3)
      nextIndex++;
    }

    if (!mounted) return;

    // All remaining steps exhausted — complete the guide
    if (nextIndex >= _visibleSteps.length) {
      await _complete();
      return;
    }

    setState(() => _currentVisibleIndex = nextIndex);
    _updateTargetRect();

    // Fade in new step
    if (mounted) {
      await _fadeController.forward();
    }
  }

  Future<void> _complete() async {
    await _fadeController.reverse();
    if (!mounted) return;
    widget.onComplete();
  }

  Future<void> _skip() async {
    await _fadeController.reverse();
    if (!mounted) return;
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visibleSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final currentStep = _currentStep;
    final gestureType = currentStep?.gestureType ?? GestureType.tap;

    // Target rect for finger pointer and ripple effect
    // When targetRect is available, use it directly; otherwise fallback to screen center
    final effectRect = _targetRect ?? Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height * 0.35),
      width: 120,
      height: 80,
    );

    // Calculate tooltip position using the pure function
    final tooltipPosition = calculateTooltipPosition(
      targetRect: effectRect,
      screenSize: screenSize,
      tooltipSize: const Size(_tooltipWidth, _tooltipHeight),
    );

    final stepIndicator =
        '${_currentVisibleIndex + 1} / ${_visibleSteps.length}';

    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Semi-transparent mask with highlight hole
            Positioned.fill(
              child: CustomPaint(
                painter: HighlightMaskPainter(
                  targetRect: _targetRect,
                  overlayColor: Colors.black.withAlpha(100),
                  highlightPadding: _highlightPadding,
                  highlightBorderRadius: 8.0,
                ),
              ),
            ),

            // Ripple effect centered on targetRect center
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rippleController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: RippleEffectPainter(
                      targetRect: effectRect,
                      rippleProgress: _rippleController.value,
                      rippleColor: Colors.white,
                    ),
                  );
                },
              ),
            ),

            // Finger pointer positioned based on targetRect, with gestureType
            FingerPointerWidget(
              targetRect: effectRect,
              gestureType: gestureType,
              bounceAnimation: _fingerAnimation,
              color: Colors.white,
              iconSize: 52.0,
            ),

            // Tooltip positioned using calculateTooltipPosition
            if (currentStep != null)
              Positioned(
                left: tooltipPosition.dx,
                top: tooltipPosition.dy,
                child: widget.tooltipStyle == GuideTooltipStyle.glassmorphism
                    ? GlassmorphismTooltip(
                        text: currentStep.description,
                        stepIndicator: stepIndicator,
                      )
                    : GlowBorderTooltip(
                        text: currentStep.description,
                        stepIndicator: stepIndicator,
                      ),
              ),

            // Skip button (bottom-right, small text)
            if (widget.canSkip && !_isLastStep)
              Positioned(
                right: 24,
                bottom: safeBottom + 20,
                child: GestureDetector(
                  onTap: _skip,
                  child: Text(
                    '跳过引导',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),

            // GestureValidatorWidget: replaces "tap anywhere to advance"
            // Positioned over the target area, validates gesture before advancing
            if (_targetRect != null && currentStep != null)
              GestureValidatorWidget(
                targetRect: _targetRect!,
                expectedGesture: gestureType,
                onGestureMatched: _nextStep,
                padding: _highlightPadding,
              ),
          ],
        ),
      ),
    );
  }
}

/// 计算提示框位置（纯函数，可独立测试）
///
/// 根据目标元素在屏幕中的位置自动决定提示框显示在目标上方或下方：
/// - 目标中心在屏幕上半部分 → 提示框显示在目标下方
/// - 目标中心在屏幕下半部分 → 提示框显示在目标上方
/// 水平方向居中对齐目标，超出屏幕边界时裁剪到安全区域内。
/// 与目标保持最小间距（[minSpacing]），避免与手指动画重叠。
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
Offset calculateTooltipPosition({
  required Rect targetRect,
  required Size screenSize,
  required Size tooltipSize,
  double padding = 16.0,
  double minSpacing = 80.0,
}) {
  final double tooltipWidth = tooltipSize.width;
  final double tooltipHeight = tooltipSize.height;

  // 垂直定位：根据目标中心在屏幕上/下半部分决定
  double top;
  final bool targetInUpperHalf = targetRect.center.dy <= screenSize.height / 2;

  if (targetInUpperHalf) {
    // 目标在上半屏 → 提示框在目标下方，保持 minSpacing 间距
    top = targetRect.bottom + minSpacing;
  } else {
    // 目标在下半屏 → 提示框在目标上方，保持 minSpacing 间距
    top = targetRect.top - minSpacing - tooltipHeight;
  }

  // 水平定位：居中对齐目标
  double left = targetRect.center.dx - tooltipWidth / 2;

  // 边界裁剪：确保提示框完全在屏幕安全区域内（16px padding）
  left = left.clamp(padding, screenSize.width - tooltipWidth - padding);
  top = top.clamp(padding, screenSize.height - tooltipHeight - padding);

  return Offset(left, top);
}

/// 显示增强引导覆盖层
OverlayEntry? showEnhancedGuideOverlay({
  required BuildContext context,
  required List<GuideStep> steps,
  required VoidCallback onComplete,
  VoidCallback? onSkip,
  bool canSkip = true,
  GuideTooltipStyle tooltipStyle = GuideTooltipStyle.glassmorphism,
}) {
  if (steps.isEmpty) {
    onComplete();
    return null;
  }

  OverlayEntry? overlayEntry;

  void removeOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  overlayEntry = OverlayEntry(
    builder: (context) => EnhancedGuideOverlay(
      steps: steps,
      canSkip: canSkip,
      tooltipStyle: tooltipStyle,
      onComplete: () {
        removeOverlay();
        onComplete();
      },
      onSkip: onSkip != null
          ? () {
              removeOverlay();
              onSkip();
            }
          : () {
              removeOverlay();
              onComplete();
            },
    ),
  );

  Overlay.of(context).insert(overlayEntry!);
  return overlayEntry;
}
