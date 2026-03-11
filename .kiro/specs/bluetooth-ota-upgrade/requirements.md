# 需求文档：蓝牙 OTA 固件升级

## 简介

本文档定义 RideWind 项目蓝牙 OTA（Over-The-Air）固件升级功能的需求。系统通过 JDY-08 BLE 透传模块，将 Flutter App 中的固件文件传输至 STM32F405，利用 W25Q128 外部 SPI Flash 暂存固件，由 Bootloader 完成固件搬运和升级。支持本地 OTA（选择本地 .bin 文件）和远程 OTA（从服务器下载后蓝牙传输）两种模式。系统保证升级过程中不会变砖，具备断电恢复和回滚能力。

## 术语表

- **Bootloader**：存储在 STM32 内部 Flash Sector 0-3（0x08000000-0x0800FFFF，64KB）的启动引导程序，负责检查升级标志、执行固件搬运、跳转到 APP
- **APP 固件**：存储在 STM32 内部 Flash Sector 4-11（0x08010000-0x080FFFFF，960KB）的应用程序固件
- **W25Q128**：16MB 外部 SPI Flash，通过 SPI2 连接，用于 OTA 固件暂存和元数据存储
- **OTA 暂存区**：W25Q128 中 0x200000-0x2FFFFF（1MB）区域，用于临时存储接收到的固件数据
- **OTA 元数据区**：W25Q128 中 0x300000-0x300FFF（4KB）区域，存储升级标志、固件大小、CRC32 等信息
- **OTA 元数据**：包含魔数（0x4F544155）、版本号、升级标志、固件大小、固件 CRC32 的 16 字节结构体
- **升级标志**：OTA 元数据中的 upgradeFlag 字段，值为 0x01 表示有待执行的升级
- **JDY-08**：BLE 4.0 透传模块，通过 USART2（115200 波特率）与 STM32 通信
- **OtaUploadService**：Flutter App 中负责固件分包发送和升级流程管理的服务类
- **OTA 协议**：App 与 STM32 之间的 OTA 通信命令集，包括 OTA_START、OTA_DATA、OTA_END、OTA_ACK 等命令
- **CRC32**：32 位循环冗余校验算法，用于固件完整性验证
- **滑动窗口**：每发送 16 个数据包后等待 ACK 确认的流控机制
- **栈指针检查**：通过验证 APP 区起始地址处的栈指针值是否在 RAM 范围内（0x20000000-0x20030000）来判断 APP 固件是否有效

## 需求

### 需求 1：固件文件获取

**用户故事**：作为用户，我希望能从本地文件或远程服务器获取固件文件，以便进行 OTA 升级。

#### 验收标准

1. WHEN 用户在 OTA 升级页面选择"本地升级"模式 THEN OtaUploadService SHALL 调用文件选择器，仅允许选择 .bin 扩展名的文件
2. WHEN 用户在 OTA 升级页面选择"远程升级"模式 THEN OtaUploadService SHALL 从配置的服务器地址下载固件文件，并在下载完成后将固件数据传递给上传流程
3. WHEN 用户选择的固件文件大小超过 960KB（983040 字节） THEN OtaUploadService SHALL 拒绝该文件并向用户显示"固件文件过大，最大支持 960KB"的错误提示
4. WHEN 用户选择的固件文件大小为 0 字节 THEN OtaUploadService SHALL 拒绝该文件并向用户显示"固件文件无效"的错误提示
5. WHEN 固件文件读取成功 THEN OtaUploadService SHALL 计算固件数据的 CRC32 校验值，并记录固件大小和 CRC32 值到日志

### 需求 2：OTA 传输协议 - 启动阶段

**用户故事**：作为开发者，我希望 OTA 传输有明确的启动握手流程，以便 STM32 能正确准备接收固件数据。

#### 验收标准

1. WHEN OtaUploadService 开始上传 THEN OtaUploadService SHALL 发送格式为 "OTA_START:size:crc32\n" 的命令，其中 size 为固件字节数，crc32 为固件 CRC32 值
2. WHEN STM32 OTA 接收模块收到 OTA_START 命令且固件大小 > 0 且 ≤ 960KB THEN OTA 接收模块 SHALL 擦除 W25Q128 OTA 暂存区（0x200000 起始，16 个 64KB Block），先发送 "OTA_ERASING\n"，擦除完成后发送 "OTA_READY\n"
3. WHEN STM32 OTA 接收模块收到 OTA_START 命令且固件大小为 0 或超过 960KB THEN OTA 接收模块 SHALL 发送 "OTA_FAIL:SIZE_INVALID:983040\n" 并拒绝升级
4. WHEN OtaUploadService 发送 OTA_START 后在 5000ms 内未收到 OTA_READY 响应 THEN OtaUploadService SHALL 判定启动失败并通过 onError 回调通知用户

