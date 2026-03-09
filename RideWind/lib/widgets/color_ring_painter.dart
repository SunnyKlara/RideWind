import 'dart:math';
import 'package:flutter/material.dart';
import '../data/traditional_chinese_colors.dart';

/// 排好序的色系数据
class SortedFamily {
  final String id;
  final String name;
  final List<ChineseColor> colors;
  final List<int> columnLengths;

  const SortedFamily({
    required this.id,
    required this.name,
    required this.colors,
    required this.columnLengths,
  });

  int get totalColumns => columnLengths.length;
  int get maxRows => columnLengths.isEmpty ? 0 : columnLengths.reduce(max);
}

/// 色彩圆环绘制器 — COPIC 风格色轮
///
/// 两层结构：
/// 1. 最内圈：白灰色系（neutral）形成闭合圆环
/// 2. 外圈：彩色色系，内圈固定，外圈自由生长
/// 两层之间有间隙
class ColorRingPainter extends CustomPainter {
  final List<SortedFamily> sortedFamilies;
  final double rotationAngle;
  final ChineseColor? selectedColor;
  final double innerRadius; // 灰度内环的内圈半径
  final double outerRadius;

  /// 灰度内环的行高（单行闭合环）
  static const double neutralRingHeight = 28.0;
  /// 灰度内环和彩色外环之间的间隙
  static const double ringGap = 6.0;
  /// 彩色色块行高
  static const double rowHeight = 28.0;

  static const double sectorGap = 0.016;
  static const double layerGap = 1.5;
  static const double colGap = 1.5;
  static const double separatorWidth = 2.0;
  static const double selectedStrokeWidth = 3.0;

  ColorRingPainter({
    required this.sortedFamilies,
    required this.rotationAngle,
    this.selectedColor,
    required this.innerRadius,
    required this.outerRadius,
  });

  /// 灰度内环的外圈半径
  double get neutralOuterRadius => innerRadius + neutralRingHeight;

  /// 彩色外环的起始半径
  double get colorRingInnerRadius => neutralOuterRadius + ringGap;

  SortedFamily? get _neutralFamily {
    for (final sf in sortedFamilies) {
      if (sf.id == 'neutral') return sf;
    }
    return null;
  }

  List<SortedFamily> get _colorFamilies =>
      sortedFamilies.where((sf) => sf.id != 'neutral').toList();

