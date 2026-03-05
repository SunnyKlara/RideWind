# Image Conversion Fix - Design Document

## Overview

本设计文档针对Logo图片上传失败问题，提供完整的技术解决方案。问题分为两个独立但相关的部分：
1. **图片预处理**：将任意尺寸的相册图片标准化为154x154
2. **RGB565取模转换**：将标准图片转换为硬件可识别的字节数组

## Architecture

### 整体流程

```
用户选择图片 (1080x1960等)
    ↓
[阶段1] 图片预处理
    ↓
裁剪为1:1正方形 (image_cropper)
    ↓
精确缩放到154x154
    ↓
标准化RGBA格式
    ↓
[阶段2] RGB565取模转换
    ↓
逐像素转换为RGB565
    ↓
按正确字节序输出
    ↓
生成47,432字节数组
    ↓
蓝牙传输到硬件
```

### 核心组件

1. **ImagePreprocessor** - 图片预处理器
2. **RGB565Converter** - RGB565转换器
3. **DiagnosticTools** - 诊断对比工具

## Detailed Design

### 1. 图片预处理器 (ImagePreprocessor)

#### 1.1 职责
- 接收任意尺寸的图片文件
- 确保图片已被裁剪为1:1正方形
- 精确缩放到154x154像素
- 输出标准RGBA格式

#### 1.2 实现方案

**方案A：使用Flutter Image库（推荐）**
```dart
class ImagePreprocessor {
  /// 预处理图片到标准154x154格式
  Future<ui.Image> preprocessImage(File imageFile) async {
    // 1. 读取并解码图片
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;
    
    // 2. 验证图片是正方形（应该已被image_cropper处理）
    if (sourceImage.width != sourceImage.height) {
      throw Exception('图片必须是正方形，当前尺寸: ${sourceImage.width}x${sourceImage.height}');
    }
    
    // 3. 使用高质量缩放到154x154
    const targetSize = 154;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 🔥 关键：使用高质量插值，而非FilterQuality.none
    final paint = Paint()
      ..filterQuality = FilterQuality.high  // 使用高质量插值
      ..isAntiAlias = true;  // 启用抗锯齿
    
    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
      const Rect.fromLTWH(0, 0, targetSize.toDouble(), targetSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(targetSize, targetSize);
    
    return resizedImage;
  }
}
```

**关键决策**：
- ✅ 使用 `FilterQuality.high` 而非 `FilterQuality.none`
- ✅ 启用抗锯齿以获得更平滑的结果
- ✅ 验证输入是正方形（依赖image_cropper）

### 2. RGB565转换器 (RGB565Converter)

#### 2.1 职责
- 接收154x154的标准图片
- 提取RGBA像素数据
- 转换为RGB565格式
- 按正确字节序输出47,432字节数组

#### 2.2 RGB565格式详解

**🔥 关键发现：专业取模软件要求BMP格式！**

BMP格式的特殊性：
- **像素存储顺序**：从下到上，从左到右（倒序扫描）
- **颜色通道**：BGR顺序（但RGB565只有RGB，所以影响不大）
- **无压缩**：原始像素数据

**位格式**：
```
16位RGB565: RRRRR GGGGGG BBBBB
             ←高位    低位→

字节序（大端序）：
  字节0: RRRRR GGG (高字节)
  字节1: GGG BBBBB (低字节)

像素扫描顺序（BMP格式）：
  第0行 → 图片最底部
  第1行 → 倒数第二行
  ...
  第153行 → 图片最顶部
```

**转换公式**：
```dart
// 从8位RGB转换到RGB565
R5 = (R8 >> 3) & 0x1F  // 取R的高5位
G6 = (G8 >> 2) & 0x3F  // 取G的高6位
B5 = (B8 >> 3) & 0x1F  // 取B的高5位

// 组合成16位值
RGB565 = (R5 << 11) | (G6 << 5) | B5

// 大端序输出
高字节 = (RGB565 >> 8) & 0xFF
低字节 = RGB565 & 0xFF
```

#### 2.3 实现方案

