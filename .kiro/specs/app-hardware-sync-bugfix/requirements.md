# 需求文档

## 简介

本文档定义了RideWind APP与STM32硬件端协同工作中的5个bug修复需求。这些问题涉及流水灯对接、RGB调色界面刷新卡顿、倒三角指示器颜色匹配、雾化器显示优化以及油门加速数字跳动效果。

## 术语表

- **APP**: RideWind Flutter移动应用程序
- **Hardware**: STM32 F4硬件控制端
- **UI2**: 硬件端颜色预设界面，支持14种LED颜色预设和流水灯模式
- **UI3**: 硬件端RGB调色界面，支持自定义四条灯带RGB颜色
- **Colorize_Mode**: APP端的颜色调节模式
- **Running_Mode**: APP端的速度/油门控制模式
- **deng_2or3**: 硬件端流水灯开关变量（0=普通模式，1=流水灯模式）
- **Streamlight_Process**: 硬件端流水灯效果处理函数
- **Color_Picker**: APP端颜色选择器组件
- **Triangle_Indicator**: APP端倒三角颜色指示器
- **Atomizer**: 雾化器，APP端称为Airflow
- **Throttle_Mode**: 油门加速模式

## 需求

### 需求 1：流水灯功能对接

**用户故事:** 作为用户，我希望APP端的流水灯功能能够正确对接硬件端UI2的流水灯效果，以便获得一致的视觉体验。

#### 验收标准

1. WHEN 用户在APP端Colorize_Mode下启动流水灯 THEN APP SHALL 发送流水灯开启命令到硬件端，触发硬件端UI2的Streamlight_Process
2. WHEN 用户在APP端停止流水灯 THEN APP SHALL 发送流水灯关闭命令到硬件端，停止硬件端的流水灯效果
3. WHEN 硬件端流水灯正在运行 THEN APP SHALL 同步显示当前流水灯的颜色预设索引
4. WHEN APP端发送流水灯命令 THEN Hardware SHALL 设置deng_2or3变量并执行对应的LED效果
5. IF APP端流水灯命令发送失败 THEN APP SHALL 显示错误提示并保持当前状态

### 需求 2：RGB调色界面刷新卡顿修复

**用户故事:** 作为用户，我希望在APP端滑动调节RGB值时，硬件端LCD不会出现卡顿刷新的视觉问题，以便获得流畅的操作体验。

#### 验收标准

1. WHEN 用户在APP端长按灯带并滑动调节RGB值 THEN APP SHALL 限制LED命令发送频率不超过每50ms一次
2. WHEN APP端连续发送LED颜色命令 THEN Hardware SHALL 检测到流水灯模式并简化LCD显示更新
3. WHILE 用户正在滑动调节RGB值 THEN Hardware SHALL 只显示R/G/B字母标识，不刷新具体数值
4. WHEN 用户停止滑动操作超过500ms THEN Hardware SHALL 恢复完整的LCD数值显示
5. THE APP SHALL 在滑动调节时使用节流机制，避免发送过多蓝牙命令

### 需求 3：倒三角指示器颜色匹配

**用户故事:** 作为用户，我希望进入APP端调色界面时，倒三角指示器能够指向与当前实际LED颜色最接近的预设，以便快速了解当前颜色状态。

#### 验收标准

1. WHEN 用户进入Colorize_Mode界面 THEN APP SHALL 查询硬件端当前颜色预设索引
2. WHEN APP收到硬件端预设报告 THEN Triangle_Indicator SHALL 自动定位到对应的颜色预设位置
3. IF 硬件端返回的预设索引有效（1-12） THEN Color_Picker SHALL 将PageView滚动到对应索引位置
4. IF 硬件端未返回预设索引或查询超时 THEN APP SHALL 使用上次保存的颜色预设索引
5. WHEN 用户手动选择新的颜色预设 THEN APP SHALL 更新本地存储的颜色预设索引

### 需求 4：雾化器显示优化

**用户故事:** 作为用户，我希望雾化器开启时只显示短暂的绿色提示效果，而不是一直显示绿色指示器，以便获得更简洁的界面体验。

#### 验收标准

1. WHEN 用户单击开启雾化器 THEN APP SHALL 显示绿色提示效果持续1.5秒
2. WHEN 绿色提示效果显示完毕 THEN APP SHALL 自动隐藏绿色指示器
3. WHILE 雾化器处于开启状态 THEN APP SHALL 不持续显示绿色指示器
4. WHEN 用户再次单击关闭雾化器 THEN APP SHALL 显示关闭提示效果持续1秒
5. THE APP SHALL 使用动画效果展示雾化器状态变化，提供视觉反馈

### 需求 5：油门加速数字跳动效果

**用户故事:** 作为用户，我希望油门加速时数字能够以更有节奏感的方式跳动，突出数字跳出屏幕的视觉效果，以便获得更刺激的加速体验。

#### 验收标准

1. WHEN 用户长按油门按钮开始加速 THEN APP SHALL 使用乱序递增模式而非固定步长递增
2. THE Running_Mode SHALL 实现数字跳动动画效果，包含缩放和位移变换
3. WHEN 速度数字变化 THEN APP SHALL 应用弹跳动画效果，使数字有跳出屏幕的视觉感
4. IF 乱序递增模式无法实现 THEN APP SHALL 回退到每次1个单位的递增模式
5. WHILE 油门加速进行中 THEN APP SHALL 配合震动反馈增强数字跳动的节奏感
6. THE APP SHALL 确保数字跳动动画不影响速度同步的准确性
