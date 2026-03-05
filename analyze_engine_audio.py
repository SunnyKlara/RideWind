"""
Professional Engine Audio Analyzer and Processor
分析9分钟赛车引擎音频，提取精华片段
"""

import os
import sys

# 设置 ffmpeg 路径
FFMPEG_PATH = r"C:\Users\35058\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0.1-full_build\bin"
os.environ["PATH"] = FFMPEG_PATH + os.pathsep + os.environ.get("PATH", "")

from pydub import AudioSegment
from pydub.silence import detect_nonsilent

def analyze_audio(file_path):
    """分析音频基本信息"""
    print(f"Loading audio: {file_path}")
    audio = AudioSegment.from_mp3(file_path)
    
    duration_sec = len(audio) / 1000
    duration_min = duration_sec / 60
    
    print(f"\n=== Audio Basic Info ===")
    print(f"Duration: {duration_sec:.2f} seconds ({duration_min:.2f} minutes)")
    print(f"Channels: {audio.channels}")
    print(f"Sample Rate: {audio.frame_rate} Hz")
    print(f"Sample Width: {audio.sample_width * 8} bits")
    print(f"File Size: {os.path.getsize(file_path) / 1024 / 1024:.2f} MB")
    
    return audio

def analyze_loudness_curve(audio, segment_duration_ms=1000):
    """分析音频响度曲线，识别不同段落"""
    print(f"\n=== Loudness Analysis (per {segment_duration_ms}ms) ===")
    
    loudness_data = []
    total_segments = len(audio) // segment_duration_ms
    
    for i in range(total_segments):
        start = i * segment_duration_ms
        end = start + segment_duration_ms
        segment = audio[start:end]
        loudness = segment.dBFS
        loudness_data.append((start/1000, loudness))
    
    return loudness_data

def print_loudness_summary(loudness_data):
    """打印响度摘要"""
    # 计算统计信息
    valid_loudness = [l for _, l in loudness_data if l > -60]
    if not valid_loudness:
        print("No valid loudness data found")
        return
    
    avg_loudness = sum(valid_loudness) / len(valid_loudness)
    max_loudness = max(valid_loudness)
    min_loudness = min(valid_loudness)
    
    print(f"\nLoudness Statistics:")
    print(f"  Average: {avg_loudness:.1f} dBFS")
    print(f"  Max: {max_loudness:.1f} dBFS")
    print(f"  Min: {min_loudness:.1f} dBFS")
    
    # 打印每10秒的响度
    print(f"\nLoudness per 10 seconds:")
    print(f"{'Time':>8} | {'Loudness':>10} | {'Level':>20}")
    print("-" * 45)
    
    for i in range(0, len(loudness_data), 10):
        time_sec = loudness_data[i][0]
        # 计算这10秒的平均响度
        segment_loudness = [l for _, l in loudness_data[i:i+10] if l > -60]
        if segment_loudness:
            avg = sum(segment_loudness) / len(segment_loudness)
            # 可视化
            level = int((avg - min_loudness) / (max_loudness - min_loudness) * 20) if max_loudness > min_loudness else 0
            bar = "█" * level + "░" * (20 - level)
            print(f"{time_sec:>6.0f}s | {avg:>8.1f} dB | {bar}")
    
    return avg_loudness, max_loudness, min_loudness

def find_best_segments(audio, loudness_data):
    """找出最佳的音频片段"""
    print("\n=== Finding Best Segments ===")
    
    valid_loudness = [l for _, l in loudness_data if l > -60]
    avg_loudness = sum(valid_loudness) / len(valid_loudness)
    max_loudness = max(valid_loudness)
    
    # 定义阈值
    high_threshold = avg_loudness + (max_loudness - avg_loudness) * 0.5
    low_threshold = avg_loudness - 3
    
    print(f"High RPM threshold: {high_threshold:.1f} dBFS")
    print(f"Idle threshold: {low_threshold:.1f} dBFS")
    
    # 找高转速段
    high_rpm_segments = []
    in_high = False
    start_time = 0
    
    for time_sec, loudness in loudness_data:
        if loudness > high_threshold and not in_high:
            in_high = True
            start_time = time_sec
        elif loudness <= high_threshold and in_high:
            in_high = False
            if time_sec - start_time >= 3:  # 至少3秒
                high_rpm_segments.append((start_time, time_sec))
    
    print(f"\nHigh RPM segments (>{high_threshold:.1f} dBFS, >=3s):")
    for start, end in high_rpm_segments[:5]:
        print(f"  {start:.0f}s - {end:.0f}s ({end-start:.0f}s)")
    
    # 找怠速段
    idle_segments = []
    in_idle = False
    start_time = 0
    prev_loudness = None
    stable_count = 0
    
    for time_sec, loudness in loudness_data:
        if loudness < low_threshold and loudness > -40:
            if prev_loudness and abs(loudness - prev_loudness) < 2:
                stable_count += 1
                if stable_count >= 3 and not in_idle:
                    in_idle = True
                    start_time = time_sec - 3
            else:
                stable_count = 0
        else:
            if in_idle and time_sec - start_time >= 5:
                idle_segments.append((start_time, time_sec))
            in_idle = False
            stable_count = 0
        prev_loudness = loudness
    
    print(f"\nIdle segments (<{low_threshold:.1f} dBFS, stable, >=5s):")
    for start, end in idle_segments[:5]:
        print(f"  {start:.0f}s - {end:.0f}s ({end-start:.0f}s)")
    
    # 找加速段（响度递增）
    accel_segments = []
    rising_start = None
    rising_count = 0
    
    for i in range(1, len(loudness_data)):
        time_sec, loudness = loudness_data[i]
        prev_time, prev_loudness = loudness_data[i-1]
        
        if loudness > prev_loudness + 0.5:  # 响度增加
            if rising_start is None:
                rising_start = prev_time
            rising_count += 1
        else:
            if rising_count >= 3:  # 至少3秒持续上升
                accel_segments.append((rising_start, time_sec))
            rising_start = None
            rising_count = 0
    
    print(f"\nAcceleration segments (rising loudness, >=3s):")
    for start, end in accel_segments[:5]:
        print(f"  {start:.0f}s - {end:.0f}s ({end-start:.0f}s)")
    
    return {
        'high_rpm': high_rpm_segments,
        'idle': idle_segments,
        'acceleration': accel_segments
    }