  @override
  void paint(Canvas canvas, Size size) {
    if (sortedFamilies.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // 1. 绘制灰度内环
    final neutral = _neutralFamily;
    if (neutral != null && neutral.colors.isNotEmpty) {
      _drawNeutralRing(canvas, neutral);
    }

    // 2. 绘制彩色外环
    final colorFams = _colorFamilies;
    if (colorFams.isNotEmpty) {
      _drawColorRing(canvas, colorFams);
    }

    canvas.restore();
  }

  /// 绘制灰度内环 — 按明度排序形成渐变闭合圆环，带文字
  void _drawNeutralRing(Canvas canvas, SortedFamily neutral) {
    final colors = List<ChineseColor>.from(neutral.colors);
    if (colors.isEmpty) return;

    colors.sort((a, b) {
      final la = 0.299 * a.r + 0.587 * a.g + 0.114 * a.b;
      final lb = 0.299 * b.r + 0.587 * b.g + 0.114 * b.b;
      return la.compareTo(lb);
    });

    final count = colors.length;
    final sweepPerBlock = 2 * pi / count;
    const gapAngle = 0.005;

    for (int i = 0; i < count; i++) {
      final color = colors[i];
      final startAngle = rotationAngle + i * sweepPerBlock + gapAngle / 2;
      final blockSweep = sweepPerBlock - gapAngle;

      final rInner = innerRadius + 1.0;
      final rOuter = neutralOuterRadius - 1.0;

      final paint = Paint()
        ..color = color.toColor()
        ..style = PaintingStyle.fill;
      final path = _buildRectRingPath(startAngle, blockSweep, rInner, rOuter);
      canvas.drawPath(path, paint);

      _drawBlockLabel(canvas, color, startAngle, blockSweep, rInner, rOuter);

      if (selectedColor != null &&
          selectedColor!.name == color.name &&
          selectedColor!.family == color.family) {
        final hlPaint = Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = selectedStrokeWidth;
        canvas.drawPath(path, hlPaint);
      }
    }

    // 精致的边框线
    final borderPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(Offset.zero, innerRadius + 0.5, borderPaint);
    canvas.drawCircle(Offset.zero, neutralOuterRadius - 0.5, borderPaint);
  }

  /// 绘制彩色外环 — 内圈固定，外圈自由生长
  void _drawColorRing(Canvas canvas, List<SortedFamily> colorFams) {
    final familyCount = colorFams.length;
    final List<int> familyCols =
        colorFams.map((f) => f.totalColumns).toList();
    final totalCols = familyCols.fold<int>(0, (sum, c) => sum + c);
    if (totalCols == 0) return;

    final cInner = colorRingInnerRadius;
    final totalGap = sectorGap * familyCount;
    final usableAngle = 2 * pi - totalGap;

    double sectorStart = rotationAngle;
    for (int fi = 0; fi < familyCount; fi++) {
      final sf = colorFams[fi];
      final cols = familyCols[fi];
      if (cols == 0) {
        sectorStart += sectorGap;
        continue;
      }

      final sectorSweep = usableAngle * cols / totalCols;
      final blockStart = sectorStart + sectorGap / 2;

      final maxOuterR = cInner + sf.maxRows * rowHeight;
      final midRadius = (cInner + maxOuterR) / 2;
      final colGapAngle = colGap / midRadius;
      final totalColGapAngle = colGapAngle * max(0, cols - 1);
      final blockSweep =
          cols > 1 ? (sectorSweep - totalColGapAngle) / cols : sectorSweep;

      int colorIdx = 0;
      for (int col = 0; col < cols; col++) {
        final colAngle = blockStart + col * (blockSweep + colGapAngle);
        final rowsInCol = sf.columnLengths[col];

        for (int row = 0; row < rowsInCol; row++) {
          if (colorIdx >= sf.colors.length) break;

          final color = sf.colors[colorIdx];
          final rInner = cInner + row * rowHeight + layerGap / 2;
          final rOuter = cInner + (row + 1) * rowHeight - layerGap / 2;

          final paint = Paint()
            ..color = color.toColor()
            ..style = PaintingStyle.fill;
          final path =
              _buildRectRingPath(colAngle, blockSweep, rInner, rOuter);
          canvas.drawPath(path, paint);

          _drawBlockLabel(canvas, color, colAngle, blockSweep, rInner, rOuter);

          if (selectedColor != null &&
              selectedColor!.name == color.name &&
              selectedColor!.family == color.family) {
            final hlPaint = Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = selectedStrokeWidth;
            canvas.drawPath(path, hlPaint);
          }

          colorIdx++;
        }
      }

      sectorStart += sectorSweep + sectorGap;
    }

    _drawSeparators(canvas, colorFams, familyCols, totalCols, usableAngle);
  }

  void _drawBlockLabel(Canvas canvas, ChineseColor color, double startAngle,
      double sweepAngle, double rInner, double rOuter) {
    final midAngle = startAngle + sweepAngle / 2;
    final midRadius = (rInner + rOuter) / 2;

    final arcLength = midRadius * sweepAngle;
    final radialHeight = rOuter - rInner;
    final minDim = min(arcLength, radialHeight);

    // 极小色块也尝试显示文字
    if (minDim < 6) return;

    final fontSize = (minDim * 0.32).clamp(4.0, 10.0);

    // 先尝试完整名字，放不下就截断
    String label = color.name;
    TextPainter textPainter;

    for (int attempt = 0; attempt < 2; attempt++) {
      final textStyle = TextStyle(
        color: color.textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      );
      final textSpan = TextSpan(text: label, style: textStyle);
      textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      if (textPainter.width <= arcLength * 1.05 &&
          textPainter.height <= radialHeight * 0.95) {
        // 能放下，绘制
        final labelCenter = Offset(
          midRadius * cos(midAngle),
          midRadius * sin(midAngle),
        );

        canvas.save();
        canvas.translate(labelCenter.dx, labelCenter.dy);

        // 文字沿切线方向排列，朝向圆环外侧
        // midAngle 是径向角度，文字沿切线 = midAngle + pi/2 或 midAngle - pi/2
        // 根据所在半圆决定翻转，确保文字始终朝外（从外向圆心方向可正读）
        double normalizedAngle = midAngle % (2 * pi);
        if (normalizedAngle < 0) normalizedAngle += 2 * pi;

        double textRotation;
        if (normalizedAngle > pi / 2 && normalizedAngle < 3 * pi / 2) {
          // 左半圆：文字需要翻转，让底部朝向圆心
          textRotation = midAngle + pi / 2 + pi;
        } else {
          // 右半圆：文字底部自然朝向圆心
          textRotation = midAngle - pi / 2;
        }

        canvas.rotate(textRotation);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
        return;
      }

      // 第一次放不下，截断到1个字再试
      if (attempt == 0 && label.length > 1) {
        label = label.substring(0, 1);
      } else {
        break;
      }
    }
  }

  void _drawSeparators(Canvas canvas, List<SortedFamily> families,
      List<int> familyCols, int totalCols, double usableAngle) {
    final separatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = separatorWidth;

    final cInner = colorRingInnerRadius;

    double angle = rotationAngle;
    for (int fi = 0; fi < families.length; fi++) {
      final sf = families[fi];
      final colOuter = cInner + sf.maxRows * rowHeight;

      final startPoint = Offset(
        cInner * cos(angle),
        cInner * sin(angle),
      );
      final endPoint = Offset(
        colOuter * cos(angle),
        colOuter * sin(angle),
      );
      canvas.drawLine(startPoint, endPoint, separatorPaint);

      final sectorSweep = usableAngle * familyCols[fi] / totalCols;
      angle += sectorSweep + sectorGap;
    }
  }

  Path _buildRectRingPath(
    double startAngle,
    double sweepAngle,
    double rInner,
    double rOuter,
  ) {
    final path = Path();
    path.arcTo(
      Rect.fromCircle(center: Offset.zero, radius: rOuter),
      startAngle,
      sweepAngle,
      true,
    );
    path.lineTo(
      rInner * cos(startAngle + sweepAngle),
      rInner * sin(startAngle + sweepAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: Offset.zero, radius: rInner),
      startAngle + sweepAngle,
      -sweepAngle,
      false,
    );
    path.close();
    return path;
  }

  /// 命中检测
  ChineseColor? colorHitTest(Offset localPosition, Size size) {
    if (sortedFamilies.isEmpty) return null;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    double angle = atan2(dy, dx);
    angle -= rotationAngle;
    angle = angle % (2 * pi);
    if (angle < 0) angle += 2 * pi;

    // 检测灰度内环
    final neutral = _neutralFamily;
    if (neutral != null &&
        distance >= innerRadius &&
        distance <= neutralOuterRadius) {
      final colors = List<ChineseColor>.from(neutral.colors);
      colors.sort((a, b) {
        final la = 0.299 * a.r + 0.587 * a.g + 0.114 * a.b;
        final lb = 0.299 * b.r + 0.587 * b.g + 0.114 * b.b;
        return la.compareTo(lb);
      });
      final count = colors.length;
      if (count > 0) {
        final sweepPerBlock = 2 * pi / count;
        final idx = (angle / sweepPerBlock).floor();
        if (idx >= 0 && idx < count) {
          return colors[idx];
        }
      }
    }

    // 检测彩色外环
    final cInner = colorRingInnerRadius;
    if (distance < cInner) return null;

    final colorFams = _colorFamilies;
    final familyCount = colorFams.length;
    final List<int> familyCols =
        colorFams.map((f) => f.totalColumns).toList();
    final totalCols = familyCols.fold<int>(0, (sum, c) => sum + c);
    if (totalCols == 0) return null;

    final totalGap = sectorGap * familyCount;
    final usableAngle = 2 * pi - totalGap;

    double sectorStart = 0.0;
    for (int fi = 0; fi < familyCount; fi++) {
      final cols = familyCols[fi];
      final sectorSweep = usableAngle * cols / totalCols;
      final sectorEnd = sectorStart + sectorSweep + sectorGap;

      if (angle >= sectorStart && angle < sectorEnd) {
        final blockStart = sectorStart + sectorGap / 2;
        final blockEnd = sectorStart + sectorGap / 2 + sectorSweep;
        if (angle < blockStart || angle > blockEnd) return null;

        final sf = colorFams[fi];
        if (cols == 0) return null;

        final maxOuterR = cInner + sf.maxRows * rowHeight;
        final midRadius = (cInner + maxOuterR) / 2;
        final colGapAngle = colGap / midRadius;
        final totalColGapAngle = colGapAngle * max(0, cols - 1);
        final blockSweep =
            cols > 1 ? (sectorSweep - totalColGapAngle) / cols : sectorSweep;

        final angleInSector = angle - blockStart;
        final colStep = blockSweep + colGapAngle;
        final col = (angleInSector / colStep).floor();
        if (col < 0 || col >= cols) return null;

        final posInCol = angleInSector - col * colStep;
        if (posInCol > blockSweep) return null;

        final rowsInCol = sf.columnLengths[col];
        final colOuter = cInner + rowsInCol * rowHeight;

        if (distance > colOuter) return null;

        final row = ((distance - cInner) / rowHeight).floor();
        if (row < 0 || row >= rowsInCol) return null;

        final posInRow = distance - cInner - row * rowHeight;
        if (posInRow < layerGap / 2 || posInRow > rowHeight - layerGap / 2) {
          return null;
        }

        int colorIndex = 0;
        for (int c = 0; c < col; c++) {
          colorIndex += sf.columnLengths[c];
        }
        colorIndex += row;
        if (colorIndex >= sf.colors.length) return null;

        return sf.colors[colorIndex];
      }

      sectorStart = sectorEnd;
    }

    return null;
  }

  @override
  bool shouldRepaint(covariant ColorRingPainter oldDelegate) {
    return sortedFamilies != oldDelegate.sortedFamilies ||
        rotationAngle != oldDelegate.rotationAngle ||
        selectedColor != oldDelegate.selectedColor ||
        innerRadius != oldDelegate.innerRadius ||
        outerRadius != oldDelegate.outerRadius;
  }
}
