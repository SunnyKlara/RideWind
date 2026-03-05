# Requirements Document

## Introduction

本需求文档定义了 RideWind 项目中硬件端（STM32F405 + LCD屏幕）与APP端（Flutter Running Mode页面）之间的双向速度同步功能。核心目标是建立一套完整的双向控制逻辑体系，使得：
1. APP端调整速度时，硬件端LCD屏幕实时同步显示
2. 硬件端通过旋钮调整速度时，APP端Running Mode页面实时同步显示
3. 两端的操控逻辑相互独立但状态保持一致

## Glossary

- **RideWind_System**: 整个风扇控制系统，包含硬件端和APP端
- **Hardware_Controller**: STM32F405硬件控制器，负责风扇PWM控制、LCD显示、旋钮输入处理
- **APP_Client**: Flutter移动应用程序，提供Running Mode界面和蓝牙通信
- **Running_Mode**: 运行模式，用于控制风扇速度的主要操作界面
- **Speed_Value**: 速度值，范围0-340（km/h），用于显示和控制
- **Fan_PWM**: 风扇PWM占空比，范围0-100%，由Speed_Value映射得到
- **BLE_Protocol**: 蓝牙低功耗通信协议，基于JDY-08模块的文本协议
- **Knob_Encoder**: 旋转编码器，硬件端的物理输入设备
- **LCD_Display**: 240x240像素LCD屏幕，显示当前速度和状态
- **Bidirectional_Sync**: 双向同步机制，确保两端状态一致

## Requirements

### Requirement 1

**User Story:** As a user, I want to control the fan speed from the APP, so that the hardware LCD display updates in real-time to show the current speed.

#### Acceptance Criteria

1. WHEN the APP_Client sends a SPEED command via BLE_Protocol THEN the Hardware_Controller SHALL update the LCD_Display within 100 milliseconds
2. WHEN the APP_Client adjusts the speed slider in Running_Mode THEN the RideWind_System SHALL transmit the Speed_Value to Hardware_Controller using the format `SPEED:value\n`
3. WHEN the Hardware_Controller receives a valid SPEED command THEN the Hardware_Controller SHALL update the Fan_PWM output according to the speed-to-PWM mapping
4. WHEN the Hardware_Controller successfully processes a SPEED command THEN the Hardware_Controller SHALL send an acknowledgment response `OK:SPEED:value\r\n` back to APP_Client

### Requirement 2

**User Story:** As a user, I want to control the fan speed from the hardware knob, so that the APP Running Mode page updates in real-time to show the current speed.

#### Acceptance Criteria

1. WHEN the user rotates the Knob_Encoder on Hardware_Controller THEN the Hardware_Controller SHALL send a speed update message `SPEED_REPORT:value\n` to APP_Client within 50 milliseconds
2. WHEN the APP_Client receives a SPEED_REPORT message THEN the APP_Client SHALL update the Running_Mode speed display within 100 milliseconds
3. WHEN the Knob_Encoder generates a rotation delta THEN the Hardware_Controller SHALL calculate the new Speed_Value by applying the delta to the current speed
4. WHEN the Hardware_Controller updates Speed_Value via knob input THEN the Hardware_Controller SHALL simultaneously update the LCD_Display and send the update to APP_Client

### Requirement 3

**User Story:** As a user, I want both control sources (APP and hardware knob) to work seamlessly together, so that I can switch between them without conflicts.

#### Acceptance Criteria

1. WHEN the APP_Client sends a SPEED command while the user is rotating the Knob_Encoder THEN the Hardware_Controller SHALL accept the most recent command and update the display accordingly
2. WHEN the Hardware_Controller receives a SPEED command THEN the Hardware_Controller SHALL update its internal Speed_Value state to match the received value
3. WHEN the APP_Client receives a SPEED_REPORT message THEN the APP_Client SHALL update its internal speed state without triggering a new SPEED command back to hardware
4. WHEN either control source changes the speed THEN the RideWind_System SHALL maintain a single source of truth for the current Speed_Value

### Requirement 4

**User Story:** As a user, I want to see the speed unit (km/h or mph) consistently displayed on both APP and hardware LCD, so that I can understand the speed value correctly.

