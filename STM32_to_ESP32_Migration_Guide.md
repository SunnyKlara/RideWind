# RideWind 项目迁移文档
## STM32F405RGTx → ESP32-WROOM-32E/32U

📅 文档日期: 2026-01-27
🎯 目标: 完成从STM32F405到ESP32-WROOM-32E/32U的硬件迁移

---

## 1. 项目背景

### 1.1 原平台规格
| 项目 | 规格 |
|------|------|
| 主控芯片 | STM32F405RGTx |
| 内核 | ARM Cortex-M4 |
| 主频 | 168MHz |
| Flash | 1MB |
| SRAM | 192KB |
| 工作电压 | 3.3V |

### 1.2 目标平台规格
| 项目 | 规格 |
|------|------|
| 主控芯片 | ESP32-WROOM-32E/32U |
| 内核 | Xtensa LX6 双核 |
| 主频 | 240MHz |
| Flash | 4MB (外置) |
| SRAM | 520KB |
| 工作电压 | 3.3V |
| 无线 | WiFi + BLE 4.2 |

---

## 2. 核心功能清单

| 序号 | 功能模块 | STM32实现方式 | 迁移优先级 |
|------|---------|--------------|-----------|
| 1 | 蓝牙通信 | USART2 + JDY-08外置模块 | ⭐⭐⭐ 高 |
| 2 | 风扇PWM控制 | TIM3_CH1 (PC6) | ⭐⭐⭐ 高 |
| 3 | LED灯带控制 | TIM+DMA (WS2812B×4条) | ⭐⭐⭐ 高 |
| 4 | 旋转编码器 | TIM1编码器模式 (PA8/PA9) | ⭐⭐⭐ 高 |
| 5 | 旋钮按键 | GPIO输入 (PB0) | ⭐⭐⭐ 高 |
| 6 | LCD显示 | SPI2 (240×240) | ⭐⭐ 中 |
| 7 | Flash存储 | SPI1 (W25Q128) | ⭐⭐ 中 |
| 8 | 音频播放 | SPI3 (VS1003) | ⭐⭐ 中 |
| 9 | 雾化器控制 | GPIO输出 (PB8) | ⭐ 低 |
| 10 | 调试串口 | UART5 | ⭐ 低 |

---

## 3. STM32F405 完整引脚映射表

### 3.1 GPIO输出引脚
| STM32引脚 | 功能 | 电平逻辑 | 初始状态 |
|-----------|------|---------|---------|
| PB8 | 雾化器控制 | 高电平开启 | HIGH |
| PB10 | LCD_CS | 低电平有效 | LOW |
| PB11 | LCD_DC | 数据/命令选择 | LOW |
| PB12 | LCD_RST | 低电平复位 | LOW |
| PA4 | Flash_CS | 低电平有效 | HIGH |
| PB9 | VS1003_CS | 低电平有效 | HIGH |
| PA12 | LED数据输出 | WS2812B协议 | LOW |
| PC11 | LED数据输出 | WS2812B协议 | LOW |
| PC13 | 通用GPIO | - | LOW |
| PC0 | 通用GPIO | - | HIGH |
| PC1 | 通用GPIO | - | HIGH |
| PC7 | 通用GPIO | - | LOW |
| PC10 | 通用GPIO | - | LOW |
| PB6 | 通用GPIO | - | LOW |

### 3.2 GPIO输入引脚
| STM32引脚 | 功能 | 上拉/下拉 | 触发方式 |
|-----------|------|----------|---------|
| PB0 | 旋钮按键 | 内部上拉 | 低电平有效 |
| PA10 | 备用输入 | 内部上拉 | - |
| PB7 | VS1003_DREQ | 无 | 高电平表示就绪 |

### 3.3 定时器/PWM引脚
| STM32引脚 | 外设 | 功能 | 配置参数 |
|-----------|------|------|---------|
| PC6 | TIM3_CH1 | 风扇PWM | 1kHz, 0-1000占空比 |
| PB1 | TIM3_CH4 | 备用PWM | 1kHz |
| PA8 | TIM1_CH1 | 编码器A相 | 编码器模式 |
| PA9 | TIM1_CH2 | 编码器B相 | 编码器模式 |

