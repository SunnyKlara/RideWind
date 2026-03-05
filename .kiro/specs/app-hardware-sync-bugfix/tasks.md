# 实现计划: APP与硬件协同Bug修复

## 概述

本计划将5个bug修复分解为可执行的编码任务，按照依赖关系排序，确保每个任务都能独立验证。

## 任务

- [x] 1. 流水灯功能对接
  - [x] 1.1 在protocol_service.dart中添加流水灯协议命令
    - 添加 `setStreamlightMode(bool enable)` 方法发送 `STREAMLIGHT:0/1` 命令
    - 添加 `parseStreamlightReport(String response)` 方法解析硬件报告
    - 添加 `_streamlightReportController` 流控制器
    - _Requirements: 1.1, 1.2_
  
  - [x] 1.2 在bluetooth_provider.dart中添加流水灯状态管理
    - 添加 `_streamlightStatus` 状态变量
    - 添加 `streamlightStream` getter暴露流水灯状态流
    - 在 `_handleReceivedData` 中解析流水灯报告
    - _Requirements: 1.3_
  
  - [x] 1.3 修改device_connect_screen.dart中的流水灯逻辑
    - 修改 `_startCycleAnimation()` 调用 `setStreamlightMode(true)`
    - 修改 `_stopCycleAnimation()` 调用 `setStreamlightMode(false)`
    - 订阅 `streamlightStream` 同步硬件状态
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [x] 1.4 在硬件端rx.c中添加STREAMLIGHT命令处理
    - 解析 `STREAMLIGHT:0/1` 命令
    - 设置 `deng_2or3` 变量
    - 返回 `OK:STREAMLIGHT:n` 确认
    - _Requirements: 1.4_
  
  - [ ]* 1.5 编写流水灯命令发送属性测试
    - **Property 1: 流水灯命令发送正确性**
    - **Validates: Requirements 1.1, 1.2**

- [x] 2. RGB调色界面刷新卡顿修复
  - [x] 2.1 创建colorize_throttler.dart节流器类
    - 实现 `ColorizeThrottler` 类
    - 添加 `canSend()` 方法检查50ms间隔
    - 添加 `reset()` 方法重置节流器
    - _Requirements: 2.1, 2.5_
  
  - [x] 2.2 在device_connect_screen.dart中集成节流器
    - 在RGB滑动回调中使用 `ColorizeThrottler`
    - 修改 `_syncAllLEDColors()` 使用节流器
    - 确保滑动结束后发送最终颜色值
    - _Requirements: 2.1, 2.5_
  
  - [x] 2.3 优化硬件端rx.c的LED命令处理
    - 检测连续LED命令（100ms内多次）
    - 连续命令时简化LCD刷新（只显示字母）
    - 500ms无命令后恢复完整显示
    - _Requirements: 2.2, 2.3, 2.4_
  
  - [ ]* 2.4 编写RGB调色节流属性测试
    - **Property 2: RGB调色命令节流**
    - **Validates: Requirements 2.1, 2.5**

- [x] 3. Checkpoint - 确保流水灯和RGB调色修复正常工作
  - 运行所有测试，确保通过
  - 如有问题请询问用户

- [x] 4. 倒三角指示器颜色匹配
  - [x] 4.1 在protocol_service.dart中添加预设查询命令
    - 添加 `queryCurrentPreset()` 方法发送 `GET:PRESET` 命令
    - 确保 `parsePresetReport()` 正确解析响应
    - _Requirements: 3.1_
  
  - [x] 4.2 修改device_connect_screen.dart进入Colorize模式时查询预设
    - 在 `_onModePageChanged` 切换到Colorize时查询预设
    - 订阅 `presetReportStream` 更新 `_selectedColorIndex`
    - 调用 `_colorPageController.animateToPage()` 定位指示器
    - _Requirements: 3.1, 3.2, 3.3_
  
  - [x] 4.3 添加预设索引本地缓存逻辑
    - 在 `_saveDeviceSettings()` 中保存当前预设索引
    - 在 `_restoreUserPreferences()` 中恢复预设索引
    - 查询超时时使用缓存值
    - _Requirements: 3.4, 3.5_
  
  - [ ]* 4.4 编写预设同步属性测试
    - **Property 3: 预设索引同步正确性**
    - **Property 4: 颜色预设本地存储一致性**
    - **Validates: Requirements 3.2, 3.3, 3.5**

