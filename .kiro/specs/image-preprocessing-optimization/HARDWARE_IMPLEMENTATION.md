# 硬件端RLE解码实现指南

## 📋 概述

硬件端需要实现RLE解码器来解压缩APP发送的压缩数据。

## 🔧 协议扩展

### 新增命令

#### LOGO_START_COMPRESSED
**格式**: `LOGO_START_COMPRESSED:原始大小:压缩大小:CRC32\r\n`

**示例**: `LOGO_START_COMPRESSED:115200:904:0x12345678\r\n`

**参数**:
- 原始大小: 解压后的数据大小(115,200字节)
- 压缩大小: 压缩后的数据大小
- CRC32: 压缩数据的CRC32校验值

**响应**: `LOGO_READY\r\n`

### 数据传输
使用现有的 `LOGO_DATA` 命令传输压缩数据。

### 完成确认
使用现有的 `LOGO_END` 命令表示传输完成。

## 📦 RLE数据格式

### 块类型
- `0x01`: 原始数据块
- `0x02`: RLE压缩块

### 原始数据块格式
```
[0x01][像素数量(1B)][像素1(2B)][像素2(2B)]...
```

**示例**:
```c
0x01 0x03 0xF8 0x00 0x07 0xE0 0x00 0x1F
// 3个不同的像素: 红色、绿色、蓝色
```

### RLE压缩块格式
```
[0x02][重复次数(1B)][像素值(2B)]
```

**示例**:
```c
0x02 0x05 0xF8 0x00
// 5个红色像素
```

## 💻 C语言实现

### 1. 数据结构

```c
// Logo状态结构
typedef struct {
    uint32_t originalSize;      // 原始大小
    uint32_t compressedSize;    // 压缩大小
    uint32_t expectedCRC32;     // 期望的CRC32
    uint32_t receivedBytes;     // 已接收字节数
    uint32_t flashAddr;         // Flash写入地址
    uint8_t buffer[256];        // 接收缓冲区
    uint16_t bufferIndex;       // 缓冲区索引
    bool isCompressed;          // 是否压缩数据
} LogoState_t;

LogoState_t logoState;
```

### 2. 处理压缩开始命令

```c
void Logo_HandleCompressedStart(char* params) {
    // 解析参数
    sscanf(params, "%lu:%lu:%lx", 
           &logoState.originalSize,
           &logoState.compressedSize,
           &logoState.expectedCRC32);
    
    // 初始化状态
    logoState.receivedBytes = 0;
    logoState.flashAddr = LOGO_FLASH_ADDR;
    logoState.bufferIndex = 0;
    logoState.isCompressed = true;
    
    // 擦除Flash
    Logo_EraseFlash();
    
    // 发送就绪
    UART_SendString("LOGO_READY\r\n");
}
```

### 3. RLE解码函数

```c
void Logo_DecodeRLE(uint8_t* buffer, uint16_t length) {
    uint16_t i = 0;
    
    while (i < length) {
        uint8_t blockType = buffer[i++];
        
        if (blockType == 0x01) {
            // 原始数据块
            uint8_t count = buffer[i++];
            for (uint8_t j = 0; j < count; j++) {
                uint16_t pixel = (buffer[i] << 8) | buffer[i + 1];
                W25Q128_Write_NoCheck((uint8_t*)&pixel, 
                                     logoState.flashAddr, 2);
                logoState.flashAddr += 2;
                i += 2;
            }
        } else if (blockType == 0x02) {
            // RLE压缩块
            uint8_t count = buffer[i++];
            uint16_t pixel = (buffer[i] << 8) | buffer[i + 1];
            i += 2;
            
            for (uint8_t j = 0; j < count; j++) {
                W25Q128_Write_NoCheck((uint8_t*)&pixel, 
                                     logoState.flashAddr, 2);
                logoState.flashAddr += 2;
            }
        }
    }
}
```

### 4. 修改数据接收处理

