# 蓝牙传输稳定性优化设计文档

> **功能名称**: JDY-08蓝牙模块Logo传输协议优化  
> **版本**: v1.0  
> **创建日期**: 2026-01-17  
> **状态**: 设计中

---

## 1. 设计概述

### 1.1 核心问题分析

**当前实现的主要缺陷**:

1. **ACK频率不合理**: 每10包才确认一次,中间9包丢失无法及时发现
2. **重传策略简陋**: 超时后简单重传,没有区分快速重传和超时重传
3. **无滑动窗口**: 发送-等待-发送模式效率低,没有利用管道传输
4. **固定延迟**: 20ms固定延迟不适应不同信号质量
5. **序号同步问题**: ACK序号不匹配时处理逻辑混乱

### 1.2 优化策略

本设计采用**类TCP滑动窗口 + 选择性重传**机制:

- **滑动窗口**: 允许多个包在途,提高吞吐量
- **累积ACK**: 确认最大连续序号,减少ACK数量
- **选择性ACK (SACK)**: 报告丢失的包,精确重传
- **自适应速率**: 根据丢包率动态调整发送间隔
- **快速重传**: 收到重复ACK立即重传,不等超时
- **RTT估算**: 动态调整超时时间

---

## 2. 协议设计

### 2.1 协议格式

#### 2.1.1 命令格式 (APP → 硬件)

```
LOGO_START:size:crc32
  - size: 数据总大小 (47432)
  - crc32: 整体CRC32校验值

LOGO_DATA:seq:hexdata
  - seq: 包序号 (0-2964)
  - hexdata: 16字节数据的十六进制编码 (32字符)

LOGO_END
  - 传输结束,触发CRC校验

LOGO_QUERY_PROGRESS
  - 查询传输进度,用于断点续传

GET:LOGO
  - 查询是否有自定义Logo
```

#### 2.1.2 响应格式 (硬件 → APP)

```
LOGO_READY
  - Flash擦除完成,准备接收

LOGO_ACK:seq
  - 累积确认: 已成功接收0~seq的所有包

LOGO_SACK:seq:bitmap
  - 选择性确认: seq是基准序号, bitmap表示后续16包的接收情况
  - bitmap: 16位二进制,1表示已收到,0表示丢失
  - 例: LOGO_SACK:100:1101111011110111
    表示包101,104,109已丢失,其他已收到

LOGO_NAK:seq
  - 请求重传seq号包

LOGO_PAUSE
  - 缓冲区满,暂停发送

LOGO_RESUME
  - 缓冲区可用,恢复发送

LOGO_PROGRESS:received:total
  - 进度报告 (用于断点续传)

LOGO_OK
  - 传输成功

LOGO_FAIL:reason
  - 传输失败及原因
```



### 2.2 状态机设计

#### 2.2.1 APP端状态机

```
┌─────────────────────────────────────────────────────────────────┐
│                        APP端传输状态机                           │
└─────────────────────────────────────────────────────────────────┘

    IDLE (空闲)
      │
      │ 用户点击上传
      ▼
    PREPARING (准备)
      │ - 图片处理
      │ - CRC32计算
      ▼
    STARTING (启动)
      │ - 发送LOGO_START
      │ - 等待LOGO_READY
      ▼
    TRANSMITTING (传输中)
      │ - 滑动窗口发送
      │ - 处理ACK/SACK
      │ - 重传丢失包
      │
      ├─→ PAUSED (暂停)
      │     │ 收到LOGO_PAUSE
      │     │ 等待LOGO_RESUME
      │     └─→ 返回TRANSMITTING
      │
      ├─→ RETRYING (重试)
      │     │ 超时或错误
      │     │ 重传丢失包
      │     └─→ 返回TRANSMITTING
      │
      ▼
    VERIFYING (校验)
      │ - 发送LOGO_END
      │ - 等待LOGO_OK
      ▼
    COMPLETED (完成)
      │
      ▼
    IDLE

    ERROR (错误)
      │ - 显示错误信息
      │ - 支持重试
      └─→ 返回IDLE或TRANSMITTING
```

#### 2.2.2 硬件端状态机

```
┌─────────────────────────────────────────────────────────────────┐
│                       硬件端接收状态机                           │
└─────────────────────────────────────────────────────────────────┘

    IDLE (空闲)
      │
      │ 收到LOGO_START
      ▼
    ERASING (擦除Flash)
      │ - 擦除12个扇区
      │ - 发送LOGO_ERASING
      ▼
    READY (就绪)
      │ - 发送LOGO_READY
      │ - 初始化接收缓冲区
      ▼
    RECEIVING (接收中)
      │ - 接收LOGO_DATA
      │ - 写入Flash
      │ - 发送ACK/SACK
      │
      ├─→ BUFFER_FULL (缓冲区满)
      │     │ 发送LOGO_PAUSE
      │     │ 等待Flash写入完成
      │     │ 发送LOGO_RESUME
      │     └─→ 返回RECEIVING
      │
      │ 收到LOGO_END
      ▼
    VERIFYING (校验)
      │ - 计算CRC32
      │ - 验证数据完整性
      ▼
    WRITING_HEADER (写入头部)
      │ - 写入LogoHeader
      │ - 标记有效
      ▼
    COMPLETE (完成)
      │ - 发送LOGO_OK
      └─→ 返回IDLE

    ERROR (错误)
      │ - 发送LOGO_FAIL
      └─→ 返回IDLE
```

---

## 3. 核心算法设计

### 3.1 滑动窗口算法

#### 3.1.1 窗口参数

```dart
class SlidingWindow {
  int windowSize;           // 窗口大小 (5-20包)
  int sendBase;             // 窗口起始序号 (最小未确认包)
  int nextSeqNum;           // 下一个要发送的序号
  int totalPackets;         // 总包数 (2965)
  
  Map<int, PacketInfo> inFlightPackets;  // 在途包信息
  Set<int> ackedPackets;                 // 已确认的包
  Set<int> lostPackets;                  // 已知丢失的包
  
  // 窗口状态
  bool get isFull => (nextSeqNum - sendBase) >= windowSize;
  bool get isEmpty => sendBase == nextSeqNum;
  int get inFlightCount => nextSeqNum - sendBase;
}

class PacketInfo {
  int seq;                  // 序号
  Uint8List data;           // 数据
  DateTime sendTime;        // 发送时间
  int retryCount;           // 重传次数
  bool acked;               // 是否已确认
}
```

