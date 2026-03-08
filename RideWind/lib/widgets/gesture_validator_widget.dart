import 'package:flutter/material.dart';
import 'package:ridewind/models/guide_models.dart';

/// 手势事件数据，用于手势匹配判断
class GestureData {
  /// 检测到的手势类型
  final GestureType gestureType;

  /// 手势速度（用于 swipe 检测）
  final Offset velocity;

  /// 手势累计位移（用于 drag 检测）
  final Offset displacement;

  const GestureData({
    required this.gestureType,
    this.velocity = Offset.zero,
    this.displacement = Offset.zero,
  });
}

/// 拖动位移匹配阈值（像素）
const double dragDisplacementThreshold = 30.0;

/// 纯函数：判断实际手势数据是否匹配期望的手势类型
///
/// 匹配规则：
/// - tap: gestureType 为 tap 即匹配
/// - longPress: gestureType 为 longPress 即匹配
/// - swipeLeft: gestureType 为 swipeLeft 且水平速度为负
/// - swipeRight: gestureType 为 swipeRight 且水平速度为正
/// - swipeUp: gestureType 为 swipeUp 且垂直速度为负
/// - swipeDown: gestureType 为 swipeDown 且垂直速度为正
/// - dragHorizontal: gestureType 为 dragHorizontal 且水平位移超过阈值
/// - dragVertical: gestureType 为 dragVertical 且垂直位移超过阈值
bool matchesGesture(GestureType expected, GestureData actual) {
  switch (expected) {
    case GestureType.tap:
      return actual.gestureType == GestureType.tap;
    case GestureType.longPress:
      return actual.gestureType == GestureType.longPress;
    case GestureType.swipeLeft:
      return actual.gestureType == GestureType.swipeLeft &&
          actual.velocity.dx < 0;
    case GestureType.swipeRight:
      return actual.gestureType == GestureType.swipeRight &&
          actual.velocity.dx > 0;
    case GestureType.swipeUp:
      return actual.gestureType == GestureType.swipeUp &&
          actual.velocity.dy < 0;
    case GestureType.swipeDown:
      return actual.gestureType == GestureType.swipeDown &&
          actual.velocity.dy > 0;
    case GestureType.dragHorizontal:
      return actual.gestureType == GestureType.dragHorizontal &&
          actual.displacement.dx.abs() >= dragDisplacementThreshold;
    case GestureType.dragVertical:
      return actual.gestureType == GestureType.dragVertical &&
          actual.displacement.dy.abs() >= dragDisplacementThreshold;
  }
}


/// 手势验证组件
///
/// 覆盖在目标区域上方，检测用户手势并判断是否匹配期望的手势类型。
/// 使用 [HitTestBehavior.translucent] 确保事件同时传递给底层组件。
class GestureValidatorWidget extends StatefulWidget {
  /// 目标区域的屏幕矩形
  final Rect targetRect;

  /// 期望的手势类型
  final GestureType expectedGesture;

  /// 手势匹配成功时的回调
  final VoidCallback onGestureMatched;

  /// 目标区域的额外内边距
  final double padding;

  const GestureValidatorWidget({
    super.key,
    required this.targetRect,
    required this.expectedGesture,
    required this.onGestureMatched,
    this.padding = 0.0,
  });

  @override
  State<GestureValidatorWidget> createState() =>
      _GestureValidatorWidgetState();
}

class _GestureValidatorWidgetState extends State<GestureValidatorWidget> {
  /// 累计水平拖动位移
  double _horizontalDragDisplacement = 0.0;

  /// 累计垂直拖动位移
  double _verticalDragDisplacement = 0.0;

  /// 是否已经触发过匹配（防止重复触发）
  bool _matched = false;

  @override
  void didUpdateWidget(covariant GestureValidatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetRect != widget.targetRect ||
        oldWidget.expectedGesture != widget.expectedGesture) {
      _matched = false;
      _horizontalDragDisplacement = 0.0;
      _verticalDragDisplacement = 0.0;
    }
  }

  void _onMatched() {
    if (_matched) return;
    _matched = true;
    widget.onGestureMatched();
  }

  void _handleTap() {
    final data = const GestureData(gestureType: GestureType.tap);
    if (matchesGesture(widget.expectedGesture, data)) {
      _onMatched();
    }
  }

  void _handleLongPress() {
    final data = const GestureData(gestureType: GestureType.longPress);
    if (matchesGesture(widget.expectedGesture, data)) {
      _onMatched();
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDisplacement += details.delta.dx;
    final data = GestureData(
      gestureType: GestureType.dragHorizontal,
      displacement: Offset(_horizontalDragDisplacement, 0),
    );
    if (matchesGesture(widget.expectedGesture, data)) {
      _onMatched();
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.dx < 0) {
      final data = GestureData(
        gestureType: GestureType.swipeLeft,
        velocity: velocity,
      );
      if (matchesGesture(widget.expectedGesture, data)) {
        _onMatched();
      }
    } else if (velocity.dx > 0) {
      final data = GestureData(
        gestureType: GestureType.swipeRight,
        velocity: velocity,
      );
      if (matchesGesture(widget.expectedGesture, data)) {
        _onMatched();
      }
    }
    _horizontalDragDisplacement = 0.0;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    _verticalDragDisplacement += details.delta.dy;
    final data = GestureData(
      gestureType: GestureType.dragVertical,
      displacement: Offset(0, _verticalDragDisplacement),
    );
    if (matchesGesture(widget.expectedGesture, data)) {
      _onMatched();
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.dy < 0) {
      final data = GestureData(
        gestureType: GestureType.swipeUp,
        velocity: velocity,
      );
      if (matchesGesture(widget.expectedGesture, data)) {
        _onMatched();
      }
    } else if (velocity.dy > 0) {
      final data = GestureData(
        gestureType: GestureType.swipeDown,
        velocity: velocity,
      );
      if (matchesGesture(widget.expectedGesture, data)) {
        _onMatched();
      }
    }
    _verticalDragDisplacement = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.targetRect.inflate(widget.padding);

    // Choose gesture callbacks based on expected gesture type
    final bool needsHorizontalDrag = widget.expectedGesture == GestureType.swipeLeft ||
        widget.expectedGesture == GestureType.swipeRight ||
        widget.expectedGesture == GestureType.dragHorizontal;

    final bool needsVerticalDrag = widget.expectedGesture == GestureType.swipeUp ||
        widget.expectedGesture == GestureType.swipeDown ||
        widget.expectedGesture == GestureType.dragVertical;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.expectedGesture == GestureType.tap ? _handleTap : null,
        onLongPress: widget.expectedGesture == GestureType.longPress
            ? _handleLongPress
            : null,
        onHorizontalDragUpdate:
            needsHorizontalDrag ? _handleHorizontalDragUpdate : null,
        onHorizontalDragEnd:
            needsHorizontalDrag ? _handleHorizontalDragEnd : null,
        onVerticalDragUpdate:
            needsVerticalDrag ? _handleVerticalDragUpdate : null,
        onVerticalDragEnd: needsVerticalDrag ? _handleVerticalDragEnd : null,
        child: const SizedBox.expand(),
      ),
    );
  }
}
