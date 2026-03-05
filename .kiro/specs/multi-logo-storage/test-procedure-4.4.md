# 测试程序 4.4: 长按删除功能测试

## 概述
本文档记录了对长按删除Logo功能的代码审查和硬件测试程序。

## 代码审查结果

### 1. xuanniu.c - UI6长按删除实现 ✅

**位置**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/xuanniu.c` (行 1984-2108)

**关键变量**:
```c
static uint32_t logo_key_press_tick = 0;    // 长按计时起点
static uint8_t logo_long_press_triggered = 0; // 长按已触发标志
```

**长按检测逻辑** (≥2秒):
```c
// 检测按键按下边沿，记录按下时间
if (logo_ui_initialized && key_now == 1 && key_old == 0) {
    logo_key_press_tick = uwTick;
    logo_long_press_triggered = 0;  // 重置长按标志
}

// 长按检测（≥2000ms = 2秒）
if (logo_ui_initialized && logo_slot_count > 0 && key_now == 1 && 
    !logo_long_press_triggered && uwTick - logo_key_press_tick >= 2000) {
    // 长按触发：删除当前槽位
    Logo_DeleteSlot(logo_view_slot);
    // ...
}
```

**验证点**:
- ✅ 长按阈值正确设置为2000ms (2秒)
- ✅ 使用 `logo_long_press_triggered` 防止重复触发
- ✅ 只在有有效Logo时才允许删除 (`logo_slot_count > 0`)
- ✅ 删除后正确调用 `Logo_DeleteSlot()`

**删除后自动切换逻辑**:
```c
if (logo_slot_count > 0) {
    // 切换到下一个有效槽位
    logo_view_slot = Logo_NextValidSlot(logo_view_slot);
    // 如果NextValidSlot返回的槽位无效，找第一个有效的
    if (!Logo_IsSlotValid(logo_view_slot)) {
        for (uint8_t i = 0; i < 3; i++) {
            if (Logo_IsSlotValid(i)) {
                logo_view_slot = i;
                break;
            }
        }
    }
    // 清屏并显示新槽位Logo
    LCD_Fill(0, 0, 240, 240, BLACK);
    Logo_ShowSlot(logo_view_slot);
} else {
    // 无有效Logo，显示默认开机画面
    LCD_Fill(0, 0, 240, 240, BLACK);
    Logo_ShowBoot();
}
```

**验证点**:
- ✅ 删除后重新统计有效槽位数量
- ✅ 有剩余Logo时自动切换到下一个有效槽位
- ✅ 无有效Logo时显示默认开机画面 (`Logo_ShowBoot()`)
- ✅ 静默删除，不显示任何反馈文字

**短按/长按区分**:
```c
// 按钮确认选择为开机Logo（短按，静默保存）
// 只在未触发长按且按键释放时处理
if (logo_ui_initialized && logo_slot_count > 0 && key_down == 1 && !logo_long_press_triggered) {
    if (Logo_IsSlotValid(logo_view_slot)) {
        Logo_SetActiveSlot(logo_view_slot);
        Logo_SaveConfig();
    }
}
```

**验证点**:
- ✅ 使用 `!logo_long_press_triggered` 确保长按后不触发短按
- ✅ 使用 `key_state = 0xFF` 标记长按已处理

---

### 2. logo.c - Logo_DeleteSlot() 实现 ✅

**位置**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c` (行 ~520-550)

```c
void Logo_DeleteSlot(uint8_t slot)
{
    if (slot >= LOGO_MAX_SLOTS) {
        printf("[LOGO] DeleteSlot: invalid slot %d\r\n", slot);
        return;
    }
    
    uint32_t addr = Logo_GetSlotAddress(slot);
    
    // 擦除槽位的Flash扇区（清除magic标志使其无效）
    // 只需擦除第一个扇区即可使header无效
    W25Q128_EraseSector(addr);
    
    printf("[LOGO] Slot %d deleted (addr=0x%08lX)\r\n", slot, (unsigned long)addr);
    
    // 如果删除的是激活槽位，重置为第一个有效槽位
    if (slot == Logo_GetActiveSlot()) {
        for (uint8_t i = 0; i < LOGO_MAX_SLOTS; i++) {
            if (Logo_IsSlotValid(i)) {
                Logo_SetActiveSlot(i);
                Logo_SaveConfig();
                printf("[LOGO] Active slot changed to %d after deletion\r\n", i);
                return;
            }
        }
        // 无有效槽位，重置为0
        Logo_SetActiveSlot(0);
        Logo_SaveConfig();
        printf("[LOGO] No valid slots, active slot reset to 0\r\n");
    }
}
```

