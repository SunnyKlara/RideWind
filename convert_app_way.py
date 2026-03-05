#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
模拟APP的转换方式：
1. 读取任意尺寸的图片
2. 缩放到154x154
3. 转换为RGB565
"""
from PIL import Image
import struct

# 读取BMP
img = Image.open('RideWind/assets/bmp/logo.bmp')
print(f'原始: {img.size}, {img.mode}')

# 缩放到154x154（最近邻插值）
img_resized = img.resize((154, 154), Image.NEAREST)
print(f'缩放后: {img_resized.size}')

# 转换为RGB
if img_resized.mode != 'RGB':
    img_resized = img_resized.convert('RGB')

# 获取像素数据
pixels = img_resized.load()

# 转换为RGB565（BMP倒序）
rgb565_data = []
for y in range(153, -1, -1):  # 从下到上
    for x in range(154):
        r, g, b = pixels[x, y]
        
        r5 = (r >> 3) & 0x1F
        g6 = (g >> 2) & 0x3F
        b5 = (b >> 3) & 0x1F
        rgb565 = (r5 << 11) | (g6 << 5) | b5
        
        rgb565_data.append((rgb565 >> 8) & 0xFF)
        rgb565_data.append(rgb565 & 0xFF)

print(f'转换后: {len(rgb565_data)} 字节')
print(f'前32字节:')
for i in range(0, 32, 2):
    print(f'  [{i:3d}-{i+1:3d}]: 0x{rgb565_data[i]:02X}, 0x{rgb565_data[i+1]:02X}')

# 保存到文件供测试
with open('app_converted.bin', 'wb') as f:
    f.write(bytes(rgb565_data))
print(f'\n已保存到 app_converted.bin')
