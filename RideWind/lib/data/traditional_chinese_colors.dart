import 'package:flutter/material.dart';

/// 单个传统色数据模型
class ChineseColor {
  final String name;
  final int r;
  final int g;
  final int b;
  final String family;

  const ChineseColor({
    required this.name,
    required this.r,
    required this.g,
    required this.b,
    required this.family,
  });

  Color toColor() => Color.fromARGB(255, r, g, b);

  /// 文字颜色 — 使用色块自身颜色的深/浅变体，而非简单黑白
  /// 深色块 → 同色系浅色文字；浅色块 → 同色系深色文字
  Color get textColor {
    final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
    if (hsl.lightness > 0.55) {
      // 浅色块：文字用同色相的深色
      return hsl
          .withLightness((hsl.lightness - 0.35).clamp(0.08, 0.35))
          .withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
          .toColor();
    } else {
      // 深色块：文字用同色相的浅色
      return hsl
          .withLightness((hsl.lightness + 0.35).clamp(0.65, 0.92))
          .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
          .toColor();
    }
  }
}

class ColorFamily {
  final String id;
  final String name;
  final List<ChineseColor> colors;

  const ColorFamily({
    required this.id,
    required this.name,
    required this.colors,
  });
}

class TraditionalChineseColors {
  static const List<ColorFamily> families = [
    // ==================== 红色系 / 紫红色系 ====================
    ColorFamily(id: 'red', name: '红色系', colors: [
      ChineseColor(name: '杨妃', r: 240, g: 145, b: 160, family: 'red'),
      ChineseColor(name: '木兰', r: 102, g: 64, b: 31, family: 'red'),
      ChineseColor(name: '胭脂水', r: 185, g: 90, b: 137, family: 'red'),
      ChineseColor(name: '盈盈', r: 249, g: 211, b: 227, family: 'red'),
      ChineseColor(name: '彤管', r: 226, g: 162, b: 172, family: 'red'),
      ChineseColor(name: '紫茎屏风', r: 167, g: 98, b: 131, family: 'red'),
      ChineseColor(name: '银红', r: 231, g: 202, b: 211, family: 'red'),
      ChineseColor(name: '咸池', r: 216, g: 169, b: 169, family: 'red'),
      ChineseColor(name: '红踯躅', r: 184, g: 53, b: 112, family: 'red'),
      ChineseColor(name: '粉米', r: 239, g: 196, b: 206, family: 'red'),
      ChineseColor(name: '莲红', r: 217, g: 160, b: 179, family: 'red'),
      ChineseColor(name: '胭脂紫', r: 176, g: 67, b: 111, family: 'red'),
      ChineseColor(name: '桃夭', r: 246, g: 190, b: 200, family: 'red'),
      ChineseColor(name: '雌霓', r: 207, g: 146, b: 158, family: 'red'),
      ChineseColor(name: '魏红', r: 167, g: 55, b: 102, family: 'red'),
      ChineseColor(name: '水红', r: 217, g: 176, b: 193, family: 'red'),
      ChineseColor(name: '缣缘', r: 206, g: 136, b: 146, family: 'red'),
      ChineseColor(name: '紫府', r: 153, g: 93, b: 127, family: 'red'),
      ChineseColor(name: '夕岚', r: 227, g: 173, b: 185, family: 'red'),
      ChineseColor(name: '长春', r: 220, g: 107, b: 130, family: 'red'),
      ChineseColor(name: '魏紫', r: 144, g: 55, b: 84, family: 'red'),
      ChineseColor(name: '绛纱', r: 178, g: 119, b: 119, family: 'red'),
      ChineseColor(name: '渥赭', r: 221, g: 107, b: 123, family: 'red'),
      ChineseColor(name: '地血', r: 129, g: 67, b: 98, family: 'red'),
      ChineseColor(name: '茹蕙', r: 163, g: 95, b: 101, family: 'red'),
      ChineseColor(name: '红麴', r: 205, g: 115, b: 114, family: 'red'),
      ChineseColor(name: '芥拾紫', r: 96, g: 38, b: 65, family: 'red'),
      ChineseColor(name: '美人祭', r: 195, g: 92, b: 106, family: 'red'),
      ChineseColor(name: '紫梅', r: 187, g: 122, b: 144, family: 'red'),
      ChineseColor(name: '紫薄汗', r: 187, g: 161, b: 203, family: 'red'),
      ChineseColor(name: '唇脂', r: 194, g: 81, b: 96, family: 'red'),
      ChineseColor(name: '紫矿', r: 158, g: 78, b: 86, family: 'red'),
      ChineseColor(name: '退红', r: 240, g: 207, b: 227, family: 'red'),
      ChineseColor(name: '鞓红', r: 176, g: 69, b: 82, family: 'red'),
      ChineseColor(name: '紫诰', r: 118, g: 65, b: 85, family: 'red'),
      ChineseColor(name: '昌容', r: 220, g: 199, b: 225, family: 'red'),
      ChineseColor(name: '葡萄褐', r: 158, g: 105, b: 109, family: 'red'),
      ChineseColor(name: '苕荣', r: 238, g: 109, b: 61, family: 'red'),
      ChineseColor(name: '樱花', r: 228, g: 184, b: 213, family: 'red'),
      ChineseColor(name: '蚩尤旗', r: 168, g: 88, b: 88, family: 'red'),
      ChineseColor(name: '扶光', r: 240, g: 194, b: 162, family: 'red'),
      ChineseColor(name: '丁香', r: 206, g: 147, b: 191, family: 'red'),
      ChineseColor(name: '苏方', r: 129, g: 71, b: 76, family: 'red'),
      ChineseColor(name: '十样锦', r: 248, g: 198, b: 181, family: 'red'),
      ChineseColor(name: '木槿', r: 186, g: 121, b: 177, family: 'red'),
      ChineseColor(name: '霁红', r: 124, g: 68, b: 73, family: 'red'),
      ChineseColor(name: '海天霞', r: 200, g: 166, b: 148, family: 'red'),
      ChineseColor(name: '茈藐', r: 166, g: 126, b: 183, family: 'red'),
      ChineseColor(name: '蜜褐', r: 104, g: 54, b: 50, family: 'red'),
      ChineseColor(name: '骍刚', r: 245, g: 176, b: 135, family: 'red'),
      ChineseColor(name: '膠紫', r: 204, g: 115, b: 160, family: 'red'),
      ChineseColor(name: '福色', r: 102, g: 43, b: 47, family: 'red'),
      ChineseColor(name: '朱颜酡', r: 242, g: 154, b: 118, family: 'red'),
      ChineseColor(name: '龙膏烛', r: 222, g: 130, b: 167, family: 'red'),
      ChineseColor(name: '油紫', r: 66, g: 11, b: 47, family: 'red'),
      ChineseColor(name: '赪霞', r: 241, g: 143, b: 96, family: 'red'),
      ChineseColor(name: '苏梅', r: 221, g: 118, b: 148, family: 'red'),
      ChineseColor(name: '丹雘', r: 230, g: 60, b: 18, family: 'red'),
      ChineseColor(name: '赪尾', r: 239, g: 132, b: 93, family: 'red'),
      ChineseColor(name: '琅玕紫', r: 203, g: 92, b: 131, family: 'red'),
      ChineseColor(name: '缙云', r: 238, g: 121, b: 89, family: 'red'),
      ChineseColor(name: '小红', r: 185, g: 119, b: 98, family: 'red'),
      ChineseColor(name: '朱孔阳', r: 184, g: 26, b: 53, family: 'red'),
      ChineseColor(name: '琼琚', r: 215, g: 127, b: 102, family: 'red'),
      ChineseColor(name: '岱赭', r: 221, g: 107, b: 79, family: 'red'),
      ChineseColor(name: '丹艧', r: 200, g: 22, b: 29, family: 'red'),
      ChineseColor(name: '朱柿', r: 237, g: 109, b: 70, family: 'red'),
      ChineseColor(name: '艴炽', r: 203, g: 82, b: 62, family: 'red'),
      ChineseColor(name: '水华朱', r: 167, g: 33, b: 38, family: 'red'),
      ChineseColor(name: '鹤顶红', r: 210, g: 71, b: 53, family: 'red'),
      ChineseColor(name: '赤缇', r: 186, g: 91, b: 73, family: 'red'),
      ChineseColor(name: '胭脂虫', r: 171, g: 29, b: 34, family: 'red'),
      ChineseColor(name: '纁黄', r: 186, g: 81, b: 64, family: 'red'),
      ChineseColor(name: '棠梨', r: 177, g: 90, b: 67, family: 'red'),
      ChineseColor(name: '朱樱', r: 129, g: 29, b: 34, family: 'red'),
      ChineseColor(name: '朱殷', r: 185, g: 58, b: 38, family: 'red'),
      ChineseColor(name: '石榴裙', r: 177, g: 59, b: 46, family: 'red'),
      ChineseColor(name: '大繎', r: 130, g: 35, b: 39, family: 'red'),
      ChineseColor(name: '朱草', r: 166, g: 64, b: 54, family: 'red'),
      ChineseColor(name: '赤灵', r: 149, g: 64, b: 36, family: 'red'),
      ChineseColor(name: '顺圣', r: 124, g: 25, b: 30, family: 'red'),
      ChineseColor(name: '佛赤', r: 143, g: 61, b: 44, family: 'red'),
      ChineseColor(name: '缋茂', r: 158, g: 42, b: 34, family: 'red'),
      ChineseColor(name: '爵头', r: 99, g: 18, b: 22, family: 'red'),
      ChineseColor(name: '朱湛', r: 149, g: 48, b: 46, family: 'red'),
      ChineseColor(name: '丹秫', r: 135, g: 52, b: 36, family: 'red'),
      ChineseColor(name: '麒麟竭', r: 76, g: 30, b: 26, family: 'red'),
      ChineseColor(name: '银朱', r: 209, g: 64, b: 32, family: 'red'),
      ChineseColor(name: '黄丹', r: 204, g: 85, b: 20, family: 'red'),
      ChineseColor(name: '珊瑚赫', r: 193, g: 44, b: 31, family: 'red'),
      ChineseColor(name: '洛神珠', r: 210, g: 57, b: 24, family: 'red'),
      ChineseColor(name: '槨丹', r: 233, g: 72, b: 64, family: 'red'),
    ]),
    // ==================== 绿色系 / 青绿色系 ====================
    ColorFamily(id: 'green', name: '绿色系', colors: [
      ChineseColor(name: '人籁', r: 158, g: 188, b: 25, family: 'green'),
      ChineseColor(name: '葱倩', r: 161, g: 134, b: 80, family: 'green'),
      ChineseColor(name: '螺青', r: 63, g: 80, b: 59, family: 'green'),
      ChineseColor(name: '青粱', r: 195, g: 217, b: 78, family: 'green'),
      ChineseColor(name: '漆姑', r: 93, g: 131, b: 81, family: 'green'),
      ChineseColor(name: '春辰', r: 169, g: 190, b: 123, family: 'green'),
      ChineseColor(name: '翠缥', r: 183, g: 211, b: 50, family: 'green'),
      ChineseColor(name: '翠微', r: 76, g: 128, b: 69, family: 'green'),
      ChineseColor(name: '麴尘', r: 192, g: 208, b: 157, family: 'green'),
      ChineseColor(name: '水龙吟', r: 132, g: 167, b: 41, family: 'green'),
      ChineseColor(name: '芰荷', r: 79, g: 121, b: 74, family: 'green'),
      ChineseColor(name: '欧碧', r: 192, g: 214, b: 149, family: 'green'),
      ChineseColor(name: '碧山', r: 119, g: 150, b: 73, family: 'green'),
      ChineseColor(name: '青青', r: 79, g: 111, b: 70, family: 'green'),
      ChineseColor(name: '苍葭', r: 168, g: 191, b: 143, family: 'green'),
      ChineseColor(name: '石发', r: 106, g: 141, b: 82, family: 'green'),
      ChineseColor(name: '翠虬', r: 68, g: 106, b: 55, family: 'green'),
      ChineseColor(name: '兰苕', r: 168, g: 183, b: 140, family: 'green'),
      ChineseColor(name: '菉竹', r: 105, g: 142, b: 106, family: 'green'),
      ChineseColor(name: '官绿', r: 42, g: 110, b: 63, family: 'green'),
      ChineseColor(name: '青玉案', r: 168, g: 176, b: 146, family: 'green'),
      ChineseColor(name: '庭芜绿', r: 104, g: 148, b: 92, family: 'green'),
      ChineseColor(name: '油绿', r: 93, g: 114, b: 89, family: 'green'),
      ChineseColor(name: '碧滋', r: 144, g: 160, b: 125, family: 'green'),
      ChineseColor(name: '莓莓', r: 78, g: 101, b: 72, family: 'green'),
      ChineseColor(name: '瓷秘', r: 179, g: 192, b: 157, family: 'green'),
      ChineseColor(name: '青楸', r: 129, g: 163, b: 128, family: 'green'),
      ChineseColor(name: '筠雾', r: 213, g: 209, b: 174, family: 'green'),
      ChineseColor(name: '行香子', r: 191, g: 185, b: 156, family: 'green'),
      ChineseColor(name: '缥碧', r: 128, g: 164, b: 146, family: 'green'),
      ChineseColor(name: '鸣珂', r: 195, g: 181, b: 156, family: 'green'),
      ChineseColor(name: '琬琰', r: 169, g: 168, b: 134, family: 'green'),
      ChineseColor(name: '翠涛', r: 129, g: 157, b: 142, family: 'green'),
      ChineseColor(name: '出岫', r: 169, g: 167, b: 115, family: 'green'),
      ChineseColor(name: '王刍', r: 169, g: 159, b: 112, family: 'green'),
      ChineseColor(name: '青梅', r: 119, g: 138, b: 119, family: 'green'),
      ChineseColor(name: '春碧', r: 157, g: 157, b: 130, family: 'green'),
      ChineseColor(name: '执大象', r: 145, g: 145, b: 119, family: 'green'),
      ChineseColor(name: '雀梅', r: 120, g: 138, b: 111, family: 'green'),
      ChineseColor(name: '青圭', r: 146, g: 144, b: 83, family: 'green'),
      ChineseColor(name: '绿沈', r: 147, g: 143, b: 76, family: 'green'),
      ChineseColor(name: '苔古', r: 121, g: 131, b: 108, family: 'green'),
      ChineseColor(name: '风入松', r: 134, g: 140, b: 78, family: 'green'),
      ChineseColor(name: '荩箧', r: 135, g: 125, b: 82, family: 'green'),
      ChineseColor(name: '蕉月', r: 134, g: 144, b: 138, family: 'green'),
      ChineseColor(name: '绞衣', r: 127, g: 117, b: 76, family: 'green'),
      ChineseColor(name: '素綦', r: 89, g: 83, b: 51, family: 'green'),
      ChineseColor(name: '千山翠', r: 120, g: 125, b: 115, family: 'green'),
      ChineseColor(name: '天缥', r: 213, g: 235, b: 225, family: 'green'),
      ChineseColor(name: '卵色', r: 213, g: 227, b: 212, family: 'green'),
      ChineseColor(name: '翕艴', r: 118, g: 118, b: 106, family: 'green'),
      ChineseColor(name: '沧浪', r: 177, g: 213, b: 200, family: 'green'),
      ChineseColor(name: '葭菼', r: 202, g: 215, b: 197, family: 'green'),
      ChineseColor(name: '结绿', r: 85, g: 95, b: 77, family: 'green'),
      ChineseColor(name: '山岚', r: 190, g: 210, b: 187, family: 'green'),
      ChineseColor(name: '冰台', r: 190, g: 202, b: 183, family: 'green'),
      ChineseColor(name: '绿云', r: 73, g: 67, b: 61, family: 'green'),
      ChineseColor(name: '青古', r: 179, g: 189, b: 169, family: 'green'),
      ChineseColor(name: '醾酴', r: 166, g: 186, b: 177, family: 'green'),
      ChineseColor(name: '二绿', r: 99, g: 163, b: 157, family: 'green'),
      ChineseColor(name: '苍筤', r: 155, g: 188, b: 172, family: 'green'),
      ChineseColor(name: '渌波', r: 155, g: 180, b: 150, family: 'green'),
      ChineseColor(name: '繐辖', r: 136, g: 191, b: 184, family: 'green'),
      ChineseColor(name: '铜青', r: 61, g: 142, b: 134, family: 'green'),
      ChineseColor(name: '青臒', r: 50, g: 113, b: 117, family: 'green'),
      ChineseColor(name: '耀色', r: 34, g: 107, b: 104, family: 'green'),
      ChineseColor(name: '石绿', r: 32, g: 104, b: 100, family: 'green'),
      ChineseColor(name: '竹月', r: 127, g: 159, b: 175, family: 'green'),
      ChineseColor(name: '月白', r: 212, g: 229, b: 239, family: 'green'),
      ChineseColor(name: '素采', r: 212, g: 221, b: 225, family: 'green'),
      ChineseColor(name: '星郎', r: 188, g: 212, b: 231, family: 'green'),
      ChineseColor(name: '影青', r: 189, g: 203, b: 210, family: 'green'),
      ChineseColor(name: '逍遥游', r: 178, g: 191, b: 195, family: 'green'),
      ChineseColor(name: '白青', r: 152, g: 182, b: 194, family: 'green'),
      ChineseColor(name: '青鸾', r: 154, g: 167, b: 177, family: 'green'),
      ChineseColor(name: '东方既白', r: 139, g: 163, b: 199, family: 'green'),
      ChineseColor(name: '秋蓝', r: 125, g: 146, b: 159, family: 'green'),
      ChineseColor(name: '空青', r: 102, g: 136, b: 158, family: 'green'),
      ChineseColor(name: '太师青', r: 84, g: 118, b: 137, family: 'green'),
      ChineseColor(name: '菘蓝', r: 107, g: 121, b: 142, family: 'green'),
      ChineseColor(name: '育阳染', r: 87, g: 100, b: 112, family: 'green'),
      ChineseColor(name: '青雀头黛', r: 53, g: 78, b: 107, family: 'green'),
      ChineseColor(name: '霁蓝', r: 68, g: 70, b: 84, family: 'green'),
      ChineseColor(name: '瑾瑜', r: 30, g: 39, b: 85, family: 'green'),
      ChineseColor(name: '缟羽', r: 239, g: 239, b: 239, family: 'green'),
    ]),
    // ==================== 蓝色系 / 蓝紫色系 ====================
    ColorFamily(id: 'blue', name: '蓝色系', colors: [
      ChineseColor(name: '佛头青', r: 25, g: 65, b: 95, family: 'blue'),
      ChineseColor(name: '青黛', r: 69, g: 70, b: 94, family: 'blue'),
      ChineseColor(name: '西子', r: 135, g: 192, b: 202, family: 'blue'),
      ChineseColor(name: '骐驎', r: 18, g: 38, b: 79, family: 'blue'),
      ChineseColor(name: '黲艴', r: 69, g: 70, b: 89, family: 'blue'),
      ChineseColor(name: '正青', r: 108, g: 168, b: 175, family: 'blue'),
      ChineseColor(name: '花青', r: 28, g: 40, b: 71, family: 'blue'),
      ChineseColor(name: '璆琳', r: 52, g: 48, b: 66, family: 'blue'),
      ChineseColor(name: '扁青', r: 80, g: 146, b: 150, family: 'blue'),
      ChineseColor(name: '优昙瑞', r: 97, g: 94, b: 168, family: 'blue'),
      ChineseColor(name: '绀蝶', r: 44, g: 47, b: 59, family: 'blue'),
      ChineseColor(name: '法翠', r: 161, g: 139, b: 150, family: 'blue'),
      ChineseColor(name: '暮山紫', r: 164, g: 171, b: 214, family: 'blue'),
      ChineseColor(name: '獭见', r: 21, g: 29, b: 41, family: 'blue'),
      ChineseColor(name: '吐绶蓝', r: 65, g: 130, b: 164, family: 'blue'),
      ChineseColor(name: '紫苑', r: 117, g: 124, b: 187, family: 'blue'),
      ChineseColor(name: '天水碧', r: 90, g: 164, b: 174, family: 'blue'),
      ChineseColor(name: '鱼师青', r: 50, g: 120, b: 138, family: 'blue'),
      ChineseColor(name: '延维', r: 74, g: 75, b: 157, family: 'blue'),
      ChineseColor(name: '天井', r: 164, g: 201, b: 204, family: 'blue'),
      ChineseColor(name: '软翠', r: 109, g: 108, b: 135, family: 'blue'),
      ChineseColor(name: '曾青', r: 83, g: 81, b: 100, family: 'blue'),
      ChineseColor(name: '云门', r: 162, g: 210, b: 226, family: 'blue'),
      ChineseColor(name: '青绹', r: 74, g: 75, b: 82, family: 'blue'),
      ChineseColor(name: '螺子黛', r: 19, g: 57, b: 86, family: 'blue'),
      ChineseColor(name: '群青', r: 46, g: 89, b: 167, family: 'blue'),
      ChineseColor(name: '监德', r: 111, g: 148, b: 205, family: 'blue'),
      ChineseColor(name: '苍苍', r: 89, g: 118, b: 186, family: 'blue'),
      ChineseColor(name: '孔雀蓝', r: 73, g: 148, b: 196, family: 'blue'),
      ChineseColor(name: '青冥', r: 50, g: 113, b: 174, family: 'blue'),
      ChineseColor(name: '柔蓝', r: 116, g: 104, b: 152, family: 'blue'),
      ChineseColor(name: '碧城', r: 118, g: 80, b: 123, family: 'blue'),
      ChineseColor(name: '蓝采和', r: 86, g: 67, b: 111, family: 'blue'),
      ChineseColor(name: '绀宇', r: 101, g: 81, b: 116, family: 'blue'),
      ChineseColor(name: '帝释青', r: 10, g: 52, b: 96, family: 'blue'),
      ChineseColor(name: '碧落', r: 174, g: 208, b: 238, family: 'blue'),
      ChineseColor(name: '晴山', r: 163, g: 187, b: 219, family: 'blue'),
      ChineseColor(name: '品月', r: 138, g: 171, b: 204, family: 'blue'),
      ChineseColor(name: '窃蓝', r: 136, g: 171, b: 218, family: 'blue'),
      ChineseColor(name: '授蓝', r: 115, g: 155, b: 197, family: 'blue'),
      ChineseColor(name: '玄校', r: 169, g: 160, b: 130, family: 'blue'),
      ChineseColor(name: '黄琮', r: 158, g: 140, b: 107, family: 'blue'),
      ChineseColor(name: '石莲褐', r: 146, g: 137, b: 123, family: 'blue'),
      ChineseColor(name: '绿豆褐', r: 146, g: 137, b: 107, family: 'blue'),
      ChineseColor(name: '猠绶', r: 117, g: 108, b: 75, family: 'blue'),
      ChineseColor(name: '茶色', r: 136, g: 118, b: 87, family: 'blue'),
      ChineseColor(name: '濯绛', r: 121, g: 104, b: 96, family: 'blue'),
      ChineseColor(name: '黑朱', r: 112, g: 105, b: 93, family: 'blue'),
      ChineseColor(name: '冥色', r: 102, g: 95, b: 77, family: 'blue'),
      ChineseColor(name: '伽罗', r: 109, g: 92, b: 86, family: 'blue'),
      ChineseColor(name: '苍艾', r: 68, g: 67, b: 59, family: 'blue'),
    ]),
    // ==================== 黄色系 / 土黄色系 / 褐色系 ====================
    ColorFamily(id: 'yellow', name: '黄色系', colors: [
      ChineseColor(name: '半见', r: 255, g: 251, b: 199, family: 'yellow'),
      ChineseColor(name: '翠樽', r: 205, g: 209, b: 113, family: 'yellow'),
      ChineseColor(name: '老茯神', r: 170, g: 133, b: 52, family: 'yellow'),
      ChineseColor(name: '断肠', r: 236, g: 235, b: 194, family: 'yellow'),
      ChineseColor(name: '田赤', r: 225, g: 221, b: 132, family: 'yellow'),
      ChineseColor(name: '流黄', r: 139, g: 112, b: 66, family: 'yellow'),
      ChineseColor(name: '葱青', r: 237, g: 241, b: 187, family: 'yellow'),
      ChineseColor(name: '禹余粮', r: 225, g: 210, b: 121, family: 'yellow'),
      ChineseColor(name: '青白玉', r: 202, g: 197, b: 160, family: 'yellow'),
      ChineseColor(name: '女贞黄', r: 247, g: 238, b: 173, family: 'yellow'),
      ChineseColor(name: '姚黄', r: 214, g: 188, b: 70, family: 'yellow'),
      ChineseColor(name: '玉色', r: 235, g: 228, b: 209, family: 'yellow'),
      ChineseColor(name: '莺儿', r: 235, g: 225, b: 169, family: 'yellow'),
      ChineseColor(name: '太一余粮', r: 213, g: 180, b: 89, family: 'yellow'),
      ChineseColor(name: '骨缥', r: 235, g: 227, b: 199, family: 'yellow'),
      ChineseColor(name: '桑蕾', r: 234, g: 216, b: 154, family: 'yellow'),
      ChineseColor(name: '栾华', r: 192, g: 173, b: 94, family: 'yellow'),
      ChineseColor(name: '黄润', r: 223, g: 214, b: 184, family: 'yellow'),
      ChineseColor(name: '绢纨', r: 236, g: 224, b: 147, family: 'yellow'),
      ChineseColor(name: '秋香', r: 191, g: 156, b: 70, family: 'yellow'),
      ChineseColor(name: '缣缃', r: 213, g: 200, b: 160, family: 'yellow'),
      ChineseColor(name: '少艾', r: 227, g: 235, b: 152, family: 'yellow'),
      ChineseColor(name: '大赤', r: 170, g: 150, b: 73, family: 'yellow'),
      ChineseColor(name: '佩玖', r: 172, g: 159, b: 138, family: 'yellow'),
      ChineseColor(name: '绮钱', r: 216, g: 222, b: 138, family: 'yellow'),
      ChineseColor(name: '苍黄', r: 182, g: 160, b: 20, family: 'yellow'),
      ChineseColor(name: '大块', r: 191, g: 167, b: 130, family: 'yellow'),
      ChineseColor(name: '蜜合', r: 223, g: 215, b: 194, family: 'yellow'),
      ChineseColor(name: '沙饧', r: 191, g: 166, b: 112, family: 'yellow'),
      ChineseColor(name: '地籁', r: 223, g: 206, b: 180, family: 'yellow'),
      ChineseColor(name: '仙米', r: 212, g: 201, b: 170, family: 'yellow'),
      ChineseColor(name: '黄螺', r: 180, g: 163, b: 121, family: 'yellow'),
      ChineseColor(name: '假山南', r: 212, g: 193, b: 166, family: 'yellow'),
      ChineseColor(name: '高粱', r: 196, g: 183, b: 152, family: 'yellow'),
      ChineseColor(name: '蒸栗', r: 143, g: 138, b: 95, family: 'yellow'),
      ChineseColor(name: '巨吕', r: 170, g: 142, b: 89, family: 'yellow'),
      ChineseColor(name: '石蜜', r: 212, g: 191, b: 137, family: 'yellow'),
      ChineseColor(name: '大云', r: 148, g: 120, b: 79, family: 'yellow'),
      ChineseColor(name: '降真香', r: 158, g: 131, b: 88, family: 'yellow'),
      ChineseColor(name: '紫花布', r: 190, g: 167, b: 139, family: 'yellow'),
      ChineseColor(name: '吉金', r: 137, g: 109, b: 71, family: 'yellow'),
      ChineseColor(name: '黄封', r: 202, g: 178, b: 114, family: 'yellow'),
      ChineseColor(name: '养生主', r: 181, g: 155, b: 127, family: 'yellow'),
      ChineseColor(name: '远志', r: 124, g: 102, b: 59, family: 'yellow'),
      ChineseColor(name: '射干', r: 124, g: 98, b: 68, family: 'yellow'),
      ChineseColor(name: '油葫芦', r: 100, g: 77, b: 49, family: 'yellow'),
      ChineseColor(name: '龙战', r: 95, g: 67, b: 33, family: 'yellow'),
      ChineseColor(name: '赩缔', r: 128, g: 76, b: 46, family: 'yellow'),
      ChineseColor(name: '葭灰', r: 190, g: 177, b: 170, family: 'yellow'),
      ChineseColor(name: '珠子褐', r: 195, g: 168, b: 157, family: 'yellow'),
      ChineseColor(name: '黄埃', r: 180, g: 146, b: 115, family: 'yellow'),
      ChineseColor(name: '黄栗留', r: 254, g: 220, b: 89, family: 'yellow'),
      ChineseColor(name: '露褐', r: 189, g: 130, b: 83, family: 'yellow'),
      ChineseColor(name: '弗肯红', r: 236, g: 217, b: 199, family: 'yellow'),
      ChineseColor(name: '嫩鹅黄', r: 222, g: 200, b: 103, family: 'yellow'),
      ChineseColor(name: '蛾黄', r: 190, g: 138, b: 47, family: 'yellow'),
      ChineseColor(name: '赤璋', r: 179, g: 193, b: 153, family: 'yellow'),
      ChineseColor(name: '黄河琉璃', r: 229, g: 168, b: 75, family: 'yellow'),
      ChineseColor(name: '光明砂', r: 204, g: 93, b: 32, family: 'yellow'),
      ChineseColor(name: '如梦令', r: 221, g: 187, b: 153, family: 'yellow'),
      ChineseColor(name: '杏子', r: 218, g: 146, b: 51, family: 'yellow'),
      ChineseColor(name: '柘黄', r: 198, g: 121, b: 33, family: 'yellow'),
      ChineseColor(name: '茧色', r: 198, g: 162, b: 104, family: 'yellow'),
      ChineseColor(name: '红友', r: 217, g: 136, b: 61, family: 'yellow'),
      ChineseColor(name: '媚蝶', r: 210, g: 163, b: 55, family: 'yellow'),
      ChineseColor(name: '芸黄', r: 210, g: 163, b: 108, family: 'yellow'),
      ChineseColor(name: '库金', r: 225, g: 138, b: 59, family: 'yellow'),
      ChineseColor(name: '黄流', r: 159, g: 96, b: 39, family: 'yellow'),
      ChineseColor(name: '椒房', r: 219, g: 156, b: 89, family: 'yellow'),
      ChineseColor(name: '鞠衣', r: 211, g: 162, b: 55, family: 'yellow'),
      ChineseColor(name: '靺鞨', r: 159, g: 82, b: 33, family: 'yellow'),
      ChineseColor(name: '金埒', r: 190, g: 148, b: 87, family: 'yellow'),
      ChineseColor(name: '黄不老', r: 219, g: 155, b: 52, family: 'yellow'),
      ChineseColor(name: '九斤黄', r: 221, g: 176, b: 120, family: 'yellow'),
      ChineseColor(name: '雌黄', r: 180, g: 136, b: 77, family: 'yellow'),
      ChineseColor(name: '郁金裙', r: 208, g: 134, b: 53, family: 'yellow'),
      ChineseColor(name: '密陀僧', r: 179, g: 147, b: 75, family: 'yellow'),
      ChineseColor(name: '沉香', r: 153, g: 128, b: 108, family: 'yellow'),
      ChineseColor(name: '明茶褐', r: 151, g: 131, b: 104, family: 'yellow'),
      ChineseColor(name: '栗壳', r: 210, g: 98, b: 57, family: 'yellow'),
      ChineseColor(name: '夏篇', r: 201, g: 175, b: 157, family: 'yellow'),
      ChineseColor(name: '麝香褐', r: 218, g: 158, b: 80, family: 'yellow'),
      ChineseColor(name: '檀唇', r: 218, g: 158, b: 140, family: 'yellow'),
      ChineseColor(name: '荆褐', r: 144, g: 108, b: 74, family: 'yellow'),
      ChineseColor(name: '椒褐', r: 114, g: 69, b: 58, family: 'yellow'),
      ChineseColor(name: '紫磨金', r: 188, g: 131, b: 107, family: 'yellow'),
      ChineseColor(name: '驼褐', r: 124, g: 91, b: 62, family: 'yellow'),
      ChineseColor(name: '枣褐', r: 104, g: 54, b: 26, family: 'yellow'),
      ChineseColor(name: '檀色', r: 178, g: 109, b: 83, family: 'yellow'),
      ChineseColor(name: '温韎', r: 143, g: 79, b: 49, family: 'yellow'),
      ChineseColor(name: '目童子', r: 91, g: 50, b: 34, family: 'yellow'),
      ChineseColor(name: '鹰背褐', r: 143, g: 109, b: 95, family: 'yellow'),
      ChineseColor(name: '棠梨褐', r: 149, g: 90, b: 66, family: 'yellow'),
      ChineseColor(name: '青骊', r: 86, g: 67, b: 23, family: 'yellow'),
      ChineseColor(name: '赭罗', r: 154, g: 102, b: 85, family: 'yellow'),
      ChineseColor(name: '檀褐', r: 148, g: 86, b: 53, family: 'yellow'),
      ChineseColor(name: '老僧衣', r: 184, g: 95, b: 68, family: 'yellow'),
      ChineseColor(name: '朱石栗', r: 129, g: 73, b: 44, family: 'yellow'),
      ChineseColor(name: '紫瓯', r: 124, g: 70, b: 30, family: 'yellow'),
      ChineseColor(name: '肉红', r: 221, g: 197, b: 184, family: 'yellow'),
      ChineseColor(name: '姜黄', r: 214, g: 197, b: 96, family: 'yellow'),
      ChineseColor(name: '丁香褐', r: 189, g: 150, b: 131, family: 'yellow'),
    ]),
    // ==================== 紫色系 ====================
    ColorFamily(id: 'purple', name: '紫色系', colors: [
      ChineseColor(name: '紫蒲', r: 166, g: 85, b: 157, family: 'purple'),
      ChineseColor(name: '香炉紫烟', r: 211, g: 204, b: 214, family: 'purple'),
      ChineseColor(name: '鸦雏', r: 106, g: 91, b: 109, family: 'purple'),
      ChineseColor(name: '紫紶', r: 125, g: 68, b: 132, family: 'purple'),
      ChineseColor(name: '苍烟落照', r: 125, g: 68, b: 132, family: 'purple'),
      ChineseColor(name: '玄天', r: 67, g: 84, b: 88, family: 'purple'),
      ChineseColor(name: '拂紫绵', r: 126, g: 82, b: 127, family: 'purple'),
      ChineseColor(name: '甘石', r: 189, g: 178, b: 178, family: 'purple'),
      ChineseColor(name: '烟墨', r: 82, g: 97, b: 85, family: 'purple'),
      ChineseColor(name: '频紫', r: 138, g: 24, b: 116, family: 'purple'),
      ChineseColor(name: '紫莳', r: 156, g: 142, b: 169, family: 'purple'),
      ChineseColor(name: '紫鼠', r: 89, g: 76, b: 87, family: 'purple'),
      ChineseColor(name: '三公子', r: 102, g: 61, b: 116, family: 'purple'),
      ChineseColor(name: '银褐', r: 156, g: 141, b: 155, family: 'purple'),
      ChineseColor(name: '栀子', r: 250, g: 192, b: 81, family: 'purple'),
      ChineseColor(name: '齐紫', r: 108, g: 33, b: 109, family: 'purple'),
      ChineseColor(name: '藕丝褐', r: 168, g: 135, b: 135, family: 'purple'),
      ChineseColor(name: '黄白游', r: 255, g: 247, b: 153, family: 'purple'),
      ChineseColor(name: '凝夜紫', r: 66, g: 34, b: 86, family: 'purple'),
      ChineseColor(name: '烟红', r: 157, g: 133, b: 143, family: 'purple'),
      ChineseColor(name: '松花', r: 255, g: 238, b: 111, family: 'purple'),
      ChineseColor(name: '石英', r: 200, g: 182, b: 187, family: 'purple'),
      ChineseColor(name: '迷楼灰', r: 145, g: 130, b: 143, family: 'purple'),
      ChineseColor(name: '缃叶', r: 236, g: 212, b: 82, family: 'purple'),
      ChineseColor(name: '红藤杖', r: 146, g: 129, b: 135, family: 'purple'),
    ]),
    // ==================== 白色 / 灰色系 ====================
    ColorFamily(id: 'neutral', name: '白灰色系', colors: [
      ChineseColor(name: '山矾', r: 245, g: 243, b: 242, family: 'neutral'),
      ChineseColor(name: '藕丝秋半', r: 211, g: 203, b: 197, family: 'neutral'),
      ChineseColor(name: '溶溶月', r: 190, g: 194, b: 188, family: 'neutral'),
      ChineseColor(name: '浅云', r: 234, g: 235, b: 241, family: 'neutral'),
      ChineseColor(name: '云母', r: 178, g: 190, b: 177, family: 'neutral'),
      ChineseColor(name: '月魄', r: 178, g: 182, b: 182, family: 'neutral'),
      ChineseColor(name: '凝脂', r: 245, g: 242, b: 233, family: 'neutral'),
      ChineseColor(name: '爨白', r: 246, g: 249, b: 228, family: 'neutral'),
      ChineseColor(name: '冻缥', r: 190, g: 194, b: 179, family: 'neutral'),
      ChineseColor(name: '皦玉', r: 235, g: 238, b: 232, family: 'neutral'),
      ChineseColor(name: '吉量', r: 235, g: 237, b: 223, family: 'neutral'),
      ChineseColor(name: '草白', r: 191, g: 193, b: 169, family: 'neutral'),
      ChineseColor(name: '玉頩', r: 234, g: 229, b: 227, family: 'neutral'),
      ChineseColor(name: '天球', r: 224, g: 223, b: 198, family: 'neutral'),
      ChineseColor(name: '不皂', r: 167, g: 170, b: 161, family: 'neutral'),
      ChineseColor(name: '二目鱼', r: 223, g: 224, b: 217, family: 'neutral'),
      ChineseColor(name: '霜地', r: 199, g: 198, b: 182, family: 'neutral'),
      ChineseColor(name: '绍衣', r: 168, g: 161, b: 156, family: 'neutral'),
      ChineseColor(name: '韶粉', r: 224, g: 224, b: 208, family: 'neutral'),
      ChineseColor(name: '余白', r: 201, g: 207, b: 193, family: 'neutral'),
      ChineseColor(name: '雷雨垂', r: 122, g: 123, b: 120, family: 'neutral'),
      ChineseColor(name: '香皮', r: 216, g: 209, b: 197, family: 'neutral'),
      ChineseColor(name: '墨黪', r: 88, g: 82, b: 72, family: 'neutral'),
      ChineseColor(name: '石涅', r: 104, g: 106, b: 103, family: 'neutral'),
      ChineseColor(name: '明月珰', r: 212, g: 211, b: 202, family: 'neutral'),
    ]),
  ];

