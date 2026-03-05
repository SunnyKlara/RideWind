# 测试程序 4.3: 测试开机Logo选择

## 测试目标
验证用户选择的开机Logo能够正确保存到Flash，并在重启后正确显示。

---

## 代码审查结果

### 1. Logo_SetActiveSlot() - 设置激活槽位 ✅

**文件**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`

```c
void Logo_SetActiveSlot(uint8_t slot)
{
    if (slot < LOGO_MAX_SLOTS) {
        logo_active_slot = slot;
    }
}
```

**验证结果**:
- ✅ 正确验证槽位范围 (0-2)
- ✅ 将激活槽位保存到全局变量 `logo_active_slot`
- ✅ 无效槽位被忽略，不会导致错误

---

### 2. Logo_SaveConfig() - 保存配置到Flash ✅

**文件**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`

```c
void Logo_SaveConfig(void)
{
    LogoConfig_t config;
    config.magic = LOGO_CONFIG_MAGIC;      // 0xBB66
    config.active_slot = logo_active_slot;
    config.reserved = 0;
    config.checksum = 0;  // 简化：暂不计算CRC
    
    // 擦除配置扇区
    W25Q128_EraseSector(LOGO_CONFIG_ADDR);  // 0x160000
    
    // 写入配置
    W25Q128_BufferWrite((uint8_t*)&config, LOGO_CONFIG_ADDR, sizeof(config));
    
    printf("[LOGO] Config saved: active_slot=%d\r\n", logo_active_slot);
}
```

**验证结果**:
- ✅ 使用正确的配置地址 `LOGO_CONFIG_ADDR` (0x160000)
- ✅ 写入前先擦除Flash扇区
- ✅ 配置结构包含magic标志用于验证
- ✅ 保存激活槽位到Flash

---

### 3. Logo_LoadConfig() - 从Flash加载配置 ✅

**文件**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`

```c
void Logo_LoadConfig(void)
{
    LogoConfig_t config;
    W25Q128_BufferRead((uint8_t*)&config, LOGO_CONFIG_ADDR, sizeof(config));
    
    if (config.magic == LOGO_CONFIG_MAGIC && config.active_slot < LOGO_MAX_SLOTS) {
        logo_active_slot = config.active_slot;
        printf("[LOGO] Config loaded: active_slot=%d\r\n", logo_active_slot);
    } else {
        // 配置无效，使用默认值
        logo_active_slot = 0;
        printf("[LOGO] Config invalid, using default slot 0\r\n");
    }
}
```

**验证结果**:
- ✅ 从正确的Flash地址读取配置
- ✅ 验证magic标志 (0xBB66) 确保配置有效
- ✅ 验证槽位范围有效性
- ✅ 配置无效时使用默认槽位0

---

### 4. Logo_ShowBoot() - 开机显示激活槽位Logo ✅

**文件**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`

```c
void Logo_ShowBoot(void)
{
    // 加载配置获取激活槽位
    Logo_LoadConfig();
    uint8_t active = Logo_GetActiveSlot();
    
    // 尝试显示激活槽位的Logo
    if (Logo_IsSlotValid(active)) {
        Logo_ShowSlot(active);
        printf("[LOGO] Boot logo displayed (slot %d)\r\n", active);
        return;
    }
    
    // 激活槽位无效，尝试找第一个有效槽位
    for (uint8_t i = 0; i < LOGO_MAX_SLOTS; i++) {
        if (Logo_IsSlotValid(i)) {
            Logo_ShowSlot(i);
            printf("[LOGO] Boot logo displayed (fallback slot %d)\r\n", i);
            return;
        }
    }
    
    // 无任何有效Logo，显示默认
    uint16_t default_x = (240 - DEFAULT_LOGO_WIDTH) / 2;
    uint16_t default_y = (240 - DEFAULT_LOGO_HEIGHT) / 2;
    LCD_ShowPicture(default_x, default_y, DEFAULT_LOGO_WIDTH, DEFAULT_LOGO_HEIGHT, 
                   gImage_tou_xiang_154_154);
    printf("[LOGO] Boot logo displayed (default, centered)\r\n");
}
```

**验证结果**:
- ✅ 开机时调用 `Logo_LoadConfig()` 加载保存的配置
- ✅ 获取激活槽位并验证有效性
- ✅ 激活槽位有效时显示该槽位Logo
- ✅ 激活槽位无效时回退到第一个有效槽位
- ✅ 无有效Logo时显示默认图片

---

### 5. UI6按钮确认选择 - xuanniu.c ✅

**文件**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/xuanniu.c`

```c
// 按钮确认选择为开机Logo（短按，静默保存，无视觉反馈）
// 只在未触发长按且按键释放时处理
if (logo_ui_initialized && logo_slot_count > 0 && key_down == 1 && !logo_long_press_triggered) {
    if (Logo_IsSlotValid(logo_view_slot)) {
        Logo_SetActiveSlot(logo_view_slot);
        Logo_SaveConfig();
        // 不显示任何反馈，保持纯净
    }
}
```

**验证结果**:
- ✅ 短按按钮触发选择确认
- ✅ 调用 `Logo_SetActiveSlot()` 设置激活槽位
- ✅ 调用 `Logo_SaveConfig()` 保存到Flash
- ✅ 静默保存，无视觉反馈（保持界面纯净）
- ✅ 与长按删除功能正确区分

---

### 6. 开机调用链 ✅

**文件**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/lcd.c`