```dart
class RGB565Converter {
  /// 将图片转换为RGB565字节数组
  Future<Uint8List> convertToRGB565(ui.Image image) async {
    // 验证尺寸
    if (image.width != 154 || image.height != 154) {
      throw Exception('图片尺寸必须是154x154');
    }
    
    // 1. 提取RGBA像素数据
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    
    if (byteData == null) {
      throw Exception('无法提取图片像素数据');
    }
    
    final rgba = byteData.buffer.asUint8List();
    
    // 2. 转换为RGB565（BMP倒序）
    const pixelCount = 154 * 154;
    final rgb565 = Uint8List(pixelCount * 2); // 每像素2字节
    
    // 🔥 关键：BMP格式从下到上扫描
    int outIndex = 0;
    for (int y = 153; y >= 0; y--) { // 从最后一行开始
      for (int x = 0; x < 154; x++) {
        // 计算RGBA数组中的索引
        final i = (y * 154 + x) * 4;
        
        // 提取RGBA通道（忽略Alpha）
        final r = rgba[i];
        final g = rgba[i + 1];
        final b = rgba[i + 2];
        
        // 转换为RGB565
        final r5 = (r >> 3) & 0x1F;
        final g6 = (g >> 2) & 0x3F;
        final b5 = (b >> 3) & 0x1F;
        
        // 组合成16位值
        final rgb565Value = (r5 << 11) | (g6 << 5) | b5;
        
        // 🔥 关键：大端序输出（高字节在前）
        rgb565[outIndex++] = (rgb565Value >> 8) & 0xFF;  // 高字节
        rgb565[outIndex++] = rgb565Value & 0xFF;         // 低字节
      }
    }
    
    return rgb565;
  }
}
```

**关键决策**：
- ✅ 使用 `rawRgba` 格式提取像素
- ✅ 忽略Alpha通道（硬件不支持透明度）
- ✅ 大端序输出（匹配专业取模软件）
- ✅ 严格验证输入尺寸

### 3. 诊断对比工具 (DiagnosticTools)

#### 3.1 字节数组对比器

```dart
class DiagnosticTools {
  /// 对比两个字节数组的差异
  static void compareByteArrays(
    Uint8List appOutput,
    Uint8List professionalOutput, {
    int maxBytes = 64,
  }) {
    print('📊 字节数组对比 (前$maxBytes字节)');
    print('─' * 60);
    
    int differences = 0;
    for (int i = 0; i < min(maxBytes, appOutput.length); i++) {
      final app = appOutput[i];
      final pro = professionalOutput[i];
      
      if (app != pro) {
        differences++;
        print('❌ 差异 @$i: '
            'APP=0x${app.toRadixString(16).padLeft(2, '0').toUpperCase()} '
            'vs '
            '专业=0x${pro.toRadixString(16).padLeft(2, '0').toUpperCase()}');
      } else if (i < 16) {
        // 前16字节总是显示
        print('✅ 匹配 @$i: 0x${app.toRadixString(16).padLeft(2, '0').toUpperCase()}');
      }
    }
    
    print('─' * 60);
    print('总差异数: $differences / $maxBytes');
  }
  
  /// 生成纯色测试数组
  static Uint8List generateSolidColorRGB565(int r, int g, int b) {
    const pixelCount = 154 * 154;
    final data = Uint8List(pixelCount * 2);
    
    // 转换为RGB565
    final r5 = (r >> 3) & 0x1F;
    final g6 = (g >> 2) & 0x3F;
    final b5 = (b >> 3) & 0x1F;
    final rgb565 = (r5 << 11) | (g6 << 5) | b5;
    
    // 填充整个数组
    for (int i = 0; i < data.length; i += 2) {
      data[i] = (rgb565 >> 8) & 0xFF;
      data[i + 1] = rgb565 & 0xFF;
    }
    
    return data;
  }
  
  /// 验证RGB565编码
  static void verifyRGB565Encoding() {
    print('🧪 RGB565编码验证');
    print('─' * 60);
    
    // 测试纯色
    final testCases = [
      {'name': '纯红', 'r': 255, 'g': 0, 'b': 0, 'expected': '0xF800'},
      {'name': '纯绿', 'r': 0, 'g': 255, 'b': 0, 'expected': '0x07E0'},
      {'name': '纯蓝', 'r': 0, 'g': 0, 'b': 255, 'expected': '0x001F'},
      {'name': '白色', 'r': 255, 'g': 255, 'b': 255, 'expected': '0xFFFF'},
      {'name': '黑色', 'r': 0, 'g': 0, 'b': 0, 'expected': '0x0000'},
    ];
    
    for (final test in testCases) {
      final r = test['r'] as int;
      final g = test['g'] as int;
      final b = test['b'] as int;
      
      final r5 = (r >> 3) & 0x1F;
      final g6 = (g >> 2) & 0x3F;
      final b5 = (b >> 3) & 0x1F;
      final rgb565 = (r5 << 11) | (g6 << 5) | b5;
      
      final actual = '0x${rgb565.toRadixString(16).padLeft(4, '0').toUpperCase()}';
      final expected = test['expected'] as String;
      final match = actual == expected ? '✅' : '❌';
      
      print('$match ${test['name']}: RGB($r,$g,$b) → $actual (期望: $expected)');
    }
    
    print('─' * 60);
  }
}
```

