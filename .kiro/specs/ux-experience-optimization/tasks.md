# Implementation Plan: UX Experience Optimization

## Overview

本实现计划将 RideWind 应用的操作体验优化分解为可执行的编码任务。实现顺序遵循依赖关系：先实现基础服务层，再实现 UI 组件，最后集成到现有页面。

## Tasks

- [x] 1. 实现首次启动管理服务
  - [x] 1.1 创建 FirstLaunchManager 服务类
    - 在 `lib/services/` 目录下创建 `first_launch_manager.dart`
    - 实现 `isFirstLaunch()` 方法检测首次启动状态
    - 实现 `markOnboardingComplete()` 方法标记引导完成
    - 实现 `reset()` 方法用于测试和调试
    - 使用 SharedPreferences 持久化状态
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  
  - [x] 1.2 编写 FirstLaunchManager 属性测试
    - **Property 1: First Launch State Round-Trip**
    - **Validates: Requirements 1.1, 1.2, 1.4**

- [x] 2. 实现功能引导服务
  - [x] 2.1 创建 FeatureGuideService 服务类
    - 在 `lib/services/` 目录下创建 `feature_guide_service.dart`
    - 定义 `GuideType` 枚举（runningMode, colorizeMode, logoUpload, deviceConnect）
    - 实现 `shouldShowGuide(GuideType)` 方法
    - 实现 `markGuideComplete(GuideType)` 方法
    - 实现 `resetAllGuides()` 方法
    - _Requirements: 3.1, 3.2, 3.3, 3.5_
  
  - [x] 2.2 编写 FeatureGuideService 属性测试
    - **Property 2: Feature Guide State Round-Trip**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.5**

- [x] 3. 实现用户偏好存储服务
  - [x] 3.1 创建 PreferenceService 服务类
    - 在 `lib/services/` 目录下创建 `preference_service.dart`
    - 实现颜色预设索引的保存和读取
    - 实现速度值的保存和读取
    - 实现雾化器状态的保存和读取
    - 实现设备特定设置的保存和读取（JSON 序列化）
    - _Requirements: 9.1, 9.2, 9.3, 9.5_
  
  - [x] 3.2 编写 PreferenceService 属性测试
    - **Property 3: Preference Storage Round-Trip**
    - **Property 4: Device Settings Round-Trip**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.5**

- [x] 4. Checkpoint - 确保所有服务层测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [x] 5. 实现引导覆盖层 UI 组件
  - [x] 5.1 创建 GuideStep 和 GuideConfiguration 数据模型
    - 在 `lib/models/` 目录下创建 `guide_models.dart`
    - 定义 `GuideStep` 类（targetKey, title, description, position, icon）
    - 定义 `GuideConfiguration` 类（featureId, steps, canSkip, stepDelay）
    - 定义 `TooltipPosition` 枚举
    - _Requirements: 3.4, 3.6_
  
  - [x] 5.2 创建 GuideOverlay Widget
    - 在 `lib/widgets/` 目录下创建 `guide_overlay.dart`
    - 实现高亮遮罩层（HighlightMask）
    - 实现提示框组件（TooltipWidget）
    - 实现步骤导航逻辑（下一步、跳过、完成）
    - 支持动画过渡效果
    - _Requirements: 3.4, 3.6_
  
  - [x] 5.3 编写 GuideOverlay Widget 测试
    - 测试步骤导航功能
    - 测试跳过和完成回调
    - _Requirements: 3.4_

- [x] 6. 实现反馈服务
  - [x] 6.1 创建 FeedbackService 服务类
    - 在 `lib/services/` 目录下创建 `feedback_service.dart`
    - 实现 `haptic(HapticType)` 方法提供触觉反馈
    - 实现 `showSuccess(context, message)` 方法显示成功提示
    - 实现 `showError(context, message, onRetry)` 方法显示错误提示
    - 实现 `showLoading(context, message)` 方法显示加载指示器
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [x] 6.2 创建统一的 Toast 通知组件
    - 在 `lib/widgets/` 目录下创建 `toast_notification.dart`
    - 支持成功、错误、警告三种类型
    - 支持自动消失和手动关闭
    - 支持重试按钮（错误类型）
    - _Requirements: 4.2, 4.3_

- [x] 7. 修改启动流程集成首次启动检测
  - [x] 7.1 修改 SplashScreen 集成 FirstLaunchManager
    - 在应用启动时检测首次启动状态
    - 首次启动显示 OnboardingFlowScreen
    - 非首次启动直接显示 DeviceScanScreen
    - _Requirements: 1.1, 1.3_
  
  - [x] 7.2 修改 OnboardingFlowScreen 标记完成状态
    - 在用户点击"开始探索"时调用 `markOnboardingComplete()`
    - 确保状态正确持久化
    - _Requirements: 1.2, 2.2_

- [x] 8. Checkpoint - 确保启动流程正常工作
  - 确保所有测试通过，如有问题请询问用户。