```c
void LCD_ui0()
{
    LCD_ShowPicture(0, 0, LCD_WIDTH, LCD_HEIGHT, gImage_beijing_240_240);
    // 🆕 显示自定义Logo（如果有）或默认Logo
    Logo_ShowBoot();  // 居中显示 (43, 43)
}
```

**验证结果**:
- ✅ `LCD_ui0()` 是开机界面函数
- ✅ 开机时调用 `Logo_ShowBoot()` 显示Logo
- ✅ 先显示背景，再显示Logo

---

## 数据流分析

### 选择开机Logo流程:
```
用户在UI6界面 → 旋钮切换到目标槽位 → 短按按钮确认
    ↓
Logo_SetActiveSlot(logo_view_slot)  // 设置内存中的激活槽位
    ↓
Logo_SaveConfig()  // 保存到Flash (0x160000)
    ↓
Flash存储: { magic: 0xBB66, active_slot: X, reserved: 0, checksum: 0 }
```

### 开机显示流程:
```
设备上电/重启
    ↓
LCD_ui0() 被调用
    ↓
Logo_ShowBoot()
    ↓
Logo_LoadConfig()  // 从Flash (0x160000) 读取配置
    ↓
验证 magic == 0xBB66 && active_slot < 3
    ↓
Logo_IsSlotValid(active_slot)  // 检查槽位是否有有效Logo
    ↓
Logo_ShowSlot(active_slot)  // 显示激活槽位的Logo
```

---

## 配置存储结构

```c
typedef struct {
    uint16_t magic;         // 0xBB66 配置有效标志
    uint8_t  active_slot;   // 当前激活的槽位 (0-2)
    uint8_t  reserved;      // 保留
    uint32_t checksum;      // 配置CRC32 (当前未使用)
} LogoConfig_t;  // 总大小: 8字节
```

**Flash地址**: `0x160000` (LOGO_CONFIG_ADDR)

---

## 硬件测试步骤

### 前置条件
- 设备已上传至少2张不同的Logo到不同槽位
- 设备能正常进入UI6 Logo界面

### 测试步骤

#### 测试1: 选择Slot 1作为开机Logo
1. 进入UI6 Logo界面
2. 旋转旋钮切换到Slot 1的Logo
3. 短按按钮确认选择
4. 关闭设备电源
5. 重新上电
6. **预期结果**: 开机显示Slot 1的Logo

#### 测试2: 选择Slot 2作为开机Logo
1. 进入UI6 Logo界面
2. 旋转旋钮切换到Slot 2的Logo
3. 短按按钮确认选择
4. 关闭设备电源
5. 重新上电
6. **预期结果**: 开机显示Slot 2的Logo

#### 测试3: 选择Slot 0作为开机Logo
1. 进入UI6 Logo界面
2. 旋转旋钮切换到Slot 0的Logo
3. 短按按钮确认选择
4. 关闭设备电源
5. 重新上电
6. **预期结果**: 开机显示Slot 0的Logo

#### 测试4: 配置持久化验证
1. 选择Slot 2作为开机Logo并确认
2. 断电等待10秒
3. 重新上电
4. **预期结果**: 开机显示Slot 2的Logo
5. 再次断电等待10秒
6. 重新上电
7. **预期结果**: 仍然显示Slot 2的Logo（配置持久化）

#### 测试5: 激活槽位被删除后的回退
1. 选择Slot 1作为开机Logo并确认
2. 长按删除Slot 1的Logo
3. 重启设备
4. **预期结果**: 开机显示第一个有效槽位的Logo（回退机制）

---

## 正确性属性验证

### P4: 配置持久化正确性 ✅
> Logo_SaveConfig() 后重启，Logo_LoadConfig() 能恢复相同的 active_slot 值

**代码验证**:
- `Logo_SaveConfig()` 将 `logo_active_slot` 写入Flash地址 `0x160000`
- `Logo_LoadConfig()` 从同一地址读取并恢复 `logo_active_slot`
- 使用 `magic` 标志 (0xBB66) 验证配置有效性

---

## 代码审查结论

✅ **所有关键功能已正确实现**:

1. **Logo_SetActiveSlot()** - 正确设置激活槽位
2. **Logo_SaveConfig()** - 正确保存配置到Flash
3. **Logo_LoadConfig()** - 正确从Flash加载配置
4. **Logo_ShowBoot()** - 正确显示激活槽位的Logo
5. **UI6按钮确认** - 正确调用保存函数

✅ **配置持久化机制完整**:
- 配置存储在独立的Flash地址 (0x160000)
- 使用magic标志验证配置有效性
- 开机时自动加载配置

✅ **回退机制完善**:
- 激活槽位无效时回退到第一个有效槽位
- 无有效Logo时显示默认图片

---

## 状态

**代码审查完成** - 代码已准备好进行硬件测试

测试人员可按照上述硬件测试步骤在实际设备上验证功能。
