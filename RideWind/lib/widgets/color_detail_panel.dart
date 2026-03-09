import 'package:flutter/material.dart';
import '../data/traditional_chinese_colors.dart';

/// 选中颜色详情面板 — 显示在圆环中心区域（白色背景适配）
class ColorDetailPanel extends StatelessWidget {
  final ChineseColor? color;
  final VoidCallback? onConfirm;

  const ColorDetailPanel({
    super.key,
    this.color,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: color != null
          ? _buildColorContent(color!)
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return const SizedBox(
      key: ValueKey('placeholder'),
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: Colors.black26, size: 28),
          SizedBox(height: 6),
          Text(
            '点击色块选色',
            style: TextStyle(color: Colors.black38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildColorContent(ChineseColor c) {
    return Container(
      key: ValueKey('${c.family}_${c.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.name,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.toColor(),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: c.toColor().withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'R:${c.r} G:${c.g} B:${c.b}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: onConfirm,
              style: TextButton.styleFrom(
                backgroundColor: c.toColor(),
                foregroundColor: c.textColor,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('确认', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
