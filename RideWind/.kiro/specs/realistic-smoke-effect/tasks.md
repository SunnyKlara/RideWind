# 实现计划：逼真烟雾效果

## 概述

基于现有 `EulerFluidSimulator` 和 `DevTestScreen` 进行增强改造，实现从左至右的逼真烟雾效果。按照"模拟器增强 → 渲染器升级 → 界面集成"的顺序递进实现。

## 任务

- [x] 1. 增强 EulerFluidSimulator 核心能力
  - [x] 1.1 添加涡度约束（Vorticity Confinement）
    - 在 `lib/utils/euler_fluid_simulator.dart` 中新增 `_curl` 字段（Float64List）和 `vorticityStrength` 参数
    - 实现 `_applyVorticityConfinement()` 方法：计算涡度场、涡度梯度、施加约束力
    - 在 `step()` 方法中，投影之后调用涡度约束
    - _Requirements: 2.2_

  - [x] 1.2 实现开放边界条件
    - 修改 `_setBoundary()` 方法，对左侧和右侧边界使用 Neumann 条件（复制相邻内部单元值）
    - 上下边界保持现有反射条件不变
    - _Requirements: 2.6_

  - [x] 1.3 添加湍流扰动和密度管理
    - 新增 `_applyTurbulence()` 方法，使用基于帧计数的时变随机扰动对速度场施加小幅扰动
    - 新增 `_applyDecay()` 方法，对密度场施加衰减系数（默认 0.99），对速度场施加衰减系数（默认 0.998）
    - 新增 `_cleanupLowDensity()` 方法，将低于 `densityThreshold`（0.005）的密度归零
    - 新增构造函数参数：`vorticityStrength`、`decayRate`、`velocityDecay`、`densityThreshold`
    - 更新 `step()` 流程为：扩散→投影→平流→投影→涡度约束→湍流→密度演化→衰减→清理
    - _Requirements: 2.3, 2.4, 2.5_

  - [ ]* 1.4 编写属性测试：涡度约束保持涡旋能量
    - **Property 3: 涡度约束保持涡旋能量**
    - 生成包含非零涡度的随机速度场，验证涡度约束后动能不减少
    - **Validates: Requirements 2.2**

  - [ ]* 1.5 编写属性测试：密度衰减与低密度清零
    - **Property 4: 密度衰减不变量**
    - 生成随机非零密度场，验证一步模拟后密度不增加
    - **Property 5: 低密度清零**
    - 生成含低值的随机密度场，验证清理后无 0 < d < 0.005 的值
    - **Validates: Requirements 2.4, 2.5**

  - [ ]* 1.6 编写属性测试：开放边界 Neumann 条件
    - **Property 6: 开放边界 Neumann 条件**
    - 生成随机场状态，验证右侧边界值等于相邻内部单元值
    - **Validates: Requirements 2.6**

- [x] 2. Checkpoint - 确保模拟器增强测试通过
  - 确保所有测试通过，如有问题请向用户确认。

- [x] 3. 实现烟雾源（从左至右）
  - [x] 3.1 重写烟雾源注入逻辑
    - 在 `lib/screens/dev_test_screen.dart` 中重写 `_addSmokeSource()` 方法
    - 烟雾源位置：x 在 2~4 列，y 在 gridSize×0.2 到 gridSize×0.8 之间
    - 密度注入：0.6 + random × 0.4
    - 水平速度：2.0 + random × 2.0（正 x 方向，从左至右）
    - 垂直扰动：(random - 0.5) × 1.0
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ]* 3.2 编写属性测试：烟雾源位置和参数范围
    - **Property 1: 烟雾源位置约束**
    - 验证源注入坐标在预期范围内
    - **Property 2: 烟雾源注入参数范围**
    - 验证密度、水平速度、垂直速度增量在指定范围内
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4**

- [x] 4. 升级烟雾渲染器
  - [x] 4.1 实现 SmokeRenderer 多层渲染
    - 在 `lib/screens/dev_test_screen.dart` 中用新的 `SmokeRenderer` 替代现有 `_FluidPainter`
    - 实现 `RenderLayer` 数据类，包含 blurSigma、opacity、densityScale
    - 实现两层渲染：底层（sigma=8, opacity=0.3, scale=1.5）+ 顶层（sigma=2, opacity=0.7, scale=1.0）
    - 每层使用 `canvas.saveLayer` + `ImageFilter.blur` 实现高斯模糊
    - 密度低于 0.01 时跳过渲染
    - _Requirements: 3.1, 3.4_

  - [x] 4.2 实现双线性插值和非线性透明度映射
    - 在 `SmokeRenderer` 中实现 `_interpolateDensity(double fx, double fy)` 双线性插值方法
    - 实现 `_mapDensityToAlpha(double density)` 非线性映射（gamma=2.2）
    - 渲染时对每个像素块使用插值采样而非直接读取网格值
    - 颜色方案：深灰蓝 `0xFF1a1a2e` → 亮白 `0xFFe0e0ff`，使用 `Color.lerp`
    - _Requirements: 3.2, 3.3, 3.5_

  - [ ]* 4.3 编写属性测试：透明度映射和双线性插值
    - **Property 7: 透明度映射单调性**
    - 生成随机密度对，验证映射函数严格单调递增
    - **Property 8: 双线性插值范围约束**
    - 生成随机角点值和坐标，验证插值结果在角点值范围内
    - **Validates: Requirements 3.2, 3.5**

- [x] 5. Checkpoint - 确保渲染器测试通过
  - 确保所有测试通过，如有问题请向用户确认。

- [x] 6. 集成触摸交互和生命周期管理
  - [x] 6.1 更新触摸交互逻辑
    - 修改 `_handlePanUpdate()` 方法，触摸注入区域改为 5×5
    - 根据手指移动方向和速度注入对应速度
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 6.2 实现 PageView 可见性管理
    - 为 `DevTestScreen` 添加 `isVisible` 参数
    - 在 `didUpdateWidget` 中根据可见性暂停/恢复 Timer
    - 确保 dispose 时取消 Timer
    - 确保 mounted 检查在 setState 之前
    - _Requirements: 4.4, 6.1, 6.3_

  - [ ]* 6.3 编写属性测试：触摸交互注入
    - **Property 9: 触摸交互注入**
    - 生成随机触摸位置和方向，验证密度和速度注入正确
    - **Validates: Requirements 5.1, 5.2**

- [x] 7. 性能调优与最终集成
  - [x] 7.1 调整模拟参数
    - 将 dt 从 0.2 调整为 0.15
    - 确认 iterations=4，gridSize=80
    - 确保 Float64List 用于所有场数据
    - 验证渲染使用批量 Canvas 操作
    - _Requirements: 4.1, 4.2, 4.3, 4.5_

  - [x] 7.2 连接 PageView 可见性信号
    - 在 `DeviceConnectScreen` 的 PageView 中，将当前页面索引传递给 `DevTestScreen` 的 `isVisible` 参数
    - 确保页面切换时正确触发暂停/恢复
    - _Requirements: 4.4, 6.3_

- [x] 8. 最终 Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请向用户确认。

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加速 MVP
- 每个任务引用了具体的需求编号以保证可追溯性
- Checkpoint 任务确保增量验证
- 属性测试使用 Dart `test` 包 + `dart:math.Random` 循环 100 次迭代实现
- 单元测试验证具体示例和边界情况
