import 'package:flutter/material.dart';
import 'ready_screen.dart';

/// 引导页 - 权限说明
/// 纯黑背景 + 代码实现的UI组件
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: Colors.black,
        // 空白画布，准备重新设计
      ),
    );
  }
}
