import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/device_model.dart';
import '../utils/responsive_utils.dart';
import 'cleaning_mode_screen.dart';
import 'bluetooth_test_screen.dart';
// import 'colorize_mode_screen.dart'; // 已弃用，功能整合到 device_connect_screen.dart

class MainControlScreen extends StatefulWidget {
  const MainControlScreen({super.key});

  @override
  State<MainControlScreen> createState() => _MainControlScreenState();
}

class _MainControlScreenState extends State<MainControlScreen> {
  int _currentIndex = 1; // 默认显示运行模式

  final List<Widget> _screens = const [
    CleaningModeScreen(),
    // RunningModeScreen(), // 已删除，使用 device_connect_screen.dart 中的内嵌设计
    Placeholder(), // 临时占位符
    Placeholder(), // ColorizeModeScreen 已弃用，功能整合到 device_connect_screen.dart
    BluetoothTestScreen(), // 蓝牙测试界面
  ];

  @override
  Widget build(BuildContext context) {
    final isSmall = ResponsiveUtils.isSmallScreen(context);
    final safeBottom = ResponsiveUtils.safeAreaBottom(context);

    // 响应式导航栏参数
    final navBarHeight = isSmall ? 56.0 : 70.0;
    final navBarBottom = safeBottom + (isSmall ? 20.0 : 40.0);
    final navBarMargin = ResponsiveUtils.horizontalPadding(context);
    final buttonWidth = isSmall ? 70.0 : 100.0;
    final buttonHeight = isSmall ? 40.0 : 50.0;
    final buttonMargin = isSmall ? 4.0 : 8.0;
    final iconSize = isSmall ? 22.0 : 28.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主内容区域
          _screens[_currentIndex],

          // 底部导航栏
          Positioned(
            left: 0,
            right: 0,
            bottom: navBarBottom,
            child: Center(
              child: Container(
                height: navBarHeight,
                margin: EdgeInsets.symmetric(horizontal: navBarMargin),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(navBarHeight / 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNavButton(
                      index: 0,
                      color: const Color(0xFF00FF94),
                      icon: Icons.cleaning_services,
                      buttonWidth: buttonWidth,
                      buttonHeight: buttonHeight,
                      buttonMargin: buttonMargin,
                      iconSize: iconSize,
                    ),
                    _buildNavButton(
                      index: 1,
                      color: Colors.red,
                      icon: Icons.play_arrow,
                      buttonWidth: buttonWidth,
                      buttonHeight: buttonHeight,
                      buttonMargin: buttonMargin,
                      iconSize: iconSize,
                    ),
                    _buildNavButton(
                      index: 2,
                      color: const Color(0xFF6366F1),
                      icon: Icons.palette,
                      buttonWidth: buttonWidth,
                      buttonHeight: buttonHeight,
                      buttonMargin: buttonMargin,
                      iconSize: iconSize,
                    ),
                    _buildNavButton(
                      index: 3,
                      color: Colors.orange,
                      icon: Icons.bluetooth,
                      buttonWidth: buttonWidth,
                      buttonHeight: buttonHeight,
                      buttonMargin: buttonMargin,
                      iconSize: iconSize,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required int index,
    required Color color,
    required IconData icon,
    required double buttonWidth,
    required double buttonHeight,
    required double buttonMargin,
    required double iconSize,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });

        // 更新设备模式
        final deviceProvider = Provider.of<DeviceProvider>(
          context,
          listen: false,
        );
        final mode = index == 0
            ? DeviceMode.cleaning
            : index == 1
            ? DeviceMode.running
            : DeviceMode.colorize;
        deviceProvider.setMode(mode);
      },
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
        margin: EdgeInsets.symmetric(horizontal: buttonMargin),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(buttonHeight / 2),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white60,
          size: iconSize,
        ),
      ),
    );
  }
}