### 需求 3：OTA 传输协议 - 数据传输阶段

**用户故事**：作为开发者，我希望固件数据能可靠地分包传输到 STM32，以便确保数据完整性。

#### 验收标准

1. WHILE OtaUploadService 处于 uploading 状态 THEN OtaUploadService SHALL 将固件数据按每包 16 字节分割，以 "OTA_DATA:seq:hexdata\n" 格式发送，其中 seq 为从 0 开始的递增序号，hexdata 为十六进制编码的数据
2. WHILE OtaUploadService 处于 uploading 状态 THEN OtaUploadService SHALL 在每发送 16 个数据包后等待 STM32 返回 OTA_ACK，等待超时时间为 5000ms
3. WHEN STM32 OTA 接收模块收到 OTA_DATA 包且序号与期望序号一致 THEN OTA 接收模块 SHALL 将解码后的数据写入批量缓冲区，每累积 16 包或收到最后一包时批量写入 W25Q128 暂存区，并发送 "OTA_ACK:seq\n"
4. WHEN STM32 OTA 接收模块收到 OTA_DATA 包且序号大于期望序号 THEN OTA 接收模块 SHALL 发送 "OTA_RESEND:expected_seq\n" 请求从期望序号重传
5. WHEN STM32 OTA 接收模块收到 OTA_DATA 包且序号小于期望序号 THEN OTA 接收模块 SHALL 忽略该重复包，不发送任何响应
6. WHEN STM32 OTA 接收模块收到 OTA_DATA 包但十六进制解码失败 THEN OTA 接收模块 SHALL 发送 "OTA_NAK:seq\n" 请求重传该包
7. WHEN OtaUploadService 在 5000ms 内未收到 OTA_ACK 响应 THEN OtaUploadService SHALL 重传当前窗口的数据包，最多重试 3 次
8. IF OtaUploadService 重试 3 次后仍未收到 OTA_ACK THEN OtaUploadService SHALL 中止传输并通过 onError 回调通知用户传输失败
9. WHILE OtaUploadService 处于 uploading 状态 THEN OtaUploadService SHALL 在每个数据包之间保持 8ms 的发送间隔
10. WHILE OtaUploadService 处于 uploading 状态 THEN OtaUploadService SHALL 通过 onProgress 回调报告当前传输进度百分比

### 需求 4：OTA 传输协议 - 校验与完成阶段

**用户故事**：作为开发者，我希望传输完成后有严格的校验机制，以便确保暂存区固件数据的完整性。

#### 验收标准

1. WHEN OtaUploadService 发送完所有数据包 THEN OtaUploadService SHALL 发送 "OTA_END\n" 命令
2. WHEN STM32 OTA 接收模块收到 OTA_END 命令且接收数据大小等于 OTA_START 中声明的大小 THEN OTA 接收模块 SHALL 从 W25Q128 暂存区读取全部固件数据并计算 CRC32
3. WHEN OTA 接收模块计算的 CRC32 与 OTA_START 中声明的 CRC32 一致 THEN OTA 接收模块 SHALL 将 OTA 元数据（魔数 0x4F544155、版本 0x01、升级标志 0x01、固件大小、固件 CRC32）写入 W25Q128 元数据区（0x300000），发送 "OTA_OK\n"，延迟 500ms 后执行 NVIC_SystemReset() 重启
4. WHEN OTA 接收模块计算的 CRC32 与 OTA_START 中声明的 CRC32 不一致 THEN OTA 接收模块 SHALL 发送 "OTA_FAIL:CRC:calculated_crc\n"，状态切换为 ERROR，不写入升级标志
5. WHEN STM32 OTA 接收模块收到 OTA_END 命令且接收数据大小不等于声明大小 THEN OTA 接收模块 SHALL 发送 "OTA_FAIL:SIZE:received/expected\n"，状态切换为 ERROR

### 需求 5：Bootloader 启动与升级判断

**用户故事**：作为开发者，我希望 Bootloader 能在上电时自动判断是否需要执行升级，以便实现无人值守的固件搬运。

#### 验收标准

