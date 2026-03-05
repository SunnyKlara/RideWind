import 'package:flutter/material.dart';
import 'permission_screen.dart';

/// 引导页 - 通知权限说明
/// 混合设计：代码实现常见组件 + 设计图实现复杂组件
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _handleBackNavigation(BuildContext context) async {
    Navigator.of(context).pop();
  }

  Future<bool> _onWillPop(BuildContext context) async {
    await _handleBackNavigation(context);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => _handleBackNavigation(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 24),
                const Text(
                  '允许通知权限',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '"驭风"需要获取通知权限，以及时报告您的设备状态，并在设备发生故障时发出警报。',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/notification_bubble.png',
                      width: MediaQuery.of(context).size.width * 0.85,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: const Text(
                            '图片加载失败\nassets/images/notification_bubble.png',
                            style: TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIndicator(true),
                    const SizedBox(width: 8),
                    _buildIndicator(false),
                    const SizedBox(width: 8),
                    _buildIndicator(false),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: SizedBox(
                    width: 320,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PermissionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(29),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '下一步',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 页面指示器横条
  /// 选中: 短条 20px，亮白色
  /// 未选中: 长条 40px，暗白色
  Widget _buildIndicator(bool isActive) {
    return Container(
      width: isActive ? 20 : 40,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isActive ? 1.0 : 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