#### 3.1.2 发送算法

```dart
Future<void> transmitWithSlidingWindow() async {
  final window = SlidingWindow(
    windowSize: 10,  // 初始窗口大小
    totalPackets: totalChunks,
  );
  
  while (window.sendBase < window.totalPackets) {
    // 1. 发送窗口内的新包
    while (!window.isFull && window.nextSeqNum < window.totalPackets) {
      await sendPacket(window.nextSeqNum);
      window.nextSeqNum++;
    }
    
    // 2. 等待ACK (非阻塞,使用超时)
    final ack = await waitForAck(timeout: calculateTimeout());
    
    if (ack != null) {
      // 3. 处理ACK
      if (ack.type == AckType.cumulative) {
        // 累积ACK: 滑动窗口
        window.slideWindow(ack.seq);
      } else if (ack.type == AckType.selective) {
        // 选择性ACK: 标记丢失包
        window.markLostPackets(ack.lostSeqs);
      }
      
      // 4. 更新RTT和超时时间
      updateRTT(ack.seq);
      
      // 5. 调整窗口大小
      adjustWindowSize();
    } else {
      // 超时: 重传最早的未确认包
      await retransmitOldest();
    }
    
    // 6. 快速重传丢失的包
    await retransmitLostPackets();
    
    // 7. 更新进度
    updateProgress();
  }
}
```



### 3.2 ACK处理算法

#### 3.2.1 累积ACK处理

```dart
void handleCumulativeAck(int ackedSeq) {
  // 确认所有 <= ackedSeq 的包
  for (int seq = sendBase; seq <= ackedSeq; seq++) {
    if (inFlightPackets.containsKey(seq)) {
      ackedPackets.add(seq);
      inFlightPackets.remove(seq);
      
      // 更新RTT
      final sendTime = inFlightPackets[seq]?.sendTime;
      if (sendTime != null) {
        final rtt = DateTime.now().difference(sendTime);
        updateRTT(rtt);
      }
    }
  }
  
  // 滑动窗口
  sendBase = ackedSeq + 1;
  
  // 重置重复ACK计数
  duplicateAckCount = 0;
}
```

#### 3.2.2 选择性ACK (SACK) 处理

```dart
void handleSelectiveAck(int baseSeq, String bitmap) {
  // bitmap: "1101111011110111" (16位)
  // 1表示已收到, 0表示丢失
  
  for (int i = 0; i < bitmap.length && i < 16; i++) {
    final seq = baseSeq + i + 1;
    
    if (bitmap[i] == '1') {
      // 已收到
      ackedPackets.add(seq);
      inFlightPackets.remove(seq);
    } else {
      // 丢失,标记为需要重传
      lostPackets.add(seq);
    }
  }
  
  // 更新sendBase到最小未确认包
  while (sendBase < totalPackets && ackedPackets.contains(sendBase)) {
    sendBase++;
  }
}
```

#### 3.2.3 重复ACK检测 (快速重传)

```dart
int lastAckSeq = -1;
int duplicateAckCount = 0;

void handleAck(int ackedSeq) {
  if (ackedSeq == lastAckSeq) {
    duplicateAckCount++;
    
    // 收到3次重复ACK,触发快速重传
    if (duplicateAckCount == 3) {
      final nextSeq = ackedSeq + 1;
      if (inFlightPackets.containsKey(nextSeq)) {
        print('快速重传: seq=$nextSeq');
        retransmitPacket(nextSeq);
        duplicateAckCount = 0;
      }
    }
  } else {
    lastAckSeq = ackedSeq;
    duplicateAckCount = 0;
    handleCumulativeAck(ackedSeq);
  }
}
```

### 3.3 超时重传算法

#### 3.3.1 RTT估算 (类TCP算法)

```dart
class RTTEstimator {
  double estimatedRTT = 500.0;  // 初始估计值 (ms)
  double devRTT = 100.0;        // RTT偏差
  
  final double alpha = 0.125;   // 平滑因子
  final double beta = 0.25;     // 偏差因子
  
  void updateRTT(Duration measuredRTT) {
    final sampleRTT = measuredRTT.inMilliseconds.toDouble();
    
    // 更新估计RTT: EstimatedRTT = (1-α) * EstimatedRTT + α * SampleRTT
    estimatedRTT = (1 - alpha) * estimatedRTT + alpha * sampleRTT;
    
    // 更新偏差: DevRTT = (1-β) * DevRTT + β * |SampleRTT - EstimatedRTT|
    devRTT = (1 - beta) * devRTT + beta * (sampleRTT - estimatedRTT).abs();
  }
  
  int getTimeout() {
    // TimeoutInterval = EstimatedRTT + 4 * DevRTT
    final timeout = (estimatedRTT + 4 * devRTT).toInt();
    
    // 限制范围: 300ms ~ 3000ms
    return timeout.clamp(300, 3000);
  }
}
```

#### 3.3.2 超时重传策略

```dart
Future<void> checkTimeout() async {
  final now = DateTime.now();
  final timeout = Duration(milliseconds: rttEstimator.getTimeout());
  
  for (final entry in inFlightPackets.entries) {
    final seq = entry.key;
    final packet = entry.value;
    
    if (!packet.acked && now.difference(packet.sendTime) > timeout) {
      // 超时,重传
      packet.retryCount++;
      
      if (packet.retryCount > maxRetries) {
        // 超过最大重传次数,标记为失败
        throw Exception('包$seq重传失败,超过最大次数');
      }
      
      print('超时重传: seq=$seq, retry=${packet.retryCount}');
      await retransmitPacket(seq);
      
      // 指数退避: 增加超时时间
      rttEstimator.estimatedRTT *= 1.5;
    }
  }
}
```

### 3.4 自适应速率调整

#### 3.4.1 丢包率计算

