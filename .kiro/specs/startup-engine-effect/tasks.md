# Implementation Plan: Startup Engine Effect

## Overview

本实现计划将"开机双闪+引擎声"功能分解为可执行的编码任务。**关键变更**：双闪和引擎声与LCD开机Logo动画同步展示，而不是在Logo动画之后。

实现顺序：先完成STM32硬件端修改（修改开机流程），再完成Flutter APP端扩展，最后进行集成测试。

## Tasks

- [x] 1. STM32硬件端：修改开机流程实现同步启动
  - [x] 1.1 创建 Startup_TaillightFlash_NoDelay() 函数
    - 在 `main.c` 中添加新函数 `Startup_TaillightFlash_NoDelay()`
    - 移除原函数中的500ms前置延迟
    - 保留双闪逻辑：2次红色闪烁（300ms亮+300ms灭）+ 200ms保持
    - 总时长约1400ms，确保在2秒Logo显示期间内完成
    - _Requirements: 1.1, 1.2, 1.4, 1.5_

  - [x] 1.2 修改 main() 函数开机流程
    - 在 `LCD_ui0()` 调用后立即添加 `printf("ENGINE_START\n")`
    - 调用 `Startup_TaillightFlash()` 执行双闪（已移除前置延迟）
    - 在双闪结束后添加 `printf("ENGINE_READY\n")`
    - _Requirements: 2.1, 2.2, 2.4, 4.1, 4.2_

- [x] 2. Flutter APP端：扩展协议服务
  - [x] 2.1 在 ProtocolService 中添加引擎通知解析和事件流
    - 添加 `_engineNotificationController` StreamController
    - 添加 `engineNotificationStream` getter
    - 实现 `parseEngineNotification()` 方法解析 ENGINE_START 和 ENGINE_READY
    - 在 `_parseProactiveReport()` 中调用引擎通知解析
    - 在 `dispose()` 中关闭新的 StreamController
    - _Requirements: 3.1, 4.3_

  - [ ]* 2.2 编写 ProtocolService 引擎通知解析单元测试
    - 测试 parseEngineNotification 正确解析 ENGINE_START
    - 测试 parseEngineNotification 正确解析 ENGINE_READY
    - 测试无效命令返回 null
    - _Requirements: 3.1_

- [x] 3. Flutter APP端：扩展引擎音效控制器
  - [x] 3.1 在 EngineAudioController 中添加 playStartupSound() 方法
    - 实现 `playStartupSound()` 方法播放 engine_start.mp3
    - 设置初始音量为 85% (0.85)
    - 从头开始播放（position = 0）
    - 添加错误处理，播放失败时静默降级
    - _Requirements: 3.1, 3.2, 3.5, 5.2, 5.3_

  - [ ]* 3.2 编写属性测试：音频失败优雅降级
    - **Property 7: Audio Failure Graceful Degradation**
    - **Validates: Requirements 5.2, 5.3**
    - 测试各种错误类型下 playStartupSound 不抛出异常

  - [x] 3.3 添加启动声到循环声的过渡逻辑
    - 使用 onPlayerComplete 监听实现循环播放
    - 根据速度状态自动切换到对应音效（idle/accel/high）
    - _Requirements: 3.3_

- [x] 4. Checkpoint - 确保所有测试通过
  - 运行 Flutter 单元测试验证协议解析和音效控制器
  - 确保所有测试通过，如有问题请询问用户

- [x] 5. Flutter APP端：集成引擎启动通知监听
  - [x] 5.1 在设备连接服务中订阅引擎通知
    - 创建 EngineAudioManager 全局单例管理器
    - 在 main.dart 中初始化引擎音效管理器
    - 在 BluetoothProvider.connectToDevice() 成功后绑定管理器
    - 收到 ENGINE_START 时调用 `engineAudioController.playStartupSound()`
    - 收到 ENGINE_READY 时记录日志
    - _Requirements: 3.1, 3.4, 4.3_

  - [ ]* 5.2 编写属性测试：APP音频响应
    - **Property 3: APP Audio Response to ENGINE_START**
    - **Validates: Requirements 3.1**
    - 测试收到 ENGINE_START 命令后音频开始播放

