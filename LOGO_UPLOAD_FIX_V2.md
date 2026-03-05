# Logo上传丢包问题修复 v2

## 问题根源

经过深入分析，丢包的根本原因是：

1. **UART缓冲区溢出**
   - `RX_BUFFER_SIZE = 1024` 字节
   - 每个LOGO_DATA命令约47字节（`LOGO_DATA:seq:hexdata\n`）
   - 缓冲区只能容纳约21个命令
   - APP每5ms发一包，21包只需105ms就填满缓冲区

2. **Flash写入阻塞UART接收**
   - 原代码在`Logo_ParseCommand`中直接调用`W25Q128_BufferWrite`
   - Flash写入需要1-5ms，期间UART接收被阻塞
   - 新数据到达时缓冲区溢出

3. **流控机制不完善**
   - 原来每50包发ACK，但APP不等待ACK就继续发送
   - 丢包检测依赖序号连续性，但包在UART层就丢了

## 解决方案

### 严格流控机制

**核心思想**：APP每发10包必须等待硬件ACK，硬件批量写入Flash后才发ACK。

### 硬件端修改 (logo.c)

1. **批量写入Flash**
   - 每收到10包先存入内存缓冲区
   - 10包收齐后批量写入Flash（160字节）
   - 写入完成后才发送ACK

2. **严格的ACK机制**
   - 每10包发一次ACK
   - APP必须等待ACK后才能发下一批

### APP端修改 (logo_upload_e2e_test_screen.dart)

1. **严格流控**
   - 每发10包后等待ACK
   - 收到ACK后才发下一批
   - 超时或丢包时重传

2. **参数调整**
   - `batchSize = 16`（每批16包，256字节=1个Flash页）
   - `packetDelayMs = 3`（包间延迟3ms）
   - `maxRetries = 5`（最大重试5次）

### 缓冲区增大 (rx.h)

- `RX_BUFFER_SIZE` 从 1024 增加到 2048

## 修改的文件

1. `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/rx.h`
   - 增大UART接收缓冲区

2. `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`
   - 实现批量写入Flash
   - 严格的ACK机制

3. `RideWind/lib/screens/logo_upload_e2e_test_screen.dart`
   - 实现严格流控
   - 每10包等待ACK

## 测试步骤

1. **重新编译固件**
   ```
   在Keil中编译f4_26_1.1项目
   ```

2. **烧录固件**
   ```
   使用ST-Link烧录到STM32
   ```

3. **运行APP测试**
   - 打开RideWind APP
   - 进入Logo上传E2E测试界面
   - 点击"开始测试"
   - 观察日志，应该看到：
     - 每10包一个ACK
     - 无丢包重传
     - 最终显示"SUCCESS!"

## 预期效果

- **传输速度**：约 16包 × 16字节 / (16×3ms + Flash写入时间) ≈ 4-5 KB/s
- **可靠性**：100%成功率（严格流控保证）
- **总时间**：47432字节 / 4KB/s ≈ 12秒

## 后续优化方向

如果需要更快的传输速度，可以考虑：

1. **增大批次大小**：从10包增加到20包（需要更大的缓冲区）
2. **使用DMA接收**：减少UART中断开销
3. **压缩传输**：对于非纯色图片，RLE压缩可减少数据量