```dart
class PacketLossMonitor {
  int sentPackets = 0;
  int lostPackets = 0;
  int retransmittedPackets = 0;
  
  double get lossRate {
    if (sentPackets == 0) return 0.0;
    return lostPackets / sentPackets;
  }
  
  void recordSent() {
    sentPackets++;
  }
  
  void recordLost() {
    lostPackets++;
  }
  
  void recordRetransmit() {
    retransmittedPackets++;
  }
  
  // 每100包重置统计,避免历史数据影响
  void resetIfNeeded() {
    if (sentPackets >= 100) {
      sentPackets = 0;
      lostPackets = 0;
      retransmittedPackets = 0;
    }
  }
}
```

#### 3.4.2 动态调整发送间隔

```dart
class AdaptiveRateController {
  int sendInterval = 20;  // 初始发送间隔 (ms)
  
  final int minInterval = 10;   // 最小间隔 (快速模式)
  final int normalInterval = 30; // 正常间隔
  final int maxInterval = 80;   // 最大间隔 (慢速模式)
  
  void adjustRate(double lossRate) {
    if (lossRate < 0.05) {
      // 丢包率 < 5%: 加速
      sendInterval = max(minInterval, sendInterval - 5);
      print('加速传输: interval=${sendInterval}ms');
    } else if (lossRate > 0.15) {
      // 丢包率 > 15%: 减速
      sendInterval = min(maxInterval, sendInterval + 10);
      print('减速传输: interval=${sendInterval}ms');
    } else {
      // 5% ~ 15%: 保持或微调
      if (sendInterval > normalInterval) {
        sendInterval--;
      } else if (sendInterval < normalInterval) {
        sendInterval++;
      }
    }
  }
  
  Future<void> waitBeforeSend() async {
    await Future.delayed(Duration(milliseconds: sendInterval));
  }
}
```

#### 3.4.3 窗口大小动态调整

```dart
class WindowSizeController {
  int windowSize = 10;  // 初始窗口大小
  
  final int minWindow = 5;   // 最小窗口
  final int maxWindow = 20;  // 最大窗口
  
  int consecutiveSuccess = 0;
  int consecutiveFailure = 0;
  
  void onSuccess() {
    consecutiveSuccess++;
    consecutiveFailure = 0;
    
    // 连续10次成功,增大窗口
    if (consecutiveSuccess >= 10 && windowSize < maxWindow) {
      windowSize++;
      consecutiveSuccess = 0;
      print('增大窗口: size=$windowSize');
    }
  }
  
  void onFailure() {
    consecutiveFailure++;
    consecutiveSuccess = 0;
    
    // 连续3次失败,减小窗口
    if (consecutiveFailure >= 3 && windowSize > minWindow) {
      windowSize = max(minWindow, windowSize - 2);
      consecutiveFailure = 0;
      print('减小窗口: size=$windowSize');
    }
  }
}
```



### 3.5 断点续传算法

#### 3.5.1 进度保存

```dart
class TransmissionProgress {
  int totalPackets;
  int lastAckedSeq;           // 最后确认的连续序号
  Set<int> receivedPackets;   // 已接收的所有包 (包括非连续)
  DateTime lastUpdateTime;
  
  // 保存到本地存储
  Future<void> save(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'logo_progress_$deviceId';
    
    final data = {
      'totalPackets': totalPackets,
      'lastAckedSeq': lastAckedSeq,
      'receivedPackets': receivedPackets.toList(),
      'timestamp': lastUpdateTime.millisecondsSinceEpoch,
    };
    
    await prefs.setString(key, jsonEncode(data));
  }
  
  // 从本地存储加载
  static Future<TransmissionProgress?> load(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'logo_progress_$deviceId';
    final jsonStr = prefs.getString(key);
    
    if (jsonStr == null) return null;
    
    final data = jsonDecode(jsonStr);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
    
    // 超过1小时的进度失效
    if (DateTime.now().difference(timestamp).inHours > 1) {
      await prefs.remove(key);
      return null;
    }
    
    return TransmissionProgress(
      totalPackets: data['totalPackets'],
      lastAckedSeq: data['lastAckedSeq'],
      receivedPackets: Set<int>.from(data['receivedPackets']),
      lastUpdateTime: timestamp,
    );
  }
  
  // 清除进度
  static Future<void> clear(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logo_progress_$deviceId');
  }
}
```

#### 3.5.2 断点恢复流程

```dart
Future<void> resumeTransmission() async {
  // 1. 查询硬件端进度
  await btProvider.sendCommand('LOGO_QUERY_PROGRESS');
  final response = await waitForResponse(timeout: Duration(seconds: 3));
  
  if (response.startsWith('LOGO_PROGRESS:')) {
    // 解析: LOGO_PROGRESS:received:total
    final parts = response.split(':');
    final hwReceivedSeq = int.parse(parts[1]);
    final hwTotal = int.parse(parts[2]);
    
    // 2. 加载本地进度
    final localProgress = await TransmissionProgress.load(deviceId);
    
    // 3. 取两者最小值作为断点 (保守策略)
    final resumeSeq = min(
      hwReceivedSeq,
      localProgress?.lastAckedSeq ?? 0,
    );
    
    print('断点续传: 从包$resumeSeq继续');
    
    // 4. 从断点继续传输
    window.sendBase = resumeSeq;
    window.nextSeqNum = resumeSeq;
    
    // 5. 继续传输
    await transmitWithSlidingWindow();
  } else {
    // 硬件端不支持断点续传,从头开始
    print('硬件端不支持断点续传,从头开始');
    await startNewTransmission();
  }
}
```

---

## 4. 数据结构设计

### 4.1 APP端数据结构

