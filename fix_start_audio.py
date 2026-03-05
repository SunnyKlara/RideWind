#!/usr/bin/env python3
"""
修复启动音效：
1. 从原始音频提取4-9秒（5秒，两次轰鸣，去掉最后的人声）
2. 优化音质（降噪滤波）
"""
import os
FFMPEG_PATH = r'C:\Users\35058\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0.1-full_build\bin'
os.environ['PATH'] = FFMPEG_PATH + os.pathsep + os.environ.get('PATH', '')

from pydub import AudioSegment
from pydub.effects import low_pass_filter, high_pass_filter

# 从原始音频重新提取
print('Loading original engine_loop.mp3...')
audio = AudioSegment.from_mp3('audio/engine_loop.mp3')

# 提取4-9秒（5秒，包含两次轰鸣，避开10秒后的人声）
# 之前是4-10秒，最后1秒有人声，所以改成4-9秒
start_audio = audio[4000:9000]
print(f'Extracted 4-9s: {len(start_audio)/1000:.1f}s')

# 音质优化：降噪滤波
# 高通滤波去除低频噪音（引擎声主要在100Hz以上）
start_audio = high_pass_filter(start_audio, 80)
# 低通滤波去除高频杂音（保留到8kHz）
start_audio = low_pass_filter(start_audio, 8000)

# 添加平滑淡出
start_audio = start_audio.fade_out(500)

# 增加音量
start_audio = start_audio + 6

print(f'Final: {len(start_audio)/1000:.1f}s, {start_audio.dBFS:.1f} dBFS')

# 导出
start_audio.export('audio/processed/engine_start.mp3', format='mp3', bitrate='64k',
                   parameters=['-write_xing', '0'])
print(f'Saved: engine_start.mp3 ({os.path.getsize("audio/processed/engine_start.mp3")} bytes)')

print('\nDone! Now run: py convert_audio_to_header.py')