1. WHEN STM32 上电或复位 THEN Bootloader SHALL 从 0x08000000 启动，初始化 GPIO、SPI2（W25Q128）和 USART2（蓝牙）
2. WHEN Bootloader 启动完成 THEN Bootloader SHALL 读取 W25Q128 OTA 元数据区（0x300000），检查魔数是否为 0x4F544155 且升级标志是否为 0x01
3. WHEN OTA 元数据中升级标志为 0x01 THEN Bootloader SHALL 执行固件搬运流程（需求 6）
4. WHEN OTA 元数据中升级标志不为 0x01 或魔数无效 THEN Bootloader SHALL 检查 APP 区（0x08010000）的栈指针值是否在 0x20000000-0x20030000 范围内
5. WHEN APP 区栈指针有效 THEN Bootloader SHALL 设置 SCB->VTOR 为 0x08010000，设置主栈指针为 APP 的初始栈指针值，跳转到 APP 的 Reset_Handler 执行
6. WHEN APP 区栈指针无效且无升级标志 THEN Bootloader SHALL 进入等待模式，通过 USART2 监听蓝牙 OTA 命令，等待接收新固件

### 需求 6：Bootloader 固件搬运

**用户故事**：作为开发者，我希望 Bootloader 能安全地将暂存区固件搬运到 APP 区，以便完成固件升级。

#### 验收标准

1. WHEN Bootloader 开始固件搬运 THEN Bootloader SHALL 从 W25Q128 暂存区（0x200000）读取固件数据并计算 CRC32，与 OTA 元数据中记录的 CRC32 进行比对
2. WHEN 暂存区固件 CRC32 校验通过 THEN Bootloader SHALL 解锁内部 Flash，擦除 APP 区 Sector 4-11，以 256 字节为单位从 W25Q128 读取固件并按 4 字节（字）写入内部 Flash APP 区（0x08010000 起始）
3. WHEN 固件写入内部 Flash 完成 THEN Bootloader SHALL 从内部 Flash APP 区读取已写入的固件数据并计算 CRC32，与 OTA 元数据中记录的 CRC32 进行比对
4. WHEN 写入校验 CRC32 通过 THEN Bootloader SHALL 清除 W25Q128 中的升级标志，锁定内部 Flash，继续执行 APP 有效性检查和跳转流程
5. WHEN 暂存区固件 CRC32 校验失败 THEN Bootloader SHALL 清除升级标志，不擦除 APP 区，继续执行 APP 有效性检查
6. WHEN 内部 Flash 擦除或写入操作失败 THEN Bootloader SHALL 锁定内部 Flash 并返回失败，继续执行 APP 有效性检查
7. WHILE Bootloader 执行固件搬运 THEN Bootloader SHALL 保持源地址偏移与目标地址偏移同步（srcAddr - 0x200000 == dstAddr - 0x08010000）

### 需求 7：OTA 元数据管理

**用户故事**：作为开发者，我希望 OTA 元数据能可靠地存储和读取，以便 Bootloader 和 APP 之间正确传递升级信息。

#### 验收标准

1. THE OTA 元数据 SHALL 采用 16 字节固定结构：4 字节魔数（0x4F544155）+ 1 字节版本（0x01）+ 1 字节升级标志 + 2 字节保留 + 4 字节固件大小 + 4 字节固件 CRC32
2. WHEN 写入 OTA 元数据 THEN OTA 接收模块 SHALL 先擦除 W25Q128 元数据区扇区（0x300000），再写入完整的 OtaMeta_t 结构体
3. WHEN 读取 OTA 元数据 THEN Bootloader SHALL 验证魔数等于 0x4F544155 且版本等于 0x01，验证失败时视为无升级标志
4. WHEN 清除升级标志 THEN Bootloader SHALL 擦除 W25Q128 元数据区扇区（0x300000），使后续读取时魔数校验失败

### 需求 8：CRC32 校验策略

**用户故事**：作为开发者，我希望固件在传输和搬运的每个阶段都经过 CRC32 校验，以便确保固件数据从 App 到最终运行始终完整。

#### 验收标准

1. WHEN OtaUploadService 读取固件文件 THEN OtaUploadService SHALL 使用标准 CRC32 算法（多项式 0xEDB88320，初始值 0xFFFFFFFF，最终异或 0xFFFFFFFF）计算固件 CRC32
2. WHEN STM32 OTA 接收模块收到 OTA_END THEN OTA 接收模块 SHALL 从 W25Q128 暂存区以 256 字节为单位读取全部固件数据，使用相同 CRC32 算法计算校验值
3. WHEN Bootloader 执行固件搬运前 THEN Bootloader SHALL 从 W25Q128 暂存区计算固件 CRC32，与元数据中记录的值比对
4. WHEN Bootloader 将固件写入内部 Flash 后 THEN Bootloader SHALL 从内部 Flash APP 区计算固件 CRC32，与元数据中记录的值比对
5. THE CRC32 算法 SHALL 在 Flutter App 端和 STM32 端产生相同的计算结果（对于相同的输入数据）

### 需求 9：错误处理与恢复

**用户故事**：作为用户，我希望 OTA 升级过程中的任何错误都能被妥善处理，以便设备不会因升级失败而变砖。

