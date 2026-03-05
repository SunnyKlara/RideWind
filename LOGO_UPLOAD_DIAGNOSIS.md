# Logo Upload 诊断指南

## 问题现象
- APP发送完所有7200包数据（~10分钟）
- 硬件LCD显示进度到100%
- 发送LOGO_END命令后，LCD跳转到Logo界面
- 显示默认Logo而不是上传的Logo
- 发送LOGO_TEST命令后，硬件没有响应

## 根本原因分析

### 当前实现方式
代码使用**直接写入Flash**方式：
```c
// LOGO_DATA处理器中
W25Q128_BufferWrite(logo_temp_buffer, writeAddr, decodedLen);
logo_received_size += decodedLen;
```

这意味着：
1. ✅ 每个包接收后立即写入Flash
2. ✅ `logo_received_size`累加
3. ❌ **但没有验证写入是否成功**
4. ❌ **LOGO_END时可能Flash中没有数据**

### 可能的失败点

#### 1. Flash写入失败（最可能）
- W25Q128_BufferWrite()可能失败但没有返回错误
- Flash可能处于忙状态
- 写入地址可能越界

#### 2. 数据被覆盖
- 其他代码可能在写入同一Flash区域
- Flash擦除可能不完整

#### 3. Header未写入
- LOGO_END中写入header，但如果CRC校验失败，header不会写入
- Logo_IsValid()检查header，如果header无效，显示默认Logo

## 调试步骤

### 第1步：检查Flash写入是否成功

在LOGO_DATA处理器中添加验证：

```c
// 写入Flash
W25Q128_BufferWrite(logo_temp_buffer, writeAddr, decodedLen);

// 🔥 立即读回验证
uint8_t verify_buffer[16];
W25Q128_BufferRead(verify_buffer, writeAddr, decodedLen);

// 比较数据
if (memcmp(logo_temp_buffer, verify_buffer, decodedLen) != 0) {
    // 写入失败！
    printf("[LOGO] ERROR: Flash write verification failed at seq %lu\r\n", seq);
    sprintf(response, "LOGO_ERROR:FLASH_WRITE_FAIL:%lu\n", seq);
    BLE_SendString(response);
    logo_state = LOGO_STATE_ERROR;
    return;
}
```

### 第2步：在LOGO_END中读取Flash数据

当前代码已添加LCD显示，会在CRC失败时显示前16字节：

```c
// 显示前16字节数据用于调试
uint8_t debug_data[16];
W25Q128_BufferRead(debug_data, LOGO_FLASH_ADDR + LOGO_HEADER_SIZE, 16);
LCD_ShowString(20, 170, "FIRST 16 BYTES:", CYAN, BLACK, 12, 0);
for (int i = 0; i < 16; i += 4) {
    snprintf(msg, 40, "%02X %02X %02X %02X", 
            debug_data[i], debug_data[i+1], debug_data[i+2], debug_data[i+3]);
    LCD_ShowString(20, 185 + i*4, msg, GREEN, BLACK, 12, 0);
}
```

**预期结果**：
- 如果显示 `F8 00 F8 00 F8 00 F8 00`，说明数据写入成功
- 如果显示 `FF FF FF FF FF FF FF FF`，说明Flash未写入（擦除后的状态）
- 如果显示 `00 00 00 00 00 00 00 00`，说明数据被清零

### 第3步：检查LOGO_TEST响应

发送LOGO_TEST命令后，应该在LCD上看到：
- Valid: 0 或 1
- Magic: 0xAA55 或其他值
- Width/Height: 240x240
- DataSize: 115200
- CRC32: 计算的CRC值

**如果没有响应**：
- 检查蓝牙连接是否正常
- 检查rx.c中是否正确调用Logo_ParseCommand()

### 第4步：检查UI切换逻辑

在xuanniu.c中，UI6是Logo调试界面：

```c
// 自动切换到Logo调试界面
ui = 6;
chu = 6;
```

**检查**：
- LOGO_START命令是否正确设置ui=6
- UI6界面是否正确渲染
- LCD_ShowString()是否正常工作

## 测试方案

### 方案A：最小化测试（推荐）

1. **只发送1包数据**：
   ```dart
   // 修改APP代码，只发送第一包
   await _sendDataPacket(0, imageData.sublist(0, 16));
   await Future.delayed(Duration(milliseconds: 100));
   await _sendCommand('LOGO_END');
   ```

2. **检查LCD显示**：
   - 应该显示 "SIZE ERROR" 因为只收到16字节
   - 应该显示 "16/115200"

3. **发送LOGO_TEST**：
   - 检查Flash中是否有这16字节数据

### 方案B：分段测试

1. **发送前100包**
2. **暂停，发送LOGO_TEST**
3. **检查Flash中是否有1600字节数据**
4. **继续发送剩余包**

### 方案C：完整测试（当前方式）

1. **发送所有7200包**
2. **观察LCD显示**：
   - 如果显示 "SUCCESS!"，说明上传成功
   - 如果显示 "CRC ERROR"，说明数据损坏
   - 如果显示 "SIZE ERROR"，说明数据丢失
3. **发送LOGO_TEST查看详细信息**

## LCD调试信息说明

### 上传过程中
```
UPLOADING
PKT:6900
95%
/7200
```

### 验证阶段
```
VERIFYING...
```

### 成功
```
SUCCESS!
LOGO UPLOADED
115200 bytes
```

### CRC错误
```
CRC ERROR
EXP:0x7436A806
GOT:0x12345678
FIRST 16 BYTES:
F8 00 F8 00
F8 00 F8 00
F8 00 F8 00
F8 00 F8 00
```

### 大小错误
```
SIZE ERROR
100000/115200
```

## 下一步行动

1. **重新编译固件**（已修复代码错误）
2. **烧录到硬件**
3. **运行完整测试**
4. **观察LCD显示**
5. **根据LCD信息判断问题**

## 预期问题和解决方案

### 问题1：CRC错误但数据正确
**原因**：APP端CRC计算错误
**解决**：检查APP端CRC32算法

### 问题2：Flash全是0xFF
**原因**：Flash写入失败
**解决**：
- 检查W25Q128_BufferWrite()实现
- 检查SPI通信
- 添加写入验证

### 问题3：数据部分正确
**原因**：某些包丢失或写入失败
**解决**：
- 添加包序号验证
- 添加重传机制

### 问题4：LOGO_TEST无响应
**原因**：蓝牙命令解析失败
**解决**：
- 检查rx.c中的命令解析
- 检查BLE_SendString()是否正常