### 4. 集成方案

#### 4.1 更新 _convertImageToRGB565

```dart
Future<Uint8List?> _convertImageToRGB565(File imageFile) async {
  try {
    _addLog('🖼️ 开始图片转换流程');
    
    // 阶段1：预处理
    _addLog('📐 阶段1: 图片预处理');
    final preprocessor = ImagePreprocessor();
    final standardImage = await preprocessor.preprocessImage(imageFile);
    _addLog('✅ 预处理完成: ${standardImage.width}x${standardImage.height}');
    
    // 阶段2：RGB565转换
    _addLog('🎨 阶段2: RGB565转换');
    final converter = RGB565Converter();
    final rgb565Data = await converter.convertToRGB565(standardImage);
    _addLog('✅ 转换完成: ${rgb565Data.length} 字节');
    
    // 验证数据大小
    if (rgb565Data.length != 47432) {
      throw Exception('数据大小错误: ${rgb565Data.length} (期望: 47432)');
    }
    
    return rgb565Data;
  } catch (e, stackTrace) {
    _addLog('❌ 转换失败: $e');
    print('[LOGO] 转换异常: $e\n$stackTrace');
    return null;
  }
}
```

#### 4.2 添加诊断测试按钮

在UI中添加新的测试按钮：

```dart
_buildActionButton(
  icon: Icons.compare,
  label: '对比测试',
  color: Colors.cyan,
  onTap: _isUploading ? null : _runDiagnosticTests,
),
```

实现诊断测试：

```dart
Future<void> _runDiagnosticTests() async {
  _addLog('🧪 ===== 开始诊断测试 =====');
  
  // 测试1：RGB565编码验证
  _addLog('');
  _addLog('测试1: RGB565编码验证');
  DiagnosticTools.verifyRGB565Encoding();
  
  // 测试2：纯色数组生成
  _addLog('');
  _addLog('测试2: 生成纯红色测试数组');
  final redArray = DiagnosticTools.generateSolidColorRGB565(255, 0, 0);
  _addLog('✅ 生成完成: ${redArray.length} 字节');
  _addLog('前4字节: ${redArray.sublist(0, 4).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');
  
  // 测试3：对比APP输出 vs 专业取模
  if (_selectedImage != null) {
    _addLog('');
    _addLog('测试3: 对比APP输出 vs 专业取模');
    final appOutput = await _convertImageToRGB565(_selectedImage!);
    
    if (appOutput != null) {
      // 专业取模软件的前64字节（从pic.h复制）
      final professionalOutput = Uint8List.fromList([
        0x00, 0x00, 0x08, 0x61, 0x18, 0xE3, 0x21, 0x24,
        0x29, 0x45, 0x21, 0x24, 0x18, 0xE3, 0x08, 0x61,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);
      
      DiagnosticTools.compareByteArrays(appOutput, professionalOutput);
    }
  }
  
  _addLog('');
  _addLog('🎉 诊断测试完成');
}
```

