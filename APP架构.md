# RideWind APP 项目架构分析文档

📅 更新日期: 2026-01-14
📱 项目类型: Flutter 智能 LED 风扇蓝牙控制应用
🔧 Flutter 版本: 3.9.2+ / Dart 3.0+

---

## 1. 项目概述

RideWind 是一款智能 LED 风扇蓝牙控制应用，通过蓝牙连接 JDY-08 模块控制硬件设备。当前已实现完整的双向通信架构，支持 APP 控制硬件和硬件主动上报状态。

### 1.1 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.9.2 + Dart 3.0+ |
| 状态管理 | Provider 6.1.2 |
| 蓝牙通信 | flutter_blue_plus 1.32.12 |
| 权限管理 | permission_handler 11.3.1 |
| UI 组件 | flutter_svg 2.0.10, google_fonts 6.2.1, font_awesome_flutter 10.7.0 |
| 音频 | audioplayers 5.2.1 |
| 本地存储 | shared_preferences 2.2.3 |

---

## 2. 页面导航流程图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           RideWind APP 页面流程                              │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌──────────────────┐
                              │   SplashScreen   │
                              │    (启动页面)     │
                              │  Logo + 用户协议  │
                              └────────┬─────────┘
                                       │ 点击"开始使用"
                                       ▼
                         ┌─────────────────────────────┐
                         │   OnboardingFlowScreen      │
                         │      (引导流程页面)          │
                         │  3页 PageView 滑动引导       │
                         │  1. 通知权限说明             │
                         │  2. 蓝牙权限说明             │
                         │  3. 全部就绪                 │
                         └─────────────┬───────────────┘
                                       │ 点击"开始探索"
                                       ▼
                         ┌─────────────────────────────┐
                         │     DeviceScanScreen        │
                         │      (设备扫描页面)          │
                         │  声波动画 + 自动扫描蓝牙     │
                         │  [DEV] 开发者模式入口        │
                         └─────────────┬───────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │ 未找到设备              │ 找到设备并连接成功       │ 开发者模式
              ▼                        ▼                        ▼
┌─────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────┐
│   NoDeviceScreen    │  │  设备发现弹窗 (底部滑入) │  │  直接跳转到控制页面  │
│    (未连接页面)      │  │  显示设备名称+信号强度   │  │  (模拟设备)          │
│  背景图 + 添加按钮   │  │  "进入控制界面" 按钮     │  └──────────┬──────────┘
└─────────┬───────────┘  └───────────┬─────────────┘             │
          │                          │                           │
          │ 点击添加                  │ 点击进入                   │
          ▼                          ▼                           │
┌─────────────────────┐  ┌─────────────────────────────────────────────────────┐
│  DeviceScanScreen   │  │              DeviceConnectScreen                    │
│    (重新扫描)        │  │               (核心控制页面)                         │
└─────────────────────┘  │  ┌─────────────────────────────────────────────────┐│
                         │  │           模式选择页面 (默认状态)                 ││
                         │  │  PageView 左右滑动选择模式，点击文字进入          ││
                         │  │  • Running Mode (速度/油门控制)                  ││
                         │  │  • Colorize Mode (LED颜色控制)                   ││
                         │  └─────────────────────────────────────────────────┘│
                         │                        │ 点击模式文字                │
                         │                        ▼                            │
                         │  ┌─────────────────────────────────────────────────┐│
                         │  │              进入具体模式                        ││
                         │  │                                                 ││
                         │  │  ┌─────────────────┐ ┌─────────────────────────┐││
                         │  │  │  Running Mode   │ │    Colorize Mode        │││
                         │  │  │                 │ │                         │││
                         │  │  │ • 速度滚轮0-340 │ │ • Entry (入口页)        │││
                         │  │  │ • 油门加速      │ │ • Preset (12色预设)     │││
                         │  │  │ • 紧急停止      │ │ • RGB Detail (调色)     │││
                         │  │  │ • 单位切换      │ │ • 流水灯动画            │││
                         │  │  │ • 引擎音效      │ │ • 亮度调节              │││
                         │  │  └─────────────────┘ └─────────────────────────┘││
                         │  └─────────────────────────────────────────────────┘│
                         └─────────────────────────────────────────────────────┘
                                       │ 返回按钮
                                       ▼
                         ┌─────────────────────────────┐
                         │     DeviceListScreen        │
                         │      (设备列表页面)          │
                         │  已连接设备卡片              │
                         │  点击进入控制 / 长按断开     │
                         └─────────────────────────────┘
