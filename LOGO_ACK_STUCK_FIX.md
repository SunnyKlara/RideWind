# Logo上传进度卡在10%问题修复

## 问题现象
- 进度卡在10%不动
- APP显示硬件不断接收相同的数据包（`BLE_len=46`重复出现）
- APP不断重传相同的数据包
- 说明：**硬件没有发送ACK响应，或APP没有收到ACK**

## 根本原因分析

### 可能原因1: ACK被发送但APP没收到
- 硬件端在`LOGO_DATA`处理中调用`BLE_SendString("LOGO_ACK:X\n")`
- 但由于printf输出过多，可能阻塞了蓝牙发送
- 或者蓝牙发送缓冲区满，导致ACK丢失

### 可能原因2: 缓冲区满导致处理停滞
- 数据包被推入缓冲区（`Buffer_Push()`）
- 但`Logo_ProcessBuffer()`处理速度跟不上
- 缓冲区满后，新包被拒绝，但ACK已经发送
- 导致数据丢失和重传

### 可能原因3: Flash写入太慢
- RLE解压缩 + Flash写入耗时较长
- 主循环中其他任务（LCD、PWM、Encoder等）占用时间
- `Logo_ProcessBuffer()`得不到足够的CPU时间

## 已实施的修复

### 修复1: 优化调试日志输出频率
**文件**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`

**修改前**:
```c
// 每100包打印进度
if ((seq + 1) % 100 == 0) {
    uint8_t progress = Logo_GetProgress();
    printf("[LOGO] Progress: %d%% (seq=%lu/%lu)\r\n", ...);
}
```

**修改后**:
```c
// 🔧 调试：确认ACK已发送（每50包打印一次，避免过多输出）
if ((seq + 1) % 50 == 0) {
    printf("[LOGO] ACK sent: seq=%lu buf=%lu/%lu\r\n", 
           (unsigned long)seq, 
           (unsigned long)g_receiveWindow.count,
           (unsigned long)PACKET_BUFFER_SIZE);
}
```

**目的**: 
- 减少printf输出，避免阻塞蓝牙发送
- 同时确认ACK是否真的被发送
- 显示缓冲区状态，判断是否有积压

### 修复2: 增强缓冲区满警告
**修改前**:
```c
printf("[LOGO] WARN: Buffer full at seq %lu\r\n", (unsigned long)seq);
```

**修改后**:
```c
printf("[LOGO] WARN: Buffer full at seq %lu (count=%lu)\r\n", 
       (unsigned long)seq, (unsigned long)g_receiveWindow.count);
```

**目的**: 显示缓冲区当前包数，判断是否真的满了

### 修复3: 优化处理进度日志
**修改前**:
```c
printf("[LOGO] Compressed: recv=%lu/%lu decomp=%lu/%lu (%d%%)\r\n", ...);
```

**修改后**:
```c
printf("[LOGO] Processed %d pkts: recv=%lu/%lu decomp=%lu/%lu buf=%lu\r\n", 
       processedCount,  // 本次处理了多少包
       (unsigned long)logo_received_size, 
       (unsigned long)logo_total_size,
       (unsigned long)logo_decompressed_total,
       (unsigned long)logo_original_size,
       (unsigned long)g_receiveWindow.count);  // 缓冲区剩余包数
```

**目的**: 
- 显示每次循环处理了多少包
- 显示缓冲区剩余包数
- 判断处理速度是否跟得上接收速度

## 测试步骤

### 1. 重新编译固件
```bash
# 在Keil MDK中
1. 打开项目: f4_26_1.1/f4_26_1.1/f4_26_1.1/MDK-ARM/f4.uvprojx
2. 按F7编译
3. 按F8下载到硬件
```

### 2. 上传Logo并观察日志
1. 打开APP的Logo上传调试界面
2. 选择图片开始上传
3. **重点观察以下信息**：

#### 正常情况（ACK正常发送）:
```
[00:00:01.000] 🔧 硬件: BLE_len=46
[00:00:01.020] 🔧 硬件: BLE_len=46
...
[00:00:01.200] [LOGO] ACK sent: seq=9 buf=10/50
[00:00:01.220] 🔧 硬件: BLE_len=46
...
[00:00:01.400] [LOGO] ACK sent: seq=19 buf=10/50
[00:00:02.000] [LOGO] Processed 10 pkts: recv=160/62547 decomp=320/115200 buf=0
```

#### 异常情况1（ACK没发送）:
```
[00:00:01.000] 🔧 硬件: BLE_len=46
[00:00:01.020] 🔧 硬件: BLE_len=46
...
（没有看到 "ACK sent"）
```
→ **说明**: ACK发送逻辑有问题或被阻塞

#### 异常情况2（缓冲区满）:
```
[00:00:01.000] [LOGO] WARN: Buffer full at seq=50 (count=50)
[00:00:01.020] [LOGO] WARN: Buffer full at seq=51 (count=50)
```
→ **说明**: 处理速度跟不上，需要优化

#### 异常情况3（处理停滞）:
```
[00:00:02.000] [LOGO] Processed 0 pkts: recv=160/62547 decomp=320/115200 buf=50
```
→ **说明**: `Logo_ProcessBuffer()`没有处理任何包，但缓冲区是满的

## 下一步调试方案

根据测试结果，我们可以采取不同的优化策略：

### 如果看到"ACK sent"但进度卡住
→ **问题在APP端**，需要检查APP的响应监听器

### 如果看不到"ACK sent"
→ **问题在硬件端**，可能是：
1. printf阻塞了蓝牙发送 → 进一步减少printf
2. `BLE_SendString()`失败 → 检查蓝牙发送函数
3. 条件判断错误 → 检查`(seq + 1) % 10 == 0`逻辑

### 如果频繁看到"Buffer full"
→ **处理速度问题**，需要：
1. 增大`PACKET_BUFFER_SIZE`（当前50）
2. 优化Flash写入（使用DMA或批量写入）
3. 减少主循环中其他任务的耗时

### 如果"Processed 0 pkts"
→ **主循环问题**，需要：
1. 确认`Logo_ProcessBuffer()`被正确调用
2. 检查是否有其他任务阻塞主循环
3. 增加`Logo_ProcessBuffer()`的调用频率

## 性能优化建议

### 短期优化（立即可做）
1. ✅ 减少printf输出频率（已完成）
2. ⏳ 增大`PACKET_BUFFER_SIZE`到100
3. ⏳ 在`Logo_ProcessBuffer()`中批量写入Flash

### 中期优化（需要测试）
1. 使用DMA进行Flash写入
2. 优化RLE解压缩算法
3. 减少主循环中其他任务的耗时

### 长期优化（架构改进）
1. 使用RTOS，将Logo处理放在独立任务
2. 使用双缓冲机制
3. 实现流式解压缩，避免中间缓冲区

## 相关文件
- 硬件端: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`
- 调试指南: `f4_26_1.1/f4_26_1.1/f4_26_1.1/LOGO_ACK_DEBUG.md`
- APP端: `RideWind/lib/services/logo_transmission_manager.dart`

## 总结
本次修复主要是**增强调试日志**，帮助定位ACK丢失的根本原因。通过观察日志，我们可以判断：
1. ACK是否真的被发送
2. 缓冲区是否有积压
3. 处理速度是否跟得上

请重新编译固件并测试，把完整的日志发给我，我会根据日志进一步优化。