```dart
// ════════════════════════════════════════════════════════════
// 传输管理器
// ════════════════════════════════════════════════════════════
class LogoTransmissionManager {
  // 基础参数
  final BluetoothProvider btProvider;
  final Uint8List imageData;  // RGB565数据 (47432字节)
  final int totalPackets = 2965;  // 47432 / 16
  final int chunkSize = 16;
  
  // 滑动窗口
  late SlidingWindow window;
  
  // 速率控制
  late AdaptiveRateController rateController;
  late WindowSizeController windowController;
  late RTTEstimator rttEstimator;
  late PacketLossMonitor lossMonitor;
  
  // 状态
  TransmissionState state = TransmissionState.idle;
  double progress = 0.0;
  String statusMessage = '';
  
  // 统计
  int totalSent = 0;
  int totalRetransmitted = 0;
  DateTime? startTime;
  
  // 回调
  Function(double)? onProgress;
  Function(String)? onStatusChange;
  Function(TransmissionStats)? onComplete;
  Function(String)? onError;
}

// ════════════════════════════════════════════════════════════
// 包信息
// ════════════════════════════════════════════════════════════
class PacketInfo {
  final int seq;
  final Uint8List data;
  DateTime sendTime;
  int retryCount;
  bool acked;
  
  PacketInfo({
    required this.seq,
    required this.data,
    required this.sendTime,
    this.retryCount = 0,
    this.acked = false,
  });
  
  Duration get age => DateTime.now().difference(sendTime);
  bool isTimeout(int timeoutMs) => age.inMilliseconds > timeoutMs;
}

// ════════════════════════════════════════════════════════════
// ACK信息
// ════════════════════════════════════════════════════════════
enum AckType { cumulative, selective, nak }

class AckInfo {
  final AckType type;
  final int seq;
  final String? bitmap;  // 用于SACK
  final DateTime receiveTime;
  
  AckInfo({
    required this.type,
    required this.seq,
    this.bitmap,
    DateTime? receiveTime,
  }) : receiveTime = receiveTime ?? DateTime.now();
  
  // 解析SACK bitmap,返回丢失的包序号列表
  List<int> getLostPackets() {
    if (type != AckType.selective || bitmap == null) return [];
    
    final lost = <int>[];
    for (int i = 0; i < bitmap!.length; i++) {
      if (bitmap![i] == '0') {
        lost.add(seq + i + 1);
      }
    }
    return lost;
  }
}

// ════════════════════════════════════════════════════════════
// 传输统计
// ════════════════════════════════════════════════════════════
class TransmissionStats {
  final int totalPackets;
  final int sentPackets;
  final int retransmittedPackets;
  final int lostPackets;
  final Duration totalTime;
  final double averageRTT;
  final double lossRate;
  final double throughput;  // 字节/秒
  
  TransmissionStats({
    required this.totalPackets,
    required this.sentPackets,
    required this.retransmittedPackets,
    required this.lostPackets,
    required this.totalTime,
    required this.averageRTT,
    required this.lossRate,
    required this.throughput,
  });
  
  @override
  String toString() {
    return '''
传输统计:
- 总包数: $totalPackets
- 发送包数: $sentPackets
- 重传包数: $retransmittedPackets
- 丢失包数: $lostPackets
- 总耗时: ${totalTime.inSeconds}秒
- 平均RTT: ${averageRTT.toStringAsFixed(1)}ms
- 丢包率: ${(lossRate * 100).toStringAsFixed(2)}%
- 吞吐量: ${(throughput / 1024).toStringAsFixed(2)} KB/s
''';
  }
}
```



### 4.2 硬件端数据结构

```c
// ════════════════════════════════════════════════════════════
// 接收窗口 (硬件端)
// ════════════════════════════════════════════════════════════
typedef struct {
    uint32_t expectedSeq;        // 期望的下一个序号
    uint32_t maxReceivedSeq;     // 已接收的最大序号
    uint32_t totalPackets;       // 总包数
    
    // 接收位图 (用于SACK)
    // 每个bit表示一个包是否已接收
    // 最多跟踪256个包的状态
    uint8_t receiveBitmap[32];   // 256 bits = 32 bytes
    
    // 缓冲区管理
    uint8_t buffer[256];         // 临时缓冲区 (16包)
    uint16_t bufferUsed;         // 已使用字节数
    bool bufferFull;             // 缓冲区满标志
    
} ReceiveWindow_t;

// ════════════════════════════════════════════════════════════
// 传输状态
// ════════════════════════════════════════════════════════════
typedef enum {
    LOGO_STATE_IDLE = 0,
    LOGO_STATE_ERASING,
    LOGO_STATE_READY,
    LOGO_STATE_RECEIVING,
    LOGO_STATE_BUFFER_FULL,
    LOGO_STATE_VERIFYING,
    LOGO_STATE_COMPLETE,
    LOGO_STATE_ERROR
} LogoState_t;

// ════════════════════════════════════════════════════════════
// 全局变量
// ════════════════════════════════════════════════════════════
static ReceiveWindow_t g_receiveWindow;
static LogoState_t g_logoState = LOGO_STATE_IDLE;
static uint32_t g_totalSize = 0;
static uint32_t g_receivedSize = 0;
static uint32_t g_expectedCRC = 0;
static uint32_t g_lastAckSeq = 0;
static uint32_t g_ackCounter = 0;  // ACK计数器

// ════════════════════════════════════════════════════════════
// 位图操作函数
// ════════════════════════════════════════════════════════════

// 设置某个序号为已接收
static void Bitmap_Set(uint32_t seq) {
    if (seq >= 256) return;  // 超出范围
    uint32_t byteIndex = seq / 8;
    uint32_t bitIndex = seq % 8;
    g_receiveWindow.receiveBitmap[byteIndex] |= (1 << bitIndex);
}

// 检查某个序号是否已接收
static bool Bitmap_IsSet(uint32_t seq) {
    if (seq >= 256) return false;
    uint32_t byteIndex = seq / 8;
    uint32_t bitIndex = seq % 8;
    return (g_receiveWindow.receiveBitmap[byteIndex] & (1 << bitIndex)) != 0;
}

// 清空位图
static void Bitmap_Clear(void) {
    memset(g_receiveWindow.receiveBitmap, 0, sizeof(g_receiveWindow.receiveBitmap));
}

// 生成SACK bitmap字符串 (16位)
static void Bitmap_GenerateSACK(uint32_t baseSeq, char* output) {
    for (int i = 0; i < 16; i++) {
        uint32_t seq = baseSeq + i + 1;
        output[i] = Bitmap_IsSet(seq % 256) ? '1' : '0';
    }
    output[16] = '\0';
}
```

---

## 5. 完整传输流程

### 5.1 APP端主流程

