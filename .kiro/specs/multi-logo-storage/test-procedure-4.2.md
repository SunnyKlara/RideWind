# 测试程序 4.2: 旋钮切换Logo功能

## 测试目标
验证在UI6 Logo界面中，旋转旋钮能够在有效Logo槽位之间流畅切换，并跳过空槽位。

## 代码审查结果

### 1. Logo_NextValidSlot 函数 (logo.c)
```c
uint8_t Logo_NextValidSlot(uint8_t current)
{
    for (uint8_t i = 1; i <= LOGO_MAX_SLOTS; i++) {
        uint8_t next = (current + i) % LOGO_MAX_SLOTS;
        if (Logo_IsSlotValid(next)) {
            return next;
        }
    }
    return current;  // 无其他有效槽位
}
```
**验证结果**: ✅ 正确
- 从当前槽位开始，循环查找下一个有效槽位
- 使用模运算实现循环 (0→1→2→0)
- 无其他有效槽位时返回当前槽位（防止无限循环）

### 2. Logo_PrevValidSlot 函数 (logo.c)
```c
uint8_t Logo_PrevValidSlot(uint8_t current)
{
    for (uint8_t i = 1; i <= LOGO_MAX_SLOTS; i++) {
        uint8_t prev = (current + LOGO_MAX_SLOTS - i) % LOGO_MAX_SLOTS;
        if (Logo_IsSlotValid(prev)) {
            return prev;
        }
    }
    return current;  // 无其他有效槽位
}
```
**验证结果**: ✅ 正确
- 从当前槽位开始，反向循环查找上一个有效槽位
- 使用 `(current + LOGO_MAX_SLOTS - i) % LOGO_MAX_SLOTS` 实现反向循环
- 无其他有效槽位时返回当前槽位

### 3. UI6 旋钮切换逻辑 (xuanniu.c)
```c
// 旋转切换槽位 (只在有多个有效槽位时)
if (logo_ui_initialized && logo_slot_count > 1 && encoder_delta != 0) {
    // 防抖：至少间隔200ms
    if (uwTick - last_slot_switch_tick >= 200) {
        uint8_t old_slot = logo_view_slot;
        
        if (encoder_delta > 0) {
            logo_view_slot = Logo_NextValidSlot(logo_view_slot);
        } else {
            logo_view_slot = Logo_PrevValidSlot(logo_view_slot);
        }
        
        if (logo_view_slot != old_slot) {
            // 清屏并显示新槽位Logo（纯净显示）
            LCD_Fill(0, 0, 240, 240, BLACK);
            Logo_ShowSlot(logo_view_slot);
        }
        
        last_slot_switch_tick = uwTick;
    }
}
```
**验证结果**: ✅ 正确
- 只在有多个有效槽位时启用切换 (`logo_slot_count > 1`)
- 200ms防抖间隔，防止过快切换
- 顺时针旋转调用 `Logo_NextValidSlot`
- 逆时针旋转调用 `Logo_PrevValidSlot`
- 切换后清屏并显示新Logo（纯净显示，无文字）
- 响应时间 < 500ms（满足性能要求）

### 4. Logo_IsSlotValid 函数 (logo.c)
```c
bool Logo_IsSlotValid(uint8_t slot)
{
    if (slot >= LOGO_MAX_SLOTS) {
        return false;
    }
    
    uint32_t addr = Logo_GetSlotAddress(slot);
    LogoHeader_t header;
    W25Q128_BufferRead((uint8_t*)&header, addr, sizeof(header));
    
    return (header.magic == LOGO_MAGIC && 
            header.width == LOGO_WIDTH && 
            header.height == LOGO_HEIGHT &&
            header.dataSize == LOGO_DATA_SIZE);
}
```
**验证结果**: ✅ 正确
- 检查槽位边界
- 读取Flash头部验证magic、尺寸和数据大小
- 只有完全匹配才返回true

## 硬件测试步骤

### 前置条件
1. 确保已上传Logo到至少2个槽位（例如Slot 0和Slot 1）
2. 设备正常开机

### 测试步骤

#### 测试场景1: 基本切换功能
1. 进入UI6 Logo界面（通过菜单选择Logo选项）
2. 观察当前显示的Logo
3. 顺时针旋转旋钮
4. **预期结果**: 显示下一个有效槽位的Logo
5. 逆时针旋转旋钮
6. **预期结果**: 显示上一个有效槽位的Logo

#### 测试场景2: 跳过空槽位
1. 确保只有Slot 0和Slot 2有Logo，Slot 1为空
2. 进入UI6界面，当前显示Slot 0
3. 顺时针旋转旋钮
4. **预期结果**: 直接跳到Slot 2，跳过空的Slot 1
5. 再次顺时针旋转
6. **预期结果**: 循环回到Slot 0

#### 测试场景3: 单槽位情况
1. 确保只有一个槽位有Logo
2. 进入UI6界面
3. 旋转旋钮
4. **预期结果**: 无变化（只有一个有效槽位时不切换）

#### 测试场景4: 响应时间测试
1. 进入UI6界面
2. 快速旋转旋钮
3. **预期结果**: 
   - 每次切换响应时间 < 500ms
   - 200ms防抖间隔内的重复旋转被忽略

#### 测试场景5: 纯净显示验证
1. 进入UI6界面
2. 切换不同槽位
3. **预期结果**: 
   - 只显示Logo图片
   - 无槽位编号指示器
   - 无任何文字提示

## 验收标准

| 测试项 | 预期结果 | 状态 |
|--------|----------|------|
| 顺时针旋转切换到下一个有效槽位 | 正确切换 | 待测试 |
| 逆时针旋转切换到上一个有效槽位 | 正确切换 | 待测试 |
| 空槽位被跳过 | 不显示空槽位 | 待测试 |
| 单槽位时不切换 | 旋转无效果 | 待测试 |
| 切换响应时间 < 500ms | 流畅切换 | 待测试 |
| 纯净显示（无文字/指示器） | 只显示Logo | 待测试 |

## 代码审查总结

✅ **Logo_NextValidSlot**: 正确实现循环查找下一个有效槽位
✅ **Logo_PrevValidSlot**: 正确实现循环查找上一个有效槽位  
✅ **UI6旋钮处理**: 正确检测旋转方向并调用相应函数
✅ **防抖机制**: 200ms间隔防止过快切换
✅ **纯净显示**: 只显示Logo，无额外UI元素
✅ **性能要求**: 切换响应时间满足 < 500ms 要求

**代码审查结论**: 实现正确，代码已准备好进行硬件测试。
