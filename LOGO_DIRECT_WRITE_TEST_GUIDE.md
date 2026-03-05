# Logo直接写入方案 - 测试指南

## 修改内容

### 核心改动
**彻底简化**：不再使用缓冲区，每收到一包数据就立即写入Flash。

### 修改的文件
- `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`

### 修改的函数
1. **LOGO_DATA处理**：
   - 删除：`Buffer_Push()`
   - 新增：`W25Q128_BufferWrite()` - 直接写入Flash

2. **LOGO_END处理**：
   - 删除：等待缓冲区清空的代码
   - 简化：直接开始校验

## 测试步骤

### 1. 编译固件
```bash
# 在Keil MDK中
1. Clean Project
2. Rebuild All
3. 确认编译成功，0 Error, 0 Warning
```

### 2. 烧录固件
```bash
# 使用ST-Link或J-Link
1. 连接硬件
2. Download到Flash
3. 确认烧录成功
4. 重启硬件
```

### 3. 连接串口
```bash
# 使用串口调试工具
波特率: 115200
数据位: 8
停止位: 1
校验位: None
```

### 4. 运行APP测试
```bash
cd RideWind
flutter run
```

### 5. 执行Logo上传
1. 在APP中进入"Logo Upload E2E Test"界面
2. 点击"Start E2E Test"按钮
3. **同时观察串口输出**

## 预期日志输出

### 发送阶段
```
[LOGO] ParseCommand: LOGO_START:115200:1949739014
[LOGO] START CMD RCV
[LOGO] Size:115200 CRC:1949739014
[LOGO] ERASING...
[LOGO] ERASE DONE
[LOGO] READY RCV 7200 PKT
```

### 接收阶段（关键！）
```
[LOGO] Packet 0: 16 bytes written to 0x00100010
[LOGO] ACK sent: seq=99
[LOGO] Packet 100: 16 bytes written to 0x00100650
[LOGO] ACK sent: seq=199
[LOGO] Packet 200: 16 bytes written to 0x00100C90
[LOGO] ACK sent: seq=299
...
[LOGO] Packet 7100: 16 bytes written to 0x0011BCD0
[LOGO] ACK sent: seq=7199
```

**关键点**：
- 每100包应该看到"written to"日志
- 每100包应该看到"ACK sent"日志
- 地址应该递增（每包+16字节）

### 结束阶段
```
[LOGO] ParseCommand: LOGO_END
[LOGO] END CMD RCV
[LOGO] VERIFYING...
[LOGO] ═══════════════════════════════════
[LOGO] END received, starting verification
[LOGO] Received size: 115200/115200
[LOGO] ═══════════════════════════════════
[LOGO] Size check: received=115200, expected=115200
[LOGO] ✓ Size check passed
[LOGO] Starting CRC32 calculation...
[LOGO]   Address: 0x00100010
[LOGO]   Size: 115200 bytes
[LOGO] CRC32 verification:
[LOGO]   Expected:   0x7436A806 (1949739014)
[LOGO]   Calculated: 0x7436A806 (1949739014)
[LOGO] ✓ CRC32 check passed
[LOGO] Writing header to Flash...
[LOGO] ═══════════════════════════════════
[LOGO] ✅ Upload complete!
[LOGO]   Mode: UNCOMPRESSED
[LOGO]   Size: 115200 bytes
[LOGO]   CRC32: 0x7436A806
[LOGO] ═══════════════════════════════════
```

### LOGO_TEST命令
```
[LOGO] TEST command executed
  Valid: 1
  Magic: 0xAA55 (expect 0xAA55)
  Size: 240x240
  DataSize: 115200 (expect 115200)
  CRC32: 0x7436A806
```

## 故障排查

### 问题1：没有"written to"日志
**原因**：代码未执行或编译失败
**解决**：
1. 确认重新编译了
2. 确认烧录成功了
3. 检查logo.c是否在项目中

### 问题2：地址不递增
**原因**：seq解析错误
**解决**：
1. 检查APP发送的数据格式
2. 检查十六进制解码

### 问题3：CRC32不匹配
**原因**：数据损坏或写入错误
**解决**：
1. 读取Flash前16字节，对比APP发送的数据
2. 检查W25Q128驱动

### 问题4：Flash写入失败
**原因**：W25Q128驱动问题
**解决**：
1. 检查SPI通信
2. 检查Flash芯片是否正常
3. 尝试擦除整个Flash

## 性能预期

### 写入速度
- **理论速度**：与蓝牙接收速度相同（~200 bytes/s）
- **实际速度**：应该看到每秒处理~12包（200/16）
- **总时间**：~10分钟（7200包）

### 如果太慢
- 检查W25Q128写入速度
- 检查SPI时钟频率
- 考虑优化Flash驱动

## 验证方法

### 方法1：读取Flash前16字节
在LOGO_END后添加：
```c
uint8_t test_buffer[16];
W25Q128_BufferRead(test_buffer, LOGO_FLASH_ADDR + LOGO_HEADER_SIZE, 16);

printf("[LOGO] Flash first 16 bytes:\r\n");
for (int i = 0; i < 16; i++) {
    printf("%02X ", test_buffer[i]);
}
printf("\r\n");
```

### 方法2：对比APP数据
在APP中打印前16字节：
```dart
print('First 16 bytes: ${rgb565Data.sublist(0, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
```

对比两者是否一致。

### 方法3：使用J-Link读取
```bash
# 使用J-Link Commander
J-Link> mem8 0x00100010, 16
```

## 下一步

如果这个方案成功：
1. ✅ 确认直接写入方案可行
2. 🔧 可以考虑优化（批量写入）
3. 📊 测量性能数据

如果这个方案失败：
1. ❌ 问题不在缓冲区
2. 🔍 需要检查Flash驱动
3. 🐛 可能是硬件问题

## 关键诊断点

### 必须看到的日志
1. `[LOGO] Packet X: 16 bytes written to 0xXXXXXXXX` - 证明数据在写入
2. `[LOGO] ACK sent: seq=X` - 证明ACK在发送
3. `[LOGO] ✓ CRC32 check passed` - 证明数据完整

### 如果看不到这些日志
说明代码未执行，需要：
1. 重新编译
2. 重新烧录
3. 检查代码是否正确

## 最简单的验证

发送一个小测试：
```dart
// 只发送前10包
for (int i = 0; i < 10; i++) {
  await _sendDataPacket(i, ...);
}
```

观察串口输出，应该看到10次"written to"。