```dart
Future<void> uploadLogo() async {
  try {
    // ════════════════════════════════════════════════════════════
    // 阶段1: 准备
    // ════════════════════════════════════════════════════════════
    setState(() {
      state = TransmissionState.preparing;
      statusMessage = '准备上传...';
    });
    
    // 1.1 图片处理
    final rgb565Data = await convertImageToRGB565(selectedImage);
    if (rgb565Data == null || rgb565Data.length != 47432) {
      throw Exception('图片处理失败');
    }
    
    // 1.2 计算CRC32
    final crc32 = calculateCRC32(rgb565Data);
    
    // 1.3 初始化传输管理器
    final manager = LogoTransmissionManager(
      btProvider: btProvider,
      imageData: rgb565Data,
      onProgress: (progress) {
        setState(() => uploadProgress = progress);
      },
      onStatusChange: (status) {
        setState(() => statusMessage = status);
      },
    );
    
    // ════════════════════════════════════════════════════════════
    // 阶段2: 启动传输
    // ════════════════════════════════════════════════════════════
    setState(() {
      state = TransmissionState.starting;
      statusMessage = '启动传输...';
    });
    
    // 2.1 发送LOGO_START
    await btProvider.sendCommand('LOGO_START:${rgb565Data.length}:$crc32');
    
    // 2.2 等待LOGO_READY (可能先收到LOGO_ERASING)
    var response = await waitForResponse(timeout: Duration(seconds: 10));
    
    if (response == 'LOGO_ERASING') {
      setState(() => statusMessage = 'Flash擦除中...');
      response = await waitForResponse(timeout: Duration(seconds: 15));
    }
    
    if (response != 'LOGO_READY') {
      throw Exception('硬件未就绪: $response');
    }
    
    // ════════════════════════════════════════════════════════════
    // 阶段3: 数据传输 (核心)
    // ════════════════════════════════════════════════════════════
    setState(() {
      state = TransmissionState.transmitting;
      statusMessage = '传输中...';
    });
    
    await manager.transmitWithSlidingWindow();
    
    // ════════════════════════════════════════════════════════════
    // 阶段4: 校验
    // ════════════════════════════════════════════════════════════
    setState(() {
      state = TransmissionState.verifying;
      statusMessage = '校验中...';
    });
    
    await btProvider.sendCommand('LOGO_END');
    response = await waitForResponse(timeout: Duration(seconds: 10));
    
    if (!response.startsWith('LOGO_OK')) {
      throw Exception('校验失败: $response');
    }
    
    // ════════════════════════════════════════════════════════════
    // 阶段5: 完成
    // ════════════════════════════════════════════════════════════
    final stats = manager.getStats();
    print(stats.toString());
    
    setState(() {
      state = TransmissionState.completed;
      statusMessage = '上传成功！';
      uploadProgress = 1.0;
    });
    
    // 清除断点进度
    await TransmissionProgress.clear(deviceId);
    
  } catch (e) {
    setState(() {
      state = TransmissionState.error;
      statusMessage = '上传失败: $e';
    });
    rethrow;
  }
}
```

### 5.2 硬件端主流程

