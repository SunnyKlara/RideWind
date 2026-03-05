import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/euler_fluid_simulator.dart';

/// 🧪 开发测试界面 - 欧拉流体模拟
class DevTestScreen extends StatefulWidget {
  const DevTestScreen({super.key});

  @override
  State<DevTestScreen> createState() => _DevTestScreenState();
}

class _DevTestScreenState extends State<DevTestScreen> {
  late EulerFluidSimulator _simulator;
  Timer? _timer;
  final Random _random = Random();
  
  // 触摸交互
  Offset? _lastTouchPos;
  
  // 网格分辨率
  static const int gridSize = 80;

  @override
  void initState() {
    super.initState();
    _simulator = EulerFluidSimulator(
      gridWidth: gridSize,
      gridHeight: gridSize,
      dt: 0.2,
      diffusion: 0.00001,
      viscosity: 0.00001,
      iterations: 4,
    );
    
    // 启动模拟循环 (~60fps)
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _addRandomSource();
      _simulator.step();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 添加随机烟雾源
  void _addRandomSource() {
    // 底部中央持续添加烟雾和向上的速度
    final centerX = gridSize ~/ 2;
    final bottomY = gridSize - 5;
    
    for (int dx = -3; dx <= 3; dx++) {
      _simulator.addDensity(centerX + dx, bottomY, 0.8 + _random.nextDouble() * 0.2);
      _simulator.addVelocity(
        centerX + dx, 
        bottomY, 
        (_random.nextDouble() - 0.5) * 1.0, // 轻微水平扰动
        -3.0 - _random.nextDouble() * 2.0,   // 向上速度
      );
    }
  }

  /// 处理触摸交互
  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    
    final x = (details.localPosition.dx / cellWidth).floor();
    final y = (details.localPosition.dy / cellHeight).floor();
    
    // 添加密度
    for (int dx = -2; dx <= 2; dx++) {
      for (int dy = -2; dy <= 2; dy++) {
        _simulator.addDensity(x + dx, y + dy, 0.5);
      }
    }
    
    // 根据滑动方向添加速度
    if (_lastTouchPos != null) {
      final delta = details.localPosition - _lastTouchPos!;
      _simulator.addVelocity(x, y, delta.dx * 0.5, delta.dy * 0.5);
    }
    
    _lastTouchPos = details.localPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanUpdate: (details) => _handlePanUpdate(details, constraints.biggest),
            onPanEnd: (_) => _lastTouchPos = null,
            child: CustomPaint(
              size: constraints.biggest,
              painter: _FluidPainter(_simulator, gridSize),
            ),
          );
        },
      ),
    );
  }
}

/// 流体渲染器
class _FluidPainter extends CustomPainter {
  final EulerFluidSimulator simulator;
  final int gridSize;

  _FluidPainter(this.simulator, this.gridSize);

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final density = simulator.getDensity(x, y);
        
        if (density > 0.01) {
          // 烟雾颜色渐变：从深灰到亮白
          final color = Color.lerp(
            const Color(0xFF1a1a2e),
            const Color(0xFFe0e0ff),
            density,
          )!;
          
          final paint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;

          canvas.drawRect(
            Rect.fromLTWH(
              x * cellWidth,
              y * cellHeight,
              cellWidth + 1,
              cellHeight + 1,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FluidPainter oldDelegate) => true;
}
