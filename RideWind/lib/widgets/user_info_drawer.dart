import 'package:flutter/material.dart';

/// 从右侧滑出的用户信息抽屉
///
/// 使用方法：
/// ```dart
/// UserInfoDrawer.show(context);
/// ```
class UserInfoDrawer extends StatelessWidget {
  const UserInfoDrawer({super.key});

  /// 显示用户信息抽屉
  static Future<void> show(BuildContext context) async {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // 路由不透明
        barrierColor: Colors.black.withOpacity(0.5), // 半透明遮罩
        barrierDismissible: true, // 点击遮罩可关闭
        transitionDuration: const Duration(milliseconds: 300), // 动画时长
        pageBuilder: (context, animation, secondaryAnimation) {
          return const UserInfoDrawer();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 从右侧滑入动画
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0), // 从右侧开始
                  end: Offset.zero, // 滑动到原位
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: screenWidth * 0.85, // 抽屉宽度为屏幕宽度的85%
          height: double.infinity,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A), // 深色背景
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  offset: Offset(-5, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部关闭按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '用户中心',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // 用户头像和信息
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      // 用户头像
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white70,
                          size: 50,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // 用户信息
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RideWind 用户',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '点击登录账号',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, thickness: 1),

                // 菜单项
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: '个人信息',
                  onTap: () {
                    Navigator.pop(context);
                    debugPrint('点击了个人信息');
                    // TODO: 实现个人信息功能
                  },
                ),

                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: '设置',
                  onTap: () {
                    Navigator.pop(context);
                    debugPrint('点击了设置');
                    // TODO: 实现设置功能
                  },
                ),

                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: '帮助与反馈',
                  onTap: () {
                    Navigator.pop(context);
                    debugPrint('点击了帮助与反馈');
                    // TODO: 实现帮助与反馈功能
                  },
                ),

                _buildMenuItem(
                  icon: Icons.info_outline,
                  title: '关于',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),

                const Spacer(),

                // 底部版本信息
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'RideWind v1.0.0',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建菜单项
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white54,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  // 显示关于对话框
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('关于 RideWind', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 1.0.0', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text(
              '© 2025 RideWind Inc. 保留所有权利',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              '该应用程序由 RideWind 团队开发，旨在提供最佳的智能设备控制体验。',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
