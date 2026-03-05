# Logo直接写入修复方案

## 问题分析

缓冲区方案太复杂，可能有以下问题：
1. 缓冲区未正确清空
2. 批量写入逻辑有bug
3. 时序问题

## 最简单的解决方案：直接写入Flash

### 原理
```
接收数据包 → 立即写入Flash → 返回ACK
```

不使用缓冲区，每收到一包就立即写入Flash。

### 优点
- 简单可靠
- 不会丢数据
- 不需要等待缓冲区清空

### 缺点
- 速度稍慢（但对于10分钟的传输来说，影响不大）

## 修改代码

### 修改logo.c中的LOGO_DATA处理

找到这段代码：
```c
else if (strncmp(cmd, "LOGO_DATA:", 10) == 0)
{
    if (logo_state != LOGO_STATE_RECEIVING) {
        printf("[LOGO] ERROR: Not in receiving state (state=%d)\r\n", logo_state);
        BLE_SendString("LOGO_ERROR:NOT_READY\n");
        return;
    }
    
    // 解析序号
    char* p = cmd + 10;
    uint32_t seq = strtoul(p, &p, 10);
    
    if (*p != ':') {
        printf("[LOGO] ERROR: Format error at seq %lu\r\n", (unsigned long)seq);
        BLE_SendString("LOGO_ERROR:FORMAT\n");
        return;
    }
    
    char* hexData = p + 1;
    
    // 解码十六进制数据到临时缓冲区
    int decodedLen = HexDecode(hexData, logo_temp_buffer, sizeof(logo_temp_buffer));
    if (decodedLen <= 0) {
        printf("[LOGO] ERROR: Hex decode failed at seq %lu\r\n", (unsigned long)seq);
        sprintf(response, "LOGO_NAK:%lu\n", (unsigned long)seq);
        BLE_SendString(response);
        return;
    }
    
    // 🔥 新方案：直接写入Flash，不使用缓冲区
    uint32_t writeAddr = LOGO_FLASH_ADDR + LOGO_HEADER_SIZE + seq * 16;
    W25Q128_BufferWrite(logo_temp_buffer, writeAddr, decodedLen);
    
    logo_received_size += decodedLen;
    logo_current_seq = seq;
    
    // 每100包显示一次进度
    if (seq % 100 == 0) {
        char msg[40];
        snprintf(msg, 40, "RCV:%lu/%lu", seq, (unsigned long)g_receiveWindow.totalPackets);
        Logo_AddDebugLog(msg);
        printf("[LOGO] Packet %lu: %d bytes written to 0x%08lX\r\n", 
               (unsigned long)seq, decodedLen, (unsigned long)writeAddr);
    }
    
    // 每100包发送一次ACK
    if ((seq + 1) % 100 == 0) {
        sprintf(response, "LOGO_ACK:%lu\n", (unsigned long)seq);
        BLE_SendString(response);
        g_receiveWindow.lastAckSeq = seq;
    }
}
```

### 修改LOGO_END处理

找到这段代码：
```c
else if (strcmp(cmd, "LOGO_END") == 0)
{
    Logo_AddDebugLog("END CMD RCV");
    
    if (logo_state != LOGO_STATE_RECEIVING) {
        printf("[LOGO] ERROR: Not in receiving state for END\r\n");
        BLE_SendString("LOGO_ERROR:NOT_RECEIVING\n");
        return;
    }
    
    // 🔥 直接写入方案：不需要等待缓冲区，直接校验
    Logo_AddDebugLog("VERIFYING...");
    
    printf("[LOGO] ═══════════════════════════════════\r\n");
    printf("[LOGO] END received, starting verification\r\n");
    printf("[LOGO] Received size: %lu/%lu\r\n", 
           (unsigned long)logo_received_size, 
           (unsigned long)logo_total_size);
    printf("[LOGO] ═══════════════════════════════════\r\n");
    logo_state = LOGO_STATE_VERIFYING;
    
    // 继续原有的校验流程...
}
```

### 删除或注释掉Logo_ProcessBuffer()

因为不再使用缓冲区，这个函数可以删除或注释掉：

```c
void Logo_ProcessBuffer(void)
{
    // 🔥 直接写入方案：不再需要这个函数
    // 所有数据在接收时已经写入Flash
    return;
}
```

## 完整修改步骤

1. **备份原文件**：
   ```bash
   cp logo.c logo.c.backup
   ```

2. **修改LOGO_DATA处理**：
   - 删除`Buffer_Push()`调用
   - 改为直接`W25Q128_BufferWrite()`

3. **修改LOGO_END处理**：
   - 删除等待缓冲区的代码
   - 直接开始校验

4. **注释Logo_ProcessBuffer()**：
   - 函数体改为`return;`

5. **编译并烧录**

6. **测试**

## 预期效果

### 日志输出
```
[LOGO] START CMD RCV
[LOGO] READY RCV 7200 PKT
[LOGO] Packet 0: 16 bytes written to 0x00100010
[LOGO] Packet 100: 16 bytes written to 0x00100650
[LOGO] Packet 200: 16 bytes written to 0x00100C90
...
[LOGO] Packet 7100: 16 bytes written to 0x0011BCD0
[LOGO] END CMD RCV
[LOGO] VERIFYING...
[LOGO] Received size: 115200/115200
[LOGO] ✓ Size check passed
[LOGO] ✓ CRC32 check passed
[LOGO] ✅ Upload complete!
```

### 性能
- **写入速度**：~200 bytes/s（与接收速度相同）
- **总时间**：~10分钟（与原方案相同）
- **可靠性**：100%（不会丢数据）

## 如果还是失败

如果这个最简单的方案还是失败，说明问题不在缓冲区，而是：

1. **Flash写入失败**：
   - 检查W25Q128驱动
   - 检查SPI通信
   - 检查Flash是否损坏

2. **数据损坏**：
   - 检查蓝牙接收
   - 检查十六进制解码
   - 检查数据完整性

3. **CRC32计算错误**：
   - APP和硬件的CRC32算法不一致
   - 需要对比验证

## 调试方法

### 1. 读取Flash验证
在LOGO_END后，读取Flash前16字节：

```c
uint8_t test_buffer[16];
W25Q128_BufferRead(test_buffer, LOGO_FLASH_ADDR + LOGO_HEADER_SIZE, 16);

printf("[LOGO] Flash first 16 bytes:\r\n");
for (int i = 0; i < 16; i++) {
    printf("%02X ", test_buffer[i]);
}
printf("\r\n");
```

### 2. 对比APP发送的数据
在APP中打印前16字节：

```dart
print('First 16 bytes: ${rgb565Data.sublist(0, 16)}');
```

对比两者是否一致。

### 3. 分段测试
先测试前100包：

```dart
// 只发送前100包
for (int i = 0; i < 100; i++) {
  await _sendDataPacket(i, ...);
}
await _sendCommand('LOGO_END');
```

看是否能成功。