```

---

## 3. 目录结构

```
lib/
├── main.dart                          # 应用入口
│
├── screens/                           # 📱 页面层 (19个文件)
│   ├── splash_screen.dart             # 启动页 - Logo、协议勾选
│   ├── onboarding_flow_screen.dart    # 引导流程 - 3页权限说明
│   ├── onboarding_screen.dart         # (旧版引导，已弃用)
│   ├── onboarding_screen_new.dart     # (新版引导，已弃用)
│   ├── permission_screen.dart         # (权限页，已整合)
│   ├── permission_screen_new.dart     # (新权限页，已整合)
│   ├── ready_screen.dart              # (就绪页，已整合)
│   ├── ready_screen_new.dart          # (新就绪页，已整合)
│   ├── device_scan_screen.dart        # 设备扫描 - 声波动画、蓝牙扫描
│   ├── no_device_screen.dart          # 未连接 - 空状态页面
│   ├── device_list_screen.dart        # 设备列表 - 已连接设备管理
│   ├── device_connect_screen.dart     # ⭐ 核心控制页 - 模式切换、设备控制
│   ├── main_control_screen.dart       # (旧版控制页，已弃用)
│   ├── cleaning_mode_screen.dart      # Cleaning Mode 独立页面
│   ├── rgb_color_screen.dart          # RGB 颜色设置页面
│   ├── bluetooth_test_screen.dart     # 蓝牙测试页面
│   ├── audio_test_screen.dart         # 音频测试页面
│   ├── register_screen.dart           # 注册页面
│   └── welcome_screen.dart            # 欢迎页面
│
├── widgets/                           # 🧩 组件层 (14个文件)
│   ├── airflow_button.dart            # 气流控制按钮 (绿/红渐变)
│   ├── running_mode_widget.dart       # ⭐ Running Mode 完整组件
│   ├── colorize_mode_color_picker.dart # 颜色选择器 (12色条)
│   ├── colorize_mode_rgb_settings.dart # RGB 设置界面
│   ├── colorize_start_button.dart     # 开始涂色按钮
│   ├── triangle_indicator_painter.dart # 倒三角指示器
│   ├── mode_button.dart               # 模式按钮
│   ├── mode_text_widget.dart          # 模式文字组件
│   ├── mode_text_image.dart           # 模式文字图片
│   ├── mode_text_svg.dart             # 模式文字 SVG
│   ├── mode_text_svg_package.dart     # SVG 包装组件
│   ├── adjustable_svg_component.dart  # 可调节 SVG 组件
│   ├── device_found_bottom_sheet.dart # 设备发现底部弹窗
│   └── user_info_drawer.dart          # 用户信息抽屉
│
├── providers/                         # 📊 状态管理层 (2个文件)
│   ├── bluetooth_provider.dart        # ⭐ 蓝牙状态管理 (核心)
│   └── device_provider.dart           # 设备状态管理
│
├── services/                          # ⚙️ 服务层 (6个文件)
│   ├── ble_service.dart               # ⭐ 蓝牙通信服务 (JDY-08)
│   ├── protocol_service.dart          # ⭐ 通信协议服务 (双向通信)
│   ├── bluetooth_service.dart         # (冗余，待删除)
│   ├── jdy08_bluetooth_service.dart   # (冗余，待删除)
│   ├── device_control_service.dart    # (编译错误，待重构)
│   └── engine_audio_controller.dart   # 引擎音效控制
│
├── models/                            # 📦 数据模型层 (3个文件)
│   ├── device_model.dart              # 设备模型 + 设备状态
│   ├── sound_wave_scanner.dart        # 声波扫描动画组件
│   └── speed_report.dart              # 🆕 速度报告模型 (硬件上报)
│
└── utils/                             # 🔧 工具层 (2个文件)
    ├── responsive_utils.dart          # 响应式布局工具类
    └── debug_logger.dart              # 调试日志工具
