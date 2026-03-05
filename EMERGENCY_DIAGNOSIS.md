# 紧急诊断 - Logo上传失败

## 当前状态
- LCD显示"Logo Debug Mode"界面 ✅
- 但没有看到调试日志 ❌
- 显示默认logo ❌

## 可能的原因

### 1. 代码未编译进去
**检查方法**：
- 打开Keil MDK
- 检查`logo.c`文件是否在项目中
- 重新编译（Clean + Rebuild）
- 确认编译成功，没有错误

### 2. 固件未烧录
**检查方法**：
- 确认烧录成功
- 重启硬件
- 检查版本号（如果有）

### 3. LOGO_END命令未收到
**检查方法**：
查看APP日志，确认发送了LOGO_END

### 4. 缓冲区处理卡死
**检查方法**：
查看串口日志，看是否卡在某个地方

## 立即诊断步骤

### 步骤1：检查串口输出
连接串口调试工具，查看是否有以下日志：

```
[BLE] Logo START command (len=XX)
[LOGO] ParseCommand: LOGO_START:115200:1949739014
[LOGO] START CMD RCV
[LOGO] Size:115200 CRC:1949739014
[LOGO] ERASING...
[LOGO] ERASE DONE
[LOGO] READY RCV 7200 PKT
```

**如果没有这些日志**：
- 说明代码未执行
- 检查编译和烧录

**如果有这些日志**：
- 继续查看后续日志
- 找到卡住的地方

### 步骤2：手动发送测试命令
在APP中手动发送以下命令，观察响应：

1. **测试基本通信**：
   ```
   发送: GET:UI
   预期响应: UI:6
   ```

2. **测试Logo状态**：
   ```
   发送: LOGO_STATUS
   预期响应: LOGO_STATE:X:X
   ```

3. **测试Flash内容**：
   ```
   发送: LOGO_TEST
   预期响应: LOGO_TEST_RESULT:...
   ```

### 步骤3：检查Flash内容
如果有J-Link或ST-Link，可以直接读取Flash：

```
地址: 0x00100000
大小: 16 bytes (header)

预期内容:
55 AA  // magic (0xAA55)
F0 00  // width (240)
F0 00  // height (240)
00 00  // reserved
00 C2 01 00  // dataSize (115200)
XX XX XX XX  // CRC32
```

**如果全是FF**：
- Flash未写入
- 数据丢失

**如果有数据但magic不对**：
- 数据损坏
- 写入错误

## 快速修复方案

### 方案A：简化测试（推荐）
先测试一个小图片（10x10），看是否能成功：

1. 修改APP代码，发送10x10的测试图片
2. 总数据量：10x10x2 = 200字节
3. 总包数：200/16 = 13包
4. 应该很快完成

### 方案B：增加超详细日志
在logo.c的关键位置增加日志：

```c
// 在Logo_ProcessBuffer()开始处
printf("[LOGO_PROC] Start, state=%d, count=%lu\r\n", 
       logo_state, (unsigned long)g_receiveWindow.count);

// 在每次写入Flash后
printf("[LOGO_PROC] Flash write: addr=0x%08lX, size=%lu\r\n",
       (unsigned long)writeAddr, (unsigned long)writeSize);

// 在LOGO_END开始处
printf("[LOGO_END] Received, state=%d, recv=%lu/%lu\r\n",
       logo_state, 
       (unsigned long)logo_received_size,
       (unsigned long)logo_total_size);
```

### 方案C：禁用缓冲区（最简单）
直接在接收时写入Flash，不使用缓冲区：

```c
// 在LOGO_DATA处理中
else if (strncmp(cmd, "LOGO_DATA:", 10) == 0)
{
    // ... 解析数据 ...
    
    // 🔥 直接写入Flash，不使用缓冲区
    uint32_t writeAddr = LOGO_FLASH_ADDR + LOGO_HEADER_SIZE + seq * 16;
    W25Q128_BufferWrite(logo_temp_buffer, writeAddr, decodedLen);
    
    logo_received_size += decodedLen;
    
    // 每100包发送ACK
    if ((seq + 1) % 100 == 0) {
        sprintf(response, "LOGO_ACK:%lu\n", (unsigned long)seq);
        BLE_SendString(response);
    }
}
```

## 我需要的信息

请提供以下信息，我才能进一步诊断：

1. **串口日志**：从发送LOGO_START到LOGO_END的完整日志
2. **APP日志**：发送LOGO_END后收到的响应
3. **编译信息**：Keil编译是否成功？有警告吗？
4. **烧录确认**：确认烧录成功了吗？

## 临时解决方案

如果急需测试，可以先用这个最简单的方案：

### 修改APP：发送LOGO_END前等待5秒
```dart
// 在logo_upload_e2e_test_screen.dart中
await Future.delayed(Duration(seconds: 5));  // 等待5秒
await _sendCommand('LOGO_END');
```

这样给硬件足够时间处理缓冲区。

如果这样还不行，说明问题不在缓冲区，而是：
- Flash写入失败
- 数据损坏
- 其他硬件问题
