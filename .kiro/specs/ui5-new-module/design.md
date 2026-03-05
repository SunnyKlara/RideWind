# UI5 新模块控制界面 - 设计文档

📅 创建日期: 2026-01-14
📋 需求文档: #[[file:.kiro/specs/ui5-new-module/requirements.md]]

---

## 1. 架构设计

### 1.1 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         UI5 新模块控制架构                                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           Flutter APP (RideWind)                            │
│   - 新增 Module5 控制页面                                                    │
│   - 发送 MOD5:xx 命令                                                        │
│   - 接收 MOD5_REPORT:xx 上报                                                 │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ BLE 通信
                                  │
┌─────────────────────────────────▼───────────────────────────────────────────┐
│                       STM32F405RGTx 主控制器                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        UI 状态机 (xuanniu.c)                         │   │
│  │                                                                      │   │
│  │   ui=0 ──▶ ui=1 ──▶ ui=2 ──▶ ui=3 ──▶ ui=4 ──▶ ui=5 ──▶ ui=0      │   │
│  │   开机     风扇     配色     RGB      亮度     新模块                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  风扇控制   │  │  新模块控制 │  │  LCD显示    │  │  蓝牙通信   │        │
│  │  TIM3_CH1   │  │  TIM?_CH?   │  │  UI5界面    │  │  MOD5命令   │        │
│  │  PC6        │  │  PC8/PC12   │  │  lcd.c      │  │  rx.c       │        │
│  │  Num        │  │  Module5_Num│  │  LCD_ui5()  │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 数据流图

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   编码器     │────▶│ Module5_Num  │────▶│   PWM输出    │
│   旋转       │     │   (0-100)    │     │   (0-1000)   │
└──────────────┘     └──────┬───────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   LCD显示    │
                     │   数值更新   │
                     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   蓝牙上报   │
                     │ MOD5_REPORT  │
                     └──────────────┘
```

---

## 2. 模块设计

### 2.1 变量定义 (xuanniu.h)

```c
// ========== UI5 新模块控制变量 ==========
extern int16_t Module5_Num;        // 新模块控制值 (0-100)
extern int16_t Module5_Num_old;    // 旧值 (用于变化检测)
extern uint8_t module5_unit;       // 单位 (0=默认, 1=备用)

// ========== UI5 相关宏定义 ==========
#define MODULE5_PWM_CHANNEL  TIM_CHANNEL_1  // PWM通道 (待确认)
#define MODULE5_PWM_TIMER    htim8          // PWM定时器 (待确认)
```

### 2.2 LCD 界面函数 (lcd.c)

```c
/**
 * @brief  UI5 界面初始化绘制
 * @note   复制 UI1 的视觉样式
 */
void LCD_ui5(void)
{
    // 1. 绘制背景
    LCD_ShowPicture(0, 0, LCD_WIDTH, LCD_HEIGHT, gImage_beijing_240_240);
    
    // 2. 绘制标题/表盘区域 (复用 UI1 的图片资源)
    LCD_ShowPicture(fengshubiao_x, fengshubiao_y, 
                    fengshubiao_width, fengshubiao_high, 
                    gImage_fengshubiao_202_43);
    
    // 3. 初始化数值显示
    LCD_ui5_update(Module5_Num);
}

/**
 * @brief  UI5 数值更新
 * @param  num: 当前控制值 (0-100)
 */
void LCD_ui5_update(int16_t num)
{
    // 复用 LCD_picture() 的数字显示逻辑
    // 根据 module5_unit 选择显示格式
    LCD_picture(num, module5_unit);
}
```

### 2.3 UI 状态机扩展 (xuanniu.c)

```c
// ========== UI 切换逻辑修改 ==========
// 原: if (ui > 4) ui = 0;
// 改: if (ui > 5) ui = 0;

// ========== UI5 处理逻辑 ==========
else if(ui == 5)
{
    // 初始化
    if(chu == 5)
    {
        chu = 0;  // 重置初始化标志
        LCD_ui5();
        LCD_ui5_update(Module5_Num);
    }
    
    // 编码器控制
    int16_t delta = Encoder_GetDelta();
    Module5_Num += delta;
    if(Module5_Num > 100) Module5_Num = 100;
    if(Module5_Num < 0) Module5_Num = 0;
    
    // 数值变化时更新
    if(Module5_Num != Module5_Num_old)
    {
        // 更新 LCD
        LCD_ui5_update(Module5_Num);
        
        // 更新 PWM
        PWM5_Update(Module5_Num);
        
        // 上报蓝牙
        BLE_ReportModule5(Module5_Num);
        
        Module5_Num_old = Module5_Num;
    }
}
```

### 2.4 PWM 输出函数 (xuanniu.c)

```c
/**
 * @brief  UI5 PWM 输出更新
 * @param  value: 控制值 (0-100)
 */
void PWM5_Update(int16_t value)
{
    // 映射: 0-100 → 0-1000
    uint16_t pwm_value = value * 10;
    if(pwm_value > 999) pwm_value = 999;
    
    // 输出到指定通道 (待确认具体定时器和通道)
    __HAL_TIM_SetCompare(&MODULE5_PWM_TIMER, MODULE5_PWM_CHANNEL, pwm_value);
}
```

### 2.5 蓝牙协议扩展 (rx.c)

```c
// ========== 命令解析 ==========
// MOD5:xx - 设置新模块值
else if(strncmp(cmd, "MOD5:", 5) == 0)
{
    int value = atoi(cmd + 5);
    if(value >= 0 && value <= 100)
    {
        Module5_Num = (int16_t)value;
        PWM5_Update(Module5_Num);
        
        // 如果当前在 UI5，更新显示
        if(ui == 5)
        {
            LCD_ui5_update(Module5_Num);
        }
        
        BLE_SendString("OK:MOD5\r\n");
    }
    else
    {
        BLE_SendString("ERR:MOD5 range 0-100\r\n");
    }
}