```

---

## 4. 核心架构详解

### 4.1 双向通信架构 ⭐

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         双向通信架构图                                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────┐                                           ┌─────────────┐
│   APP 端    │                                           │  硬件端     │
│             │                                           │  (JDY-08)   │
├─────────────┤                                           ├─────────────┤
│             │  ──────── 控制命令 (APP→硬件) ────────▶   │             │
│ Bluetooth   │  FAN:50\n, LED:1:255:0:0\n, WUHUA:1\n    │  STM32      │
│ Provider    │                                           │  MCU        │
│             │  ◀──────── 状态上报 (硬件→APP) ────────   │             │
│             │  SPEED_REPORT:120:0\n, THROTTLE_REPORT:1  │             │
└─────────────┘                                           └─────────────┘
       │                                                         │
       │                                                         │
       ▼                                                         ▼
┌─────────────┐                                           ┌─────────────┐
│ Protocol    │                                           │  FFE0/FFE1  │
│ Service     │  ◀────── BLE 透传通道 (20字节/包) ──────▶ │  特征       │
└─────────────┘                                           └─────────────┘
```

### 4.2 状态流架构

```dart
// BluetoothProvider 提供的数据流
Stream<SpeedReport> speedReportStream;     // 🏎️ 速度报告 (硬件旋钮)
Stream<bool> throttleReportStream;         // 🔥 油门模式 (硬件三击)
Stream<bool> unitReportStream;             // 📏 单位切换 (硬件单击)
Stream<int> presetReportStream;            // 🎨 预设切换 (硬件旋钮)
Stream<Map<String, String>> buttonEventStream;  // 🔘 按钮事件
Stream<Map<String, dynamic>> sensorDataStream;  // 📊 传感器数据
Stream<bool> connectionStream;             // 🔗 连接状态
Stream<String> rawDataStream;              // 🐛 原始数据 (调试)
```

---

## 5. 核心页面详解

### 5.1 DeviceConnectScreen (核心控制页) ⭐

**文件**: `lib/screens/device_connect_screen.dart`

这是整个 APP 最核心的页面，包含所有控制功能。

**控制模式枚举** (重构后简化为2个):
```dart
enum ControlMode {
  running,   // Running Mode - 速度/油门控制
  colorize,  // Colorize Mode - LED颜色控制
}

enum ColorizeState {
  entry,      // 🎨 色彩模式入口页
  preset,     // 配色预设界面 (12种预设)
  rgbDetail,  // RGB 调色界面
}
```

**状态机**:
```
┌─────────────────────────────────────────────────────────────────┐
│                    DeviceConnectScreen                           │
├─────────────────────────────────────────────────────────────────┤
│  _isInModeSelection = false (主页面)                             │
│  ├─ 显示模式选择 PageView                                        │
│  ├─ 可左右滑动选择: Running / Colorize                          │
│  └─ 点击文字 → _isInModeSelection = true                        │
├─────────────────────────────────────────────────────────────────┤
│  _isInModeSelection = true (进入模式)                            │
│  ├─ _currentModeIndex = 0 → Running Mode                        │
│  │   ├─ _showSpeedControl = false → 单击区域                    │
│  │   └─ _showSpeedControl = true → 调速滚轮界面                 │
│  └─ _currentModeIndex = 1 → Colorize Mode                       │
│      ├─ _colorizeState = entry → 入口页                         │
│      ├─ _colorizeState = preset → 12色预设选择                  │
│      └─ _colorizeState = rgbDetail → RGB调色界面                │
└─────────────────────────────────────────────────────────────────┘
```

**12色预设配置**:
```dart
static const List<Map<String, dynamic>> _ledColorCapsules = [
  {'type': 'gradient', 'colors': [紫, 绿], 'led2': {...}, 'led3': {...}},
  {'type': 'solid', 'color': 青色, ...},
  {'type': 'gradient', 'colors': [橙, 蓝], ...},
  // ... 共12种预设
];
```

---

### 5.2 RunningModeWidget (速度控制组件) ⭐

**文件**: `lib/widgets/running_mode_widget.dart`