### 3.4 SPI接口引脚
| 接口 | 功能 | SCK | MISO | MOSI | CS |
|------|------|-----|------|------|-----|
| SPI1 | Flash (W25Q128) | PA5 | PA6 | PA7 | PA4 |
| SPI2 | LCD (240×240) | PB13 | PB14 | PB15 | PB10 |
| SPI3 | VS1003音频 | PB3 | PB4 | PB5 | PB9 |

### 3.5 UART接口引脚
| 接口 | 功能 | TX | RX | 波特率 |
|------|------|-----|-----|--------|
| USART2 | 蓝牙(JDY-08) | PA2 | PA3 | 115200 |
| UART5 | 调试串口 | PC12 | PD2 | 115200 |

---

## 4. ESP32-WROOM-32E/32U 引脚分配方案

### 4.1 ESP32引脚特性说明

**可用GPIO范围**: GPIO0-39 (部分有限制)

| 引脚类型 | GPIO编号 | 说明 |
|---------|---------|------|
| 仅输入 | GPIO34-39 | 无内部上拉，仅支持输入 |
| 启动敏感 | GPIO0, 2, 12, 15 | 影响启动模式，需谨慎使用 |
| Flash占用 | GPIO6-11 | 内部Flash使用，禁止使用 |
| 推荐使用 | GPIO4, 5, 13-19, 21-23, 25-27, 32, 33 | 通用IO |

**ADC限制**: 
- ADC2在WiFi使用时不可用
- 推荐使用ADC1 (GPIO32-39)

### 4.2 ESP32引脚映射方案

#### 4.2.1 蓝牙通信 (ESP32内置BLE)
| 功能 | STM32方案 | ESP32方案 | 说明 |
|------|----------|----------|------|
| BLE通信 | USART2+JDY-08 | 内置BLE | 无需外置模块 |
| - | PA2 (TX) | - | 不需要 |
| - | PA3 (RX) | - | 不需要 |

**ESP32适配逻辑**:
- STM32使用JDY-08透传模块，通过UART2发送AT指令或透传数据
- ESP32内置BLE 4.2，使用ESP-IDF的`esp_ble_gatts`API直接实现BLE服务
- 保持相同的Service UUID (0xFFE0) 和 Characteristic UUID (0xFFE1)
- 协议层代码可复用，仅需替换底层传输接口

#### 4.2.2 风扇PWM控制
| 功能 | STM32引脚 | ESP32引脚 | 外设 |
|------|----------|----------|------|
| 风扇PWM | PC6 (TIM3_CH1) | **GPIO25** | LEDC_CH0 |
| 备用PWM | PB1 (TIM3_CH4) | **GPIO26** | LEDC_CH1 |

**ESP32适配逻辑**:
- STM32: TIM3配置为1kHz PWM，Period=1000，占空比0-1000
- ESP32: 使用LEDC外设，配置如下:
```c
// ESP32 LEDC配置
ledc_timer_config_t timer_conf = {
    .speed_mode = LEDC_LOW_SPEED_MODE,
    .duty_resolution = LEDC_TIMER_10_BIT,  // 0-1023
    .timer_num = LEDC_TIMER_0,
    .freq_hz = 1000,  // 1kHz
    .clk_cfg = LEDC_AUTO_CLK
};

ledc_channel_config_t channel_conf = {
    .gpio_num = GPIO_NUM_25,
    .speed_mode = LEDC_LOW_SPEED_MODE,
    .channel = LEDC_CHANNEL_0,
    .timer_sel = LEDC_TIMER_0,
    .duty = 0,
    .hpoint = 0
};
```
- 占空比映射: STM32的0-1000 → ESP32的0-1023 (需乘以1.023)

#### 4.2.3 旋转编码器
| 功能 | STM32引脚 | ESP32引脚 | 说明 |
|------|----------|----------|------|
| 编码器A相 | PA8 (TIM1_CH1) | **GPIO32** | PCNT_UNIT0 |
| 编码器B相 | PA9 (TIM1_CH2) | **GPIO33** | PCNT_UNIT0 |
| 旋钮按键 | PB0 | **GPIO27** | GPIO中断 |