## Alternative Approaches Considered

### 方案对比

| 方案 | 优点 | 缺点 | 决策 |
|------|------|------|------|
| FilterQuality.none | 速度快，像素精确 | 产生锯齿，质量差 | ❌ 不采用 |
| FilterQuality.low | 速度较快 | 质量一般 | ❌ 不采用 |
| FilterQuality.medium | 平衡 | 可能不够平滑 | ⚠️ 备选 |
| FilterQuality.high | 质量最好 | 速度稍慢 | ✅ 采用 |

### 字节序方案

| 方案 | 说明 | 匹配专业取模 | 决策 |
|------|------|--------------|------|
| 小端序 | 低字节在前 | ❌ | ❌ 不采用 |
| 大端序 | 高字节在前 | ✅ | ✅ 采用 |

## Error Handling

### 预期错误场景

1. **图片不是正方形**
   ```dart
   if (image.width != image.height) {
     throw ImageFormatException('图片必须是1:1正方形');
   }
   ```

2. **图片尺寸不对**
   ```dart
   if (image.width != 154 || image.height != 154) {
     throw ImageSizeException('预处理后尺寸必须是154x154');
   }
   ```

3. **数据大小错误**
   ```dart
   if (rgb565Data.length != 47432) {
     throw DataSizeException('RGB565数据必须是47432字节');
   }
   ```

4. **像素提取失败**
   ```dart
   if (byteData == null) {
     throw PixelExtractionException('无法提取图片像素数据');
   }
   ```

## Testing Strategy

### 单元测试

```dart
// test/image_conversion_test.dart
void main() {
  group('ImagePreprocessor', () {
    test('应该将正方形图片缩放到154x154', () async {
      // 测试实现
    });
    
    test('应该拒绝非正方形图片', () async {
      // 测试实现
    });
  });
  
  group('RGB565Converter', () {
    test('纯红色应该转换为0xF800', () async {
      // 测试实现
    });
    
    test('纯绿色应该转换为0x07E0', () async {
      // 测试实现
    });
    
    test('纯蓝色应该转换为0x001F', () async {
      // 测试实现
    });
    
    test('应该输出47432字节', () async {
      // 测试实现
    });
  });
  
  group('DiagnosticTools', () {
    test('应该正确对比字节数组', () {
      // 测试实现
    });
  });
}
```

### 集成测试

1. **端到端测试**：选择图片 → 转换 → 上传 → 验证显示
2. **对比测试**：APP输出 vs 专业取模输出
3. **纯色测试**：红/绿/蓝纯色图片验证

## Performance Considerations

### 性能目标
- 图片预处理：< 500ms
- RGB565转换：< 200ms
- 总转换时间：< 1秒

### 优化策略
1. 使用 `compute()` 在isolate中处理大图片
2. 缓存转换结果避免重复计算
3. 异步处理不阻塞UI

## Security Considerations

1. **输入验证**：严格验证图片格式和尺寸
2. **内存管理**：及时释放大图片占用的内存
3. **错误处理**：防止恶意图片导致崩溃

## Deployment Strategy

### 分阶段部署

**阶段1：诊断工具**
- 添加字节对比功能
- 添加纯色测试
- 收集实际差异数据

**阶段2：修复转换算法**
- 实现新的ImagePreprocessor
- 实现新的RGB565Converter
- 保留旧代码作为fallback

**阶段3：验证和优化**
- 大量测试不同图片
- 性能优化
- 移除旧代码

## Open Questions

1. ❓ 专业取模软件使用什么缩放算法？
2. ❓ 是否需要支持透明背景（Alpha通道）？
3. ❓ 是否需要颜色校正或Gamma调整？
4. ❓ 是否需要支持其他图片格式（当前只测试了JPEG/PNG）？

## References

- Flutter Image API: https://api.flutter.dev/flutter/dart-ui/Image-class.html
- RGB565格式说明: https://en.wikipedia.org/wiki/High_color
- 专业取模软件输出: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/pic.h`
