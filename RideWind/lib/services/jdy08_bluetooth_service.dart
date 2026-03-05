import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// JDY-08蓝牙模块通信服务
///
/// 专门用于与STM32+JDY-08硬件设备通信
/// 支持统一协议和JDY兼容模式
class JDY08BluetoothService {
  static const String _deviceNamePrefix = 'RideWind'; // JDY-08设备名称前缀
  static const String _jdyNamePrefix = 'JDY-08'; // JDY-08默认名称前缀

  // JDY-08透传服务UUID (通常是0xFFE0) - 保留用于未来精确匹配
  // static const String _serviceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  // static const String _writeCharUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";
  // static const String _notifyCharUuid = "0000ffe1-0000-1000-8000-00805f9b34fb"; // JDY-08读写同一个特征

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _notificationSubscription;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;

  // 状态流控制器
  final StreamController<BluetoothConnectionState> _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  final StreamController<Uint8List> _dataReceivedController =
      StreamController<Uint8List>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 公开的流
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Uint8List> get dataReceivedStream => _dataReceivedController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  bool get isConnected =>
      _connectionState == BluetoothConnectionState.connected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// 扫描JDY-08设备
  ///
  /// [timeoutSeconds] 扫描超时时间(秒)
  /// 返回发现的设备列表
  Future<List<BluetoothDevice>> scanForDevices({
    int timeoutSeconds = 10,
  }) async {
    List<BluetoothDevice> foundDevices = [];

    // 检查蓝牙是否可用
    if (!await FlutterBluePlus.isSupported) {
      throw Exception('蓝牙不可用');
    }

    // 检查蓝牙是否开启
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw Exception('请开启蓝牙');
    }

    // 开始扫描
    await FlutterBluePlus.startScan(timeout: Duration(seconds: timeoutSeconds));

    // 监听扫描结果
    await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
      for (ScanResult result in results) {
        String deviceName = result.device.platformName;

        // 检查是否是目标设备
        if (_isTargetDevice(deviceName) &&
            !foundDevices.contains(result.device)) {
          foundDevices.add(result.device);
        }
      }