- [x] 6. 集成与验证
  - [x] 6.1 端到端功能验证
    - 编译并烧录 STM32 固件
    - 在 Flutter APP 中连接设备
    - 重启硬件验证：Logo显示时双闪和引擎声同步出现
    - _Requirements: 4.1, 4.2, 4.5_

  - [ ]* 6.2 编写集成测试
    - 模拟 BLE 收到 ENGINE_START 命令
    - 验证音频播放器被调用
    - 验证播放延迟在 100ms 内
    - _Requirements: 4.3_

- [x] 7. Final Checkpoint - 确保所有测试通过
  - 运行所有单元测试和属性测试
  - 验证 STM32 编译无错误
    - 确保所有测试通过，如有问题请询问用户

- [x] 8. STM32硬件端：实现音量调节界面 (UI6)
  - [x] 8.1 添加音量全局变量和Flash存储
    - 在 `xuanniu.c` 中添加 `volume` 和 `volume_old` 变量
    - 在 `deng_init()` 中从Flash读取音量设置
    - 在 `deng_update()` 中保存音量到Flash
    - _Requirements: 6.6_

  - [x] 8.2 实现 LCD_ui6() 音量界面初始化函数
    - 在 `lcd.c` 中实现 `LCD_ui6()` 函数
    - 显示背景、Voice图标和"Voice"文字
    - 复用亮度界面的数字显示位置参数
    - _Requirements: 6.1, 6.5_

  - [x] 8.3 实现 LCD_ui6_num_update() 数字更新函数
    - 复用 `LCD_ui4_num_update()` 的逻辑显示0-100数字
    - 确保数字位数变化时正确清除旧数字
    - _Requirements: 6.2_

  - [x] 8.4 实现 volume_ui6() 音量调节处理函数
    - 在 `xuanniu.c` 中实现编码器控制音量
    - 调用 `VS1003_SetVolumePercent()` 更新实际音量
    - 限制音量范围在0-100之间
    - _Requirements: 6.3, 6.4_

  - [x] 8.5 在主循环中集成UI6界面
    - 在 `main.c` 的 while(1) 循环中添加 ui==6 的处理
    - 确保界面切换和编码器响应正常
    - _Requirements: 6.1, 6.3_

- [x] 9. STM32硬件端：修复长按松手触发单击的Bug
  - [x] 9.1 添加长按触发标志位
    - 在 `xuanniu.c` 中添加 `static uint8_t long_press_triggered = 0` 变量
    - 在按键按下时重置标志位
    - _Requirements: 7.4_

  - [x] 9.2 修改长按检测逻辑
    - 当按住超过500ms时设置 `long_press_triggered = 1`
    - 确保长按动作只触发一次
    - _Requirements: 7.2, 7.4_

  - [x] 9.3 修改按键释放逻辑
    - 在释放时检查 `long_press_triggered` 标志
    - 只有标志为0时才执行单击动作（切换单位）
    - 长按释放后不触发单击
    - _Requirements: 7.1, 7.3, 7.5_

- [x] 10. STM32硬件端：实现油门模式数字跳跃动画
  - [x] 10.1 实现 LCD_Speed_Update_Animated() 函数
    - 在 `lcd.c` 中添加带跳跃效果的速度更新函数
    - 根据速度变化量计算跳跃偏移（3-8像素）
    - 实现两帧动画：向上跳跃 → 回到原位
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 10.2 在油门模式中集成动画函数
    - 修改油门模式的速度显示逻辑
    - 当速度变化时调用动画更新函数
    - 确保动画不阻塞主循环太久（<100ms）
    - _Requirements: 8.4, 8.5_

