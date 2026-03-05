import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// 单股烟雾流的状态
class _SmokeStream {
  final double y;          // 固定 Y 位置（屏幕像素）
  double headX;            // 烟雾前端 X 位置
  double noiseOffset;      // Noise 偏移，让每股有微小波动
  final double speed;      // 水平推进速度
  final double thickness;  // 线条粗细

  _SmokeStream({
    required this.y,
    required this.speed,
    required this.thickness,
    this.headX = 0,
    this.noiseOffset = 0,
  });
}

/// 烟雾射流绘制器 - 5 条笔直连续的烟雾线
class _SmokeStreamPainter extends CustomPainter {
  final List<_SmokeStream> streams;
  final int tick;

  _SmokeStreamPainter({required this.streams, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    // 黑色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    for (final stream in streams) {
      _drawStream(canvas, size, stream);
    }
  }

  void _drawStream(Canvas canvas, Size size, _SmokeStream stream) {
    final double endX = stream.headX.clamp(0.0, size.width);
    if (endX <= 0) return;

    // 构建路径：从左边缘到 headX，带微小垂直波动
    final path = Path();
    path.moveTo(0, stream.y);

    // 每 20 像素一个控制点，加入极小的正弦波动让烟雾有生命感
    const double segLen = 20.0;
    final int segments = (endX / segLen).ceil();
    for (int i = 1; i <= segments; i++) {
      final double x = (i * segLen).clamp(0.0, endX);
      // 微小的垂直波动（±2像素），随时间缓慢变化
      final double wave = sin(x * 0.02 + stream.noiseOffset + tick * 0.03) * 2.0;
      path.lineTo(x, stream.y + wave);
    }

    // 第1层：外层大范围发光
    final glowPaint = Paint()
      ..color = const Color(0xFFc0c0d8).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stream.thickness * 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stream.thickness * 2.5);
    canvas.drawPath(path, glowPaint);

    // 第2层：中层主体
    final bodyPaint = Paint()
      ..color = const Color(0xFFd0d0e0).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stream.thickness * 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stream.thickness * 1.2);
    canvas.drawPath(path, bodyPaint);

    // 第3层：内层亮核
    final corePaint = Paint()
      ..color = const Color(0xFFe8e8ff).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stream.thickness * 1.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stream.thickness * 0.5);
    canvas.drawPath(path, corePaint);

    // 烟雾前端：渐隐效果（在最后 60 像素逐渐变淡）
    if (endX > 60) {
      final fadeStart = endX - 60;
      final fadePaint = Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stream.thickness * 5.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 35);
      // 在尾端画一小段黑色模糊来柔化边缘
      final fadePath = Path()
        ..moveTo(endX - 10, stream.y)
        ..lineTo(endX + 20, stream.y);
      canvas.drawPath(fadePath, fadePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


/// 🧪 开发测试界面 - 5股笔直烟雾射流
class DevTestScreen extends StatefulWidget {
  final bool isVisible;
  const DevTestScreen({super.key, this.isVisible = true});

  @override
  State<DevTestScreen> createState() => _DevTestScreenState();
}

class _DevTestScreenState extends State<DevTestScreen> {
  Timer? _timer;
  final List<_SmokeStream> _streams = [];
  int _tick = 0;
  bool _initialized = false;

  // 触摸交互
  Offset? _lastTouchPos;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _startSimulation();
    }
  }

  @override
  void didUpdateWidget(DevTestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _startSimulation();
      } else {
        _stopSimulation();
      }
    }
  }

  @override
  void dispose() {
    _stopSimulation();
    super.dispose();
  }

  void _initStreams(double screenHeight) {
    if (_initialized) return;
    _initialized = true;
    final random = Random();

    // 5 股烟雾，均匀分布在屏幕高度 12%~88%
    for (int i = 0; i < 5; i++) {
      final y = screenHeight * (0.12 + 0.76 * i / 4);
      _streams.add(_SmokeStream(
        y: y,
        speed: 4.0 + random.nextDouble() * 2.0, // 每股速度略有差异
        thickness: 12.0 + random.nextDouble() * 5.0, // 更粗的烟雾
        headX: 0,
        noiseOffset: random.nextDouble() * 6.28, // 随机相位
      ));
    }
  }

  void _startSimulation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _tick++;
      final screenW = _lastKnownWidth ?? 500;

      for (final stream in _streams) {
        // 烟雾前端向右推进
        if (stream.headX < screenW + 30) {
          stream.headX += stream.speed;
        }
        // 更新 noise 偏移让波动持续变化
        stream.noiseOffset += 0.01;
      }

      if (mounted) setState(() {});
    });
  }

  void _stopSimulation() {
    _timer?.cancel();
    _timer = null;
  }

  double? _lastKnownWidth;
  double? _lastKnownHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastKnownWidth = constraints.biggest.width;
          _lastKnownHeight = constraints.biggest.height;
          _initStreams(constraints.biggest.height);
          return GestureDetector(
            onPanUpdate: (details) {
              // 触摸交互：扰动最近的烟雾流
              _lastTouchPos = details.localPosition;
            },
            onPanEnd: (_) => _lastTouchPos = null,
            child: CustomPaint(
              size: constraints.biggest,
              painter: _SmokeStreamPainter(
                streams: _streams,
                tick: _tick,
              ),
            ),
          );
        },
      ),
    );
  }
}
