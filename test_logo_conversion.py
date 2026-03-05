#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import struct

# 读取79x33的BMP
with open('RideWind/assets/bmp/logo.bmp', 'rb') as f:
    data = f.read()

pixel_data_offset = struct.unpack('<I', data[10:14])[0]
width = struct.unpack('<i', data[18:22])[0]
height = struct.unpack('<i', data[22:26])[0]
bits_per_pixel = struct.unpack('<H', data[28:30])[0]

print(f'BMP: {width}x{abs(height)}, {bits_per_pixel}位')

pixel_data = data[pixel_data_offset:]
row_size = ((width * 3 + 3) // 4) * 4

# 转换为RGB565（BMP倒序）
rgb565_data = []
for y in range(abs(height) - 1, -1, -1):
    for x in range(width):
        offset = y * row_size + x * 3
        b = pixel_data[offset]
        g = pixel_data[offset + 1]
        r = pixel_data[offset + 2]
        
        r5 = (r >> 3) & 0x1F
        g6 = (g >> 2) & 0x3F
        b5 = (b >> 3) & 0x1F
        rgb565 = (r5 << 11) | (g6 << 5) | b5
        
        rgb565_data.append((rgb565 >> 8) & 0xFF)
        rgb565_data.append(rgb565 & 0xFF)

print(f'转换后: {len(rgb565_data)} 字节')
print(f'前16字节: {", ".join(f"0x{b:02X}" for b in rgb565_data[:16])}')

# 读取logo.c
logo_c_hex = "00 00 08 61 18 E3 21 24 29 45 21 24 18 E3 08 61"
logo_c_bytes = bytes.fromhex(logo_c_hex)
print(f'logo.c前16字节: {", ".join(f"0x{b:02X}" for b in logo_c_bytes)}')

# 对比
match = sum(1 for i in range(16) if rgb565_data[i] == logo_c_bytes[i])
print(f'匹配: {match}/16')
