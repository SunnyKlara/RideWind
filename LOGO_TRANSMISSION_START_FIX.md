# Logo传输无法开始问题修复

## 问题现象
- ✅ 硬件成功接收 `LOGO_START_COMPRESSED` 命令
- ✅ 硬件成功擦除Flash
- ✅ 硬件发送 `LOGO_READY` 响应
- ✅ APP显示"传输中..."
- ❌ 但进度一直停在 0.0%，没有发送任何数据包

## 可能原因

### 原因1: 响应监听器冲突
`_setupResponseListener()` 被调用多次，创建了多个监听器，导致响应处理混乱。

**修复**: 在创建新监听器前先取消旧的
```dart
void _setupResponseListener() {
    // 先取消之前的监听器
    _responseSub?.cancel();
    
    _responseSub = btProvider.rawDataStream.listen((data) {
        // ...
    });
}
```

### 原因2: window或imageData未正确初始化
`_transmitWithSlidingWindow()` 依赖 `window` 和 `imageData`，如果它们未初始化，传输无法开始。

**调试**: 添加日志确认初始化状态
```dart
Future<void> _transmitWithSlidingWindow() async {
    print('[SLIDING_WINDOW] 开始传输');
    print('[SLIDING_WINDOW] totalPackets=${window.totalPackets}, sendBase=${window.sendBase}');
    print('[SLIDING_WINDOW] imageData.length=${imageData.length}');
    
    while (window.sendBase < window.totalPackets) {
        // ...
    }
}
```

## 已实施的修复

### 修复1: 取消旧的响应监听器
**文件**: `RideWind/lib/services/logo_transmission_manager.dart`

在 `_setupResponseListener()` 开头添加：
```dart
_responseSub?.cancel();
```

### 修复2: 添加调试日志
在 `_transmitWithSlidingWindow()` 开头添加：
```dart
print('[SLIDING_WINDOW] 开始传输');
print('[SLIDING_WINDOW] totalPackets=${window.totalPackets}, sendBase=${window.sendBase}');
print('[SLIDING_WINDOW] imageData.length=${imageData.length}');
```

在发送包时添加：
```dart
print('[SLIDING_WINDOW] 发送包 seq=${window.nextSeqNum}');
```

## 测试步骤

### 1. 重新编译APP
```bash
cd RideWind
flutter run
```

### 2. 上传Logo并观察日志
选择图片开始上传，观察日志输出：

#### ✅ 正常情况：
```
[SLIDING_WINDOW] 开始传输
[SLIDING_WINDOW] totalPackets=3910, sendBase=0
[SLIDING_WINDOW] imageData.length=62547
[SLIDING_WINDOW] 发送包 seq=0
[SLIDING_WINDOW] 发送包 seq=1
[SLIDING_WINDOW] 发送包 seq=2
...
📊 上传进度: 1%
📊 上传进度: 2%
```

#### ❌ 异常情况1: 没有看到 `[SLIDING_WINDOW]` 日志
说明：`_transmitWithSlidingWindow()` 没有被调用
可能原因：
- `transmitCompressedImage()` 在等待 `LOGO_READY` 时超时
- 抛出了异常

#### ❌ 异常情况2: 看到 `[SLIDING_WINDOW] 开始传输` 但没有 `发送包`
说明：while循环条件不满足
可能原因：
- `window.sendBase >= window.totalPackets` (不应该发生)
- `window.totalPackets == 0` (imageData为空)

#### ❌ 异常情况3: 看到 `发送包` 但进度不更新
说明：数据包发送了，但ACK没有收到
可能原因：
- 硬件没有发送ACK
- APP没有正确处理ACK
- 响应监听器有问题

## 下一步调试

根据日志输出，我们可以判断：

### 如果看到 `[SLIDING_WINDOW] 开始传输`
说明 `_transmitWithSlidingWindow()` 被调用了，检查：
- `totalPackets` 是否正确（应该是 3910 左右）
- `sendBase` 是否为 0
- `imageData.length` 是否正确（应该是 62547）

### 如果看到 `发送包 seq=0`
说明数据包开始发送了，检查：
- 硬件是否收到数据包（应该看到 `[LOGO] Packet X` 日志）
- 硬件是否发送ACK（应该看到 `[LOGO] ACK sent` 日志）
- APP是否收到ACK（应该看到 `收到ACK:X` 日志）

### 如果什么都没看到
说明 `_transmitWithSlidingWindow()` 没有被调用，检查：
- `transmitCompressedImage()` 是否抛出异常
- `_waitForResponse()` 是否超时
- 响应监听器是否正常工作

## 可能需要的额外修复

### 如果 `window.totalPackets == 0`
检查 `transmitCompressedImage()` 中的初始化：
```dart
window = SlidingWindow(
  totalPackets: (compressedData.length + 15) ~/ 16,  // 应该 > 0
  windowSize: 50,
);
```

### 如果响应监听器不工作
检查 `btProvider.rawDataStream` 是否正常：
```dart
btProvider.rawDataStream.listen((data) {
    print('[RAW] 收到数据: $data');
});
```

### 如果硬件没有发送ACK
检查硬件端 `logo.c` 中的ACK发送逻辑：
```c
if ((seq + 1) % 10 == 0) {
    sprintf(response, "LOGO_ACK:%lu\n", (unsigned long)seq);
    BLE_SendString(response);
}
```

## 总结
本次修复主要是：
1. ✅ 修复响应监听器冲突
2. ✅ 添加详细的调试日志

请重新编译APP并测试，把完整的日志发给我！