**ESP32适配逻辑**:
- STM32: 使用TIM1编码器模式，硬件自动计数
- ESP32: 使用PCNT (Pulse Counter) 外设实现编码器模式
```c
// ESP32 PCNT编码器配置
pcnt_config_t pcnt_config = {
    .pulse_gpio_num = GPIO_NUM_32,    // A相
    .ctrl_gpio_num = GPIO_NUM_33,     // B相
    .channel = PCNT_CHANNEL_0,
    .unit = PCNT_UNIT_0,
    .pos_mode = PCNT_COUNT_INC,       // 上升沿计数
    .neg_mode = PCNT_COUNT_DEC,       // 下降沿计数
    .lctrl_mode = PCNT_MODE_REVERSE,  // 低电平反向
    .hctrl_mode = PCNT_MODE_KEEP,     // 高电平保持
    .counter_h_lim = 32767,
    .counter_l_lim = -32768
};
```
- 按键检测: GPIO27配置为上拉输入，下降沿中断触发

#### 4.2.4 WS2812B LED灯带控制
| 功能 | STM32引脚 | ESP32引脚 | 说明 |
|------|----------|----------|------|
| LED灯带1 (M) | PA12 | **GPIO18** | RMT_CH0 |
| LED灯带2 (L) | PC11 | **GPIO19** | RMT_CH1 |
| LED灯带3 (R) | - | **GPIO21** | RMT_CH2 |
| LED灯带4 (B) | - | **GPIO22** | RMT_CH3 |

**ESP32适配逻辑**:
- STM32: 使用TIM+DMA生成WS2812B时序
- ESP32: 使用RMT (Remote Control) 外设，专为精确时序设计
```c
// ESP32 RMT配置 (WS2812B时序)
rmt_config_t config = {
    .rmt_mode = RMT_MODE_TX,
    .channel = RMT_CHANNEL_0,
    .gpio_num = GPIO_NUM_18,
    .clk_div = 2,  // 40MHz / 2 = 20MHz (50ns分辨率)
    .mem_block_num = 1
};

// WS2812B时序: T0H=400ns, T0L=850ns, T1H=800ns, T1L=450ns
```
- 推荐使用ESP-IDF的`led_strip`组件或FastLED库

#### 4.2.5 LCD显示 (SPI)
| 功能 | STM32引脚 | ESP32引脚 | 说明 |
|------|----------|----------|------|
| LCD_SCK | PB13 (SPI2) | **GPIO14** | HSPI_CLK |
| LCD_MOSI | PB15 (SPI2) | **GPIO13** | HSPI_MOSI |
| LCD_MISO | PB14 (SPI2) | **GPIO12** | HSPI_MISO (可选) |
| LCD_CS | PB10 | **GPIO15** | GPIO |
| LCD_DC | PB11 | **GPIO2** | GPIO |
| LCD_RST | PB12 | **GPIO4** | GPIO |

**ESP32适配逻辑**:
- STM32: SPI2，分频16，约5.25MHz
- ESP32: HSPI，可配置更高速率 (最高80MHz)
```c
// ESP32 SPI配置
spi_bus_config_t bus_cfg = {
    .mosi_io_num = GPIO_NUM_13,
    .miso_io_num = GPIO_NUM_12,
    .sclk_io_num = GPIO_NUM_14,
    .quadwp_io_num = -1,
    .quadhd_io_num = -1,
    .max_transfer_sz = 240 * 240 * 2  // 全屏缓冲
};

spi_device_interface_config_t dev_cfg = {
    .clock_speed_hz = 40 * 1000 * 1000,  // 40MHz
    .mode = 0,
    .spics_io_num = GPIO_NUM_15,
    .queue_size = 7
};
```

#### 4.2.6 Flash存储 (W25Q128)
| 功能 | STM32引脚 | ESP32引脚 | 说明 |
|------|----------|----------|------|
| Flash_SCK | PA5 (SPI1) | **GPIO18** | VSPI_CLK |
| Flash_MOSI | PA7 (SPI1) | **GPIO23** | VSPI_MOSI |
| Flash_MISO | PA6 (SPI1) | **GPIO19** | VSPI_MISO |
| Flash_CS | PA4 | **GPIO5** | GPIO |

**注意**: 如果LED灯带已占用GPIO18/19，需要调整:
- 方案A: Flash使用HSPI (与LCD共用总线，不同CS)
- 方案B: LED灯带改用其他GPIO