      // 如果找到设备就提前结束
      if (foundDevices.isNotEmpty) {
        break;
      }
    }

    await FlutterBluePlus.stopScan();
    return foundDevices;
  }

  /// 检查是否是目标JDY-08设备
  bool _isTargetDevice(String deviceName) {
    return deviceName.startsWith(_deviceNamePrefix) ||
        deviceName.startsWith(_jdyNamePrefix) ||
        deviceName.contains('RideWind') ||
        deviceName.contains('LED');
  }

  /// 连接到JDY-08设备
  ///
  /// [device] 要连接的蓝牙设备
  /// [autoReconnect] 是否自动重连
  Future<bool> connectToDevice(
    BluetoothDevice device, {
    bool autoReconnect = true,
  }) async {
    try {
      // 断开现有连接
      if (_connectedDevice != null) {
        await disconnect();
      }

      // 连接设备
      await device.connect(autoConnect: autoReconnect, mtu: null);
      _connectedDevice = device;

      // 监听连接状态变化
      _deviceStateSubscription = device.connectionState.listen((state) {
        _connectionState = state;
        _connectionStateController.add(state);

        if (state == BluetoothConnectionState.disconnected) {
          _cleanup();
        }
      });

      // 发现服务
      List<BluetoothService> services = await device.discoverServices();

      // 查找JDY-08透传服务
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase().contains('ffe0')) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception('未找到JDY-08透传服务');
      }

      // 查找读写特征
      for (BluetoothCharacteristic characteristic
          in targetService.characteristics) {
        String charUuid = characteristic.uuid.toString().toLowerCase();

        if (charUuid.contains('ffe1')) {
          // JDY-08通常读写使用同一个特征
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
          }
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            _notifyCharacteristic = characteristic;
          }
        }
      }

      if (_writeCharacteristic == null) {
        throw Exception('未找到写入特征');
      }

      // 启用通知
      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(true);
        _notificationSubscription = _notifyCharacteristic!.lastValueStream
            .listen((value) {
              if (value.isNotEmpty) {
                _dataReceivedController.add(Uint8List.fromList(value));
                _parseReceivedData(Uint8List.fromList(value));
              }
            });
      }

      // 发送连接成功状态
      _connectionStateController.add(BluetoothConnectionState.connected);

      // 查询设备状态
      await Future.delayed(Duration(milliseconds: 500));
      await queryDeviceStatus();

      return true;
    } catch (e) {
      print('连接失败: $e');
      await disconnect();
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      await _notificationSubscription?.cancel();
      await _deviceStateSubscription?.cancel();

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      print('断开连接错误: $e');
    } finally {
      _cleanup();
    }
  }

  /// 清理资源
  void _cleanup() {
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _connectionState = BluetoothConnectionState.disconnected;
    _notificationSubscription?.cancel();
    _deviceStateSubscription?.cancel();
  }

  /// 发送统一协议数据包
  ///
  /// [cmd] 命令字
  /// [data] 数据载荷
  Future<bool> sendUnifiedCommand(int cmd, List<int> data) async {
    if (!isConnected || _writeCharacteristic == null) {
      return false;
    }

    try {
      // 构造统一协议数据包
      List<int> packet = [];
      packet.add(0xAA); // 帧头
      packet.add(data.length + 1); // 长度
      packet.add(cmd); // 命令
      packet.addAll(data); // 数据

      // 计算校验和
      int checksum = 0;
      for (int i = 1; i < packet.length; i++) {
        checksum += packet[i];
      }
      packet.add(checksum & 0xFF); // 校验和
      packet.add(0x55); // 帧尾

      // 发送数据
      await _writeCharacteristic!.write(packet, withoutResponse: true);
      return true;
    } catch (e) {
      print('发送命令失败: $e');
      return false;
    }
  }

  /// 查询设备状态
  Future<bool> queryDeviceStatus() async {
    return await sendUnifiedCommand(0x01, []); // 查询状态命令
  }

  /// 设置LED颜色
  ///
  /// [zone] LED区域 (0-3对应L/M/R/B)
  /// [r] 红色值 (0-255)
  /// [g] 绿色值 (0-255)
  /// [b] 蓝色值 (0-255)
  /// [brightness] 亮度 (0-100)
  Future<bool> setLedColor(
    int zone,
    int r,
    int g,
    int b,
    int brightness,
  ) async {
    return await sendUnifiedCommand(0x02, [zone, r, g, b, brightness]);
  }

  /// 设置整体亮度
  ///
  /// [brightness] 亮度值 (0-100)
  Future<bool> setBrightness(int brightness) async {
    return await sendUnifiedCommand(0x03, [brightness]);
  }

  /// 设置风扇速度(百分比)
  ///
  /// [percent] 速度百分比 (0-100)
  Future<bool> setFanSpeedPercent(int percent) async {
    return await sendUnifiedCommand(0x04, [percent]);
  }

  /// 选择预设配色方案
  ///
  /// [preset] 方案编号 (1-8)
  Future<bool> selectPreset(int preset) async {
    return await sendUnifiedCommand(0x05, [preset]);
  }

  /// 设置工作模式
  ///
  /// [mode] 模式 (0=独立模式, 1=组合模式)
  Future<bool> setMode(int mode) async {
    return await sendUnifiedCommand(0x06, [mode]);
  }

  /// 紧急停止
  Future<bool> emergencyStop() async {
    return await sendUnifiedCommand(0x08, []);
  }

  /// 保存配置到Flash
  Future<bool> saveConfig() async {
    return await sendUnifiedCommand(0x10, []);
  }

  /// 恢复出厂设置
  Future<bool> restoreDefaults() async {
    return await sendUnifiedCommand(0x11, []);
  }

  /// 解析接收到的数据
  void _parseReceivedData(Uint8List data) {
    // 检查是否是统一协议响应
    if (data.length >= 5 && data[0] == 0xAA && data[data.length - 1] == 0x55) {
      int cmd = data[2];

      if (cmd == 0x81) {
        // 状态响应
        _parseStatusResponse(data);
      } else if (cmd == 0x82) {
        // 操作成功
        print('操作成功: 命令 0x${data[3].toRadixString(16)}');
      } else if (cmd == 0x83) {
        // 操作失败
        print(
          '操作失败: 命令 0x${data[3].toRadixString(16)}, 错误码 0x${data[4].toRadixString(16)}',
        );
      }
    }
  }

  /// 解析状态响应数据
  void _parseStatusResponse(Uint8List data) {
    if (data.length < 23) return; // 状态数据至少23字节

    Map<String, dynamic> status = {};

    // 解析LED颜色 (4组 x 3字节RGB)
    List<List<int>> zoneColors = [];
    for (int i = 0; i < 4; i++) {
      int offset = 3 + i * 4; // 跳过帧头、长度、命令
      zoneColors.add([
        data[offset], // R
        data[offset + 1], // G
        data[offset + 2], // B
      ]);
    }
    status['zoneColors'] = zoneColors;

    // 解析其他参数
    status['fanPercent'] = data[19]; // 风扇速度百分比
    status['brightness'] = data[20]; // 亮度
    status['ui'] = data[21]; // 当前UI界面
    status['mode'] = data[22]; // 工作模式

    // 发送状态更新
    _statusController.add(status);
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _dataReceivedController.close();
    _statusController.close();
  }
}
