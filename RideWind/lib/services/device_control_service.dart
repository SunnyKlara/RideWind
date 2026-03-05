import 'dart:async';
import 'package:flutter/material.dart';
import 'protocol_service.dart';
import 'ble_service.dart';

/// 设备控制服务
/// 提供高层次的设备控制接口
class DeviceControlService {
  late final ProtocolService _protocol;
  final BLEService _bleService = BLEService();

  DeviceControlService() {
    _protocol = ProtocolService(_bleService);
  }

  // 状态回调
  StreamController<Map<String, dynamic>>? _statusController;
  StreamSubscription? _statusSubscription;

  /// 初始化设备控制服务
  void init() {
    _statusController = StreamController<Map<String, dynamic>>.broadcast();
    
    // 监听设备数据
    _statusSubscription = _bleService.rxDataStream.listen((data) {
      // 这里原本调用了 parseDeviceStatusFromBytes，但 ProtocolService 中没有这个方法
      // 我们改用通用的解析逻辑或留空
      final response = String.fromCharCodes(data);
      final status = <String, dynamic>{'raw': response};
      
      // 尝试解析风扇速度作为示例
      final speed = _protocol.parseFanSpeed(response);
      if (speed != null) status['speed'] = speed;

      if (_statusController != null) {
        _statusController!.add(status);
      }
    });
  }

  /// 释放资源
  void dispose() {
    _statusSubscription?.cancel();
    _statusController?.close();
    _bleService.dispose();
  }

  /// 获取设备状态流
  Stream<Map<String, dynamic>>? get statusStream => _statusController?.stream;

  /// 控制风扇转速
  /// speed: 0-100
  Future<void> controlFan(int speed) async {
    if (!isConnected) {
      debugPrint('设备未连接，无法控制风扇');
      return;
    }
    
    await _protocol.setFanSpeed(speed);
  }

  /// 控制LED颜色
  /// r, g, b: 0-255
  Future<void> controlLedColor(int r, int g, int b) async {
    if (!isConnected) {
      debugPrint('设备未连接，无法控制LED颜色');
      return;
    }
    
    // 默认控制灯带1
    await _protocol.setLEDColor(1, r, g, b);
  }

  /// 从Color对象设置LED颜色
  Future<void> controlLedColorFromColor(Color color) async {
    await controlLedColor(
      color.red,
      color.green,
      color.blue,
    );
  }

  /// 控制LED亮度
  /// 注意：ProtocolService 目前没有 setLedBrightness，这里暂时留空或打印
  Future<void> controlLedBrightness(int brightness) async {
    debugPrint('ProtocolService 暂不支持亮度控制');
  }

  /// 控制LED模式
  /// 注意：ProtocolService 目前没有 setLedMode
  Future<void> controlLedMode(int mode, {int frequency = 1}) async {
    debugPrint('ProtocolService 暂不支持模式控制');
  }

  /// 控制烟雾开关
  Future<void> controlSmoke(bool turnOn) async {
    if (!isConnected) {
      debugPrint('设备未连接，无法控制烟雾');
      return;
    }
    
    await _protocol.setWuhuaqiStatus(turnOn);
  }

  /// 检查是否已连接
  bool get isConnected => _bleService.isConnected;
}