- [x] 5. 雾化器显示优化
  - [x] 5.1 创建airflow_indicator_controller.dart控制器
    - 实现 `AirflowIndicatorController` 类
    - 添加 `showOnIndicator()` 方法（1.5秒后隐藏）
    - 添加 `showOffIndicator()` 方法（1秒后隐藏）
    - 使用 `ValueNotifier` 管理可见性状态
    - _Requirements: 4.1, 4.2, 4.4_
  
  - [x] 5.2 修改device_connect_screen.dart中的雾化器显示逻辑
    - 移除 `_isAirflowStarted` 直接控制指示器显示
    - 集成 `AirflowIndicatorController`
    - 开启时调用 `showOnIndicator()`，关闭时调用 `showOffIndicator()`
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [x] 5.3 添加雾化器指示器动画效果
    - 使用 `AnimatedOpacity` 实现淡入淡出
    - 添加缩放动画增强视觉效果
    - _Requirements: 4.5_
  
  - [ ]* 5.4 编写雾化器指示器属性测试
    - **Property 5: 雾化器指示器显示时长**
    - **Property 6: 雾化器指示器非持续显示**
    - **Validates: Requirements 4.1, 4.2, 4.3**

- [x] 6. Checkpoint - 确保倒三角和雾化器修复正常工作
  - 运行所有测试，确保通过
  - 如有问题请询问用户

- [x] 7. 油门加速数字跳动效果
  - [x] 7.1 创建throttle_accelerator.dart乱序递增类
    - 实现 `ThrottleAccelerator` 类
    - 添加 `getNextStep()` 方法返回1-3随机步长
    - 添加 `getFallbackStep()` 方法返回固定步长1
    - _Requirements: 5.1, 5.4_
  
  - [x] 7.2 创建speed_bounce_animation.dart弹跳动画类
    - 实现缩放动画（1.0 → 1.3 → 1.0）
    - 实现位移动画（0 → -15 → 0）
    - 使用 `Curves.bounceOut` 曲线
    - _Requirements: 5.2, 5.3_
  
  - [x] 7.3 修改running_mode_widget.dart集成乱序加速
    - 替换 `_baseAccelerationStep` 为 `ThrottleAccelerator`
    - 在 `_accelerate()` 中使用乱序步长
    - 添加回退逻辑（异常时使用固定步长1）
    - _Requirements: 5.1, 5.4_
  
  - [x] 7.4 在running_mode_widget.dart中集成弹跳动画
    - 在速度数字Widget中添加 `AnimatedBuilder`
    - 每次速度变化时触发弹跳动画
    - 配合震动反馈增强节奏感
    - _Requirements: 5.2, 5.3, 5.5_
  
  - [x] 7.5 确保动画不影响速度同步准确性
    - 验证动画过程中 `_currentSpeed` 值正确
    - 验证 `onSpeedChanged` 回调传递正确速度
    - _Requirements: 5.6_
  
  - [ ]* 7.6 编写油门加速属性测试
    - **Property 7: 油门加速步长范围**
    - **Property 8: 油门加速速度准确性**
    - **Validates: Requirements 5.1, 5.4, 5.6**

- [x] 8. Final Checkpoint - 确保所有修复正常工作
  - 运行所有测试，确保通过
  - 如有问题请询问用户

## 备注

- 标记 `*` 的任务为可选测试任务，可跳过以加快MVP开发
- 每个任务都引用了具体的需求条款以确保可追溯性
- Checkpoint任务用于增量验证，确保每个阶段的修复都能正常工作
- 属性测试验证通用正确性属性，覆盖多种输入情况