def extract_segments(audio, output_dir="audio/processed"):
    """提取音频片段"""
    os.makedirs(output_dir, exist_ok=True)
    
    duration_ms = len(audio)
    duration_sec = duration_ms / 1000
    
    print(f"\n=== Extracting Audio Segments ===")
    print(f"Total duration: {duration_sec:.1f} seconds")
    
    # 根据分析结果定义提取点
    # 基于实际音频分析：
    # - 0-5s: 启动段（较低响度）
    # - 9-17s: 怠速段（稳定低响度）
    # - 33-37s, 47-50s: 高转速段
    # - 151-155s: 加速段
    extractions = [
        # (name, start_sec, end_sec, fade_in_ms, fade_out_ms, description)
        ("engine_start", 0, 2.5, 0, 100, "启动音效 - 开机双闪使用"),
        ("engine_idle", 10, 16, 150, 150, "怠速循环 - 待机状态"),
        ("engine_accel", 151, 155, 50, 100, "加速音效 - 油门加速"),
        ("engine_high", 33, 37, 100, 100, "高转速循环 - 油门最大"),
        ("engine_rev", 47, 50, 50, 100, "轰油门 - 短促高转"),
    ]
    
    extracted_files = []
    
    for name, start_sec, end_sec, fade_in, fade_out, desc in extractions:
        if end_sec * 1000 > duration_ms:
            print(f"Adjusting {name}: {end_sec}s > duration, using {duration_sec:.0f}s")
            end_sec = min(end_sec, duration_sec - 1)
            if start_sec >= end_sec:
                print(f"Skipping {name}: invalid range")
                continue
        
        start_ms = int(start_sec * 1000)
        end_ms = int(end_sec * 1000)
        
        segment = audio[start_ms:end_ms]
        
        # 添加淡入淡出
        if fade_in > 0:
            segment = segment.fade_in(fade_in)
        if fade_out > 0:
            segment = segment.fade_out(fade_out)
        
        output_path = os.path.join(output_dir, f"{name}.mp3")
        segment.export(output_path, format="mp3", bitrate="192k")
        
        file_size = os.path.getsize(output_path) / 1024
        print(f"✓ {name}.mp3 ({end_sec-start_sec:.1f}s, {file_size:.1f}KB) - {desc}")
        extracted_files.append(output_path)
    
    return extracted_files

def main():
    audio_file = "audio/engine_loop.mp3"
    
    if not os.path.exists(audio_file):
        print(f"Error: Audio file not found: {audio_file}")
        return
    
    # 1. 分析音频基本信息
    audio = analyze_audio(audio_file)
    
    # 2. 分析响度曲线
    loudness_data = analyze_loudness_curve(audio, segment_duration_ms=1000)
    
    # 3. 打印响度摘要
    print_loudness_summary(loudness_data)
    
    # 4. 找出最佳片段
    segments = find_best_segments(audio, loudness_data)
    
    # 5. 打印建议
    print("\n" + "="*60)
    print("ANALYSIS COMPLETE")
    print("="*60)
    print("""
To extract audio segments, run:
  py analyze_engine_audio.py --extract

The extracted files will be saved to: audio/processed/
  - engine_start.mp3  (启动音效)
  - engine_idle.mp3   (怠速循环)
  - engine_accel.mp3  (加速音效)
  - engine_high.mp3   (高转速循环)
""")

if __name__ == "__main__":
    if "--extract" in sys.argv:
        audio = AudioSegment.from_mp3("audio/engine_loop.mp3")
        extract_segments(audio)
        print("\n✓ Extraction complete!")
        print("Files saved to: audio/processed/")
    else:
        main()
