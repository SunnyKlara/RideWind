import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../utils/responsive_utils.dart';

class RGBColorScreen extends StatefulWidget {
  const RGBColorScreen({super.key});

  @override
  State<RGBColorScreen> createState() => _RGBColorScreenState();
}

class _RGBColorScreenState extends State<RGBColorScreen> {
  // 四个灯光区域的RGB值
  final List<List<double>> _rgbValues = [
    [255, 255, 255], // L - 左侧
    [255, 255, 255], // M - 中间
    [255, 255, 255], // R - 右侧
    [255, 0, 0],     // B - 后部（默认红色）
  ];
  
  int _selectedZone = 3; // 默认选择后部(B)
  double _loopSpeed = 0.5; // 循环速度

  Future<void> _handleBackNavigation() async {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
          builder: (context, constraints) {
            // 根据可用空间动态计算各部分高度
            final isSmallScreen = ResponsiveUtils.isSmallScreen(context);
            final availableHeight = constraints.maxHeight;
            
            // 动态高度分配
            final topBarHeight = ResponsiveUtils.scaledHeight(context, 80.0).clamp(70.0, 90.0);
            final deviceDisplayHeight = isSmallScreen 
                ? availableHeight * 0.18  // 小屏幕：18%
                : availableHeight * 0.22; // 大屏幕：22%
            final spacing1 = isSmallScreen ? 24.0 : 40.0;
            
            return SingleChildScrollView(  // ✅ 添加滚动支持，防止overflow
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight,
                ),
                child: Column(
                  children: [
                    // 顶部栏
                    SizedBox(
                      height: topBarHeight,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.horizontalPadding(context),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              iconSize: ResponsiveUtils.scaledSize(context, 24.0).clamp(20.0, 28.0),
                              onPressed: _handleBackNavigation,
                            ),
                            Text(
                              '色彩设置',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.scaledFontSize(
                                  context, 
                                  18.0,
                                  minSize: 16.0,
                                  maxSize: 20.0,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              iconSize: ResponsiveUtils.scaledSize(context, 24.0).clamp(20.0, 28.0),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 设备展示
                    Container(
                      height: deviceDisplayHeight.clamp(140.0, 200.0),
                      margin: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.horizontalPadding(context) * 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]?.withAlpha(77),
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.scaledSize(context, 20.0).clamp(16.0, 24.0),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: ResponsiveUtils.width(context, 70).clamp(240.0, 320.0),
                          height: ResponsiveUtils.scaledSize(context, 70.0).clamp(60.0, 80.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.directions_car, 
                              color: Colors.white, 
                              size: ResponsiveUtils.scaledSize(context, 40.0).clamp(32.0, 48.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing1),
            
                    // 区域选择按钮
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.horizontalPadding(context),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildZoneButton(context, 'L', 0),
                          SizedBox(width: ResponsiveUtils.scaledSize(context, 12.0).clamp(8.0, 16.0)),
                          _buildZoneButton(context, 'M', 1),
                          SizedBox(width: ResponsiveUtils.scaledSize(context, 12.0).clamp(8.0, 16.0)),
                          _buildZoneButton(context, 'R', 2),
                          SizedBox(width: ResponsiveUtils.scaledSize(context, 12.0).clamp(8.0, 16.0)),
                          _buildZoneButton(context, 'B', 3),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 40.0 : 60.0),
            
                    // RGB滑块（移除Expanded，使用固定高度）
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.horizontalPadding(context) * 2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildColorSlider(
                            context,
                            'R',
                            Colors.red,
                            _rgbValues[_selectedZone][0],
                            (value) {
                              setState(() {
                                _rgbValues[_selectedZone][0] = value;
                              });
                            },
                          ),
                          
                          SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                          
                          _buildColorSlider(
                            context,
                            'G',
                            Colors.green,
                            _rgbValues[_selectedZone][1],
                            (value) {
                              setState(() {
                                _rgbValues[_selectedZone][1] = value;
                              });
                            },
                          ),
                          
                          SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                          
                          _buildColorSlider(
                            context,
                            'B',
                            Colors.blue,
                            _rgbValues[_selectedZone][2],
                            (value) {
                              setState(() {
                                _rgbValues[_selectedZone][2] = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
            
                    
                    SizedBox(height: isSmallScreen ? 30.0 : 40.0),
                    
                    // 循环速度控制
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.horizontalPadding(context) * 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '循环速度',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.scaledFontSize(
                                    context, 
                                    18.0,
                                    minSize: 16.0,
                                    maxSize: 20.0,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                  
                  Row(
                    children: [
                      const Text('慢', style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: _loopSpeed,
                            min: 0,
                            max: 1,
                            divisions: 4,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white30,
                            onChanged: (value) {
                              setState(() {
                                _loopSpeed = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const Text('快', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            
                    SizedBox(height: isSmallScreen ? 30.0 : 40.0),
                    
                    // 应用按钮
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.horizontalPadding(context),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: ResponsiveUtils.buttonHeight(context),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFFEC4899),
                        Colors.red,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final deviceProvider = Provider.of<DeviceProvider>(
                        context,
                        listen: false,
                      );
                      
                      // 应用选中区域的颜色
                      deviceProvider.setRGBColor(
                        _rgbValues[_selectedZone].map((e) => e.toInt()).toList(),
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '已应用颜色: RGB(${_rgbValues[_selectedZone][0].toInt()}, '
                            '${_rgbValues[_selectedZone][1].toInt()}, '
                            '${_rgbValues[_selectedZone][2].toInt()})',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      '应用设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 30.0 : 40.0),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildZoneButton(BuildContext context, String label, int index) {
    final isSelected = _selectedZone == index;
    final rgb = _rgbValues[index];
    final color = Color.fromRGBO(
      rgb[0].toInt(),
      rgb[1].toInt(),
      rgb[2].toInt(),
      1,
    );
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedZone = index;
        });
      },
      child: Container(
        width: ResponsiveUtils.scaledSize(context, 70.0).clamp(60.0, 80.0),
        height: ResponsiveUtils.scaledSize(context, 110.0).clamp(90.0, 120.0),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveUtils.scaledSize(context, 35.0).clamp(30.0, 40.0)),
          border: isSelected ? Border.all(
            color: Colors.white, 
            width: ResponsiveUtils.scaledSize(context, 3.0).clamp(2.0, 4.0),
          ) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontSize: ResponsiveUtils.scaledFontSize(context, 32.0, minSize: 28.0, maxSize: 36.0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSlider(
    BuildContext context,
    String label,
    Color color,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final isSmallScreen = ResponsiveUtils.isSmallScreen(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveUtils.scaledFontSize(context, 20.0, minSize: 18.0, maxSize: 22.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        
        SizedBox(width: isSmallScreen ? 16.0 : 20.0),
        
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: ResponsiveUtils.scaledSize(context, 8.0).clamp(6.0, 10.0),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: ResponsiveUtils.scaledSize(context, 12.0).clamp(10.0, 14.0),
              ),
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: ResponsiveUtils.scaledSize(context, 20.0).clamp(16.0, 24.0),
              ),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              activeColor: color,
              inactiveColor: Colors.white30,
              onChanged: onChanged,
            ),
          ),
        ),
        
        SizedBox(width: isSmallScreen ? 8.0 : 12.0),
        
        SizedBox(
          width: ResponsiveUtils.scaledSize(context, 50.0).clamp(45.0, 55.0),
          child: Text(
            value.toInt().toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.scaledFontSize(context, 16.0, minSize: 14.0, maxSize: 18.0),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

