import 'dart:math';
import 'package:flutter/material.dart';
import '../data/traditional_chinese_colors.dart';
import '../widgets/color_detail_panel.dart';
import '../widgets/color_ring_painter.dart';

/// 色彩圆环全屏页面
///
/// 用 Transform 做手势变换，RepaintBoundary 缓存圆环位图，
/// 手势过程中不触发圆环重绘，只变换矩阵 → 流畅跟手
class ColorRingScreen extends StatefulWidget {
  final Function(int r, int g, int b) onColorSelected;

  const ColorRingScreen({super.key, required this.onColorSelected});

  @override
  State<ColorRingScreen> createState() => _ColorRingScreenState();
}

class _ColorRingScreenState extends State<ColorRingScreen>
    with TickerProviderStateMixin {
  ChineseColor? _selectedColor;

  // 圆环位置、缩放、旋转
  Offset _ringCenter = Offset.zero;
  double _scale = 1.8;
  double _rotation = 0.0;
  bool _initialized = false;

  // 手势状态
  Offset? _gestureStartFocal;
  double _gestureStartScale = 1.0;
  double _gestureStartRotation = 0.0;
  Offset _gestureStartRingCenter = Offset.zero;
  Offset? _tapPosition;
  double _totalDistance = 0.0;
  int _pointerCount = 0;
  bool _isSingleFingerRotation = false;
  double _singleFingerStartAngle = 0.0;

  // 预计算排好序的色系数据
  late final List<SortedFamily> _sortedFamilies = _buildSortedFamilies();

  // 动画
  late final AnimationController _popupController;
  late final Animation<double> _popupAnimation;

  static const double _baseInnerRadius = 90.0;

  List<SortedFamily> _buildSortedFamilies() {
    return TraditionalChineseColors.families.map((family) {
      final result =
          TraditionalChineseColors.sortFamilyIntoColumns(family);
      return SortedFamily(
        id: family.id,
        name: family.name,
        colors: result.colors,
        columnLengths: result.columnLengths,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _popupAnimation = CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _popupController.dispose();
    super.dispose();
  }

  double _calcMaxOuterRadius() {
    const innerR = _baseInnerRadius;
    const neutralOuter = innerR + ColorRingPainter.neutralRingHeight;
    const colorInner = neutralOuter + ColorRingPainter.ringGap;
    int maxRows = 0;
    for (final sf in _sortedFamilies) {
      if (sf.id == 'neutral') continue;
      if (sf.maxRows > maxRows) maxRows = sf.maxRows;
    }
    return colorInner + maxRows * ColorRingPainter.rowHeight;
  }

  bool _isTouchOnRing(Offset globalPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final localPos = box.globalToLocal(globalPos);
    final screenCenter = Offset(box.size.width / 2, box.size.height / 2);
    final ringScreenCenter = screenCenter + _ringCenter;
    final dx = localPos.dx - ringScreenCenter.dx;
    final dy = localPos.dy - ringScreenCenter.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final scaledInner = _baseInnerRadius * _scale;
    final scaledOuter = _calcMaxOuterRadius() * _scale;
    return dist >= scaledInner * 0.8 && dist <= scaledOuter * 1.1;
  }

  double _angleFromCenter(Offset globalPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final localPos = box.globalToLocal(globalPos);
    final screenCenter = Offset(box.size.width / 2, box.size.height / 2);
    final ringScreenCenter = screenCenter + _ringCenter;
    return atan2(
      localPos.dy - ringScreenCenter.dy,
      localPos.dx - ringScreenCenter.dx,
    );
  }

  // ─── 手势处理 ───

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartFocal = details.focalPoint;
    _gestureStartScale = _scale;
    _gestureStartRotation = _rotation;
    _gestureStartRingCenter = _ringCenter;
    _tapPosition = details.focalPoint;
    _totalDistance = 0.0;
    _pointerCount = details.pointerCount;

    if (details.pointerCount == 1) {
      _isSingleFingerRotation = _isTouchOnRing(details.focalPoint);
      if (_isSingleFingerRotation) {
        _singleFingerStartAngle = _angleFromCenter(details.focalPoint);
      }
    } else {
      _isSingleFingerRotation = false;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _pointerCount = max(_pointerCount, details.pointerCount);
    _totalDistance += details.focalPointDelta.distance;

    setState(() {
      if (_pointerCount >= 2) {
        _scale = (_gestureStartScale * details.scale).clamp(0.3, 4.0);
        _rotation = _gestureStartRotation + details.rotation;
        final delta = details.focalPoint - (_gestureStartFocal ?? details.focalPoint);
        _ringCenter = _gestureStartRingCenter + delta;
      } else if (_isSingleFingerRotation) {
        final currentAngle = _angleFromCenter(details.focalPoint);
        final angleDelta = currentAngle - _singleFingerStartAngle;
        _rotation = _gestureStartRotation + angleDelta;
      } else {
        final delta = details.focalPoint - (_gestureStartFocal ?? details.focalPoint);
        _ringCenter = _gestureStartRingCenter + delta;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_totalDistance < 8.0 && _tapPosition != null) {
      _handleTap(_tapPosition!);
    }
    _gestureStartFocal = null;
    _tapPosition = null;
  }

  void _handleTap(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(globalPosition);
    final canvasSize = box.size;

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final fromCenter = localPos - _ringCenter - center;
    final unscaled = fromCenter / _scale;
    // 反旋转
    final cosR = cos(-_rotation);
    final sinR = sin(-_rotation);
    final unrotated = Offset(
      unscaled.dx * cosR - unscaled.dy * sinR,
      unscaled.dx * sinR + unscaled.dy * cosR,
    );
    final adjustedPos = unrotated + center;

    final painter = ColorRingPainter(
      sortedFamilies: _sortedFamilies,
      rotationAngle: 0, // 旋转已在 Transform 中处理
      selectedColor: _selectedColor,
      innerRadius: _baseInnerRadius,
      outerRadius: _calcMaxOuterRadius(),
    );

    final hit = painter.colorHitTest(adjustedPos, canvasSize);
    if (hit != null) {
      setState(() => _selectedColor = hit);
      _popupController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      _ringCenter = Offset(-size.width / 2, -size.height / 2);
      _initialized = true;
    }

    final outerR = _calcMaxOuterRadius();
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: SizedBox.expand(
              child: Transform(
                transform: Matrix4.identity()
                  ..translate(
                    screenCenter.dx + _ringCenter.dx,
                    screenCenter.dy + _ringCenter.dy,
                  )
                  ..scale(_scale)
                  ..rotateZ(_rotation)
                  ..translate(-screenCenter.dx, -screenCenter.dy),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ColorRingPainter(
                      sortedFamilies: _sortedFamilies,
                      rotationAngle: 0, // 旋转由 Transform 处理
                      selectedColor: _selectedColor,
                      innerRadius: _baseInnerRadius,
                      outerRadius: outerR,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),

          if (_selectedColor != null)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: ScaleTransition(
                  scale: _popupAnimation,
                  alignment: Alignment.topCenter,
                  child: Material(
                    color: Colors.transparent,
                    child: ColorDetailPanel(
                      color: _selectedColor,
                      onConfirm: () {
                        final c = _selectedColor;
                        if (c != null) {
                          widget.onColorSelected(c.r, c.g, c.b);
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black54, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${(_scale * 100).round()}%',
                style: const TextStyle(color: Colors.black26, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
