# Requirements Document

## Introduction

本功能旨在将 RideWind 车模灯光控制系统的颜色预设从现有的 8 条扩展到 12 条，实现完整的色相覆盖，同时针对车模玩家的审美偏好进行专业配色设计。该功能涉及 Flutter APP 端 UI 更新和 STM32 硬件端固件同步修改，需要确保软硬件协议一致性和蓝牙通信稳定性。

## Glossary

- **LED Strip (灯带)**: WS2812B RGB 灯珠组成的灯带，系统共有 4 条：LED1(M-中间)、LED2(L-左侧)、LED3(R-右侧)、LED4(B-后部)
- **Color Preset (颜色预设)**: 预定义的 LED2 和 LED3 颜色组合方案，用户可通过滑动选择
- **Color Capsule (颜色胶囊)**: APP 端 UI 中显示颜色预设的圆角矩形条状组件
- **PageView**: Flutter 中用于实现水平滑动切换的组件
- **PRESET Command (预设命令)**: 蓝牙协议中用于切换颜色预设的文本命令，格式为 `PRESET:n\n`
- **deng_num**: 硬件端存储当前预设索引的全局变量
- **Gradient (渐变)**: 颜色胶囊从顶部到底部的双色渐变效果
- **Solid (纯色)**: 颜色胶囊的单一颜色填充效果

## Requirements

### Requirement 1

**User Story:** As a car model enthusiast, I want to have more color preset options, so that I can find the perfect lighting style for my vehicle model.

#### Acceptance Criteria

1. WHEN the user enters the Colorize Mode preset interface THEN the System SHALL display exactly 12 color capsules in a horizontally scrollable PageView
2. WHEN the user swipes left or right on the color capsules THEN the System SHALL smoothly animate the transition between presets with haptic feedback
3. WHEN a color capsule is centered (selected) THEN the System SHALL display it at 1.15x scale with enhanced shadow effects
4. WHEN color capsules are not centered THEN the System SHALL apply stage-light dimming effect (100% → 70% → 50% → 30% based on distance)
5. WHEN the user selects a preset THEN the System SHALL send the corresponding PRESET command to hardware within 80ms

### Requirement 2

**User Story:** As a user, I want the color presets to cover the full color spectrum, so that I can choose any color style I prefer.

#### Acceptance Criteria

1. THE System SHALL provide color presets covering all major hues: red, orange, yellow, green, cyan, blue, purple, pink, and white
2. THE System SHALL include both solid color presets and gradient color presets for visual variety
3. WHEN displaying gradient presets THEN the System SHALL render a smooth vertical gradient from LED2 color (top) to LED3 color (bottom)
4. THE System SHALL ensure no two presets have identical color combinations

### Requirement 3

**User Story:** As a developer, I want the APP and hardware to stay synchronized, so that the selected preset is correctly applied to the LED strips.

#### Acceptance Criteria

1. WHEN the APP sends a PRESET command THEN the Hardware SHALL update LED2 and LED3 colors within 100ms
2. WHEN the Hardware receives PRESET:n command THEN the Hardware SHALL validate n is within range 1-12
3. IF the Hardware receives an invalid preset index THEN the Hardware SHALL ignore the command and log an error message
4. WHEN the preset is applied THEN the Hardware SHALL update all 4 LED strips (LED1=LED2 color, LED4=LED3 color)
5. WHEN the user is on the preset interface (ui=2) THEN the Hardware SHALL refresh the LCD display to show the current selection

### Requirement 4

**User Story:** As a user, I want the color presets to look premium and professional, so that my car model lighting appears high-quality.

#### Acceptance Criteria

1. THE System SHALL use carefully calibrated RGB values optimized for WS2812B LED characteristics
2. THE System SHALL apply brightness coefficient (bright * bright_num) to all color outputs
3. WHEN displaying color capsules THEN the System SHALL render them with rounded corners (radius = width/2) for a pill-shaped appearance
4. WHEN a capsule is selected THEN the System SHALL display a dual-layer box shadow for depth effect
5. THE System SHALL maintain consistent color appearance between APP preview and actual LED output

### Requirement 5

**User Story:** As a user, I want the preset selection to feel responsive and smooth, so that the interaction is enjoyable.

#### Acceptance Criteria

1. WHEN swiping between presets THEN the System SHALL use BouncingScrollPhysics for natural momentum
2. WHEN a preset changes THEN the System SHALL trigger HapticFeedback.selectionClick()
3. THE System SHALL throttle hardware sync commands to prevent bluetooth congestion (minimum 80ms interval)
4. WHEN the user taps a non-centered capsule THEN the System SHALL animate to that capsule with 300ms ease-in-out curve
5. THE System SHALL maintain 60fps animation performance during preset scrolling

### Requirement 6

**User Story:** As a developer, I want the protocol to be backward compatible, so that existing functionality is not broken.

#### Acceptance Criteria

1. THE System SHALL continue to support PRESET:1-8 commands with unchanged behavior
2. THE System SHALL extend support to PRESET:9-12 commands using the same protocol format
3. WHEN hardware receives LED:strip:r:g:b command THEN the Hardware SHALL continue to function independently of preset system
4. THE System SHALL not modify any existing UI navigation or mode switching logic
5. THE System SHALL preserve all existing color sync mechanisms (_syncPresetToHardware, _applyPresetToLocalColors)