  static List<ChineseColor> get allColors =>
      families.expand((f) => f.colors).toList();

  /// 返回按色相子组排列的色系列表
  /// 
  /// 核心思路（模仿 COPIC 色轮）：
  /// 1. 每个色系内的颜色按色相分成若干子组（色相带），每个子组将成为一列
  /// 2. 每个子组内按明度排序（浅→深，内圈→外圈）
  /// 3. 子组之间按色相顺序排列（角度方向色相渐变）
  /// 4. 不同子组的颜色数量不同 → 每列行数不同 → 自然参差不齐
  /// 
  /// 返回的 ColorFamily.colors 是按列优先顺序排列的，
  /// 配合 columnLengths 使用来确定每列有多少颜色
  static List<ColorFamily> get sortedFamilies {
    return families.map((family) {
      final result = sortFamilyIntoColumns(family);
      return ColorFamily(id: family.id, name: family.name, colors: result.colors);
    }).toList();
  }

  /// 排序结果：按列排列的颜色 + 每列的长度
  /// 
  /// 使用 20° 色相桶，不合并不拆分，让每列的长度自然不同。
  /// 列内按明度排序（浅→深）。
  static ({List<ChineseColor> colors, List<int> columnLengths}) sortFamilyIntoColumns(ColorFamily family) {
    final colors = List<ChineseColor>.from(family.colors);
    if (colors.length <= 3) {
      return (colors: colors, columnLengths: [colors.length]);
    }

    // 1. 计算每个颜色的 HSL
    final withHsl = colors.map((c) {
      final hsl = HSLColor.fromColor(Color.fromARGB(255, c.r, c.g, c.b));
      return (color: c, hsl: hsl);
    }).toList();

    // 2. 按色相分组 — 20° 桶宽度，更细腻的过渡
    //    低饱和度的颜色单独归组
    const hueBucketSize = 20.0;
    const satThreshold = 0.10;
    
    final Map<int, List<({ChineseColor color, HSLColor hsl})>> buckets = {};
    const grayBucket = -1;
    
    for (final item in withHsl) {
      int bucket;
      if (item.hsl.saturation < satThreshold) {
        bucket = grayBucket;
      } else {
        bucket = (item.hsl.hue / hueBucketSize).floor();
      }
      buckets.putIfAbsent(bucket, () => []);
      buckets[bucket]!.add(item);
    }

    // 3. 不合并小桶 — 让 1-2 个颜色的列自然地短
    //    只合并只有 1 个颜色的桶到最近的桶（太短的列视觉上不好）
    final sortedKeys = buckets.keys.where((k) => k != grayBucket).toList()..sort();
    final mergedBuckets = <int, List<({ChineseColor color, HSLColor hsl})>>{};
    
    for (final key in sortedKeys) {
      final items = buckets[key]!;
      if (items.length == 1 && mergedBuckets.isNotEmpty) {
        // 只合并单个颜色的桶
        final lastKey = mergedBuckets.keys.last;
        mergedBuckets[lastKey]!.addAll(items);
      } else {
        mergedBuckets[key] = List.from(items);
      }
    }
    
    if (buckets.containsKey(grayBucket) && buckets[grayBucket]!.isNotEmpty) {
      mergedBuckets[grayBucket] = buckets[grayBucket]!;
    }

    // 4. 每个桶内按明度排序（深→浅，内圈→外圈），桶之间按色相排序
    //    超过 maxRowsPerCol 的桶拆分成多列，但保持不均匀长度
    //    这样外圈依然参差不齐（COPIC 风格）
    const maxRowsPerCol = 8;

    final orderedKeys = mergedBuckets.keys.toList()
      ..sort((a, b) {
        if (a == grayBucket) return 1;
        if (b == grayBucket) return -1;
        return a.compareTo(b);
      });

    final sortedColors = <ChineseColor>[];
    final columnLengths = <int>[];

    for (final key in orderedKeys) {
      final items = mergedBuckets[key]!;
      // 按明度从低到高排序（深色在内圈，浅色在外圈）
      items.sort((a, b) => a.hsl.lightness.compareTo(b.hsl.lightness));

      if (items.length > maxRowsPerCol) {
        // 拆分：按明度子范围分列，保持自然差异
        final numSplits = (items.length / maxRowsPerCol).ceil();
        final baseSize = items.length ~/ numSplits;
        final remainder = items.length % numSplits;
        int offset = 0;
        for (int s = 0; s < numSplits; s++) {
          final chunkSize = baseSize + (s < remainder ? 1 : 0);
          for (int i = offset; i < offset + chunkSize; i++) {
            sortedColors.add(items[i].color);
          }
          columnLengths.add(chunkSize);
          offset += chunkSize;
        }
      } else {
        for (final item in items) {
          sortedColors.add(item.color);
        }
        columnLengths.add(items.length);
      }
    }

    // 5. 平滑相邻列长度 — 避免长短列突然衔接
    //    如果相邻列长度差 > 3，把长列的部分颜色移到短列
    _smoothColumnLengths(sortedColors, columnLengths);

    return (colors: sortedColors, columnLengths: columnLengths);
  }