**推荐方案 (避免冲突)**:
| 功能 | 调整后ESP32引脚 |
|------|----------------|
| Flash_SCK | GPIO14 (与LCD共用HSPI) |
| Flash_MOSI | GPIO13 (与LCD共用HSPI) |
| Flash_MISO | GPIO12 (与LCD共用HSPI) |
| Flash_CS | GPIO5 (独立CS) |

#### 4.2.7 VS1003音频芯片
| 功能 | STM32引脚 | ESP32引脚 | 说明 |
|------|----------|----------|------|
| VS_SCK | PB3 (SPI3) | **GPIO14** | 共用HSPI |
| VS_MOSI | PB5 (SPI3) | **GPIO13** | 共用HSPI |
| VS_MISO | PB4 (SPI3) | **GPIO12** | 共用HSPI |
| VS_XCS | PB9 | **GPIO16** | 命令CS |
| VS_XDCS | - | **GPIO17** | 数据CS |
| VS_DREQ | PB7 | **GPIO34** | 数据请求(仅输入) |
| VS_RST | - | **GPIO4** | 可与LCD_RST共用 |

**ESP32适配逻辑**:
- VS1003使用SPI通信，可与LCD/Flash共用SPI总线
- DREQ引脚使用GPIO34 (仅输入引脚，适合检测)
- 注意SPI时钟速率: VS1003最高支持约4MHz

#### 4.2.8 雾化器控制
| 功能 | STM32引脚 | ESP32引脚 | 说明 |
|------|----------|----------|------|
| 雾化器开关 | PB8 | **GPIO26** | 高电平开启 |

#### 4.2.9 调试串口
| 功能 | STM32引脚 | ESP32引脚 | 说明 |
|------|----------|----------|------|
| Debug_TX | PC12 (UART5) | **GPIO1** | UART0_TX |
| Debug_RX | PD2 (UART5) | **GPIO3** | UART0_RX |

**注意**: ESP32的GPIO1/3是默认串口，用于下载和调试

---

## 5. ESP32完整引脚分配总表

| ESP32 GPIO | 功能 | 方向 | 电平/协议 | 对应STM32 |
|------------|------|------|----------|----------|
| GPIO1 | Debug_TX | 输出 | UART | PC12 |
| GPIO3 | Debug_RX | 输入 | UART | PD2 |
| GPIO2 | LCD_DC | 输出 | GPIO | PB11 |
| GPIO4 | LCD_RST / VS_RST | 输出 | GPIO | PB12 |
| GPIO5 | Flash_CS | 输出 | GPIO | PA4 |
| GPIO12 | SPI_MISO (共用) | 输入 | SPI | PB14/PA6/PB4 |
| GPIO13 | SPI_MOSI (共用) | 输出 | SPI | PB15/PA7/PB5 |
| GPIO14 | SPI_CLK (共用) | 输出 | SPI | PB13/PA5/PB3 |
| GPIO15 | LCD_CS | 输出 | GPIO | PB10 |
| GPIO16 | VS_XCS | 输出 | GPIO | PB9 |
| GPIO17 | VS_XDCS | 输出 | GPIO | - |
| GPIO18 | LED_Strip_M | 输出 | RMT | PA12 |
| GPIO19 | LED_Strip_L | 输出 | RMT | PC11 |
| GPIO21 | LED_Strip_R | 输出 | RMT | - |
| GPIO22 | LED_Strip_B | 输出 | RMT | - |
| GPIO25 | Fan_PWM | 输出 | LEDC | PC6 |
| GPIO26 | 雾化器 | 输出 | GPIO | PB8 |
| GPIO27 | 旋钮按键 | 输入 | GPIO中断 | PB0 |
| GPIO32 | 编码器A | 输入 | PCNT | PA8 |
| GPIO33 | 编码器B | 输入 | PCNT | PA9 |
| GPIO34 | VS_DREQ | 输入 | GPIO | PB7 |
| 内置BLE | 蓝牙通信 | - | BLE | PA2/PA3+JDY-08 |

---

## 6. 操作逻辑迁移对照表


### 6.1 蓝牙通信逻辑

**STM32原有逻辑**:
```
1. UART2中断接收JDY-08透传数据
2. 数据存入ble_rx_buffer (200字节)
3. 50ms超时判定一包完成
4. Protocol_Process()解析命令
5. BLE_SendString()通过UART2发送响应
```

