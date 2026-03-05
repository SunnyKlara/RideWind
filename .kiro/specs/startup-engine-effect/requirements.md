# Requirements Document

## Introduction

本功能实现硬件（STM32 F4）开机时的"跑车启动仪式感"效果：当硬件上电启动时，在LCD显示开机Logo动画的**同时**，自动触发尾灯双闪效果，并通过蓝牙通知已连接的APP播放汽车引擎启动声音，营造沉浸式的驾驶体验。

**关键时序**：双闪和引擎声与LCD开机Logo动画同步展示，而不是在Logo动画之后。

## Glossary

- **STM32_Controller**: STM32 F4微控制器，负责硬件控制和蓝牙通信
- **RideWind_App**: Flutter移动应用程序，负责接收蓝牙通知并播放音效
- **Taillight_System**: WS2812B LED尾灯系统，由STM32控制
- **BLE_Module**: 蓝牙低功耗通信模块（JDY-08），用于硬件与APP之间的双向通信
- **Engine_Audio_Controller**: APP端的引擎音效控制器，负责播放engine.mp3和engine_loop.mp3
- **Startup_Sequence**: 开机启动序列，包含Logo动画、双闪和引擎声的协调触发
- **LCD_Logo_Animation**: LCD开机Logo动画，由`LCD_ui0()`函数显示，持续约2秒

## Requirements

### Requirement 1: 硬件开机双闪效果（与Logo动画同步）

**User Story:** As a user, I want the taillight to flash while the boot logo is displayed, so that I can experience a racing car startup ceremony.

#### Acceptance Criteria

1. WHEN the LCD_Logo_Animation starts (`LCD_ui0()` called), THE Taillight_System SHALL execute a double-flash animation with red color **simultaneously**
2. THE Taillight_System SHALL flash exactly 2 times with 300ms on and 300ms off intervals
3. WHEN the double-flash animation completes, THE Taillight_System SHALL restore to the user's saved color settings
4. THE Startup_Sequence SHALL NOT delay before starting the double-flash (与Logo同时开始)
5. THE double-flash animation SHALL complete within the 2-second Logo display period

### Requirement 2: 蓝牙启动通知（与Logo动画同步）

**User Story:** As a user, I want the hardware to notify my phone when the boot logo appears, so that the app can play the engine sound in sync with the visual startup.

#### Acceptance Criteria

1. WHEN the LCD_Logo_Animation starts, THE BLE_Module SHALL send a startup notification command to the connected APP **immediately**
2. THE BLE_Module SHALL use the protocol format "ENGINE_START\n" for the startup notification
3. IF no APP is connected, THEN THE STM32_Controller SHALL continue the startup sequence without waiting for acknowledgment
4. WHEN the startup sequence completes (Logo + 双闪结束), THE BLE_Module SHALL send "ENGINE_READY\n" to indicate completion

### Requirement 3: APP引擎声播放

**User Story:** As a user, I want my phone to play an engine startup sound when the hardware powers on, so that I can have an immersive racing experience.

#### Acceptance Criteria

1. WHEN the RideWind_App receives "ENGINE_START\n" command, THE Engine_Audio_Controller SHALL play the engine startup sound (engine.mp3)
2. THE Engine_Audio_Controller SHALL play the sound from the beginning (0 seconds position)
3. WHEN the engine startup sound completes, THE Engine_Audio_Controller SHALL transition to the idle loop sound (engine_loop.mp3) if in throttle mode
4. IF the RideWind_App is not in foreground, THEN THE Engine_Audio_Controller SHALL still attempt to play the sound
5. THE Engine_Audio_Controller SHALL set initial volume to 70% for the startup sound

### Requirement 4: Logo动画、双闪与引擎声同步

**User Story:** As a user, I want the boot logo, taillight flash and engine sound to be synchronized, so that the startup experience feels cohesive.

#### Acceptance Criteria

1. THE STM32_Controller SHALL send "ENGINE_START\n" at the same moment `LCD_ui0()` is called (Logo显示开始)
2. THE Startup_Sequence SHALL complete within 2000ms total duration (与Logo显示时间一致)
3. WHEN the RideWind_App receives "ENGINE_START\n", THE Engine_Audio_Controller SHALL begin playback within 100ms
4. IF Bluetooth latency exceeds 200ms, THEN THE RideWind_App SHALL log a warning but continue playback
5. THE double-flash animation SHALL be visible during the Logo display period

### Requirement 5: 错误处理与降级

**User Story:** As a user, I want the startup sequence to work even if some components fail, so that I always have a functional device.

#### Acceptance Criteria

1. IF the BLE_Module fails to send notification, THEN THE STM32_Controller SHALL complete the Logo display and double-flash animation normally
2. IF the Engine_Audio_Controller fails to play sound, THEN THE RideWind_App SHALL log the error and not crash
3. IF the audio file is missing, THEN THE Engine_Audio_Controller SHALL skip playback gracefully
4. WHEN an error occurs during startup, THE STM32_Controller SHALL continue to normal operation mode

### Requirement 6: 硬件端音量调节界面