```c
// ════════════════════════════════════════════════════════════
// 命令解析入口
// ════════════════════════════════════════════════════════════
void Logo_ParseCommand(char* cmd) {
    char response[128];
    
    // ────────────────────────────────────────────────────────
    // LOGO_START: 开始传输
    // ────────────────────────────────────────────────────────
    if (strncmp(cmd, "LOGO_START:", 11) == 0) {
        // 解析参数
        uint32_t size = 0, crc = 0;
        char* p = cmd + 11;
        size = strtoul(p, &p, 10);
        if (*p == ':') {
            crc = strtoul(p + 1, NULL, 10);
        }
        
        // 校验大小
        if (size != LOGO_DATA_SIZE) {
            sprintf(response, "LOGO_ERROR:SIZE_MISMATCH\n");
            BLE_SendString(response);
            return;
        }
        
        // 擦除Flash
        g_logoState = LOGO_STATE_ERASING;
        BLE_SendString("LOGO_ERASING\n");
        
        for (int i = 0; i < 12; i++) {
            W25Q128_EraseSector(LOGO_FLASH_ADDR + i * 4096);
        }
        
        // 初始化接收窗口
        memset(&g_receiveWindow, 0, sizeof(g_receiveWindow));
        g_receiveWindow.totalPackets = (size + 15) / 16;  // 向上取整
        
        g_totalSize = size;
        g_receivedSize = 0;
        g_expectedCRC = crc;
        g_lastAckSeq = 0;
        g_ackCounter = 0;
        
        g_logoState = LOGO_STATE_READY;
        BLE_SendString("LOGO_READY\n");
    }
    
    // ────────────────────────────────────────────────────────
    // LOGO_DATA: 接收数据包
    // ────────────────────────────────────────────────────────
    else if (strncmp(cmd, "LOGO_DATA:", 10) == 0) {
        if (g_logoState != LOGO_STATE_RECEIVING && 
            g_logoState != LOGO_STATE_READY) {
            BLE_SendString("LOGO_ERROR:NOT_READY\n");
            return;
        }
        
        g_logoState = LOGO_STATE_RECEIVING;
        
        // 解析序号
        char* p = cmd + 10;
        uint32_t seq = strtoul(p, &p, 10);
        if (*p != ':') return;
        
        char* hexData = p + 1;
        
        // 检查是否已接收 (幂等处理)
        if (Bitmap_IsSet(seq % 256)) {
            // 已接收,发送ACK但不重复写入
            g_ackCounter++;
            if (g_ackCounter % 10 == 0) {
                sprintf(response, "LOGO_ACK:%lu\n", (unsigned long)g_lastAckSeq);
                BLE_SendString(response);
            }
            return;
        }
        
        // 解码十六进制数据
        uint8_t buffer[32];
        int len = HexDecode(hexData, buffer, sizeof(buffer));
        if (len <= 0) {
            sprintf(response, "LOGO_NAK:%lu\n", (unsigned long)seq);
            BLE_SendString(response);
            return;
        }
        
        // 写入Flash
        uint32_t writeAddr = LOGO_FLASH_ADDR + LOGO_HEADER_SIZE + seq * 16;
        W25Q128_BufferWrite(buffer, writeAddr, len);
        
        // 更新接收状态
        Bitmap_Set(seq % 256);
        g_receivedSize += len;
        g_ackCounter++;
        
        // 更新最大连续序号
        while (Bitmap_IsSet(g_lastAckSeq % 256)) {
            g_lastAckSeq++;
        }
        
        // 发送ACK策略:
        // 1. 每10包发送一次累积ACK
        // 2. 检测到丢包时发送SACK
        if (g_ackCounter % 10 == 0) {
            // 累积ACK
            sprintf(response, "LOGO_ACK:%lu\n", (unsigned long)(g_lastAckSeq - 1));
            BLE_SendString(response);
        } else if (seq > g_lastAckSeq) {
            // 检测到丢包,发送SACK
            char bitmap[17];
            Bitmap_GenerateSACK(g_lastAckSeq - 1, bitmap);
            sprintf(response, "LOGO_SACK:%lu:%s\n", 
                    (unsigned long)(g_lastAckSeq - 1), bitmap);
            BLE_SendString(response);
        }
        
        // 缓冲区管理 (简化版,实际可能需要更复杂的逻辑)
        if (g_receiveWindow.bufferUsed > 200) {
            BLE_SendString("LOGO_PAUSE\n");
            g_logoState = LOGO_STATE_BUFFER_FULL;
            // ... 等待Flash写入完成 ...
            g_receiveWindow.bufferUsed = 0;
            BLE_SendString("LOGO_RESUME\n");
            g_logoState = LOGO_STATE_RECEIVING;
        }
    }
    
    // ────────────────────────────────────────────────────────
    // LOGO_END: 传输结束
    // ────────────────────────────────────────────────────────
    else if (strcmp(cmd, "LOGO_END") == 0) {
        if (g_logoState != LOGO_STATE_RECEIVING) {
            BLE_SendString("LOGO_ERROR:NOT_RECEIVING\n");
            return;
        }
        
        g_logoState = LOGO_STATE_VERIFYING;
        
        // 校验大小
        if (g_receivedSize != g_totalSize) {
            sprintf(response, "LOGO_FAIL:SIZE:%lu/%lu\n",
                    (unsigned long)g_receivedSize,
                    (unsigned long)g_totalSize);
            BLE_SendString(response);
            g_logoState = LOGO_STATE_ERROR;
            return;
        }
        
        // 计算CRC32
        uint32_t crc = CRC32_CalculateFlash(
            LOGO_FLASH_ADDR + LOGO_HEADER_SIZE,
            g_totalSize
        );
        
        if (crc != g_expectedCRC) {
            sprintf(response, "LOGO_FAIL:CRC:%lu\n", (unsigned long)crc);
            BLE_SendString(response);
            g_logoState = LOGO_STATE_ERROR;
            return;
        }
        
        // 写入头部
        LogoHeader_t header = {
            .magic = LOGO_MAGIC,
            .width = LOGO_WIDTH,
            .height = LOGO_HEIGHT,
            .reserved1 = 0,
            .dataSize = g_totalSize,
            .checksum = crc
        };
        W25Q128_BufferWrite((uint8_t*)&header, LOGO_FLASH_ADDR, sizeof(header));
        
        g_logoState = LOGO_STATE_COMPLETE;
        BLE_SendString("LOGO_OK\n");
    }
    
    // ────────────────────────────────────────────────────────
    // LOGO_QUERY_PROGRESS: 查询进度 (用于断点续传)
    // ────────────────────────────────────────────────────────
    else if (strcmp(cmd, "LOGO_QUERY_PROGRESS") == 0) {
        sprintf(response, "LOGO_PROGRESS:%lu:%lu\n",
                (unsigned long)g_lastAckSeq,
                (unsigned long)g_receiveWindow.totalPackets);
        BLE_SendString(response);
    }
}
```



---

## 6. 性能优化细节

### 6.1 批量发送优化

```dart
// 批量发送多个包,减少异步开销
Future<void> sendBatch(List<int> seqList) async {
  final commands = <String>[];
  
  for (final seq in seqList) {
    final start = seq * chunkSize;
    final end = min(start + chunkSize, imageData.length);
    final chunk = imageData.sublist(start, end);
    final hexString = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    commands.add('LOGO_DATA:$seq:$hexString');
  }
  
  // 批量发送
  for (final cmd in commands) {
    await btProvider.sendCommand(cmd);
    await Future.delayed(Duration(milliseconds: rateController.sendInterval));
  }
}
```

### 6.2 ACK合并处理

```dart
// 合并处理多个ACK,避免频繁更新UI
class AckBatcher {
  final List<AckInfo> _pendingAcks = [];
  Timer? _batchTimer;
  
  void addAck(AckInfo ack) {
    _pendingAcks.add(ack);
    
    // 延迟50ms批量处理
    _batchTimer?.cancel();
    _batchTimer = Timer(Duration(milliseconds: 50), () {
      _processBatch();
    });
  }
  
  void _processBatch() {
    if (_pendingAcks.isEmpty) return;
    
    // 找到最大的累积ACK
    int maxAck = -1;
    final sacks = <AckInfo>[];
    
    for (final ack in _pendingAcks) {
      if (ack.type == AckType.cumulative && ack.seq > maxAck) {
        maxAck = ack.seq;
      } else if (ack.type == AckType.selective) {
        sacks.add(ack);
      }
    }
    
    // 先处理累积ACK
    if (maxAck >= 0) {
      handleCumulativeAck(maxAck);
    }
    
    // 再处理SACK
    for (final sack in sacks) {
      handleSelectiveAck(sack.seq, sack.bitmap!);
    }
    
    _pendingAcks.clear();
  }
}
```

### 6.3 内存优化

```dart
// 避免重复创建Uint8List,使用对象池
class PacketPool {
  final Queue<Uint8List> _pool = Queue();
  final int _packetSize = 16;
  final int _maxPoolSize = 50;
  
  Uint8List acquire() {
    if (_pool.isNotEmpty) {
      return _pool.removeFirst();
    }
    return Uint8List(_packetSize);
  }
  
  void release(Uint8List packet) {
    if (_pool.length < _maxPoolSize) {
      _pool.add(packet);
    }
  }
}
```

