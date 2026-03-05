# Logo上传缓冲区问题诊断

## 问题现象
- APP发送完所有数据包（7200包，115200字节）
- 发送LOGO_END后，硬件显示默认logo
- LOGO_TEST命令显示Flash中没有有效数据

## 根本原因

### 数据流程分析
```
APP发送数据 → rx.c接收 → Buffer_Push(缓冲区) → Logo_ProcessBuffer() → Flash写入
                ↓                                      ↓
            立即返回ACK                          在主循环中异步处理
```

### 问题所在
1. **缓冲区积压**：7200包数据需要时间处理，缓冲区可能还有大量未写入Flash的数据
2. **LOGO_END过早校验**：APP发送完最后一包后立即发送LOGO_END，但此时：
   - 缓冲区还有数据未处理
   - Flash写入未完成
   - CRC32校验读取的是不完整的数据
3. **校验失败**：因为数据不完整，CRC32不匹配，header未写入，logo无效

### 时序问题
```
时间轴：
T0: APP发送包#7199（最后一包）
T1: rx.c接收，放入缓冲区，返回ACK
T2: APP收到ACK，立即发送LOGO_END
T3: LOGO_END命令开始校验 ← 问题：此时缓冲区还有数据！
T4: Logo_ProcessBuffer()继续处理缓冲区...（但已经晚了）
```

## 解决方案

### 方案1：LOGO_END等待缓冲区清空（推荐）
修改`Logo_ParseCommand`中的`LOGO_END`处理：
```c
else if (strcmp(cmd, "LOGO_END") == 0)
{
    Logo_AddDebugLog("END CMD RCV");
    
    if (logo_state != LOGO_STATE_RECEIVING) {
        printf("[LOGO] ERROR: Not in receiving state for END\r\n");
        BLE_SendString("LOGO_ERROR:NOT_RECEIVING\n");
        return;
    }
    
    // 🔥 新增：等待缓冲区清空
    Logo_AddDebugLog("WAIT BUFFER...");
    printf("[LOGO] Waiting for buffer to flush...\r\n");
    
    uint32_t wait_start = uwTick;
    uint32_t last_count = g_receiveWindow.count;
    uint32_t no_progress_time = 0;
    
    while (!Buffer_IsEmpty()) {
        Logo_ProcessBuffer();  // 主动处理缓冲区
        
        // 检测进度
        if (g_receiveWindow.count != last_count) {
            last_count = g_receiveWindow.count;
            no_progress_time = uwTick;
        }
        
        // 超时检测（5秒无进度）
        if (uwTick - no_progress_time > 5000) {
            Logo_AddDebugLog("BUFFER TIMEOUT!");
            printf("[LOGO] ERROR: Buffer flush timeout!\r\n");
            BLE_SendString("LOGO_ERROR:BUFFER_TIMEOUT\n");
            logo_state = LOGO_STATE_ERROR;
            return;
        }
        
        // 总超时（30秒）
        if (uwTick - wait_start > 30000) {
            Logo_AddDebugLog("TOTAL TIMEOUT!");
            printf("[LOGO] ERROR: Total timeout!\r\n");
            BLE_SendString("LOGO_ERROR:TIMEOUT\n");
            logo_state = LOGO_STATE_ERROR;
            return;
        }
        
        // 每秒打印一次进度
        if ((uwTick - wait_start) % 1000 == 0) {
            printf("[LOGO] Buffer: %lu packets remaining\r\n", 
                   (unsigned long)g_receiveWindow.count);
        }
        
        HAL_Delay(10);  // 短暂延时，避免CPU占用过高
    }
    
    // 🔥 新增：确保最后一批数据也写入Flash
    if (g_receiveWindow.flashWriteCount > 0) {
        Logo_AddDebugLog("FLUSH LAST BATCH");
        printf("[LOGO] Flushing last batch: %lu packets\r\n", 
               (unsigned long)g_receiveWindow.flashWriteCount);
        
        if (logo_is_compressed) {
            // 解压并写入最后一批
            uint32_t batch_size = g_receiveWindow.flashWriteCount * 16;
            uint32_t decompressed_len = Logo_DecompressRLE(
                g_receiveWindow.flashWriteBuffer, 
                batch_size,
                decompress_buffer, 
                DECOMPRESS_BUFFER_SIZE
            );
            
            if (decompressed_len > 0) {
                uint32_t writeAddr = LOGO_FLASH_ADDR + LOGO_HEADER_SIZE + logo_decompressed_total;
                W25Q128_BufferWrite(decompress_buffer, writeAddr, decompressed_len);
                logo_decompressed_total += decompressed_len;
            }
        } else {
            // 写入最后一批
            uint32_t writeAddr = LOGO_FLASH_ADDR + LOGO_HEADER_SIZE + 
                                g_receiveWindow.flashWriteBaseSeq * 16;
            uint32_t writeSize = g_receiveWindow.flashWriteCount * 16;
            W25Q128_BufferWrite(g_receiveWindow.flashWriteBuffer, writeAddr, writeSize);
        }
        
        g_receiveWindow.flashWriteCount = 0;
    }
    
    Logo_AddDebugLog("BUFFER EMPTY");
    printf("[LOGO] Buffer flushed, took %lu ms\r\n", (unsigned long)(uwTick - wait_start));
    
    // 继续原有的校验流程...
    Logo_AddDebugLog("VERIFYING...");
    // ... 后续代码不变 ...
}
```

### 方案2：APP端延迟发送LOGO_END（简单但不优雅）
在APP的`logo_upload_e2e_test_screen.dart`中：
```dart
// 发送完最后一包后，等待一段时间
await Future.delayed(Duration(seconds: 3));  // 等待3秒让硬件处理缓冲区
await _sendCommand('LOGO_END');
```

### 方案3：增加LOGO_FLUSH命令（最优雅）
1. 新增命令：`LOGO_FLUSH` - 强制刷新缓冲区
2. APP发送流程：
   ```
   发送所有数据包 → LOGO_FLUSH → 等待ACK → LOGO_END
   ```

## 推荐实施步骤

1. **立即测试**：先用方案2快速验证（APP端加延迟）
2. **正式修复**：实施方案1（硬件端等待缓冲区清空）
3. **长期优化**：考虑方案3（增加FLUSH命令）

## 验证方法

修复后，在LOGO_END处理中添加详细日志：
```c
printf("[LOGO] Buffer status before verification:\r\n");
printf("  Buffer empty: %d\r\n", Buffer_IsEmpty());
printf("  Flash write count: %lu\r\n", (unsigned long)g_receiveWindow.flashWriteCount);
printf("  Received size: %lu/%lu\r\n", 
       (unsigned long)logo_received_size, 
       (unsigned long)logo_total_size);
if (logo_is_compressed) {
    printf("  Decompressed size: %lu/%lu\r\n",
           (unsigned long)logo_decompressed_total,
           (unsigned long)logo_original_size);
}
```
