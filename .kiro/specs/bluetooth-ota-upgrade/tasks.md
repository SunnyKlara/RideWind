 # 实施计划：蓝牙 OTA 固件升级

## 概述

本计划将蓝牙 OTA 固件升级功能分解为增量式编码任务。从 STM32 端基础设施（OTA 元数据、CRC32）开始，逐步构建 APP 端 OTA 接收模块、Bootloader 工程、Flutter 端 OtaUploadService 和 OTA 升级页面，最后集成联调。每个任务基于前一步的成果，确保无孤立代码。

## 任务

- [x] 1. STM32 APP 端 OTA 基础设施
  - [x] 1.1 创建 OTA 头文件和数据结构定义
    - 在 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/` 创建 `ota.h`
    - 定义 `OtaState_t` 枚举、`OtaMeta_t` 结构体、OTA 地址宏（`OTA_STAGING_ADDR`、`OTA_META_ADDR`、`OTA_META_MAGIC`、`APP_MAX_SIZE` 等）
    - 声明 `OTA_Init()`、`OTA_ParseCommand()`、`OTA_GetState()`、`OTA_GetProgress()` 函数原型
    - _需求: 7.1, 2.2, 2.3_

  - [x] 1.2 实现 CRC32 计算函数（从 W25Q128 读取）
    - 在 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/ota.c` 中实现 `CRC32_CalculateFlash(addr, len)`
    - 复用现有 `logo.c` 中的 CRC32 算法（多项式 0xEDB88320），扩展为支持从 W25Q128 分块读取计算
    - 同时实现 `CRC32_Calculate(uint8_t* data, uint32_t len)` 用于内部 Flash 校验
    - _需求: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 1.3 实现 OTA 元数据读写函数
    - 实现 `OTA_WriteMetadata(OtaMeta_t* meta)`: 擦除 W25Q128 元数据区扇区（0x300000），写入 OtaMeta_t
    - 实现 `OTA_ReadMetadata(OtaMeta_t* meta)`: 从 0x300000 读取并校验魔数和版本号
    - 实现 `OTA_ClearUpgradeFlag()`: 擦除元数据区扇区
    - _需求: 7.1, 7.2, 7.3, 7.4_


- [x] 2. STM32 APP 端 OTA 接收模块
  - [x] 2.1 实现 OTA_ParseCommand() 核心逻辑
    - 在 `ota.c` 中实现 OTA_START 命令处理：校验固件大小、擦除 W25Q128 暂存区（16 个 64KB Block）、发送 OTA_ERASING 和 OTA_READY
    - 实现 OTA_DATA 命令处理：序号校验、HexDecode、批量缓冲区写入、每 16 包或最后一包时批量写入 W25Q128 并发送 OTA_ACK
    - 实现 OTA_END 命令处理：校验接收大小、计算 CRC32、写入 OTA 元数据、发送 OTA_OK、延迟 500ms 后 NVIC_SystemReset()
    - 实现 OTA_ABORT、OTA_VERSION 命令处理
    - 实现序号异常处理：重复包忽略、跳号发送 OTA_RESEND、解码失败发送 OTA_NAK
    - _需求: 2.1, 2.2, 2.3, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3, 4.4, 4.5, 9.3, 9.6, 9.7, 13.1_

  - [x] 2.2 集成 OTA 命令路由到现有 BLE 命令解析
    - 修改 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/rx.c` 中的 `BLE_ParseCommand()`，添加 `OTA_` 前缀命令路由到 `OTA_ParseCommand()`
    - 修改 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/main.c` 的 while(1) 循环，OTA RECEIVING 状态时跳过 LCD/Encoder/PWM/LED 等非必要任务
    - 在 `main.c` 中调用 `OTA_Init()`
    - _需求: 11.1, 11.2, 11.3_

  - [x] 2.3 添加固件版本号定义
    - 在 `main.h` 或 `ota.h` 中定义 `FW_VERSION_MAJOR`、`FW_VERSION_MINOR`、`FW_VERSION_PATCH` 宏
    - 确保 OTA_VERSION 命令能正确返回版本号
    - _需求: 13.1_