**验证点**:
- ✅ 参数验证：检查槽位范围 (0-2)
- ✅ 正确计算槽位Flash地址
- ✅ 擦除Flash扇区使header的magic标志无效
- ✅ 如果删除的是激活槽位，自动切换到下一个有效槽位
- ✅ 无有效槽位时重置激活槽位为0
- ✅ 保存配置到Flash

---

### 3. logo.h - 函数声明 ✅

**位置**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/logo.h`

```c
// 删除指定槽位的Logo
void Logo_DeleteSlot(uint8_t slot);
```

---

## 硬件测试程序

### 前置条件
1. 设备已刷入最新固件
2. APP已安装并可连接设备
3. 准备3张不同的测试Logo图片

### 测试步骤

#### 测试1: 删除单个Logo
1. 通过APP上传Logo到Slot 0
2. 进入UI6 Logo界面
3. 长按按钮≥2秒
4. **预期结果**: 
   - Logo被删除
   - 显示默认开机画面
   - 无任何文字反馈

#### 测试2: 删除后自动切换
1. 通过APP上传Logo到Slot 0, 1, 2
2. 进入UI6 Logo界面
3. 旋转旋钮切换到Slot 1
4. 长按按钮≥2秒删除Slot 1
5. **预期结果**:
   - Slot 1被删除
   - 自动切换显示Slot 2的Logo
   - 旋转旋钮只能在Slot 0和Slot 2之间切换

#### 测试3: 删除激活槽位
1. 上传Logo到Slot 0, 1, 2
2. 进入UI6，切换到Slot 1
3. 短按确认Slot 1为开机Logo
4. 长按删除Slot 1
5. 重启设备
6. **预期结果**:
   - 开机显示Slot 0或Slot 2的Logo（自动切换到下一个有效槽位）

#### 测试4: 删除所有Logo
1. 上传Logo到Slot 0, 1, 2
2. 进入UI6
3. 依次长按删除所有3个Logo
4. **预期结果**:
   - 删除最后一个Logo后显示默认开机画面
   - 重启后显示默认开机画面

#### 测试5: 短按/长按区分
1. 上传Logo到Slot 0, 1
2. 进入UI6，显示Slot 0
3. 短按按钮（<2秒）
4. **预期结果**: Slot 0被设为开机Logo，Logo不被删除
5. 长按按钮（≥2秒）
6. **预期结果**: Slot 0被删除，自动切换到Slot 1

---

## 符合性检查

| 需求 | 实现状态 | 说明 |
|------|----------|------|
| 5.1 长按≥2秒删除 | ✅ | `uwTick - logo_key_press_tick >= 2000` |
| 5.2 清除Flash数据 | ✅ | `W25Q128_EraseSector(addr)` 使header无效 |
| 5.3 删除后自动切换 | ✅ | `Logo_NextValidSlot()` + 显示新槽位 |
| 5.4 无Logo显示默认 | ✅ | `Logo_ShowBoot()` 显示默认画面 |
| 5.5 静默删除 | ✅ | 无任何反馈文字 |

---

## 结论

代码审查通过。长按删除功能的实现完全符合设计规范：
1. 长按检测阈值正确设置为2秒
2. Flash扇区擦除正确实现
3. 删除后自动切换逻辑正确
4. 无Logo时正确显示默认画面
5. 静默操作，无视觉反馈

**状态**: 代码审查完成，等待硬件测试验证
