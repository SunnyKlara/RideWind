#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
模拟专业取模软件的转换过程
从24位BMP转换为16位RGB565
"""
import struct

def read_bmp_24bit(filename):
    """读取24位BMP文件"""
    with open(filename, 'rb') as f:
        data = f.read()
    
    # 验证BMP标识
    if data[0:2] != b'BM':
        raise ValueError('不是有效的BMP文件')
    
    # 解析文件头
    pixel_data_offset = struct.unpack('<I', data[10:14])[0]
    width = struct.unpack('<i', data[18:22])[0]
    height = struct.unpack('<i', data[22:26])[0]
    bits_per_pixel = struct.unpack('<H', data[28:30])[0]
    
    print(f'📊 BMP信息: {width}x{abs(height)}, {bits_per_pixel}位')
    
    if bits_per_pixel != 24:
        raise ValueError(f'只支持24位BMP，当前是{bits_per_pixel}位')
    
    # 读取像素数据
    pixel_data = data[pixel_data_offset:]
    
    # BMP的行字节数必须是4的倍数（padding）
    row_size = ((width * 3 + 3) // 4) * 4
    
    return width, abs(height), height > 0, pixel_data, row_size

def convert_to_rgb565(width, height, is_bottom_up, pixel_data, row_size):
    """
    转换24位BGR到16位RGB565
    
    BMP格式特点：
    1. 颜色顺序是BGR（不是RGB）
    2. 如果height>0，扫描顺序是从下到上（倒序）
    3. 每行有padding对齐到4字节
    """
    rgb565_data = []
    
    # 确定扫描顺序
    if is_bottom_up:
        # 从下到上扫描（BMP标准）
        row_range = range(height - 1, -1, -1)
        print('🔄 扫描顺序: 从下到上 (BMP标准倒序)')
    else:
        # 从上到下扫描
        row_range = range(height)
        print('🔄 扫描顺序: 从上到下')
    
    for y in row_range:
        for x in range(width):
            # 计算像素在BMP数据中的位置
            offset = y * row_size + x * 3
            
            # BMP是BGR顺序
            b = pixel_data[offset]
            g = pixel_data[offset + 1]
            r = pixel_data[offset + 2]
            
            # 转换为RGB565
            r5 = (r >> 3) & 0x1F  # 5位红色
            g6 = (g >> 2) & 0x3F  # 6位绿色
            b5 = (b >> 3) & 0x1F  # 5位蓝色
            
            rgb565 = (r5 << 11) | (g6 << 5) | b5
            
            # 大端序输出（高字节在前）
            high_byte = (rgb565 >> 8) & 0xFF
            low_byte = rgb565 & 0xFF
            
            rgb565_data.append(high_byte)
            rgb565_data.append(low_byte)
    
    return bytes(rgb565_data)

def main():
    # 读取BMP文件
    width, height, is_bottom_up, pixel_data, row_size = read_bmp_24bit('RideWind/assets/bmp/logo.bmp')
    
    # 转换为RGB565
    rgb565_data = convert_to_rgb565(width, height, is_bottom_up, pixel_data, row_size)
    
    print(f'✅ 转换完成: {len(rgb565_data)} 字节')
    print()
    
    # 显示前32字节
    print('🔍 转换后的前32字节:')
    for i in range(0, min(32, len(rgb565_data)), 2):
        byte1 = rgb565_data[i]
        byte2 = rgb565_data[i+1]
        word = (byte1 << 8) | byte2
        print(f'   [{i:3d}-{i+1:3d}]: 0x{byte1:02X}, 0x{byte2:02X}  → 0x{word:04X}')
    
    print()
    
    # 读取logo.c的前32字节进行对比
    print('🔍 logo.c的前32字节:')
    logo_c_hex = "00 00 08 61 18 E3 21 24 29 45 21 24 18 E3 08 61 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    logo_c_bytes = bytes.fromhex(logo_c_hex)
    
    for i in range(0, min(32, len(logo_c_bytes)), 2):
        byte1 = logo_c_bytes[i]
        byte2 = logo_c_bytes[i+1]
        word = (byte1 << 8) | byte2
        print(f'   [{i:3d}-{i+1:3d}]: 0x{byte1:02X}, 0x{byte2:02X}  → 0x{word:04X}')
    
    print()
    
    # 逐字节对比
    print('🔍 逐字节对比:')
    match_count = 0
    for i in range(min(32, len(rgb565_data), len(logo_c_bytes))):
        converted = rgb565_data[i]
        original = logo_c_bytes[i]
        if converted == original:
            match_count += 1
            status = '✅'
        else:
            status = '❌'
        print(f'   {status} [{i:3d}]: 转换=0x{converted:02X} vs 取模=0x{original:02X}')
    
    print()
    total = min(32, len(rgb565_data), len(logo_c_bytes))
    print(f'📊 匹配度: {match_count}/{total} ({match_count*100//total}%)')
    
    if match_count == total:
        print('🎉 完美匹配！转换算法正确！')
    else:
        print('⚠️ 存在差异，需要调整转换参数')

if __name__ == '__main__':
    main()
