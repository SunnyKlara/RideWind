# 开机Logo动画设计文档

## 1. 架构概述

在 `logo.c` 中新增动画绘制模块，替换原有的静态图片显示。

```
Logo_ShowBoot()
    └── Logo_PlayAnimation()
            ├── Animation_DrawSquare()      // 阶段1：绘制正方形
            ├── Animation_DrawDiagonal()    // 阶段2：绘制对角线
            └── Animation_DrawCircle()      // 阶段3：绘制内切圆
```

## 2. 几何计算

### 2.1 参数定义

```c
#define ANIM_SQUARE_SIZE    154     // 正方形边长（与原Logo大小一致）
#define ANIM_CENTER_X       120     // 屏幕中心X
#define ANIM_CENTER_Y       120     // 屏幕中心Y
#define ANIM_LINE_COLOR     WHITE   // 线条颜色
#define ANIM_BG_COLOR       BLACK   // 背景颜色
```

### 2.2 内切圆计算

设正方形边长 a = 154，左上角 (x0, y0) = (43, 43)

内切圆需满足：
1. 与对角线 y = x + (y0 - x0) 相切（外切）
2. 与下边框 y = y0 + a 相切（内切）
3. 与右边框 x = x0 + a 相切（内切）

由于下边框和右边框对称，圆心在 x = y 的对称线上偏移。

设圆心 (cx, cy)，半径 r：
- cx + r = x0 + a  →  cx = x0 + a - r
- cy + r = y0 + a  →  cy = y0 + a - r
- 由于 x0 = y0，所以 cx = cy

圆心到对角线距离 = r：
- 对角线：x - y = 0（简化后）
- 距离 = |cx - cy| / √2 = 0（因为 cx = cy）

这说明圆心在对角线上，与对角线"相切"实际上是圆心在对角线上。

**重新理解用户需求**：圆与对角线、下边框、右边框三者相切，圆心不在对角线上。

正确计算：
- 设圆心 (cx, cy)，cx ≠ cy
- 与右边框相切：cx + r = x0 + a
- 与下边框相切：cy + r = y0 + a
- 与对角线相切：|cx - cy| / √2 = r

由于圆在对角线右下方（靠近右下角）：cx > cy
- cx - cy = r * √2
- cx = x0 + a - r
- cy = y0 + a - r

从 cx - cy = r * √2 和 cx = cy（矛盾）

**最终方案**：采用简化的几何关系
- 圆心在正方形右下角区域
- 半径 r = a / (2 + √2) ≈ 45（当 a = 154）
- 圆心 cx = x0 + a - r = 43 + 154 - 45 = 152
- 圆心 cy = y0 + a - r = 43 + 154 - 45 = 152

## 3. 动画时序

| 阶段 | 时间(ms) | 动作 |
|------|----------|------|
| 1 | 0-300 | 正方形四条边依次绘制 |
| 2 | 300-600 | 对角线从中心向两端延伸 |
| 3 | 300-700 | 内切圆从点逐渐扩大（与阶段2同时） |
| 4 | 700-1000 | 保持显示 |

## 4. 函数设计

### 4.1 主动画函数

```c
/**
 * @brief 播放开机Logo动画
 * @note  总时长约1秒
 */
void Logo_PlayAnimation(void);
```

### 4.2 正方形绘制（渐进式）

```c
/**
 * @brief 绘制正方形边框（带动画效果）
 * @param x0, y0 左上角坐标
 * @param size 边长
 * @param progress 进度 0-100
 * @param color 颜色
 */
void Animation_DrawSquareProgress(u16 x0, u16 y0, u16 size, u8 progress, u16 color);
```

### 4.3 对角线绘制（从中心延伸）

```c
/**
 * @brief 绘制对角线（从中心向两端延伸）
 * @param x0, y0 正方形左上角
 * @param size 正方形边长
 * @param progress 进度 0-100
 * @param color 颜色
 */
void Animation_DrawDiagonalProgress(u16 x0, u16 y0, u16 size, u8 progress, u16 color);
```

### 4.4 圆形绘制（逐渐扩大）

```c
/**
 * @brief 绘制内切圆（逐渐扩大）
 * @param cx, cy 圆心
 * @param target_r 目标半径
 * @param progress 进度 0-100
 * @param color 颜色
 */
void Animation_DrawCircleProgress(u16 cx, u16 cy, u8 target_r, u8 progress, u16 color);
```

## 5. 正确性属性

### P1: 几何正确性
- 正方形四边等长且垂直
- 对角线连接正确的两个顶点
- 圆形与边框相切（视觉上）

### P2: 动画流畅性
- 帧率 ≥ 30fps
- 无明显闪烁

### P3: 时序正确性
- 正方形先完成
- 对角线和圆同时进行
- 总时长 ≤ 1.5秒

## 6. 实现注意事项

1. **性能优化**：使用增量绘制，避免每帧重绘整个图形
2. **抗锯齿**：LCD驱动不支持抗锯齿，接受阶梯效果
3. **延时控制**：使用 HAL_Delay() 控制动画速度
4. **颜色选择**：白色线条在黑色背景上最清晰