  /// 平滑相邻列长度差异，避免视觉突兀
  static void _smoothColumnLengths(
      List<ChineseColor> colors, List<int> lengths) {
    if (lengths.length < 2) return;

    const maxDiff = 2;
    bool changed = true;
    int iterations = 0;

    while (changed && iterations < 5) {
      changed = false;
      iterations++;

      for (int i = 0; i < lengths.length - 1; i++) {
        final diff = lengths[i] - lengths[i + 1];
        if (diff > maxDiff) {
          // 列 i 太长，移一个颜色到列 i+1
          final moveCount = (diff - maxDiff + 1) ~/ 2;
          for (int m = 0; m < moveCount; m++) {
            // 计算列 i 的最后一个颜色的索引
            int colIEnd = 0;
            for (int c = 0; c <= i; c++) {
              colIEnd += lengths[c];
            }
            // 把列 i 的最后一个颜色移到列 i+1 的开头
            if (colIEnd > 0 && colIEnd <= colors.length) {
              final color = colors.removeAt(colIEnd - 1);
              colors.insert(colIEnd, color);
              lengths[i]--;
              lengths[i + 1]++;
              changed = true;
            }
          }
        } else if (diff < -maxDiff) {
          // 列 i+1 太长，移一个颜色到列 i
          final moveCount = (-diff - maxDiff + 1) ~/ 2;
          for (int m = 0; m < moveCount; m++) {
            int colIEnd = 0;
            for (int c = 0; c <= i; c++) {
              colIEnd += lengths[c];
            }
            // 把列 i+1 的第一个颜色移到列 i 的末尾
            if (colIEnd < colors.length) {
              final color = colors.removeAt(colIEnd);
              colors.insert(colIEnd, color);
              lengths[i]++;
              lengths[i + 1]--;
              changed = true;
            }
          }
        }
      }
    }
  }
}