### 6.4 日志优化

```dart
// 减少日志输出,避免影响性能
class TransmissionLogger {
  int _logCounter = 0;
  final int _logInterval = 50;  // 每50包输出一次
  
  void logPacket(int seq, String action) {
    _logCounter++;
    if (_logCounter % _logInterval == 0) {
      print('[$action] seq=$seq, progress=${(seq * 100 / totalPackets).toStringAsFixed(1)}%');
    }
  }
  
  void logImportant(String message) {
    print('[IMPORTANT] $message');
  }
}
```

---

## 7. 错误处理与恢复

### 7.1 错误分类

```dart
enum TransmissionError {
  // 连接错误
  bluetoothDisconnected,
  connectionTimeout,
  
  // 协议错误
  invalidResponse,
  protocolMismatch,
  
  // 传输错误
  packetLost,
  checksumMismatch,
  timeoutExceeded,
  
  // 硬件错误
  flashEraseFailed,
  flashWriteFailed,
  bufferOverflow,
  
  // 其他错误
  userCancelled,
  unknownError,
}

class TransmissionException implements Exception {
  final TransmissionError error;
  final String message;
  final dynamic details;
  final bool recoverable;
  
  TransmissionException({
    required this.error,
    required this.message,
    this.details,
    this.recoverable = false,
  });
  
  @override
  String toString() => 'TransmissionException: $message';
}
```

### 7.2 错误恢复策略

```dart
Future<void> handleError(TransmissionException e) async {
  print('错误: ${e.message}');
  
  switch (e.error) {
    case TransmissionError.bluetoothDisconnected:
      // 蓝牙断开: 等待重连
      setState(() => statusMessage = '蓝牙断开,等待重连...');
      await waitForReconnection(timeout: Duration(seconds: 30));
      if (btProvider.isConnected) {
        // 重连成功,尝试断点续传
        await resumeTransmission();
      } else {
        throw TransmissionException(
          error: TransmissionError.connectionTimeout,
          message: '重连超时',
          recoverable: false,
        );
      }
      break;
      
    case TransmissionError.packetLost:
      // 丢包: 重传
      if (e.details is int) {
        final seq = e.details as int;
        await retransmitPacket(seq);
      }
      break;
      
    case TransmissionError.timeoutExceeded:
      // 超时: 减速重试
      rateController.sendInterval = min(80, rateController.sendInterval + 20);
      windowController.windowSize = max(5, windowController.windowSize - 2);
      print('降速重试: interval=${rateController.sendInterval}ms, window=${windowController.windowSize}');
      await retransmitOldest();
      break;
      
    case TransmissionError.checksumMismatch:
      // 校验失败: 完全重传
      if (await confirmRetry('CRC校验失败,是否重新上传?')) {
        await startNewTransmission();
      } else {
        throw e;
      }
      break;
      
    case TransmissionError.userCancelled:
      // 用户取消: 清理资源
      await cleanup();
      break;
      
    default:
      // 其他错误: 询问用户
      if (e.recoverable && await confirmRetry('上传失败: ${e.message}\n是否重试?')) {
        await resumeTransmission();
      } else {
        throw e;
      }
  }
}
```

### 7.3 重试策略

```dart
class RetryPolicy {
  int maxRetries = 3;
  int currentRetry = 0;
  Duration baseDelay = Duration(seconds: 1);
  
  // 指数退避
  Duration getDelay() {
    return baseDelay * pow(2, currentRetry).toInt();
  }
  
  bool shouldRetry() {
    return currentRetry < maxRetries;
  }
  
  void recordRetry() {
    currentRetry++;
  }
  
  void reset() {
    currentRetry = 0;
  }
}

Future<T> retryWithPolicy<T>(
  Future<T> Function() operation,
  RetryPolicy policy,
) async {
  while (true) {
    try {
      final result = await operation();
      policy.reset();
      return result;
    } catch (e) {
      if (!policy.shouldRetry()) {
        rethrow;
      }
      
      policy.recordRetry();
      final delay = policy.getDelay();
      print('重试 ${policy.currentRetry}/${policy.maxRetries}, 等待${delay.inSeconds}秒...');
      await Future.delayed(delay);
    }
  }
}
```

---

## 8. 测试与验证

### 8.1 单元测试

```dart
// 测试滑动窗口
void testSlidingWindow() {
  final window = SlidingWindow(windowSize: 10, totalPackets: 100);
  
  // 测试发送
  assert(window.sendBase == 0);
  assert(window.nextSeqNum == 0);
  assert(!window.isFull);
  
  // 发送10个包
  for (int i = 0; i < 10; i++) {
    window.nextSeqNum++;
  }
  assert(window.isFull);
  
  // 确认前5个包
  window.slideWindow(4);
  assert(window.sendBase == 5);
  assert(!window.isFull);
  
  print('✓ 滑动窗口测试通过');
}

// 测试RTT估算
void testRTTEstimator() {
  final estimator = RTTEstimator();
  
  // 模拟RTT样本
  estimator.updateRTT(Duration(milliseconds: 100));
  estimator.updateRTT(Duration(milliseconds: 150));
  estimator.updateRTT(Duration(milliseconds: 120));
  
  final timeout = estimator.getTimeout();
  assert(timeout >= 300 && timeout <= 3000);
  
  print('✓ RTT估算测试通过, timeout=${timeout}ms');
}

// 测试CRC32
void testCRC32() {
  final data = Uint8List.fromList([1, 2, 3, 4, 5]);
  final crc1 = calculateCRC32(data);
  final crc2 = calculateCRC32(data);
  
  assert(crc1 == crc2);  // 相同数据应该得到相同CRC
  
  data[0] = 99;
  final crc3 = calculateCRC32(data);
  assert(crc1 != crc3);  // 不同数据应该得到不同CRC
  
  print('✓ CRC32测试通过');
}
```

### 8.2 集成测试场景