- [x] 9. 集成功能引导到主要页面
  - [x] 9.1 创建 Running Mode 引导配置
    - 定义速度控制、雾化器开关、最大速度的引导步骤
    - 在 `lib/configs/guide_configs.dart` 中定义 GlobalKey 和 GuideConfiguration
    - _Requirements: 3.1_
  
  - [x] 9.2 创建 Colorize Mode 引导配置
    - 定义颜色预设、详细调色、亮度调节的引导步骤
    - 在 `lib/configs/guide_configs.dart` 中定义 GlobalKey 和 GuideConfiguration
    - _Requirements: 3.2_
  
  - [x] 9.3 创建 Logo 上传引导配置
    - 定义图片选择、裁剪、上传的引导步骤
    - 在 `lib/configs/guide_configs.dart` 中定义 GlobalKey 和 GuideConfiguration
    - _Requirements: 3.3_
  
  - [x] 9.4 修改 DeviceConnectScreen 集成功能引导
    - 导入 guide_configs.dart 和 FeatureGuideService
    - 在 Running Mode 界面中为目标元素分配 GlobalKey（runningModeSpeedControlKey 等）
    - 在 Colorize Mode 界面中为目标元素分配 GlobalKey（colorizeModeColorPresetsKey 等）
    - 在首次进入 Running Mode 时检查并显示引导
    - 在首次进入 Colorize Mode 时检查并显示引导
    - 引导完成后调用 markGuideComplete() 标记状态
    - _Requirements: 3.1, 3.2, 3.5_
  
  - [x] 9.5 修改 Logo 上传界面集成功能引导
    - 导入 guide_configs.dart 和 FeatureGuideService
    - 为目标元素分配 GlobalKey（logoUploadImageSelectionKey 等）
    - 在首次打开 Logo 上传界面时检查并显示引导
    - 引导完成后调用 markGuideComplete() 标记状态
    - _Requirements: 3.3, 3.5_

- [x] 10. 集成操作反馈到控制操作
  - [x] 10.1 在速度控制中添加触觉反馈
    - 导入 FeedbackService
    - 滑动调节速度时调用 FeedbackService.haptic(HapticType.selection)
    - 速度值变化时调用 FeedbackService.haptic(HapticType.light)
    - _Requirements: 4.1_
  
  - [x] 10.2 在颜色切换中添加触觉反馈
    - 切换颜色预设时调用 FeedbackService.haptic(HapticType.selection)
    - 进入详细调色时调用 FeedbackService.haptic(HapticType.medium)
    - _Requirements: 4.1_
  
  - [x] 10.3 在蓝牙命令发送中添加状态反馈
    - 命令发送成功时调用 FeedbackService.showSuccess()
    - 命令发送失败时调用 FeedbackService.showError() 并提供重试选项
    - _Requirements: 4.2, 4.3_
  
  - [x] 10.4 在异步操作中添加加载状态
    - 蓝牙扫描时调用 FeedbackService.showLoading() 显示加载指示器
    - 设备连接时显示连接步骤提示
    - Logo 上传时显示进度百分比
    - _Requirements: 4.4, 5.1, 5.2, 5.3_

- [x] 11. 集成状态持久化
  - [x] 11.1 在 DeviceConnectScreen 中恢复用户偏好
    - 导入 PreferenceService
    - 在 initState 中调用 getColorPreset() 读取上次的颜色预设索引
    - 在 initState 中调用 getSpeedValue() 读取上次的速度值
    - 在 initState 中调用 getAtomizerState() 读取上次的雾化器状态
    - 将读取的值应用到界面状态
    - _Requirements: 9.4_
  
  - [x] 11.2 在控制操作中保存用户偏好
    - 颜色预设变化时调用 saveColorPreset() 保存索引
    - 速度值变化时调用 saveSpeedValue() 保存数值
    - 雾化器状态变化时调用 saveAtomizerState() 保存状态
    - _Requirements: 9.1, 9.2, 9.3_
  
  - [x] 11.3 实现设备特定设置的保存和恢复
    - 连接设备时调用 getDeviceSettings(deviceId) 读取该设备的历史设置
    - 设置变化时调用 saveDeviceSettings(deviceId, settings) 保存到设备特定存储
    - _Requirements: 9.5_

- [x] 12. 优化错误处理和恢复
  - [x] 12.1 优化蓝牙断连处理
    - 断连时使用 FeedbackService.showError() 显示提示
    - 提供"重新连接"按钮，点击后重新扫描设备
    - _Requirements: 7.1_
  
  - [x] 12.2 优化设备扫描失败处理
    - 未找到设备时显示排查建议（检查设备电源、确认配对模式等）
    - 提供重新扫描按钮
    - _Requirements: 7.2_
  
  - [x] 12.3 优化 Logo 上传失败处理
    - 失败时保留已选择的图片状态
    - 使用 FeedbackService.showError() 显示具体失败原因
    - 提供重试按钮
    - _Requirements: 7.3_

- [x] 13. Final Checkpoint - 确保所有功能正常工作
  - 确保所有测试通过，如有问题请询问用户。

## Notes

- 所有测试任务都是必需的，确保全面的测试覆盖
- 每个任务都引用了具体的需求条款以确保可追溯性
- Checkpoint 任务用于阶段性验证，确保增量开发的稳定性
- 属性测试验证通用正确性属性，单元测试验证具体示例和边界情况
- 任务 9.3 已完成：Logo 上传引导配置已在 `lib/configs/guide_configs.dart` 中定义
