from PIL import Image
import struct
import zlib

# 创建10x10的测试图片：红色数字'1'
img = Image.new('RGB', (10, 10), color=(0, 0, 0))  # 黑色背景
pixels = img.load()

# 画一个简单的'1'
for y in range(2, 8):
    pixels[5, y] = (255, 0, 0)  # 红色竖线
pixels[4, 3] = (255, 0, 0)  # 左上角

img.save('RideWind/assets/bmp/test_10x10.bmp')
print('✓ 创建了10x10测试图片')

# 转换为RGB565并计算CRC32
width, height = 10, 10
rgb565_data = bytearray()

for y in range(height):
    for x in range(width):
        r, g, b = img.getpixel((x, y))
        r5 = (r >> 3) & 0x1F
        g6 = (g >> 2) & 0x3F
        b5 = (b >> 3) & 0x1F
        rgb565 = (r5 << 11) | (g6 << 5) | b5
        rgb565_data.append((rgb565 >> 8) & 0xFF)
        rgb565_data.append(rgb565 & 0xFF)

# 计算CRC32
crc32 = zlib.crc32(rgb565_data) & 0xFFFFFFFF

print(f'数据大小: {len(rgb565_data)} bytes')
print(f'包数: {(len(rgb565_data) + 15) // 16}')
print(f'CRC32: 0x{crc32:08X} ({crc32})')
print(f'前16字节: {" ".join(f"{b:02x}" for b in rgb565_data[:16])}')