- [x] 11. STM32硬件端：修复油门模式旋转退出Bug
  - [x] 11.1 修改菜单切换逻辑的条件判断
    - 在 `Encoder()` 函数中，菜单切换逻辑添加 `wuhuaqi_state != 2` 条件
    - 确保油门模式下不触发菜单切换
    - _Requirements: 9.1, 9.4_

  - [x] 11.2 修改油门模式退出逻辑
    - 旋转退出时强制设置 `ui = 1`（保持在调速界面）
    - 不修改 `menu_selected` 值
    - 退出后立即 `return`，不执行后续逻辑
    - _Requirements: 9.2, 9.3, 9.5_

- [x] 12. STM32硬件端：实现流水灯平滑渐变过渡
  - [x] 12.1 创建渐变状态管理结构体和变量
    - 定义 `LED_Gradient_t` 结构体（当前颜色、目标颜色、帧数等）
    - 创建三组LED的渐变状态数组
    - _Requirements: 10.1_

  - [x] 12.2 实现 LED_StartGradient() 函数
    - 设置目标颜色和过渡时间
    - 根据速度模式计算帧数（快速25帧/正常75帧/慢速150帧）
    - 保存当前颜色作为起点
    - _Requirements: 10.4_

  - [x] 12.3 实现 LED_GradientProcess() 渐变处理函数
    - 50fps刷新率控制（每20ms执行一次）
    - 使用线性插值计算当前帧颜色
    - 批量更新三组LED
    - _Requirements: 10.2, 10.3, 10.5, 10.6_

  - [x] 12.4 修改蓝牙流水灯指令处理
    - 收到流水灯指令时调用 `LED_StartGradient()` 而不是直接设置颜色
    - 解析速度参数（快/正常/慢）
    - _Requirements: 10.4, 10.7_

  - [x] 12.5 在主循环中集成渐变处理
    - 在 `while(1)` 中添加 `LED_GradientProcess()` 调用
    - 确保不阻塞其他功能
    - _Requirements: 10.3_

- [x] 13. Flutter APP端：专业赛车引擎音频处理
  - [x] 13.1 分析并提取专业赛车引擎音频片段
    - 使用Python pydub分析9分钟源音频的响度曲线
    - 识别启动、怠速、加速、高转速等不同段落
    - 提取最佳音频片段并添加淡入淡出效果
    - 输出文件：engine_start.mp3, engine_idle.mp3, engine_accel.mp3, engine_high.mp3
    - _Requirements: 11.1, 11.2_

  - [x] 13.2 更新 EngineAudioController 支持多音频切换
    - 添加 _engineStart, _engineIdle, _engineAccel, _engineHigh 音频文件常量
    - 添加 _currentEngineState 状态变量（idle/accel/high）
    - 添加 _startPlayer 独立播放器用于启动音效
    - 实现 playStartupSound() 方法播放启动音效
    - _Requirements: 11.6_

  - [x] 13.3 实现基于速度的智能音效切换
    - 在 updateSpeed() 中根据速度阈值切换音效
    - 速度 < 30: 播放 engine_idle.mp3
    - 速度 30-150: 播放 engine_accel.mp3
    - 速度 > 150: 播放 engine_high.mp3
    - 使用 onPlayerComplete 监听实现循环播放
    - _Requirements: 11.3_

  - [x] 13.4 实现动态音量和音调调整
    - 根据速度动态调整音量（0.45-0.95）
    - 根据加速/减速状态调整播放速率（0.95-1.12）
    - 使用平方曲线让低速时音量变化更敏感
    - _Requirements: 11.4, 11.5_

## Notes

- 任务标记 `*` 的为可选测试任务，可跳过以加快 MVP 开发
- 每个任务都引用了具体的需求条款以便追溯
- **关键变更**：双闪现在与Logo动画同步，而不是在Logo之后
- **新增功能**：UI6音量调节界面，模仿UI4亮度界面
- **音频升级**：使用专业赛车引擎音频，智能切换不同驾驶状态
- STM32 代码修改需要重新编译和烧录
- Flutter 测试使用 `flutter test` 命令运行
- 属性测试验证通用正确性属性，最少运行 100 次迭代