**功能**:
- ListWheelScrollView 速度滚轮 (0-340 km/h)
- 油门加速按钮 (长按持续加速)
- 紧急停止按钮
- 单位切换 (km/h ↔ mph)
- 引擎音效 (audioplayers)
- 🆕 外部速度流支持 (硬件旋钮同步)
- 🆕 外部油门流支持 (硬件三击模式同步)
- 🆕 外部单位流支持 (硬件单击切换)
- 🆕 连接状态显示

**关键参数**:
```dart
int _currentSpeed = 0;              // 当前速度
int _maxSpeed = 340;                // 最大速度
int _accelerationInterval = 80;     // 加速间隔(ms)
int _baseAccelerationStep = 5;      // 基础加速步长
bool _isMetric = true;              // true=km/h, false=mph
```

**响应式布局配置**:
```dart
class _RunningModeConfig {
  double get wheelItemExtent;       // 滚轮项目高度 (动态计算)
  double get speedFontSize;         // 速度数字字体大小
  double get emergencyStopBottom;   // 紧急停止按钮位置
  double get quickArrowSize;        // 油门按钮尺寸
  // ...
}
```

---

## 6. 服务层详解

### 6.1 BLEService (蓝牙服务) ⭐

**文件**: `lib/services/ble_service.dart`

**职责**:
- 蓝牙扫描 (flutter_blue_plus)
- 设备连接/断开
- 数据收发 (JDY-08 透传模式)
- 连接状态监听
- 🆕 发送锁机制 (防止并发发送)
- 🆕 分包发送 (>20字节自动分包)

**JDY-08 配置**:
```dart
SERVICE_UUID = "0000FFE0-0000-1000-8000-00805F9B34FB"
CHAR_UUID = "0000FFE1-0000-1000-8000-00805F9B34FB"
```

**关键方法**:
```dart
Future<List<ScanResult>> scanDevices({Duration timeout});
Future<bool> connect(BluetoothDevice device);
Future<void> sendData(List<int> data);
Future<void> sendString(String text);
Future<void> disconnect();
```

---

### 6.2 ProtocolService (协议服务) ⭐

**文件**: `lib/services/protocol_service.dart`

**职责**:
- 命令编码/解码
- 响应解析
- 🆕 双向通信支持
- 🆕 同步查询方法 (带超时)
- 🆕 硬件主动上报解析

**命令格式**:
```
# APP → 硬件 (控制命令)
FAN:50\n              # 设置风扇速度 50%
SPEED:120\n           # 同步运行速度 120
WUHUA:1\n             # 开启雾化器
LED:1:255:0:0\n       # 设置灯带1为红色
PRESET:5\n            # 设置LED预设方案5
BRIGHT:80\n           # 设置全局亮度80%
THROTTLE:1\n          # 开启油门模式
UNIT:0\n              # 设置单位 (0=km/h, 1=mph)
UI:1\n                # 设置硬件UI界面
LCD:1\n               # 开启LCD屏幕
AUDIO:PLAY:0\n        # 播放音频文件0
AUDIO:VOL:80\n        # 设置音量80%

# 硬件 → APP (状态上报)
SPEED_REPORT:120:0\n  # 速度报告 (120 km/h)
THROTTLE_REPORT:1\n   # 油门模式开启
UNIT_REPORT:0\n       # 单位报告 (km/h)
PRESET_REPORT:5\n     # 预设报告 (预设5)
BTN:KNOB:CLICK\n      # 按钮事件
SENSOR:TEMP:45\n      # 传感器数据
```

**数据流控制器**:
```dart
StreamController<SpeedReport> _speedReportController;
StreamController<bool> _throttleReportController;
StreamController<bool> _unitReportController;
StreamController<int> _presetReportController;
StreamController<Map<String, String>> _buttonEventController;
StreamController<Map<String, dynamic>> _sensorDataController;
```

---

### 6.3 BluetoothProvider (状态管理) ⭐

**文件**: `lib/providers/bluetooth_provider.dart`

**职责**:
- 蓝牙扫描/连接/断开
- 设备列表管理
- 风扇速度控制
- LED 颜色控制
- 雾化器控制
- 音频控制
- 🆕 双向通信状态管理
- 🆕 重连后自动同步硬件状态
- 🆕 速度命令节流 (50ms间隔)

