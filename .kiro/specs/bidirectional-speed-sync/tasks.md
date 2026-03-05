# Implementation Plan

## 1. 扩展协议服务支持速度报告解析

- [x] 1.1 在 protocol_service.dart 中已有基础协议支持
  - 已实现：setRunningSpeed 方法发送 SPEED:value 命令
  - 已实现：parseKnobDelta 解析旋钮增量 KNOB:delta
  - _Requirements: 6.2, 6.3_

- [x] 1.2 添加 SpeedReport 数据模型和解析方法
  - 创建 SpeedReport 类包含 speed, unit, timestamp, fromHardware 字段
  - 实现 parseSpeedReport 方法解析格式 `SPEED_REPORT:value:unit\n`
  - _Requirements: 2.2, 6.4_

- [x] 1.3 添加 speedReportStream 流控制器
  - 创建 StreamController<SpeedReport> 广播流
  - 在 _handleReceivedData 中检测并广播速度报告
  - _Requirements: 2.1, 2.2_

- [ ]* 1.4 编写属性测试：协议往返一致性
  - **Property 1: Protocol Round-Trip Consistency**
  - **Validates: Requirements 1.2, 1.4, 6.2, 6.3, 6.4, 6.5**

## 2. 扩展 Bluetooth Provider 支持双向速度同步

- [x] 2.1 已有基础速度同步支持
  - 已实现：setRunningSpeed 方法
  - 已实现：knobDeltaStream 监听旋钮增量
  - _Requirements: 3.2_

- [x] 2.2 添加 currentRunningSpeed 状态和 speedReportStream
  - 新增 _currentRunningSpeed 私有变量
  - 暴露 speedReportStream getter（转发 protocolService 的流）
  - _Requirements: 3.2, 3.4_

- [x] 2.3 实现防循环更新标志 _isReceivingReport
  - 接收硬件报告时设置标志为 true
  - 更新完成后重置为 false
  - 发送命令前检查标志
  - _Requirements: 3.3_

- [ ]* 2.4 编写属性测试：无反馈循环
  - **Property 4: No Feedback Loop**
  - **Validates: Requirements 3.3**

## 3. 修改 Running Mode Widget 支持外部速度流

- [x] 3.1 已有基础速度控制功能
  - 已实现：滚轮速度选择器
  - 已实现：onSpeedChanged 回调
  - 已实现：onThrottleStatusChanged 油门状态回调
  - _Requirements: 1.2_

- [x] 3.2 添加 externalSpeedStream 参数接收硬件速度报告
  - 新增可选参数 Stream<SpeedReport>? externalSpeedStream
  - 在 initState 中订阅流
  - 在 dispose 中取消订阅
  - _Requirements: 2.2_

- [x] 3.3 实现 _handleExternalSpeedReport 处理硬件速度更新
  - 更新 _currentSpeed 状态
  - 同步滚轮位置（使用 animateToItem）
  - 不触发 onSpeedChanged 回调（避免循环）
  - _Requirements: 2.2, 3.3_

- [ ]* 3.4 编写属性测试：速度计算正确性
  - **Property 3: Speed Calculation Correctness**
  - **Validates: Requirements 2.3, 3.1**

## 4. 实现命令节流机制

- [x] 4.1 在 Running Mode Widget 中添加命令节流逻辑
  - 已实现：使用 _uiUpdateInterval 控制蓝牙命令发送频率
  - 快速滑动时只发送最新值
  - _Requirements: 8.1_

- [x] 4.2 在 Bluetooth Provider 中添加节流包装方法
  - 创建 setRunningSpeedThrottled 方法
  - 内部维护节流状态（50ms 间隔）
  - _Requirements: 8.1_

- [ ]* 4.3 编写属性测试：命令节流
  - **Property 6: Command Throttling**
  - **Validates: Requirements 8.1**

## 5. Checkpoint - 确保所有测试通过
- Ensure all tests pass, ask the user if questions arise.

## 6. 硬件端实现速度报告上报

- [x] 6.1 已有旋钮增量上报功能
  - 已实现：BLE_ReportKnobDelta 函数上报 KNOB:delta
  - 已实现：Encoder() 函数中调用上报
  - _Requirements: 2.1_

- [x] 6.2 在 rx.c 中添加 BLE_ReportSpeed 函数
  - 格式化速度报告字符串 `SPEED_REPORT:value:unit\n`
  - 通过 UART2 发送
  - _Requirements: 2.1, 6.3_

