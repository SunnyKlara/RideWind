# Implementation Plan

## 1. APP 端颜色预设数据扩展

- [x] 1.1 更新 `_ledColorCapsules` 列表从 8 条扩展到 12 条
  - 修改 `RideWind/lib/screens/device_connect_screen.dart`
  - 按照设计文档更新预设配置（注意：设计文档中的配色方案与原有不同，需要完全替换）：
    - 1: 赛博霓虹 (138,43,226)→(0,255,128) 渐变
    - 2: 冰晶青 (0,234,255) 纯色
    - 3: 日落熔岩 (255,100,0)→(0,200,255) 渐变
    - 4: 竞速黄 (255,210,0) 纯色
    - 5: 烈焰红 (255,0,0) 纯色
    - 6: 警灯双闪 (255,0,0)→(0,80,255) 渐变
    - 7: 樱花绯红 (255,105,180)→(255,0,80) 渐变
    - 8: 极光幻紫 (180,0,255)→(0,255,200) 渐变
    - 9: 暗夜紫晶 (148,0,211) 纯色
    - 10: 薄荷清风 (0,255,180)→(100,200,255) 渐变
    - 11: 丛林猛兽 (0,255,65) 纯色
    - 12: 纯净白 (225,225,225) 纯色
  - 确保每个预设包含 type, colors/color, led2, led3 字段
  - _Requirements: 1.1, 2.1, 2.2, 6.1_

- [ ]* 1.2 编写属性测试验证无重复颜色组合
  - **Property 2: No duplicate color combinations**
  - **Validates: Requirements 2.4**

- [ ]* 1.3 编写属性测试验证 1-8 预设向后兼容
  - **Property 6: Backward compatibility for presets 1-8**
  - **Validates: Requirements 6.1**

## 2. APP 端协议服务更新

- [x] 2.1 更新 `setLEDPreset` 方法的索引范围检查
  - 修改 `RideWind/lib/services/protocol_service.dart`
  - 将 `if (index < 1 || index > 8)` 改为 `if (index < 1 || index > 12)`
  - 更新错误日志信息和注释
  - _Requirements: 3.2, 6.2_

- [ ]* 2.2 编写属性测试验证预设索引验证逻辑
  - **Property 3: Preset index validation**
  - **Validates: Requirements 3.2**

- [ ]* 2.3 编写属性测试验证协议格式一致性
  - **Property 7: Protocol format consistency for new presets**
  - **Validates: Requirements 6.2**

## 3. Checkpoint - APP 端验证

- [x] 3. Checkpoint - 确保 APP 端修改正确
  - Ensure all tests pass, ask the user if questions arise.

## 4. 硬件端预设命令处理扩展

- [x] 4.1 更新 `rx.c` 中 PRESET 命令的范围检查和颜色定义
  - 修改 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/rx.c`
  - 将 `if(preset >= 1 && preset <= 8)` 改为 `if(preset >= 1 && preset <= 12)`
  - 在 switch 语句中更新 case 1-8 并添加 case 9-12 的颜色设置逻辑
  - RGB 值必须与 APP 端 `_ledColorCapsules` 和设计文档完全一致：
    - case 1: LED2=(138,43,226), LED3=(0,255,128)
    - case 2: LED2=(0,234,255), LED3=(0,234,255)
    - case 3: LED2=(255,100,0), LED3=(0,200,255)
    - case 4: LED2=(255,210,0), LED3=(255,210,0)
    - case 5: LED2=(255,0,0), LED3=(255,0,0)
    - case 6: LED2=(255,0,0), LED3=(0,80,255)
    - case 7: LED2=(255,105,180), LED3=(255,0,80)
    - case 8: LED2=(180,0,255), LED3=(0,255,200)
    - case 9: LED2=(148,0,211), LED3=(148,0,211)
    - case 10: LED2=(0,255,180), LED3=(100,200,255)
    - case 11: LED2=(0,255,65), LED3=(0,255,65)
    - case 12: LED2=(225,225,225), LED3=(225,225,225)
  - _Requirements: 3.2, 3.4, 6.2_

## 5. 硬件端预设界面函数扩展

- [x] 5.1 更新 `xuanniu.c` 中 `deng_ui2()` 函数
  - 修改 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/xuanniu.c`
  - 更新 case 1-8 并添加 case 9-12 的颜色定义
  - RGB 值必须与 APP 端和 rx.c 完全一致
  - _Requirements: 3.4, 4.5_

## 6. Checkpoint - 硬件端验证

- [x] 6. Checkpoint - 确保硬件端修改正确
  - Ensure all tests pass, ask the user if questions arise.

## 7. 集成验证

- [x] 7.1 验证软硬件颜色一致性
  - 对比 APP 端 `_ledColorCapsules` 和硬件端 `rx.c`/`xuanniu.c` 的 RGB 值
  - 确保 12 条预设的颜色定义完全一致
  - _Requirements: 4.5_

- [ ]* 7.2 编写属性测试验证舞台灯光亮度计算
  - **Property 1: Stage-light brightness calculation**
  - **Validates: Requirements 1.4**

- [ ]* 7.3 编写属性测试验证节流间隔
  - **Property 5: Throttle interval enforcement**
  - **Validates: Requirements 5.3**

## 8. Final Checkpoint - 完整功能验证

- [x] 8. Final Checkpoint - 确保所有功能正常
  - Ensure all tests pass, ask the user if questions arise.
