import 'package:flutter/material.dart';

/// 提示框位置枚举
/// 定义引导提示框相对于目标元素的显示位置
enum TooltipPosition {
  top,
  bottom,
  left,
  right,
}

/// 引导步骤定义
/// 用于定义功能引导中的单个步骤
class GuideStep {
  /// 目标元素的 GlobalKey，用于定位高亮区域
  final GlobalKey targetKey;

  /// 步骤标题
  final String title;

  /// 步骤描述
  final String description;

  /// 提示框位置，默认显示在目标元素下方
  final TooltipPosition position;

  /// 可选图标，用于增强视觉提示
  final IconData? icon;

  const GuideStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.position = TooltipPosition.bottom,
    this.icon,
  });
}

/// 功能引导配置
/// 用于配置完整的功能引导流程
class GuideConfiguration {
  /// 功能标识符，用于区分不同功能的引导
  final String featureId;

  /// 引导步骤列表
  final List<GuideStep> steps;

  /// 是否允许跳过引导，默认为 true
  final bool canSkip;

  /// 步骤之间的延迟时间，默认 300 毫秒
  final Duration stepDelay;

  const GuideConfiguration({
    required this.featureId,
    required this.steps,
    this.canSkip = true,
    this.stepDelay = const Duration(milliseconds: 300),
  });
}