- [x] 6.3 在 xuanniu.c 旋钮处理中调用绝对速度上报
  - 在 Encoder() 函数中检测 Num 值变化
  - 当 Num 值变化时调用 BLE_ReportSpeed 上报绝对速度
  - _Requirements: 2.1, 2.4_

- [x] 6.4 SPEED 命令处理已实现
  - 已实现：rx.c 中 SPEED 命令处理会更新 LCD 和 PWM
  - 已实现：软件消噪方案（二值输出）
  - _Requirements: 1.3_

- [ ]* 6.5 编写属性测试：查询响应格式
  - **Property 8: Query Response Format**
  - **Validates: Requirements 7.4**

## 7. 实现单位同步功能

- [x] 7.1 APP端单位切换已实现
  - 已实现：setSpeedUnit 方法发送 UNIT:0/1 命令
  - 已实现：Running Mode Widget 中 _isMetric 状态和 onUnitChanged 回调
  - _Requirements: 4.1, 4.4_

- [x] 7.2 硬件端单位切换已实现
  - 已实现：rx.c 中 UNIT 命令处理更新 speed_value 和 LCD
  - _Requirements: 4.2_

- [x] 7.3 扩展 parseSpeedReport 支持 unit 字段
  - 解析 SPEED_REPORT:value:unit 格式
  - 同步单位到 APP 显示
  - _Requirements: 4.3_

- [ ]* 7.4 编写属性测试：单位转换正确性
  - **Property 5: Unit Conversion Correctness**
  - **Validates: Requirements 4.3, 4.4**

## 8. 实现油门模式双向同步

- [x] 8.1 APP端油门模式控制已实现
  - 已实现：setHardwareThrottleMode 发送 THROTTLE:0/1 命令
  - 已实现：Running Mode Widget 中 onThrottleStatusChanged 回调
  - _Requirements: 5.1, 5.2_

- [x] 8.2 硬件端油门模式接收已实现
  - 已实现：rx.c 中 THROTTLE 命令处理
  - 已实现：调用 EngineAudio_Start/Stop
  - 已实现：远程控制模式状态机（防止本地干扰）
  - _Requirements: 5.3, 5.4_

- [x] 8.3 在硬件端添加 THROTTLE_REPORT 上报
  - 三击进入油门模式时发送 `THROTTLE_REPORT:1\n`
  - 退出时发送 `THROTTLE_REPORT:0\n`
  - _Requirements: 5.5_

- [x] 8.4 在 protocol_service.dart 中解析油门报告
  - 添加 parseThrottleReport 方法
  - 添加 throttleReportStream 流
  - _Requirements: 5.6_

- [x] 8.5 在 Bluetooth Provider 中监听油门报告
  - 订阅 throttleReportStream
  - 更新油门模式状态
  - _Requirements: 5.6_

- [ ]* 8.6 编写属性测试：油门模式独立性
  - **Property 7: Throttle Mode Independence**
  - **Validates: Requirements 5.4**

## 9. 实现断线重连状态同步

- [x] 9.1 在 Bluetooth Provider 中监听连接状态
  - 已实现：connectionStream 监听连接状态变化
  - 已实现：断开时清除 _connectedDevice
  - _Requirements: 7.1_

- [x] 9.2 硬件端查询命令已实现
  - 已实现：GET:FAN, GET:WUHUA, GET:ALL 等查询命令
  - 已实现：queryFanSpeedSync, queryAllStatusSync 等同步查询方法
  - _Requirements: 7.4_

- [x] 9.3 实现重连后自动查询硬件状态
  - 在 connectionStream 检测到重连时触发
  - 调用 queryAllStatusSync 获取当前状态
  - 同步到 APP 状态
  - _Requirements: 7.3, 7.5_

- [x] 9.4 在 Running Mode Widget 中显示连接状态
  - 断开时显示断开指示器
  - 重连后自动更新显示
  - _Requirements: 7.2_

## 10. 集成测试和状态一致性验证

- [ ]* 10.1 编写属性测试：状态一致性
  - **Property 2: Speed State Consistency**
  - **Validates: Requirements 3.2, 3.4**

- [ ]* 10.2 编写集成测试：APP→硬件同步
  - 模拟滑块操作
  - 验证命令发送和响应处理
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 10.3 编写集成测试：硬件→APP同步
  - 模拟硬件速度报告
  - 验证 UI 更新
  - _Requirements: 2.1, 2.2_

## 11. Final Checkpoint - 确保所有测试通过
- Ensure all tests pass, ask the user if questions arise.