- [x] 3. 检查点 - STM32 APP 端 OTA 模块编译验证
  - 确保 Keil MDK 工程编译通过，所有新增文件已加入工程。如有问题请向用户确认。


- [ ] 4. STM32 Bootloader 工程
  - [x] 4.1 创建 Bootloader Keil 工程和基础代码
    - 在 `f4_26_1.1/` 下创建 Bootloader 工程目录（或在现有工程中新建 Target）
    - 配置 Flash 起始地址为 0x08000000，大小 64KB（Sector 0-3）
    - 实现最小硬件初始化：HAL_Init、SystemClock_Config、GPIO（LED）、SPI2（W25Q128）、USART2（蓝牙）
    - 复用现有 `w25q128.c`/`w25q128.h` 驱动和 `usart.c`/`usart.h` 驱动
    - _需求: 5.1_

  - [x] 4.2 实现 Bootloader 核心函数
    - 实现 `Bootloader_IsAppValid(uint32_t appAddr)`: 检查 APP 区栈指针是否在 0x20000000-0x20030000 范围内
    - 实现 `Bootloader_JumpToApp(uint32_t appAddr)`: 关闭中断、设置 VTOR、设置 MSP、跳转到 Reset_Handler
    - 实现 `Bootloader_CheckUpgradeFlag()`: 读取 W25Q128 OTA 元数据，校验魔数和升级标志
    - 实现 `Bootloader_ClearUpgradeFlag()`: 擦除 W25Q128 元数据区扇区
    - _需求: 5.2, 5.4, 5.5, 7.3, 7.4_

  - [x] 4.3 实现 Bootloader 固件搬运流程
    - 实现 `Bootloader_PerformUpgrade()`: 读取元数据 → CRC32 校验暂存区 → 擦除 APP 区 Sector 4-11 → 256 字节分块从 W25Q128 读取并按 4 字节写入内部 Flash → 写入后 CRC32 校验 → 清除升级标志
    - 复用 `ota.c` 中的 CRC32 计算函数（或在 Bootloader 中独立实现）
    - 确保源地址偏移与目标地址偏移同步（循环不变量）
    - _需求: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 8.3, 8.4_

  - [x] 4.4 实现 Bootloader 主流程和等待模式
    - 实现 `main()`: 初始化 → 检查升级标志 → 执行搬运 → 检查 APP 有效性 → 跳转或进入等待模式
    - 实现等待模式：通过 USART2 监听蓝牙 OTA 命令，复用 OTA_ParseCommand 逻辑接收固件到 W25Q128
    - LED 指示：升级中快闪、等待模式慢闪
    - _需求: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 9.4, 9.5, 10.2_

  - [x] 4.5 修改 APP 固件编译配置
    - 修改 Keil scatter file（f4.sct）或 Target 设置，APP 固件起始地址改为 0x08010000，大小 960KB
    - 修改 `system_stm32f4xx.c` 中 `VECT_TAB_OFFSET` 为 0x10000
    - 确保 APP 固件编译后 bin 文件从 0x08010000 起始
    - _需求: 11.4_

- [x] 5. 检查点 - Bootloader 编译验证
  - 确保 Bootloader 工程和修改后的 APP 工程均编译通过。如有问题请向用户确认。


