#!/usr/bin/env python3
"""
创建优化的音频文件 - 减小文件大小以适应Flash
- 启动音效：5-7秒，去掉人声
- 加速音效：压缩大小
- 使用较低比特率（64kbps）节省空间
"""
import os
FFMPEG_PATH = r'C:\Users\35058\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0.1-full_build\bin'
os.environ['PATH'] = FFMPEG_PATH + os.pathsep + os.environ.get('PATH', '')

from pydub import AudioSegment
from pydub.effects import low_pass_filter, high_pass_filter

# 加载原始音频
print('Loading original audio...')
audio = AudioSegment.from_mp3('audio/engine_loop.mp3')

# ============ 启动音效 (5-7秒) ============
print('\n=== Creating engine start sound (5-7s) ===')

# 分析 4-11 秒（避开最后的人声）
print('Analyzing 4-11s for roar peaks...')
for i in range(4, 11):
    seg = audio[i*1000:(i+1)*1000]
    print(f'  {i}-{i+1}s: {seg.dBFS:.1f} dBFS')

# 提取 4-10 秒（6秒，两次轰鸣，避开人声）
roar = audio[4000:10000]
print(f'\nOriginal roar (4-10s): {len(roar)/1000:.1f}s, {roar.dBFS:.1f} dBFS')

# 降噪滤波
roar = high_pass_filter(roar, 100)
roar = low_pass_filter(roar, 6000)

# 增加音量
roar = roar + 8

# 淡出
roar = roar.fade_out(800)

print(f'Final start sound: {len(roar)/1000:.1f}s, {roar.dBFS:.1f} dBFS')

# 导出为低比特率（64kbps）节省空间
roar.export('audio/processed/engine_start.mp3', format='mp3', bitrate='64k',
            parameters=['-write_xing', '0'])
print(f'Exported: engine_start.mp3 ({os.path.getsize("audio/processed/engine_start.mp3")} bytes)')

# ============ 加速音效 (压缩版) ============
print('\n=== Creating compressed accel sound ===')

# 使用较短的循环（12秒）和低比特率
seg1 = audio[50000:54000] + 5
seg2 = audio[34000:38000] + 5
seg3 = audio[44000:48000] + 5

# 降噪
seg1 = high_pass_filter(seg1, 100)
seg1 = low_pass_filter(seg1, 6000)
seg2 = high_pass_filter(seg2, 100)
seg2 = low_pass_filter(seg2, 6000)
seg3 = high_pass_filter(seg3, 100)
seg3 = low_pass_filter(seg3, 6000)

# 拼接
crossfade = 800
mixed = seg1.append(seg2, crossfade=crossfade)
mixed = mixed.append(seg3, crossfade=crossfade)

# 无缝循环处理
loop_fade = 1000
final_loop = mixed[loop_fade//2:-loop_fade//2]

print(f'Accel loop: {len(final_loop)/1000:.1f}s, {final_loop.dBFS:.1f} dBFS')

# 导出为低比特率
final_loop.export('audio/processed/engine_accel.mp3', format='mp3', bitrate='64k',
                  parameters=['-write_xing', '0'])
print(f'Exported: engine_accel.mp3 ({os.path.getsize("audio/processed/engine_accel.mp3")} bytes)')

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
print('\nDone!')