**User Story:** As a user, I want to adjust the engine sound volume from the hardware menu, so that I can control the audio level without using the app.

#### Acceptance Criteria

1. WHEN the user enters the Volume menu (UI6), THE LCD SHALL display a volume control interface similar to the brightness interface (UI4)
2. THE Volume interface SHALL display a numeric value from 0 to 100 representing the current volume percentage
3. WHEN the user rotates the encoder, THE volume value SHALL increase or decrease accordingly
4. WHEN the volume value changes, THE VS1003 audio chip SHALL be updated with the new volume setting via `VS1003_SetVolumePercent()`
5. THE Volume interface SHALL display a "Voice" icon and text label similar to other menu pages
6. THE volume setting SHALL be saved to Flash memory and restored on device boot

### Requirement 7: 修复长按松手触发单击的Bug

**User Story:** As a user, I want long press and short click to be distinct actions, so that releasing after a long press does not accidentally trigger a unit switch.

#### Acceptance Criteria

1. WHEN the user performs a short click (press and release within 500ms), THE system SHALL trigger the short click action (switch speed unit)
2. WHEN the user performs a long press (hold for more than 500ms), THE system SHALL trigger the long press action (toggle atomizer)
3. WHEN the user releases after a long press, THE system SHALL NOT trigger the short click action
4. THE system SHALL use a flag to track whether a long press was detected, and suppress the short click event on release
5. THE button state machine SHALL clearly distinguish between: idle → pressed → (short click OR long press detected) → released

### Requirement 8: 油门模式数字跳跃动画效果

**User Story:** As a user, I want the speed numbers to have a bouncing/jumping animation effect in throttle mode, so that the display feels more dynamic and impactful.

#### Acceptance Criteria

1. WHEN the speed value changes in throttle mode, THE number display SHALL show a jumping/bouncing animation effect
2. THE animation SHALL include a brief scale-up effect (e.g., 1.2x size) followed by return to normal size
3. THE animation duration SHALL be approximately 100-150ms to feel snappy but visible
4. THE animation SHALL NOT block or delay the actual speed value update
5. THE jumping effect SHALL be more pronounced for larger speed changes

### Requirement 9: 修复油门模式旋转退出Bug

**User Story:** As a user, I want to stay in throttle mode when rotating the encoder, so that I don't accidentally exit to the menu.

#### Acceptance Criteria

1. WHEN in throttle mode (wuhuaqi_state == 2), rotating the encoder SHALL NOT exit to the menu
2. WHEN in throttle mode, rotating the encoder SHALL be used for exiting throttle mode ONLY (return to UI1 speed control)
3. WHEN exiting throttle mode via encoder rotation, THE system SHALL stay in UI1 (speed interface), NOT switch to menu (UI5)
4. THE system SHALL NOT change menu_selected value while in throttle mode
5. WHEN exiting throttle mode, THE system SHALL restore the previous atomizer state (wuhuaqi_state_saved)

### Requirement 10: 流水灯平滑渐变过渡效果

**User Story:** As a user, I want the LED color transitions to be smooth and gradual like breathing lights, so that the visual effect is premium and not jarring.

#### Acceptance Criteria

1. WHEN the APP sends a streaming light command, THE LED system (left/center/right) SHALL transition colors using smooth gradient interpolation
2. THE color transition SHALL use linear interpolation between current and target RGB values
3. THE LED refresh rate SHALL be at least 50fps (update every 20ms) to ensure imperceptible transitions
4. THE transition speed SHALL be configurable via APP commands:
   - Fast mode: 0.5-1 second per color cycle
   - Normal mode: 1.5-2 seconds per color cycle  
   - Slow mode: 3-4 seconds per color cycle
5. THE RGB value change per frame SHALL be calculated as: `delta = (target - current) / frames_remaining`
6. THE transition SHALL NOT show any visible "jumping" or "flashing" between colors
7. THE smooth transition SHALL apply to all three LED groups (LED1/left, LED2/center, LED3/right) simultaneously

### Requirement 11: 专业赛车引擎音频处理

**User Story:** As a user, I want professional racing engine sounds that match different driving states, so that the audio experience feels authentic and immersive.

#### Acceptance Criteria

1. THE Engine_Audio_Controller SHALL use professionally extracted audio segments from a 9-minute racing engine recording
2. THE audio segments SHALL include:
   - engine_start.mp3 (2.5s): Startup sound for boot animation
   - engine_idle.mp3 (6s): Idle loop for standby/low speed state
   - engine_accel.mp3 (4s): Acceleration sound for throttle increase
   - engine_high.mp3 (4s): High RPM loop for maximum throttle
3. THE Engine_Audio_Controller SHALL automatically switch between audio segments based on speed:
   - Speed < 30: Play engine_idle.mp3 (loop)
   - Speed 30-150: Play engine_accel.mp3 (loop)
   - Speed > 150: Play engine_high.mp3 (loop)
4. THE audio transitions between segments SHALL be smooth with fade-in/fade-out effects
5. THE volume and playback rate SHALL be dynamically adjusted based on current speed
6. THE startup sound (engine_start.mp3) SHALL be played when receiving "ENGINE_START\n" from hardware