```c
void Logo_HandleData(char* params) {
    uint16_t packetNum;
    char hexData[64];
    
    // 解析参数
    sscanf(params, "%hu:%s", &packetNum, hexData);
    
    // 转换hex字符串为字节
    uint8_t data[16];
    for (int i = 0; i < 16; i++) {
        sscanf(&hexData[i * 2], "%2hhx", &data[i]);
    }
    
    // 添加到缓冲区
    memcpy(&logoState.buffer[logoState.bufferIndex], data, 16);
    logoState.bufferIndex += 16;
    logoState.receivedBytes += 16;
    
    // 如果是压缩数据,缓冲区满时进行RLE解码
    if (logoState.isCompressed) {
        if (logoState.bufferIndex >= 128 || 
            logoState.receivedBytes >= logoState.compressedSize) {
            Logo_DecodeRLE(logoState.buffer, logoState.bufferIndex);
            logoState.bufferIndex = 0;
        }
    } else {
        // 未压缩数据,直接写入Flash
        if (logoState.bufferIndex >= 128) {
            W25Q128_Write_NoCheck(logoState.buffer, 
                                 logoState.flashAddr, 
                                 logoState.bufferIndex);
            logoState.flashAddr += logoState.bufferIndex;
            logoState.bufferIndex = 0;
        }
    }
    
    // 每10包发送ACK
    if (packetNum % 10 == 0) {
        char ack[32];
        sprintf(ack, "LOGO_ACK:%hu\r\n", packetNum);
        UART_SendString(ack);
    }
}
```

### 5. 命令路由

```c
void Logo_HandleCommand(char* command) {
    if (strncmp(command, "LOGO_START_COMPRESSED:", 22) == 0) {
        Logo_HandleCompressedStart(command + 22);
    } else if (strncmp(command, "LOGO_START:", 11) == 0) {
        Logo_HandleStart(command + 11);  // 未压缩模式
    } else if (strncmp(command, "LOGO_DATA:", 10) == 0) {
        Logo_HandleData(command + 10);
    } else if (strcmp(command, "LOGO_END") == 0) {
        Logo_HandleEnd();
    }
    // ... 其他命令
}
```

## 🧪 测试验证

### 测试步骤

1. **准备测试数据**
```c
// 测试数据: 5个红色像素
uint8_t testData[] = {
    0x02, 0x05, 0xF8, 0x00  // RLE块: 5个红色
};
```

2. **调用解码函数**
```c
Logo_DecodeRLE(testData, sizeof(testData));
```

3. **验证Flash数据**
```c
uint16_t pixels[5];
W25Q128_Read(pixels, LOGO_FLASH_ADDR, 10);

for (int i = 0; i < 5; i++) {
    assert(pixels[i] == 0xF800);  // 验证都是红色
}
```

### 测试用例

#### 用例1: 纯色图片
```c
// 输入: 240x240纯红色
// 压缩数据: 约900字节
// 预期: 解压后115,200字节,全部为0xF800
```

#### 用例2: 混合数据
```c
// 输入: RLE块 + 原始块
// 预期: 正确解码两种块类型
```

## ⚠️ 注意事项

### 内存管理
- 缓冲区大小: 256字节
- 及时清空缓冲区
- 避免内存溢出

### Flash写入
- 先擦除再写入
- 检查写入结果
- 处理写入失败

### 错误处理
- 无效块类型
- 缓冲区溢出
- Flash写入失败
- CRC32校验失败

## 📊 性能优化

### 优化建议

1. **批量写入**: 累积多个像素后一次性写入
2. **DMA传输**: 使用DMA加速Flash写入
3. **中断处理**: 在中断中接收数据
4. **流式处理**: 边接收边解码

### 预期性能
- 解码速度: >10KB/s
- 内存占用: <4KB
- Flash写入: <1秒

## 🔍 调试技巧

### 调试输出
```c
void Logo_DebugRLE(uint8_t* buffer, uint16_t length) {
    printf("RLE Debug: length=%d\n", length);
    for (int i = 0; i < length; i++) {
        printf("%02X ", buffer[i]);
        if ((i + 1) % 16 == 0) printf("\n");
    }
    printf("\n");
}
```

### 验证解码
```c
// 解码后读取Flash验证
uint16_t pixel;
W25Q128_Read(&pixel, LOGO_FLASH_ADDR, 2);
printf("First pixel: 0x%04X\n", pixel);
```

## ✅ 实现检查清单

- [ ] 添加LogoState_t结构
- [ ] 实现Logo_HandleCompressedStart()
- [ ] 实现Logo_DecodeRLE()
- [ ] 修改Logo_HandleData()
- [ ] 更新命令路由
- [ ] 添加错误处理
- [ ] 编写测试用例
- [ ] 验证解码正确性
- [ ] 性能测试
- [ ] 文档更新

---

**版本**: v1.0  
**更新日期**: 2026-01-18
