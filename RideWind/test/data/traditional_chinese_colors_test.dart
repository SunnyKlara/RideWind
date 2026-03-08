import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewind/data/traditional_chinese_colors.dart';

void main() {
  group('ChineseColor', () {
    test('toColor returns correct ARGB color', () {
      const color = ChineseColor(
        name: '朱砂',
        r: 255,
        g: 46,
        b: 0,
        family: 'red',
      );
      expect(color.toColor(), equals(const Color.fromARGB(255, 255, 46, 0)));
    });

    test('textColor returns black for bright colors (luminance > 128)', () {
      // White: luminance = 0.299*255 + 0.587*255 + 0.114*255 = 255
      const bright = ChineseColor(
        name: '白',
        r: 255,
        g: 255,
        b: 255,
        family: 'neutral',
      );
      expect(bright.textColor, equals(Colors.black));
    });

    test('textColor returns white for dark colors (luminance <= 128)', () {
      // Black: luminance = 0
      const dark = ChineseColor(
        name: '黑',
        r: 0,
        g: 0,
        b: 0,
        family: 'neutral',
      );
      expect(dark.textColor, equals(Colors.white));
    });

    test('textColor boundary: luminance exactly 128 returns white', () {
      // Find RGB where 0.299*r + 0.587*g + 0.114*b = 128 exactly
      // r=128, g=128, b=128 → luminance = 128*(0.299+0.587+0.114) = 128
      const boundary = ChineseColor(
        name: '中灰',
        r: 128,
        g: 128,
        b: 128,
        family: 'neutral',
      );
      // luminance = 128.0, not > 128, so should return white
      expect(boundary.textColor, equals(Colors.white));
    });

    test('textColor boundary: luminance just above 128 returns black', () {
      // r=129, g=128, b=128 → luminance ≈ 128.299
      const aboveBoundary = ChineseColor(
        name: '浅灰',
        r: 129,
        g: 128,
        b: 128,
        family: 'neutral',
      );
      expect(aboveBoundary.textColor, equals(Colors.black));
    });

    test('stores all fields correctly', () {
      const color = ChineseColor(
        name: '胭脂',
        r: 157,
        g: 41,
        b: 51,
        family: 'red',
      );
      expect(color.name, '胭脂');
      expect(color.r, 157);
      expect(color.g, 41);
      expect(color.b, 51);
      expect(color.family, 'red');
    });
  });

  group('ColorFamily', () {
    test('stores all fields correctly', () {
      const family = ColorFamily(
        id: 'red',
        name: '红色系',
        colors: [
          ChineseColor(name: '朱砂', r: 255, g: 46, b: 0, family: 'red'),
          ChineseColor(name: '胭脂', r: 157, g: 41, b: 51, family: 'red'),
        ],
      );
      expect(family.id, 'red');
      expect(family.name, '红色系');
      expect(family.colors.length, 2);
      expect(family.colors[0].name, '朱砂');
      expect(family.colors[1].name, '胭脂');
    });

    test('can be constructed with empty colors list', () {
      const family = ColorFamily(
        id: 'empty',
        name: '空色系',
        colors: [],
      );
      expect(family.colors, isEmpty);
    });
  });
}