**ESP32适配逻辑**:
```
1. 注册BLE GATTS回调函数
2. 在ESP_GATTS_WRITE_EVT事件中接收数据
3. 数据存入rx_buffer
4. Protocol_Process()解析命令 (复用)
5. esp_ble_gatts_send_indicate()发送响应
```

**关键差异**:
- ESP32无需外置蓝牙模块，直接使用内置BLE
- 需要配置BLE服务和特征值
- 数据收发通过GATTS API而非UART

### 6.2 风扇PWM控制逻辑

**STM32原有逻辑**:
```c
// 设置风扇速度 (0-100%)
void CMD_SetFanSpeed(uint8_t percent) {
    uint16_t pwm_value = percent * 10;  // 0-1000
    if(pwm_value > 999) pwm_value = 999;
    __HAL_TIM_SetCompare(&htim3, TIM_CHANNEL_1, pwm_value);
}
```

**ESP32适配逻辑**:
```c
// 设置风扇速度 (0-100%)
void CMD_SetFanSpeed(uint8_t percent) {
    uint32_t duty = (percent * 1023) / 100;  // 0-1023 (10bit)
    ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, duty);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0);
}
```

**关键差异**:
- STM32使用TIM外设，ESP32使用LEDC外设
- 占空比分辨率: STM32=1000, ESP32=1024 (10bit)
- ESP32需要调用update_duty()使设置生效

### 6.3 旋转编码器逻辑

**STM32原有逻辑**:
```c
void Encoder(void) {
    static int16_t last_count = 0;
    int16_t current = __HAL_TIM_GET_COUNTER(&htim1);
    int16_t delta = current - last_count;
    
    if (delta != 0) {
        BLE_ReportKnobDelta(delta);
        last_count = current;
    }
}
```

**ESP32适配逻辑**:
```c
void Encoder(void) {
    static int16_t last_count = 0;
    int16_t current;
    pcnt_get_counter_value(PCNT_UNIT_0, &current);
    int16_t delta = current - last_count;
    
    if (delta != 0) {
        BLE_ReportKnobDelta(delta);
        last_count = current;
    }
}
```

**关键差异**:
- STM32使用TIM编码器模式，ESP32使用PCNT外设
- API不同但逻辑完全相同
- ESP32的PCNT支持滤波功能，可减少抖动

### 6.4 旋钮按键检测逻辑

**STM32原有逻辑**:
```c
// PB0上拉输入，低电平有效
if(HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_0) == GPIO_PIN_RESET) {
    // 按键按下
}
```

**ESP32适配逻辑**:
```c
// GPIO27上拉输入，低电平有效
gpio_config_t io_conf = {
    .pin_bit_mask = (1ULL << GPIO_NUM_27),
    .mode = GPIO_MODE_INPUT,
    .pull_up_en = GPIO_PULLUP_ENABLE,
    .pull_down_en = GPIO_PULLDOWN_DISABLE,
    .intr_type = GPIO_INTR_NEGEDGE  // 下降沿中断
};
gpio_config(&io_conf);

// 中断处理
gpio_isr_handler_add(GPIO_NUM_27, button_isr_handler, NULL);
```

**关键差异**:
- ESP32支持任意GPIO配置中断
- 建议使用FreeRTOS任务通知处理按键事件

### 6.5 WS2812B LED控制逻辑

**STM32原有逻辑**:
```c
// 使用TIM+DMA生成WS2812B时序
void WS2812B_SetAllLEDs(uint8_t strip, uint8_t r, uint8_t g, uint8_t b) {
    // 填充DMA缓冲区
    // 启动DMA传输
}
```

**ESP32适配逻辑**:
```c
// 使用RMT外设
#include "led_strip.h"

led_strip_handle_t led_strip;

led_strip_config_t strip_config = {
    .strip_gpio_num = GPIO_NUM_18,
    .max_leds = 30,  // LED数量
};

led_strip_rmt_config_t rmt_config = {
    .resolution_hz = 10 * 1000 * 1000,  // 10MHz
};

led_strip_new_rmt_device(&strip_config, &rmt_config, &led_strip);

// 设置颜色
led_strip_set_pixel(led_strip, index, r, g, b);
led_strip_refresh(led_strip);
```