// GET:MOD5 - 查询新模块值
else if(strcmp(cmd, "GET:MOD5") == 0)
{
    char buf[20];
    sprintf(buf, "MOD5:%d\r\n", Module5_Num);
    BLE_SendString(buf);
}

// UI:5 - 切换到 UI5
// 在现有 UI 命令处理中扩展范围: if(target_ui >= 0 && target_ui <= 5)

// ========== 状态上报 ==========
void BLE_ReportModule5(int16_t value)
{
    char buf[24];
    sprintf(buf, "MOD5_REPORT:%d\n", value);
    BLE_SendString(buf);
}
```

---

## 3. 接口设计

### 3.1 蓝牙命令接口

| 方向 | 命令 | 参数 | 说明 |
|------|------|------|------|
| APP→硬件 | `MOD5:xx` | 0-100 | 设置新模块值 |
| APP→硬件 | `GET:MOD5` | 无 | 查询新模块值 |
| APP→硬件 | `UI:5` | 无 | 切换到 UI5 |
| 硬件→APP | `MOD5:xx\r\n` | 0-100 | 查询响应 |
| 硬件→APP | `MOD5_REPORT:xx\n` | 0-100 | 主动上报 |
| 硬件→APP | `OK:MOD5\r\n` | 无 | 命令成功 |

### 3.2 内部函数接口

```c
// lcd.h
void LCD_ui5(void);                      // UI5 界面绘制
void LCD_ui5_update(int16_t num);        // UI5 数值更新

// xuanniu.h
void PWM5_Update(int16_t value);         // PWM5 输出更新

// rx.h
void BLE_ReportModule5(int16_t value);   // 上报 Module5 状态
```

---

## 4. 正确性属性

### 4.1 不变量 (Invariants)

```
INV-001: 0 <= Module5_Num <= 100
INV-002: PWM 输出值 = Module5_Num * 10
INV-003: ui 变量范围 0-5
```

### 4.2 前置条件 (Preconditions)

```
PRE-001: LCD_ui5() 调用前，LCD 已初始化
PRE-002: PWM5_Update() 调用前，定时器已启动
PRE-003: BLE_ReportModule5() 调用前，蓝牙已初始化
```

### 4.3 后置条件 (Postconditions)

```
POST-001: MOD5:xx 命令执行后，Module5_Num == xx
POST-002: 编码器旋转后，Module5_Num 在 [0,100] 范围内
POST-003: UI 切换到 5 后，LCD 显示 UI5 界面
```

---

## 5. 测试用例

### TC-001: 界面切换测试
- **步骤**: 长按旋钮多次，观察 UI 切换
- **预期**: UI 按 0→1→2→3→4→5→0 循环切换

### TC-002: 编码器控制测试
- **步骤**: 在 UI5 界面旋转编码器
- **预期**: 数值在 0-100 范围内变化，LCD 实时更新

### TC-003: 蓝牙命令测试
- **步骤**: 发送 `MOD5:50\n`
- **预期**: 收到 `OK:MOD5\r\n`，Module5_Num = 50

### TC-004: 状态查询测试
- **步骤**: 发送 `GET:MOD5\n`
- **预期**: 收到 `MOD5:50\r\n` (假设当前值为 50)

### TC-005: 状态上报测试
- **步骤**: 在 UI5 界面旋转编码器改变数值
- **预期**: 收到 `MOD5_REPORT:xx\n` 上报

### TC-006: PWM 输出测试
- **步骤**: 设置 Module5_Num = 50，用示波器测量 PWM 引脚
- **预期**: PWM 占空比约 50%

---

## 6. 待确认设计决策

> ⚠️ 以下设计决策需要用户确认

### D-001: PWM 定时器选择
- **选项 A**: 使用 TIM8_CH1 (PC8)
- **选项 B**: 使用 TIM3 的其他通道
- **选项 C**: 使用 GPIO 软件 PWM
- **当前假设**: TIM8_CH1 (PC8)

### D-002: 显示格式
- **选项 A**: 显示百分比 (0-100%)
- **选项 B**: 显示映射值 (0-340，与风扇一致)
- **选项 C**: 显示自定义单位
- **当前假设**: 显示百分比

### D-003: 单位切换
- **选项 A**: 支持单位切换 (单击旋钮)
- **选项 B**: 不支持单位切换
- **当前假设**: 支持单位切换

### D-004: 油门模式
- **选项 A**: 支持油门模式 (三击进入)
- **选项 B**: 不支持油门模式
- **当前假设**: 不支持油门模式

---

## 7. 文件修改清单

| 文件 | 修改类型 | 修改内容 |
|------|---------|---------|
| `xuanniu.h` | 新增 | Module5_Num 变量声明、宏定义 |
| `xuanniu.c` | 修改 | UI 切换范围、UI5 处理逻辑、PWM5_Update() |
| `lcd.h` | 新增 | LCD_ui5()、LCD_ui5_update() 声明 |
| `lcd.c` | 新增 | LCD_ui5()、LCD_ui5_update() 实现 |
| `rx.c` | 修改 | MOD5 命令解析、BLE_ReportModule5() |
| `rx.h` | 新增 | BLE_ReportModule5() 声明 |

---

**文档状态**: 📝 草稿 - 等待用户确认设计决策
**最后更新**: 2026-01-14