- [ ] 6. Flutter 端 CRC32 和 OTA 上传服务
  - [x] 6.1 实现 Flutter 端 CRC32 计算工具
    - 在 `RideWind/lib/utils/` 创建 `crc32.dart`
    - 实现标准 CRC32 算法（多项式 0xEDB88320，初始值 0xFFFFFFFF，最终异或 0xFFFFFFFF）
    - 确保与 STM32 端 CRC32 算法产生相同结果
    - _需求: 8.1, 8.5_

  - [ ]* 6.2 编写 CRC32 跨平台一致性属性测试
    - **Property 1: CRC32 Cross-Platform Equivalence**
    - 使用 `glados` 库，对任意长度 1-983040 的字节数组，验证 Flutter CRC32 计算结果与参考实现一致
    - **验证: 需求 8.5, 8.1, 8.2**

  - [x] 6.3 实现 OtaUploadService 核心类
    - 在 `RideWind/lib/services/` 创建 `ota_upload_service.dart`
    - 定义 `OtaState` 枚举（idle, preparing, erasing, uploading, verifying, rebooting, complete, error）
    - 实现 `upload(Uint8List firmwareData)` 方法：计算 CRC32 → 发送 OTA_START 等待 OTA_READY → 分包发送 → 发送 OTA_END 等待结果
    - 实现 `cancel()` 方法：发送 OTA_ABORT
    - 参考现有 `simple_logo_uploader.dart` 的蓝牙通信和 ACK 流控模式
    - _需求: 1.5, 2.1, 2.4, 3.1, 3.2, 3.7, 3.8, 3.9, 3.10, 4.1, 9.1_

  - [x] 6.4 实现 OtaUploadService 滑动窗口和重传机制
    - 实现 `_sendDataWithSlidingWindow()`: 每包 16 字节、每 16 包等待 ACK、包间延迟 8ms
    - 实现 ACK 超时重传：5000ms 超时、最大重试 3 次
    - 处理 OTA_RESEND 响应：从指定序号重传
    - 处理 OTA_NAK 响应：重传指定包
    - _需求: 3.1, 3.2, 3.7, 3.8, 3.9_

  - [x] 6.5 实现固件文件获取（本地和远程）
    - 实现本地文件选择：使用 `file_picker` 包，限制 .bin 扩展名
    - 实现远程固件下载（预留接口）
    - 实现固件大小校验：拒绝 0 字节和超过 960KB 的文件
    - 在 `pubspec.yaml` 中添加 `file_picker` 依赖
    - _需求: 1.1, 1.2, 1.3, 1.4_

  - [ ]* 6.6 编写固件大小校验属性测试
    - **Property 2: Firmware Size Validation**
    - 验证对任意 size 值，size > 0 且 ≤ 983040 时接受，否则拒绝
    - **验证: 需求 1.3, 2.2, 2.3**

  - [ ]* 6.7 编写分包与重组属性测试
    - **Property 3: Packet Splitting Round-Trip**
    - 对任意长度 1-983040 的字节数组，按 16 字节分包、hex 编码、hex 解码、重组后与原始数据一致
    - **验证: 需求 3.1, 3.3**

- [x] 7. 检查点 - Flutter OTA 服务编译验证
  - 确保 Flutter 项目编译通过（`flutter analyze`），所有新增文件无语法错误。如有问题请向用户确认。


- [ ] 8. Flutter OTA 升级页面和版本查询
  - [x] 8.1 实现 OTA 升级页面 UI
    - 在 `RideWind/lib/screens/` 创建 `ota_upgrade_screen.dart`
    - 显示当前固件版本号（通过 OTA_VERSION 命令查询）
    - 提供"本地升级"和"远程升级"模式选择按钮
    - 显示进度条和百分比（uploading 状态时）
    - 显示状态文本（准备中、擦除中、传输中、校验中、重启中、完成、错误）
    - 错误时显示错误详情和"重试"按钮
    - 成功时显示升级成功提示，建议等待设备重启后重新连接蓝牙
    - _需求: 12.1, 12.2, 12.3, 12.4, 12.5_

  - [x] 8.2 实现固件版本查询功能
    - 在 OtaUploadService 或 OTA 页面中实现发送 "OTA_VERSION\n" 命令
    - 解析 "OTA_VERSION:major.minor.patch\n" 响应，提取版本号并显示
    - _需求: 13.1, 13.2_

  - [ ]* 8.3 编写版本号解析属性测试
    - **Property 17: Version Response Round-Trip**
    - 对任意非负整数 (major, minor, patch)，格式化为 "OTA_VERSION:major.minor.patch\n" 后解析，恢复原始值
    - **验证: 需求 13.1, 13.2**

  - [x] 8.4 集成 OTA 页面到 APP 导航
    - 在现有导航结构中添加 OTA 升级页面入口（如设置页面或设备详情页面）
    - 确保蓝牙已连接时才允许进入 OTA 页面
    - _需求: 12.1_