**关键差异**:
- ESP32的RMT外设专为精确时序设计，更适合WS2812B
- 推荐使用ESP-IDF的led_strip组件，简化开发
- 每条灯带使用独立的RMT通道

### 6.6 SPI通信逻辑

**STM32原有逻辑**:
```c
// HAL库SPI传输
HAL_SPI_Transmit(&hspi2, data, len, 100);
HAL_SPI_Receive(&hspi2, data, len, 100);
```

**ESP32适配逻辑**:
```c
// ESP-IDF SPI传输
spi_transaction_t trans = {
    .length = len * 8,  // 位数
    .tx_buffer = tx_data,
    .rx_buffer = rx_data
};
spi_device_transmit(spi_handle, &trans);
```

**关键差异**:
- ESP32 SPI支持DMA，大数据传输更高效
- 多设备共用SPI总线时，通过不同CS引脚区分
- ESP32 SPI支持全双工和半双工模式

---

## 7. 硬件差异与适配注意事项

### 7.1 电压兼容性
| 项目 | STM32F405 | ESP32 | 兼容性 |
|------|----------|-------|--------|
| IO电压 | 3.3V | 3.3V | ✅ 兼容 |
| 5V容忍 | 部分引脚 | 不支持 | ⚠️ 需注意 |
| 驱动能力 | 25mA | 40mA | ✅ ESP32更强 |

**注意**: ESP32所有GPIO不支持5V输入，如有5V信号需加电平转换

### 7.2 中断机制差异
| 项目 | STM32F405 | ESP32 |
|------|----------|-------|
| 外部中断 | EXTI (16通道) | 任意GPIO |
| 中断优先级 | NVIC (0-15) | 1-7 |
| 中断处理 | 直接ISR | ISR + FreeRTOS |

**建议**: ESP32中断处理建议使用FreeRTOS任务通知，避免在ISR中执行耗时操作

### 7.3 定时器差异
| 项目 | STM32F405 | ESP32 |
|------|----------|-------|
| 通用定时器 | TIM2-5 (32bit) | 4个64bit |
| 高级定时器 | TIM1, TIM8 | - |
| PWM通道 | 每TIM 4通道 | LEDC 16通道 |
| 编码器模式 | TIM硬件支持 | PCNT外设 |

### 7.4 SPI差异
| 项目 | STM32F405 | ESP32 |
|------|----------|-------|
| SPI数量 | 3个 | 4个 (2个可用) |
| 最高速率 | 42MHz | 80MHz |
| DMA支持 | 需配置 | 自动 |
| 全双工 | 支持 | 支持 |

### 7.5 内存管理
| 项目 | STM32F405 | ESP32 |
|------|----------|-------|
| SRAM | 192KB | 520KB |
| 堆栈 | 手动管理 | FreeRTOS管理 |
| DMA缓冲 | 任意SRAM | 需DMA capable |

**注意**: ESP32的DMA缓冲区需要使用`heap_caps_malloc(size, MALLOC_CAP_DMA)`分配

---

## 8. 软件架构迁移建议

### 8.1 开发框架选择
| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| ESP-IDF | 功能完整，性能最优 | 学习曲线陡 | ⭐⭐⭐ |
| Arduino-ESP32 | 简单易用，兼容Arduino | 性能略低 | ⭐⭐ |
| PlatformIO | 跨平台，IDE支持好 | 配置复杂 | ⭐⭐ |

**推荐**: 使用ESP-IDF，可获得最佳性能和完整功能

### 8.2 代码复用策略
| 模块 | 复用程度 | 说明 |
|------|---------|------|
| 协议解析 | 100% | Protocol_Process()可直接复用 |
| 业务逻辑 | 90% | 状态机、UI逻辑可复用 |
| LED颜色预设 | 100% | 颜色数据可直接复用 |
| 硬件驱动 | 0% | 需完全重写 |
| 蓝牙通信 | 30% | 协议层复用，传输层重写 |