#### 验收标准

1. WHEN 蓝牙在 OTA 传输过程中断开 THEN OtaUploadService SHALL 检测到断开事件，中止传输，通过 onError 回调通知用户，并将状态设置为 error
2. WHEN 蓝牙在 OTA 传输过程中断开 THEN STM32 OTA 接收模块 SHALL 在超时后将状态恢复为 IDLE，W25Q128 暂存区中已接收的数据保持不变
3. WHEN 用户发送 OTA_ABORT 命令 THEN STM32 OTA 接收模块 SHALL 将状态恢复为 IDLE 并发送 "OTA_ABORTED\n"
4. WHEN Bootloader 搬运过程中发生断电 THEN Bootloader SHALL 在下次上电时检测到升级标志仍然存在，重新执行完整的固件搬运流程
5. WHEN Bootloader 搬运过程中断电导致 APP 区数据不完整 THEN Bootloader SHALL 通过栈指针检查检测到 APP 无效，在搬运重试失败后进入等待模式
6. IF STM32 OTA 接收模块在非 RECEIVING 状态收到 OTA_DATA 命令 THEN OTA 接收模块 SHALL 发送 "OTA_FAIL:NOT_READY\n"
7. IF STM32 OTA 接收模块在非 RECEIVING 状态收到 OTA_END 命令 THEN OTA 接收模块 SHALL 发送 "OTA_FAIL:NOT_RECEIVING\n"

### 需求 10：不变砖保证

**用户故事**：作为用户，我希望无论升级过程中发生什么错误，设备都不会变成无法使用的状态。

#### 验收标准

1. THE Bootloader（Sector 0-3） SHALL 在任何 OTA 操作中保持不被修改，OTA 仅擦除和写入 Sector 4-11
2. WHEN APP 区固件无效（栈指针检查失败） THEN Bootloader SHALL 进入等待模式，通过蓝牙接收新固件并执行升级
3. THE 升级标志 SHALL 仅在 OTA 接收模块完成 CRC32 校验通过后写入，确保暂存区数据完整性已验证
4. WHEN Bootloader 检测到升级标志有效但暂存区 CRC32 校验失败 THEN Bootloader SHALL 清除升级标志，尝试启动现有 APP 固件

### 需求 11：STM32 APP 端集成

**用户故事**：作为开发者，我希望 OTA 功能能无缝集成到现有 APP 固件中，以便不影响现有功能的正常运行。

#### 验收标准

1. WHEN STM32 APP 固件收到以 "OTA_" 开头的蓝牙命令 THEN BLE 命令解析模块 SHALL 将该命令路由到 OTA_ParseCommand() 函数处理
2. WHILE STM32 OTA 接收模块处于 RECEIVING 状态 THEN APP 固件 SHALL 跳过 LCD 刷新、编码器处理、PWM 输出和 LED 渐变等非必要任务，专注于数据接收
3. WHILE STM32 OTA 接收模块处于 IDLE 状态 THEN APP 固件 SHALL 正常执行所有功能（LCD、编码器、PWM、LED 等）
4. THE APP 固件 SHALL 使用 0x08010000 作为 Flash 起始地址编译，中断向量表偏移设置为 0x10000

### 需求 12：Flutter OTA 升级界面

**用户故事**：作为用户，我希望有清晰的升级界面显示升级进度和状态，以便了解升级过程。

#### 验收标准

1. WHEN 用户进入 OTA 升级页面 THEN OTA 升级页面 SHALL 显示当前固件版本（通过发送 OTA_VERSION 命令查询）和升级操作按钮
2. WHILE OtaUploadService 处于 uploading 状态 THEN OTA 升级页面 SHALL 显示进度条和百分比数值，实时反映传输进度
3. WHEN OtaUploadService 状态变更 THEN OTA 升级页面 SHALL 显示对应的状态文本（准备中、擦除中、传输中、校验中、重启中、完成、错误）
4. WHEN OtaUploadService 报告错误 THEN OTA 升级页面 SHALL 显示错误详情并提供"重试"按钮
5. WHEN OtaUploadService 报告升级成功 THEN OTA 升级页面 SHALL 显示升级成功提示，并建议用户等待设备重启完成后重新连接蓝牙

### 需求 13：固件版本查询

**用户故事**：作为用户，我希望能查询设备当前的固件版本，以便判断是否需要升级。

#### 验收标准

1. WHEN OtaUploadService 发送 "OTA_VERSION\n" 命令 THEN STM32 OTA 接收模块 SHALL 返回 "OTA_VERSION:major.minor.patch\n" 格式的版本号
2. WHEN OTA 升级页面收到版本号响应 THEN OTA 升级页面 SHALL 解析并显示当前固件版本号
