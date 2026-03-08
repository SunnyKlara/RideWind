import 'package:flutter/material.dart';

/// 单个传统色数据模型
class ChineseColor {
  final String name; // 中文名称，如 "朱砂"
  final int r;
  final int g;
  final int b;
  final String family; // 色系标识，如 "red", "yellow"

  const ChineseColor({
    required this.name,
    required this.r,
    required this.g,
    required this.b,
    required this.family,
  });

  Color toColor() => Color.fromARGB(255, r, g, b);

  /// 根据背景亮度返回适合的文字颜色
  Color get textColor {
    final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
    return luminance > 128 ? Colors.black : Colors.white;
  }
}

/// 色系分类
class ColorFamily {
  final String id; // "red", "yellow", etc.
  final String name; // "红色系", "黄色系", etc.
  final List<ChineseColor> colors;

  const ColorFamily({
    required this.id,
    required this.name,
    required this.colors,
  });
}

/// 传统色数据集（静态常量）
class TraditionalChineseColors {
  static const List<ColorFamily> families = [
    // ========== 红色系 ==========
    ColorFamily(
      id: 'red',
      name: '红色系',
      colors: [
        // 暗红 luminance ≈ 0.299*101+0.587*25+0.114*11 = 46.2
        ChineseColor(name: '暗红', r: 101, g: 25, b: 11, family: 'red'),
        // 殷红 luminance ≈ 0.299*128+0.587*25+0.114*14 = 54.5
        ChineseColor(name: '殷红', r: 128, g: 25, b: 14, family: 'red'),
        // 胭脂 luminance ≈ 0.299*157+0.587*41+0.114*51 = 76.8
        ChineseColor(name: '胭脂', r: 157, g: 41, b: 51, family: 'red'),
        // 朱砂 luminance ≈ 0.299*255+0.587*46+0.114*0 = 103.3
        ChineseColor(name: '朱砂', r: 255, g: 46, b: 0, family: 'red'),
        // 妃色 luminance ≈ 0.299*237+0.587*87+0.114*54 = 128.1
        ChineseColor(name: '妃色', r: 237, g: 87, b: 54, family: 'red'),
        // 银红 luminance ≈ 0.299*196+0.587*99+0.114*108 = 129.0
        ChineseColor(name: '银红', r: 196, g: 99, b: 108, family: 'red'),
        // 海棠红 luminance ≈ 0.299*219+0.587*90+0.114*107 = 130.5
        ChineseColor(name: '海棠红', r: 219, g: 90, b: 107, family: 'red'),
        // 桃红 luminance ≈ 0.299*240+0.587*173+0.114*160 = 191.7
        ChineseColor(name: '桃红', r: 240, g: 173, b: 160, family: 'red'),
        // 粉红 luminance ≈ 0.299*255+0.587*179+0.114*167 = 200.2
        ChineseColor(name: '粉红', r: 255, g: 179, b: 167, family: 'red'),
      ],
    ),
    // ========== 黄色系 ==========
    ColorFamily(
      id: 'yellow',
      name: '黄色系',
      colors: [
        // 棕黑 luminance ≈ 0.299*65+0.587*43+0.114*21 = 47.1
        ChineseColor(name: '棕黑', r: 65, g: 43, b: 21, family: 'yellow'),
        // 赭石 luminance ≈ 0.299*132+0.587*76+0.114*34 = 87.9
        ChineseColor(name: '赭石', r: 132, g: 76, b: 34, family: 'yellow'),
        // 土黄 luminance ≈ 0.299*168+0.587*123+0.114*67 = 129.9
        ChineseColor(name: '土黄', r: 168, g: 123, b: 67, family: 'yellow'),
        // 琥珀 luminance ≈ 0.299*202+0.587*130+0.114*42 = 141.2
        ChineseColor(name: '琥珀', r: 202, g: 130, b: 42, family: 'yellow'),
        // 藤黄 luminance ≈ 0.299*255+0.587*182+0.114*5 = 183.5
        ChineseColor(name: '藤黄', r: 255, g: 182, b: 5, family: 'yellow'),
        // 雌黄 luminance ≈ 0.299*255+0.587*199+0.114*23 = 196.5
        ChineseColor(name: '雌黄', r: 255, g: 199, b: 23, family: 'yellow'),
        // 鹅黄 luminance ≈ 0.299*255+0.587*223+0.114*70 = 215.0
        ChineseColor(name: '鹅黄', r: 255, g: 223, b: 70, family: 'yellow'),
        // 缃色 luminance ≈ 0.299*240+0.587*223+0.114*180 = 223.4
        ChineseColor(name: '缃色', r: 240, g: 223, b: 180, family: 'yellow'),
        // 牙白 luminance ≈ 0.299*255+0.587*241+0.114*218 = 242.4
        ChineseColor(name: '牙白', r: 255, g: 241, b: 218, family: 'yellow'),
      ],
    ),
    // ========== 绿色系 ==========
    ColorFamily(
      id: 'green',
      name: '绿色系',
      colors: [
        // 苍绿 luminance ≈ 0.299*22+0.587*49+0.114*35 = 39.4
        ChineseColor(name: '苍绿', r: 22, g: 49, b: 35, family: 'green'),
        // 墨绿 luminance ≈ 0.299*0+0.587*88+0.114*38 = 56.0
        ChineseColor(name: '墨绿', r: 0, g: 88, b: 38, family: 'green'),
        // 青竹 luminance ≈ 0.299*50+0.587*113+0.114*59 = 88.0
        ChineseColor(name: '青竹', r: 50, g: 113, b: 59, family: 'green'),
        // 石绿 luminance ≈ 0.299*42+0.587*142+0.114*90 = 105.3
        ChineseColor(name: '石绿', r: 42, g: 142, b: 90, family: 'green'),
        // 铜绿 luminance ≈ 0.299*78+0.587*148+0.114*68 = 117.8
        ChineseColor(name: '铜绿', r: 78, g: 148, b: 68, family: 'green'),
        // 松花绿 luminance ≈ 0.299*97+0.587*172+0.114*119 = 143.6
        ChineseColor(name: '松花绿', r: 97, g: 172, b: 119, family: 'green'),
        // 豆绿 luminance ≈ 0.299*155+0.587*205+0.114*155 = 184.1
        ChineseColor(name: '豆绿', r: 155, g: 205, b: 155, family: 'green'),
        // 艾绿 luminance ≈ 0.299*195+0.587*222+0.114*179 = 212.9
        ChineseColor(name: '艾绿', r: 195, g: 222, b: 179, family: 'green'),
      ],
    ),
    // ========== 蓝色系 ==========
    ColorFamily(
      id: 'blue',
      name: '蓝色系',
      colors: [
        // 藏蓝 luminance ≈ 0.299*7+0.587*22+0.114*82 = 24.3
        ChineseColor(name: '藏蓝', r: 7, g: 22, b: 82, family: 'blue'),
        // 靛蓝 luminance ≈ 0.299*6+0.587*60+0.114*97 = 48.1
        ChineseColor(name: '靛蓝', r: 6, g: 60, b: 97, family: 'blue'),
        // 石青 luminance ≈ 0.299*30+0.587*100+0.114*142 = 83.9
        ChineseColor(name: '石青', r: 30, g: 100, b: 142, family: 'blue'),
        // 群青 luminance ≈ 0.299*46+0.587*117+0.114*182 = 103.2
        ChineseColor(name: '群青', r: 46, g: 117, b: 182, family: 'blue'),
        // 景泰蓝 luminance ≈ 0.299*75+0.587*135+0.114*175 = 121.7
        ChineseColor(name: '景泰蓝', r: 75, g: 135, b: 175, family: 'blue'),
        // 天蓝 luminance ≈ 0.299*102+0.587*169+0.114*204 = 152.5
        ChineseColor(name: '天蓝', r: 102, g: 169, b: 204, family: 'blue'),
        // 月白 luminance ≈ 0.299*168+0.587*206+0.114*225 = 197.6
        ChineseColor(name: '月白', r: 168, g: 206, b: 225, family: 'blue'),
        // 水色 luminance ≈ 0.299*200+0.587*225+0.114*235 = 218.9
        ChineseColor(name: '水色', r: 200, g: 225, b: 235, family: 'blue'),
      ],
    ),
    // ========== 紫色系 ==========
    ColorFamily(
      id: 'purple',
      name: '紫色系',
      colors: [
        // 玄紫 luminance ≈ 0.299*36+0.587*10+0.114*42 = 21.4
        ChineseColor(name: '玄紫', r: 36, g: 10, b: 42, family: 'purple'),
        // 紫棠 luminance ≈ 0.299*86+0.587*42+0.114*56 = 56.9
        ChineseColor(name: '紫棠', r: 86, g: 42, b: 56, family: 'purple'),
        // 酱紫 luminance ≈ 0.299*104+0.587*49+0.114*68 = 67.6
        ChineseColor(name: '酱紫', r: 104, g: 49, b: 68, family: 'purple'),
        // 紫檀 luminance ≈ 0.299*123+0.587*55+0.114*80 = 78.1
        ChineseColor(name: '紫檀', r: 123, g: 55, b: 80, family: 'purple'),
        // 青莲 luminance ≈ 0.299*128+0.587*85+0.114*159 = 106.3
        ChineseColor(name: '青莲', r: 128, g: 85, b: 159, family: 'purple'),
        // 丁香 luminance ≈ 0.299*186+0.587*147+0.114*171 = 161.7
        ChineseColor(name: '丁香', r: 186, g: 147, b: 171, family: 'purple'),
        // 藕荷 luminance ≈ 0.299*195+0.587*170+0.114*195 = 180.2
        ChineseColor(name: '藕荷', r: 195, g: 170, b: 195, family: 'purple'),
        // 雪青 luminance ≈ 0.299*210+0.587*196+0.114*223 = 203.6
        ChineseColor(name: '雪青', r: 210, g: 196, b: 223, family: 'purple'),
      ],
    ),
    // ========== 白灰黑系 ==========
    ColorFamily(
      id: 'neutral',
      name: '白灰黑系',
      colors: [
        // 漆黑 luminance ≈ 0.299*12+0.587*12+0.114*12 = 12.0
        ChineseColor(name: '漆黑', r: 12, g: 12, b: 12, family: 'neutral'),
        // 墨色 luminance ≈ 0.299*35+0.587*38+0.114*36 = 36.9
        ChineseColor(name: '墨色', r: 35, g: 38, b: 36, family: 'neutral'),
        // 铁灰 luminance ≈ 0.299*72+0.587*72+0.114*72 = 72.0
        ChineseColor(name: '铁灰', r: 72, g: 72, b: 72, family: 'neutral'),
        // 青灰 luminance ≈ 0.299*104+0.587*112+0.114*115 = 109.9
        ChineseColor(name: '青灰', r: 104, g: 112, b: 115, family: 'neutral'),
        // 银灰 luminance ≈ 0.299*155+0.587*155+0.114*155 = 155.0
        ChineseColor(name: '银灰', r: 155, g: 155, b: 155, family: 'neutral'),
        // 素色 luminance ≈ 0.299*195+0.587*195+0.114*195 = 195.0
        ChineseColor(name: '素色', r: 195, g: 195, b: 195, family: 'neutral'),
        // 霜色 luminance ≈ 0.299*220+0.587*225+0.114*222 = 223.3
        ChineseColor(name: '霜色', r: 220, g: 225, b: 222, family: 'neutral'),
        // 月影白 luminance ≈ 0.299*242+0.587*240+0.114*236 = 239.9
        ChineseColor(name: '月影白', r: 242, g: 240, b: 236, family: 'neutral'),
        // 精白 luminance ≈ 0.299*255+0.587*255+0.114*255 = 255.0
        ChineseColor(name: '精白', r: 255, g: 255, b: 255, family: 'neutral'),
      ],
    ),
  ];

  /// 获取所有颜色的扁平列表
  static List<ChineseColor> get allColors =>
      families.expand((f) => f.colors).toList();
}