### 8.3 FreeRTOS任务划分建议
```
┌─────────────────────────────────────────────────────────────┐
│                    ESP32 任务架构                            │
├─────────────────────────────────────────────────────────────┤
│  Task: ble_task          优先级: 5    核心: 0               │
│  功能: BLE事件处理、数据收发                                 │
├─────────────────────────────────────────────────────────────┤
│  Task: main_task         优先级: 4    核心: 1               │
│  功能: 主循环、协议处理、状态更新                            │
├─────────────────────────────────────────────────────────────┤
│  Task: led_task          优先级: 3    核心: 1               │
│  功能: LED刷新、动画效果                                     │
├─────────────────────────────────────────────────────────────┤
│  Task: encoder_task      优先级: 4    核心: 1               │
│  功能: 编码器读取、按键检测                                  │
├─────────────────────────────────────────────────────────────┤
│  Task: audio_task        优先级: 2    核心: 0               │
│  功能: VS1003音频播放                                        │
├─────────────────────────────────────────────────────────────┤
│  Task: lcd_task          优先级: 2    核心: 1               │
│  功能: LCD显示更新                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. 迁移检查清单

### 9.1 硬件准备
- [ ] ESP32-WROOM-32E/32U开发板
- [ ] 确认所有外设3.3V兼容
- [ ] 准备SPI总线连接 (LCD/Flash/VS1003共用)
- [ ] 准备4路LED灯带连接
- [ ] 准备旋转编码器连接
- [ ] 准备风扇PWM连接

### 9.2 软件开发
- [ ] 搭建ESP-IDF开发环境
- [ ] 配置BLE服务 (UUID: 0xFFE0/0xFFE1)
- [ ] 移植协议解析代码
- [ ] 实现LEDC PWM控制
- [ ] 实现PCNT编码器读取
- [ ] 实现RMT LED控制
- [ ] 实现SPI LCD驱动
- [ ] 实现SPI Flash驱动
- [ ] 实现VS1003音频驱动

### 9.3 功能测试
- [ ] BLE连接与数据收发
- [ ] 风扇速度控制 (0-100%)
- [ ] LED颜色控制 (4条灯带)
- [ ] LED预设切换 (14种)
- [ ] 亮度调节 (0-100%)
- [ ] 旋钮旋转检测
- [ ] 旋钮按键检测 (单击/双击/三击/长按)
- [ ] LCD显示更新
- [ ] 音频播放
- [ ] 雾化器控制
- [ ] Flash数据存储

---

## 10. 附录

### 10.1 ESP32-WROOM-32E引脚图
```
                    ┌──────────────────┐
              EN ──┤1               38├── GND
         GPIO36 ──┤2               37├── GPIO23 (VSPI_MOSI)
         GPIO39 ──┤3               36├── GPIO22 (LED_B)
         GPIO34 ──┤4  (VS_DREQ)    35├── GPIO1  (TX0)
         GPIO35 ──┤5               34├── GPIO3  (RX0)
         GPIO32 ──┤6  (ENC_A)      33├── GPIO21 (LED_R)
         GPIO33 ──┤7  (ENC_B)      32├── GND
         GPIO25 ──┤8  (FAN_PWM)    31├── GPIO19 (LED_L)
         GPIO26 ──┤9  (雾化器)     30├── GPIO18 (LED_M)
         GPIO27 ──┤10 (BTN)        29├── GPIO5  (FLASH_CS)
         GPIO14 ──┤11 (SPI_CLK)    28├── GPIO17 (VS_XDCS)
         GPIO12 ──┤12 (SPI_MISO)   27├── GPIO16 (VS_XCS)
             GND ──┤13              26├── GPIO4  (LCD_RST)
         GPIO13 ──┤14 (SPI_MOSI)   25├── GPIO0
         GPIO9  ──┤15              24├── GPIO2  (LCD_DC)
         GPIO10 ──┤16              23├── GPIO15 (LCD_CS)
         GPIO11 ──┤17              22├── GPIO8
             VDD ──┤18              21├── GPIO7
         GPIO6  ──┤19              20├── GPIO6
                    └──────────────────┘
```

### 10.2 参考资源
- [ESP-IDF编程指南](https://docs.espressif.com/projects/esp-idf/zh_CN/latest/)
- [ESP32技术参考手册](https://www.espressif.com/sites/default/files/documentation/esp32_technical_reference_manual_cn.pdf)
- [ESP32-WROOM-32E数据手册](https://www.espressif.com/sites/default/files/documentation/esp32-wroom-32e_esp32-wroom-32ue_datasheet_cn.pdf)

---

**文档版本**: v1.0
**创建日期**: 2026-01-27
**维护者**: RideWind 开发团队