- [x] 9. 检查点 - Flutter OTA 页面编译验证
  - 确保 Flutter 项目编译通过，OTA 页面可正常渲染。如有问题请向用户确认。


- [ ] 10. 协议健壮性与错误处理
  - [x] 10.1 实现 STM32 OTA 状态机防护
    - 确保非 RECEIVING 状态收到 OTA_DATA 时返回 "OTA_FAIL:NOT_READY\n"
    - 确保非 RECEIVING 状态收到 OTA_END 时返回 "OTA_FAIL:NOT_RECEIVING\n"
    - 确保 OTA_ABORT 在任意非 IDLE 状态下都能正确重置为 IDLE
    - 实现蓝牙断开超时恢复：OTA 接收超时后自动恢复 IDLE 状态
    - _需求: 9.2, 9.3, 9.6, 9.7_

  - [x] 10.2 实现 Flutter 端蓝牙断开检测和错误处理
    - 监听蓝牙断开事件，OTA 传输中断开时中止传输、通知用户
    - 实现 onError 回调的完整错误信息传递
    - _需求: 9.1_

  - [ ]* 10.3 编写 OTA 状态机命令拒绝属性测试
    - **Property 12: OTA State Machine Command Rejection**
    - 对任意非 RECEIVING 状态，OTA_DATA 和 OTA_END 命令应返回失败消息且不修改 W25Q128 暂存区
    - **验证: 需求 9.6, 9.7**

  - [ ]* 10.4 编写序号处理属性测试
    - **Property 4: Sequence Number Handling**
    - 对任意期望序号 E 和到达序号 S：S==E 接受，S<E 忽略，S>E 发送 RESEND
    - **验证: 需求 3.3, 3.4, 3.5**

  - [ ]* 10.5 编写 OTA 中止重置属性测试
    - **Property 15: OTA Abort Resets State**
    - 对任意非 IDLE 的 OTA 状态，OTA_ABORT 命令应将状态转为 IDLE 并响应 "OTA_ABORTED\n"
    - **验证: 需求 9.3**

  - [ ]* 10.6 编写大小不匹配检测属性测试
    - **Property 18: Size Mismatch Detection at OTA_END**
    - 对任意接收字节数不等于声明大小的 OTA 会话，OTA_END 应返回 OTA_FAIL:SIZE 且不写入升级标志
    - **验证: 需求 4.5, 10.3**