```dart
// 场景1: 正常传输
Future<void> testNormalTransmission() async {
  print('测试场景1: 正常传输');
  
  final result = await uploadLogo();
  assert(result.success);
  assert(result.stats.lossRate < 0.05);
  assert(result.stats.totalTime.inSeconds < 60);
  
  print('✓ 正常传输测试通过');
}

// 场景2: 弱信号环境
Future<void> testWeakSignal() async {
  print('测试场景2: 弱信号环境 (距离5米)');
  
  // 模拟弱信号: 增加丢包率
  simulatePacketLoss(rate: 0.15);
  
  final result = await uploadLogo();
  assert(result.success);
  assert(result.stats.totalTime.inSeconds < 90);
  
  print('✓ 弱信号测试通过');
}

// 场景3: 中断恢复
Future<void> testInterruptResume() async {
  print('测试场景3: 中断恢复');
  
  // 传输到50%时模拟断开
  final future = uploadLogo();
  await Future.delayed(Duration(seconds: 20));
  simulateDisconnect();
  
  // 等待5秒后重连
  await Future.delayed(Duration(seconds: 5));
  simulateReconnect();
  
  final result = await future;
  assert(result.success);
  assert(result.resumedFromBreakpoint);
  
  print('✓ 中断恢复测试通过');
}

// 场景4: 高丢包率
Future<void> testHighPacketLoss() async {
  print('测试场景4: 高丢包率 (20%)');
  
  simulatePacketLoss(rate: 0.20);
  
  final result = await uploadLogo();
  assert(result.success);
  assert(result.stats.retransmittedPackets > 0);
  
  print('✓ 高丢包率测试通过');
}
```

### 8.3 性能基准测试

```dart
class PerformanceBenchmark {
  Future<void> runBenchmarks() async {
    print('═══════════════════════════════════════');
    print('         性能基准测试');
    print('═══════════════════════════════════════');
    
    // 测试1: 理想环境
    final ideal = await runTest(
      name: '理想环境',
      distance: 1.0,
      lossRate: 0.01,
    );
    
    // 测试2: 正常环境
    final normal = await runTest(
      name: '正常环境',
      distance: 2.0,
      lossRate: 0.05,
    );
    
    // 测试3: 弱信号
    final weak = await runTest(
      name: '弱信号',
      distance: 5.0,
      lossRate: 0.15,
    );
    
    // 输出对比
    print('\n性能对比:');
    print('环境\t\t传输时间\t丢包率\t\t重传次数');
    print('─────────────────────────────────────');
    print('理想\t\t${ideal.time}s\t\t${ideal.loss}%\t\t${ideal.retrans}');
    print('正常\t\t${normal.time}s\t\t${normal.loss}%\t\t${normal.retrans}');
    print('弱信号\t\t${weak.time}s\t\t${weak.loss}%\t\t${weak.retrans}');
  }
}
```

---

## 9. 部署与监控

### 9.1 版本兼容性

```dart
class ProtocolVersion {
  static const int current = 2;  // 当前协议版本
  
  // 检查硬件端协议版本
  static Future<int> queryHardwareVersion() async {
    await btProvider.sendCommand('GET:PROTOCOL_VERSION');
    final response = await waitForResponse();
    
    if (response.startsWith('PROTOCOL_VERSION:')) {
      return int.parse(response.substring(17));
    }
    return 1;  // 默认版本1 (旧版)
  }
  
  // 根据版本选择传输策略
  static TransmissionStrategy selectStrategy(int hwVersion) {
    if (hwVersion >= 2) {
      return OptimizedStrategy();  // 使用优化协议
    } else {
      return LegacyStrategy();     // 使用旧协议
    }
  }
}
```

### 9.2 性能监控

```dart
class TransmissionMonitor {
  final List<TransmissionStats> _history = [];
  
  void recordTransmission(TransmissionStats stats) {
    _history.add(stats);
    
    // 保留最近100次记录
    if (_history.length > 100) {
      _history.removeAt(0);
    }
    
    // 分析趋势
    analyzeTrends();
  }
  
  void analyzeTrends() {
    if (_history.length < 10) return;
    
    final recent = _history.sublist(_history.length - 10);
    final avgTime = recent.map((s) => s.totalTime.inSeconds).reduce((a, b) => a + b) / 10;
    final avgLoss = recent.map((s) => s.lossRate).reduce((a, b) => a + b) / 10;
    
    print('最近10次传输统计:');
    print('- 平均时间: ${avgTime.toStringAsFixed(1)}秒');
    print('- 平均丢包率: ${(avgLoss * 100).toStringAsFixed(2)}%');
    
    // 异常检测
    if (avgTime > 80) {
      print('⚠️ 警告: 传输时间异常偏高');
    }
    if (avgLoss > 0.20) {
      print('⚠️ 警告: 丢包率异常偏高');
    }
  }
  
  Map<String, dynamic> getReport() {
    return {
      'totalTransmissions': _history.length,
      'successRate': _history.where((s) => s.lossRate < 0.10).length / _history.length,
      'averageTime': _history.map((s) => s.totalTime.inSeconds).reduce((a, b) => a + b) / _history.length,
      'averageLossRate': _history.map((s) => s.lossRate).reduce((a, b) => a + b) / _history.length,
    };
  }
}
```

---

## 10. 总结

### 10.1 优化效果预期

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 成功率 | <80% | >95% | +15% |
| 传输时间 (正常) | 60-120秒 | 40-50秒 | -33% |
| 传输时间 (弱信号) | 常失败 | 50-70秒 | 可用 |
| 丢包容忍度 | <5% | <20% | +15% |
| 断点续传 | 不支持 | 支持 | ✓ |

### 10.2 关键改进点

1. **滑动窗口**: 提升吞吐量30-50%
2. **选择性重传**: 减少无效重传80%
3. **自适应速率**: 适应不同信号质量
4. **快速重传**: 减少超时等待时间
5. **断点续传**: 提升用户体验

### 10.3 实施优先级

**P0 (必须)**:
- 滑动窗口机制
- 累积ACK确认
- 基础重传优化

**P1 (重要)**:
- 选择性ACK (SACK)
- 自适应速率调整
- 断点续传

**P2 (可选)**:
- 性能监控
- 高级错误恢复
- 压缩传输

---

**文档版本**: v1.0  
**最后更新**: 2026-01-17  
**审核状态**: 待审核
