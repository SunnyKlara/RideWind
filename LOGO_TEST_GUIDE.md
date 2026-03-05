# Logo上传测试指南

## 当前状态

你已经完成了一次上传测试（7200包），硬件自动切换到了Logo调试界面（ui=6）。现在需要检查上传是否真正成功。

## 问题分析

上传图片后LCD不显示的可能原因：

1. **CRC32校验失败** - 硬件拒绝写入header，`Logo_IsValid()`返回false
2. **Header未写入** - 数据写入了但header没写，Flash中magic!=0xAA55
3. **数据大小不匹配** - dataSize字段不等于115200
4. **Flash读取失败** - 数据写入了但读取时出错

## 测试步骤

### 步骤1: 重新编译硬件（添加LOGO_TEST命令）

硬件代码已经添加了`LOGO_TEST`命令（在`logo.c`第826行），需要重新编译烧录：

```c
// LOGO_TEST命令会返回：
// - Valid: 0或1（Logo是否有效）
// - Magic: 0xAA55（期望值）
// - Width: 240
// - Height: 240
// - DataSize: 115200
// - CRC32: 实际存储的CRC32值
// - State: 当前状态
// - RecvSize: 已接收大小
// - ExpCRC: 期望的CRC32值
```

**操作**：
1. 打开Keil MDK
2. 编译项目
3. 烧录到硬件
4. 重启硬件

### 步骤2: 使用E2E测试界面查询Flash状态

APP已经更新，添加了"查询Flash状态"按钮：

**操作**：
1. 打开APP的"LOGO上传端到端测试"界面
2. 点击"查询Flash状态"按钮
3. 查看日志输出

**期望结果**：
```
LOGO_TEST_RESULT:
Valid:1
Magic:0xAA55
Width:240
Height:240
DataSize:115200
CRC32:0xE202FF73
State:4
RecvSize:115200
ExpCRC:0xE202FF73
```

### 步骤3: 根据结果诊断问题

#### 情况A: Valid=1（成功）
- **说明**：Header已写入，数据完整
- **下一步**：进入Logo界面（ui=6），应该能看到红色数字"1"
- **如果还是看不到**：检查`Logo_ShowOnLCD()`函数是否被正确调用

#### 情况B: Valid=0, CRC32不匹配
```
Valid:0
CRC32:0x12345678  (与ExpCRC不同)
ExpCRC:0xE202FF73
```
- **说明**：数据传输有误，CRC32校验失败
- **原因**：可能是蓝牙传输丢包或数据损坏
- **解决**：重新上传，检查蓝牙连接稳定性

#### 情况C: Valid=0, Magic=0xFFFF
```
Valid:0
Magic:0xFFFF  (Flash擦除后的默认值)
```
- **说明**：Header未写入，可能是CRC校验失败或LOGO_END命令未执行
- **原因**：
  1. APP未发送LOGO_END命令
  2. 硬件未收到LOGO_END命令
  3. CRC32校验失败，硬件拒绝写入header
- **解决**：检查日志，确认LOGO_END是否发送和接收

#### 情况D: Valid=0, DataSize!=115200
```
Valid:0
DataSize:0 或其他值
```
- **说明**：数据大小不匹配
- **原因**：传输未完成或数据损坏
- **解决**：重新上传

### 步骤4: 重新测试（使用新的测试图片）

APP已更新，现在创建的是**240x240的红色大数字"1"**（之前是10x10然后resize）：

**特点**：
- 图案清晰可见（100像素高的数字"1"）
- 黑色背景，红色数字
- 居中显示
- 115200字节，7200包

**操作**：
1. 点击"开始测试"按钮
2. 等待上传完成（约60秒）
3. 点击"查询Flash状态"按钮
4. 如果Valid=1，进入Logo界面查看

## 调试技巧

### 查看硬件串口输出

硬件会输出详细的调试信息：

```
[LOGO] START size=115200 crc=3791847283
[LOGO] Ready to receive 7200 packets
[LOGO] Packet 0: 16 bytes decoded
[LOGO] Packet 200: 16 bytes decoded
...
[LOGO] ═══════════════════════════════════
[LOGO] END received, starting verification
[LOGO] ═══════════════════════════════════
[LOGO] Size check: received=115200, expected=115200
[LOGO] ✓ Size check passed
[LOGO] Starting CRC32 calculation...
[LOGO]   Expected:   0xE202FF73 (3791847283)
[LOGO]   Calculated: 0xE202FF73 (3791847283)
[LOGO] ✓ CRC32 check passed
[LOGO] Writing header to Flash...
[LOGO] ═══════════════════════════════════
[LOGO] ✅ Upload complete!
[LOGO] ═══════════════════════════════════
```

### 查看LCD调试界面

硬件会在LCD上显示调试信息（ui=6）：

```
LOGO DEBUG
====================
START CMD RCV
Size:115200 CRC:3791847283
ERASING...
ERASE DONE
READY RCV 7200 PKT
RCV:0/7200
RCV:100/7200
...
END CMD RCV
VERIFYING...
SIZE CHECK OK
CRC32 OK
WRITE HEADER...
UPLOAD OK!
```

## 常见问题

### Q1: 上传完成但LCD不显示图片

**检查清单**：
1. ✓ 发送LOGO_TEST命令，确认Valid=1
2. ✓ 确认当前界面是Logo界面（ui=6）
3. ✓ 检查`Logo_ShowOnLCD()`是否被调用
4. ✓ 检查Flash读取是否正常

### Q2: CRC32一直不匹配

**可能原因**：
1. 蓝牙传输不稳定，丢包
2. 十六进制解码错误
3. Flash写入错误
4. CRC32计算算法不一致

**解决方法**：
1. 减少传输速度（增加延迟）
2. 检查十六进制编码/解码
3. 验证Flash读写功能
4. 确认APP和硬件使用相同的CRC32算法

### Q3: 硬件一直返回LOGO_BUSY

**原因**：缓冲区满（200包），主循环处理不过来

**解决方法**：
1. 增加`Logo_ProcessBuffer()`调用频率
2. 增加缓冲区大小（PACKET_BUFFER_SIZE）
3. 优化Flash写入速度（批量写入）

## 下一步

1. **重新编译硬件** - 添加LOGO_TEST命令
2. **重新上传APP** - 使用新的测试图片
3. **执行测试** - 点击"开始测试"
4. **查询状态** - 点击"查询Flash状态"
5. **查看结果** - 根据Valid值判断成功与否

如果Valid=1但LCD还是不显示，说明问题在显示逻辑，需要进一步调试`Logo_ShowOnLCD()`函数。
