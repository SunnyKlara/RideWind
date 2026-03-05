#!/usr/bin/env python3
"""
创建高质量无缝循环的加速音效
1. 提高比特率改善音质
2. 使用更长的交叉淡化实现无缝循环
3. 选择音色一致的片段避免听出循环
"""
import os
FFMPEG_PATH = r'C:\Users\35058\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0.1-full_build\bin'
os.environ['PATH'] = FFMPEG_PATH + os.pathsep + os.environ.get('PATH', '')

from pydub import AudioSegment
from pydub.effects import low_pass_filter, high_pass_filter, normalize

print('Loading original engine_loop.mp3...')
audio = AudioSegment.from_mp3('audio/engine_loop.mp3')

# ============ 创建真正无缝的循环 ============
print('\n=== Creating truly seamless loop ===')

# 选择一段稳定的引擎声（避免有明显变化的部分）
# 使用更长的片段，这样循环点更不容易被察觉
segment = audio[35000:50000]  # 15秒稳定片段
print(f'Base segment: {len(segment)/1000:.1f}s')

# 轻度降噪
segment = high_pass_filter(segment, 50)
segment = low_pass_filter(segment, 12000)

# 标准化
segment = normalize(segment)

# ============ 无缝循环处理 ============
# 关键技术：让音频的结尾能够完美衔接到开头
# 方法：取结尾3秒和开头3秒做交叉淡化

fade_duration = 3000  # 3秒交叉淡化

# 取结尾部分
end_part = segment[-fade_duration:]
# 取开头部分  
start_part = segment[:fade_duration]

# 创建交叉淡化过渡
# 结尾淡出
end_faded = end_part.fade_out(fade_duration)
# 开头淡入
start_faded = start_part.fade_in(fade_duration)

# 叠加创建过渡段
transition = end_faded.overlay(start_faded)

# 组合：中间部分 + 过渡段（替换原来的结尾）
middle = segment[fade_duration:-fade_duration]
seamless = middle + transition

print(f'Seamless loop: {len(seamless)/1000:.1f}s')

# ============ 导出 ============
seamless.export('audio/processed/engine_accel.mp3', format='mp3', bitrate='128k',
                parameters=['-write_xing', '0'])

size = os.path.getsize('audio/processed/engine_accel.mp3')
print(f'Saved: engine_accel.mp3 ({size} bytes, {size/1024:.1f} KB)')

# 检查总大小
start_size = os.path.getsize('audio/processed/engine_start.mp3')
total = start_size + size
print(f'\nTotal audio: {total/1024:.1f} KB')