- [ ] 11. 不变砖保证与安全性验证
  - [x] 11.1 实现 Bootloader 分区保护
    - 确保 Bootloader 代码中所有 Flash 擦除/写入操作仅针对 Sector 4-11
    - 在 Bootloader_PerformUpgrade() 中添加地址范围检查，防止误写 Sector 0-3
    - 可选：通过 STM32 Option Bytes 对 Sector 0-3 设置写保护
    - _需求: 10.1_

  - [x] 11.2 实现断电恢复机制验证
    - 确保升级标志在 CRC32 校验通过后才写入（OTA_END 处理中）
    - 确保 Bootloader 检测到升级标志但 CRC 校验失败时清除标志并尝试启动旧 APP
    - 确保 Bootloader 搬运中断电后，下次启动重新检测升级标志并重试搬运
    - _需求: 9.4, 9.5, 10.3, 10.4_

  - [ ]* 11.3 编写升级标志原子性属性测试
    - **Property 5: Upgrade Flag Atomicity**
    - 升级标志仅在 CRC32 校验通过后写入；CRC32 不匹配时不写入升级标志
    - **验证: 需求 4.3, 4.4, 10.3**

  - [ ]* 11.4 编写元数据序列化往返属性测试
    - **Property 6: OTA Metadata Serialization Round-Trip**
    - 对任意有效 OtaMeta_t 结构体，序列化为 16 字节后反序列化应得到相同结构体
    - **验证: 需求 7.1, 7.3**

  - [ ]* 11.5 编写无效元数据拒绝属性测试
    - **Property 7: Metadata Validation Rejects Invalid Data**
    - 对任意 16 字节缓冲区，若前 4 字节不等于 0x4F544155 或第 5 字节不等于 0x01，则元数据校验应报告无有效升级标志
    - **验证: 需求 7.3, 5.2**

  - [ ]* 11.6 编写分区隔离属性测试
    - **Property 8: Partition Isolation Invariant**
    - 对任意 OTA 操作序列，Bootloader 区域（Sector 0-3）保持不被修改
    - **验证: 需求 10.1**

  - [ ]* 11.7 编写无效 APP 恢复属性测试
    - **Property 9: Invalid APP Recovery**
    - 对任意 APP 区栈指针无效的状态，Bootloader 不跳转到 APP 并进入等待模式
    - **验证: 需求 10.2, 5.6**

  - [ ]* 11.8 编写 CRC 门控搬运安全属性测试
    - **Property 11: CRC-Gated Copy Safety**
    - 升级标志有效但暂存区 CRC 不匹配时，Bootloader 清除升级标志且不擦除 APP 区
    - **验证: 需求 6.5, 10.4**

  - [ ]* 11.9 编写断电恢复属性测试
    - **Property 16: Power-Loss Recovery via Persistent Flag**
    - 升级标志写入后系统复位，Bootloader 下次启动应检测到升级标志并重新执行搬运
    - **验证: 需求 9.4, 5.3**

- [x] 12. 检查点 - 安全性与健壮性验证
  - 确保所有测试通过，Bootloader 分区保护逻辑正确。如有问题请向用户确认。


- [ ] 13. 端到端集成与剩余属性测试
  - [x] 13.1 集成 OTA 命令路由测试
    - 确保 `rx.c` 中 "OTA_" 前缀命令正确路由到 OTA_ParseCommand()
    - 确保非 "OTA_" 前缀命令不受影响，现有功能正常
    - _需求: 11.1, 11.3_

  - [ ]* 13.2 编写 OTA 命令路由属性测试
    - **Property 13: OTA Command Routing**
    - 对任意以 "OTA_" 开头的命令字符串，BLE 命令解析器应路由到 OTA_ParseCommand()；不以 "OTA_" 开头的命令不应路由
    - **验证: 需求 11.1**

  - [ ]* 13.3 编写进度报告准确性属性测试
    - **Property 14: Progress Reporting Accuracy**
    - 对任意总包数 N，发送第 i 包后报告进度为 (i+1)/N，单调递增从 1/N 到 1.0
    - **验证: 需求 3.10**

  - [ ]* 13.4 编写搬运地址同步属性测试
    - **Property 10: Copy Address Synchronization Invariant**
    - 搬运循环中任意时刻 (srcAddr - 0x200000) == (dstAddr - 0x08010000) 且 (remaining + dstAddr - 0x08010000) == firmwareSize
    - **验证: 需求 6.7, 6.2**

- [x] 14. 最终检查点 - 全部编译与测试验证
  - 确保 STM32 APP 工程、Bootloader 工程、Flutter 项目均编译通过，所有测试通过。如有问题请向用户确认。

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加快 MVP 进度
- 每个任务引用了具体的需求编号，确保可追溯性
- 检查点任务用于增量验证，确保每个阶段的代码正确
- 属性测试验证设计文档中的正式正确性属性（Property 1-18）
- STM32 端属性测试建议在 Flutter 端用 `glados` 模拟验证协议逻辑，硬件相关属性通过代码审查确认
- Bootloader 等待模式中的 OTA 接收逻辑可复用 APP 端 OTA_ParseCommand 的核心代码
