import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../models/device_model.dart';

/// 蓝牙服务类
/// 负责处理真实的蓝牙通信
/// 注意：当前使用模拟数据，实际设备连接时需要替换为真实的蓝牙协议
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // 蓝牙设备列表
  final List<fbp.ScanResult> _scanResults = [];
  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _writeCharacteristic;
  fbp.BluetoothCharacteristic? _notifyCharacteristic;

  // UUID定义（需要根据实际硬件修改）
  static const String serviceUUID = "0000fff0-0000-1000-8000-00805f9b34fb";
  static const String writeCharUUID = "0000fff1-0000-1000-8000-00805f9b34fb";
  static const String notifyCharUUID = "0000fff2-0000-1000-8000-00805f9b34fb";

  /// 检查蓝牙是否可用
  Future<bool> isBluetoothAvailable() async {
    try {
      final state = await fbp.FlutterBluePlus.adapterState.first;
      return state == fbp.BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('检查蓝牙状态失败: $e');
      return false;
    }
  }

  /// 开始扫描蓝牙设备
  Stream<List<fbp.ScanResult>> startScan({Duration timeout = const Duration(seconds: 3)}) {
    _scanResults.clear();
    
    fbp.FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    return fbp.FlutterBluePlus.scanResults;
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await fbp.FlutterBluePlus.stopScan();
  }

  /// 连接到设备
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // 发现服务
      List<fbp.BluetoothService> services = await device.discoverServices();
      
      // 查找特定服务和特征
      for (var service in services) {
        if (service.uuid.toString() == serviceUUID) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == writeCharUUID) {
              _writeCharacteristic = characteristic;
            }
            if (characteristic.uuid.toString() == notifyCharUUID) {
              _notifyCharacteristic = characteristic;
              // 启用通知
              await characteristic.setNotifyValue(true);
            }
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('连接设备失败: $e');
      return false;
    }
  }

  /// 断开设备连接
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
    }
  }

  /// 发送速度命令
  /// 格式：0xAA 0x01 速度高字节 速度低字节 校验和 0xFF
  Future<void> sendSpeedCommand(int speed) async {
    if (_writeCharacteristic == null) {
      debugPrint('写入特征未找到');
      return;
    }

    try {
      final highByte = (speed >> 8) & 0xFF;
      final lowByte = speed & 0xFF;
      final checksum = (0x01 + highByte + lowByte) & 0xFF;
      
      final command = [0xAA, 0x01, highByte, lowByte, checksum, 0xFF];
      
      await _writeCharacteristic!.write(command, withoutResponse: false);
      debugPrint('发送速度命令: $speed km/h');
    } catch (e) {
      debugPrint('发送速度命令失败: $e');
    }
  }

  /// 发送模式命令
  /// 格式：0xAA 0x02 模式代码 校验和 0xFF
  /// 模式代码：0x01=清洁 0x02=运行 0x03=调色
  Future<void> sendModeCommand(DeviceMode mode) async {
    if (_writeCharacteristic == null) {
      debugPrint('写入特征未找到');
      return;
    }

    try {
      final modeCode = mode == DeviceMode.cleaning
          ? 0x01
          : mode == DeviceMode.running
              ? 0x02
              : 0x03;
      
      final checksum = (0x02 + modeCode) & 0xFF;
      final command = [0xAA, 0x02, modeCode, checksum, 0xFF];
      
      await _writeCharacteristic!.write(command, withoutResponse: false);
      debugPrint('发送模式命令: ${mode.name}');
    } catch (e) {
      debugPrint('发送模式命令失败: $e');
    }
  }

  /// 发送RGB颜色命令
  /// 格式：0xAA 0x03 区域 R G B 校验和 0xFF
  /// 区域：0x01=L 0x02=M 0x03=R 0x04=B
  Future<void> sendColorCommand(int zone, List<int> rgb) async {
    if (_writeCharacteristic == null) {
      debugPrint('写入特征未找到');
      return;
    }

    try {
      final r = rgb[0] & 0xFF;
      final g = rgb[1] & 0xFF;
      final b = rgb[2] & 0xFF;
      final checksum = (0x03 + zone + r + g + b) & 0xFF;
      
      final command = [0xAA, 0x03, zone, r, g, b, checksum, 0xFF];
      
      await _writeCharacteristic!.write(command, withoutResponse: false);
      debugPrint('发送颜色命令 - 区域$zone: RGB($r, $g, $b)');
    } catch (e) {
      debugPrint('发送颜色命令失败: $e');
    }
  }

  /// 监听设备数据
  Stream<List<int>>? listenToDevice() {
    return _notifyCharacteristic?.lastValueStream;
  }

  /// 获取连接状态
  bool get isConnected => _connectedDevice != null;

  /// 获取当前连接的设备
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;

  /// 获取写入特征（供ProtocolService使用）
  fbp.BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;

  /// 获取通知特征（供ProtocolService使用）
  fbp.BluetoothCharacteristic? get notifyCharacteristic => _notifyCharacteristic;
}