**关键方法**:
```dart
// 扫描连接
Future<void> startScan();
Future<bool> connectToDevice(DeviceModel device);
Future<void> disconnect();

// 控制命令
Future<bool> setFanSpeed(int speed);
Future<bool> setRunningSpeed(int speed);
Future<bool> setRunningSpeedThrottled(int speed);  // 带节流
Future<bool> setHardwareThrottleMode(bool enable);
Future<bool> setLEDColor(int strip, int r, int g, int b);
Future<bool> setLEDPreset(int index);
Future<bool> setWuhuaqiStatus(bool enable);
Future<bool> setBrightness(int brightness);
Future<bool> setSpeedUnit(bool isMetric);
Future<bool> setHardwareUI(int uiIndex);

// 同步查询
Future<Map<String, dynamic>> queryFanSpeedSync();
Future<Map<String, dynamic>> queryWuhuaqiStatusSync();
Future<Map<String, dynamic>> queryAudioStatusSync();
Future<Map<String, dynamic>> queryAllStatusSync();

// 音频控制
Future<bool> audioPlay(int index);
Future<bool> audioStop();
Future<bool> audioPause();
Future<bool> audioResume();
Future<bool> audioSetVolume(int volume);
Future<bool> audioNext();
Future<bool> audioPrev();
```

---

## 7. 数据模型

### 7.1 DeviceModel

```dart
class DeviceModel {
  final String id;
  final String name;
  final int rssi;
  bool isConnected;
  final BluetoothDevice? bluetoothDevice;
}

enum DeviceMode { cleaning, running, colorize }
```

### 7.2 SpeedReport (🆕 新增)

```dart
class SpeedReport {
  final int speed;      // 速度值 (0-340)
  final int unit;       // 单位 (0=km/h, 1=mph)
  final DateTime timestamp;
  final bool fromHardware;
  
  // 协议解析
  static SpeedReport? fromProtocol(String response);
  String toProtocol();
}
```

---

## 8. 资源文件

### 8.1 图片资源 (assets/images/)

| 文件名 | 用途 |
|--------|------|
| connected_interface.png | 默认连接界面背景 |
| running_mode.png | Running Mode 背景 (带文字) |
| running_mode_no_text.png | Running Mode 背景 (无文字) |
| colorize_mode.png | Colorize Mode 背景 (带按钮) |
| colorize_mode_no_text.png | Colorize Mode 背景 (无文字) |
| colorize_mode_no_button.png | Colorize Mode 背景 (无按钮) |
| rgb_settings_clean.png | RGB 设置界面背景 |
| no_device.png | 未连接页面背景 |
| device_list_connected.png | 设备列表背景 (未连接) |
| device_list_connected_active.png | 设备列表背景 (已连接) |
| device_product.png | 设备产品图 |

### 8.2 音频资源 (assets/sound/)

| 文件名 | 用途 |
|--------|------|
| engine.mp3 | 引擎音效 (Running Mode) |

---

## 9. 已知问题

### 9.1 废弃 API
- `WillPopScope` → 应改为 `PopScope`
- `withOpacity` → 应改为 `withValues`
- `Color.red/green/blue` → 应使用新 API

### 9.2 冗余代码
- `bluetooth_service.dart` - 与 ble_service 重复
- `jdy08_bluetooth_service.dart` - 与 ble_service 重复
- `device_control_service.dart` - 编译错误

### 9.3 Lint 警告
- 大量 `print` 语句应替换为日志框架
- 部分局部变量命名以下划线开头

---

## 10. 开发者模式

在 DeviceScanScreen 右下角添加了开发者模式入口：

- **触发方式**: 长按 "DEV" 标签
- **效果**: 跳过蓝牙扫描，创建模拟设备，直接进入 DeviceConnectScreen
- **用途**: 方便 UI 开发调试，无需真实蓝牙设备

---

## 11. 后续开发建议

1. **清理冗余代码**: 删除 bluetooth_service.dart、jdy08_bluetooth_service.dart
2. **修复废弃 API**: 批量替换 WillPopScope、withOpacity 等
3. **日志框架**: 将 print 替换为 DebugLogger 或其他日志框架
4. **添加权限请求**: 在 OnboardingFlowScreen 中实现真实权限请求
5. **断线重连**: 完善自动重连逻辑
6. **单元测试**: 为 ProtocolService 添加协议解析测试
