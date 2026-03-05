#!/usr/bin/env python3
"""
将MP3音频文件转换为C头文件数组
用于STM32嵌入式音频播放
"""

import os
import sys

def is_xing_info_frame(data, frame_offset):
    """检查帧是否是Xing/Info VBR信息帧"""
    # Xing/Info标签通常在帧头后32或36字节处
    for offset in [32, 36]:
        check_pos = frame_offset + offset
        if check_pos + 4 < len(data):
            tag = data[check_pos:check_pos+4]
            if tag in [b'Xing', b'Info']:
                return True
    return False

def find_mp3_frame_offset(data):
    """查找真正的MP3音频帧起始位置（跳过ID3标签和Xing/Info VBR帧）"""
    start_search = 0
    
    # 检查是否有ID3v2标签
    if len(data) >= 10 and data[0:3] == b'ID3':
        # ID3v2标签大小（syncsafe integer）
        size = ((data[6] & 0x7F) << 21) | ((data[7] & 0x7F) << 14) | \
               ((data[8] & 0x7F) << 7) | (data[9] & 0x7F)
        start_search = 10 + size
    
    # 查找MP3帧同步字节，跳过Xing/Info帧
    offset = start_search
    while offset < len(data) - 4:
        if data[offset] == 0xFF and (data[offset + 1] & 0xE0) == 0xE0:
            # 检查是否是Xing/Info VBR信息帧
            if is_xing_info_frame(data, offset):
                # 跳过这个帧，继续查找下一个
                offset += 1
                continue
            # 找到真正的音频帧
            return offset
        offset += 1
    
    # 没找到，返回0
    return 0

def convert_mp3_to_header(mp3_path, output_path, array_name):
    """将MP3文件转换为C头文件"""
    
    # 读取MP3文件
    with open(mp3_path, 'rb') as f:
        data = f.read()
    
    size = len(data)
    offset = find_mp3_frame_offset(data)
    
    print(f"文件: {mp3_path}")
    print(f"大小: {size} 字节")
    print(f"MP3帧起始偏移: {offset}")
    
    # 生成头文件
    header_name = array_name.upper()
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"""/**
 ******************************************************************************
 * @file    {os.path.basename(output_path)}
 * @brief   Audio data array (Auto-generated)
 * @note    Source: {os.path.basename(mp3_path)}, Size: {size} bytes
 *          MP3 audio start offset: {offset}
 ******************************************************************************
 */

#ifndef __{header_name}_H
#define __{header_name}_H

#ifdef __cplusplus
extern "C" {{
#endif

#include "main.h"

/* Audio data size in bytes */
#define {header_name}_SIZE {size}

/* MP3 frame header offset (skip ID3 tag) */
#define {header_name}_START_OFFSET {offset}

/* Audio data array - stored in Flash */
static const uint8_t {array_name}_data[{header_name}_SIZE] = {{
""")
        
        # 写入数据，每行16字节
        for i in range(0, size, 16):
            line_data = data[i:min(i+16, size)]
            hex_str = ', '.join(f'0x{b:02X}' for b in line_data)
            if i + 16 < size:
                f.write(f"    {hex_str},\n")
            else:
                f.write(f"    {hex_str}\n")
        
        f.write(f"""}};

#ifdef __cplusplus
}}
#endif

#endif /* __{header_name}_H */
""")
    
    print(f"生成: {output_path}")
    return size, offset

def main():
    # 音频文件列表（只保留启动和加速两个）
    audio_files = [
        ("audio/processed/engine_start.mp3", "engine_start", "engine_start"),
        ("audio/processed/engine_accel.mp3", "engine_accel", "engine_accel"),
    ]
    
    output_dir = "f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc"
    
    total_size = 0
    
    print("=" * 60)
    print("音频文件转换为C头文件")
    print("=" * 60)
    
    for mp3_path, output_name, array_name in audio_files:
        if os.path.exists(mp3_path):
            output_path = os.path.join(output_dir, f"{output_name}.h")
            size, offset = convert_mp3_to_header(mp3_path, output_path, array_name)
            total_size += size
            print("-" * 40)
        else:
            print(f"警告: 文件不存在 - {mp3_path}")
    
    print("=" * 60)
    print(f"总大小: {total_size} 字节 ({total_size / 1024:.1f} KB)")
    print("=" * 60)

if __name__ == "__main__":
    main()
