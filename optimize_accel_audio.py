#!/usr/bin/env python3
"""
优化加速音效大小，确保总音频能放入Flash
目标：总大小 < 300KB
"""
import os
FFMPEG_PATH = r'C:\Users\35058\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0.1-full_build\bin'
os.environ['PATH'] = FFMPEG_PATH + os.pathsep + os.environ.get('PATH', '')

from pydub import AudioSegment
from pydub.effects import low_pass_filter, high_pass_filter

# 加载原始音频
print('Loading original engine_loop.mp3...')
audio = AudioSegment.from_mp3('audio/engine_loop.mp3')

# ============ 优化加速音效 ============
print('\n=== Optimizing accel audio ===')

# 提取一段好听的加速循环（约8秒）
seg1 = audio[50000:54000]  # 4秒
seg2 = audio[34000:38000]  # 4秒

# 降噪
seg1 = high_pass_filter(seg1, 100)
seg1 = low_pass_filter(seg1, 6000)
seg2 = high_pass_filter(seg2, 100)
seg2 = low_pass_filter(seg2, 6000)

# 增加音量
seg1 = seg1 + 5
seg2 = seg2 + 5

# 拼接（交叉淡化）
mixed = seg1.append(seg2, crossfade=500)

print(f'Accel loop: {len(mixed)/1000:.1f}s')

# 导出为更低比特率（48kbps）
mixed.export('audio/processed/engine_accel.mp3', format='mp3', bitrate='48k',
             parameters=['-write_xing', '0'])
print(f'Saved: engine_accel.mp3 ({os.path.getsize("audio/processed/engine_accel.mp3")} bytes)')

# ============ 计算总大小 ============
print('\n=== Total audio size ===')
total = 0
for f in ['engine_start.mp3', 'engine_accel.mp3']:
    path = f'audio/processed/{f}'
    if os.path.exists(path):
        size = os.path.getsize(path)
        total += size
        print(f'  {f}: {size} bytes ({size/1024:.1f} KB)')

print(f'Total: {total} bytes ({total/1024:.1f} KB)')