#### Acceptance Criteria

1. WHEN the APP_Client changes the speed unit THEN the APP_Client SHALL send a UNIT command `UNIT:0\n` (km/h) or `UNIT:1\n` (mph) to Hardware_Controller
2. WHEN the Hardware_Controller receives a UNIT command THEN the Hardware_Controller SHALL update the LCD_Display to show the correct unit label
3. WHEN the Hardware_Controller reports speed to APP_Client THEN the Hardware_Controller SHALL include the current unit in the message format `SPEED_REPORT:value:unit\n`
4. WHEN the APP_Client receives a speed report with unit information THEN the APP_Client SHALL display the speed value with the correct unit conversion

### Requirement 5

**User Story:** As a user, I want the throttle mode (oil gate acceleration) to work correctly with bidirectional sync, so that both APP and hardware show the acceleration state.

#### Acceptance Criteria

1. WHEN the APP_Client enters throttle mode (long press acceleration button) THEN the APP_Client SHALL send `THROTTLE:1\n` to Hardware_Controller
2. WHEN the APP_Client exits throttle mode (release acceleration button) THEN the APP_Client SHALL send `THROTTLE:0\n` to Hardware_Controller
3. WHEN the Hardware_Controller receives THROTTLE:1 command THEN the Hardware_Controller SHALL enter throttle mode and update LCD_Display to show throttle state indicator
4. WHEN the Hardware_Controller is in throttle mode and receives SPEED commands THEN the Hardware_Controller SHALL update the speed display without exiting throttle mode
5. WHEN the user triple-clicks the Knob_Encoder to enter local throttle mode THEN the Hardware_Controller SHALL send `THROTTLE_REPORT:1\n` to APP_Client
6. WHEN the APP_Client receives THROTTLE_REPORT:1 THEN the APP_Client SHALL enter throttle mode display state in Running_Mode

### Requirement 6

**User Story:** As a developer, I want a well-defined communication protocol for speed synchronization, so that the implementation is consistent and maintainable.

#### Acceptance Criteria

1. THE RideWind_System SHALL use text-based protocol with newline termination for all speed-related commands
2. THE Hardware_Controller SHALL parse incoming commands using the format `COMMAND:PARAM1:PARAM2\n`
3. THE Hardware_Controller SHALL generate outgoing reports using the format `REPORT_TYPE:PARAM1:PARAM2\n`
4. THE APP_Client SHALL implement a protocol parser that handles all defined message types
5. THE APP_Client SHALL implement a protocol serializer that generates correctly formatted commands

### Requirement 7

**User Story:** As a user, I want the system to handle connection loss gracefully, so that I can continue using either control method independently.

#### Acceptance Criteria

1. WHEN the BLE connection is lost THEN the Hardware_Controller SHALL continue to accept Knob_Encoder input and update LCD_Display locally
2. WHEN the BLE connection is lost THEN the APP_Client SHALL display a disconnected state indicator in Running_Mode
3. WHEN the BLE connection is restored THEN the APP_Client SHALL query the current Hardware_Controller state using `GET:SPEED\n`
4. WHEN the Hardware_Controller receives GET:SPEED command THEN the Hardware_Controller SHALL respond with `SPEED:value:unit\r\n`
5. WHEN the APP_Client receives the current state after reconnection THEN the APP_Client SHALL synchronize its display to match the Hardware_Controller state

### Requirement 8

**User Story:** As a user, I want smooth and responsive speed control on both interfaces, so that the user experience feels natural and immediate.

#### Acceptance Criteria

1. WHEN the APP_Client speed slider is moved THEN the APP_Client SHALL implement command throttling to send updates at most every 50 milliseconds
2. WHEN the Knob_Encoder is rotated THEN the Hardware_Controller SHALL implement delta accumulation to batch small movements into meaningful speed changes
3. WHEN the LCD_Display updates speed value THEN the Hardware_Controller SHALL use optimized rendering to update only the changed digits
4. WHEN the APP_Client receives rapid speed updates THEN the APP_Client SHALL use animation smoothing to prevent visual jitter in the Running_Mode display
