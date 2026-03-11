# OTA 蓝牙远程升级 — 完整行动手册

> 适用于：STM32F405RG + W25Q128 + JDY-08蓝牙 + Flutter APP (RideWind)
> 当前状态：所有代码框架已写好，但从未实际跑通过
> 目标：分步验证，最终实现手机APP通过蓝牙远程升级STM32固件

---

## 系统架构总览

```
┌─────────────┐    蓝牙BLE     ┌──────────────────────────────────────┐
│  Flutter APP │ ◄──────────► │  STM32F405RG                          │
│  (RideWind)  │   JDY-08     │                                      │
│              │   USART2     │  内部Flash布局:                       │
│  OTA升级页面  │   115200     │  0x08000000 ┌──────────────┐         │
│  ota_upgrade │              │             │ Bootloader   │ 64KB    │
│  _screen.dart│              │             │ (Sector 0-3) │         │
│              │              │  0x08010000 ├──────────────┤         │
│  上传服务     │              │             │ APP 固件     │ 960KB   │
│  ota_upload  │              │             │ (Sector 4-11)│         │
│  _service.dart│             │  0x08100000 └──────────────┘         │
│              │              │                                      │
│              │              │  W25Q128 外部Flash布局:               │
│              │              │  0x200000  ┌──────────────┐          │
│              │              │            │ OTA暂存区    │ 1MB     │
│              │              │  0x300000  ├──────────────┤          │
│              │              │            │ OTA元数据    │ 4KB     │
│              │              │            │ (升级标志)   │          │
│              │              │            └──────────────┘          │
└─────────────┘              └──────────────────────────────────────┘
```

## OTA 升级完整流程

```
手机APP                    STM32 APP端                 Bootloader
  │                           │                           │
  │  OTA_START:size:crc ──►  │                           │
  │                           │ 擦除W25Q128暂存区         │
  │  ◄── OTA_ERASING         │                           │
  │  ◄── OTA_READY           │                           │
  │                           │                           │
  │  OTA_DATA:0:hex ────►    │                           │
  │  OTA_DATA:1:hex ────►    │ 每16包批量写入W25Q128      │
  │  ...                      │                           │
  │  OTA_DATA:15:hex ───►    │                           │
  │  ◄── OTA_ACK:15          │                           │
  │  ...重复直到所有包发完...   │                           │
  │                           │                           │
  │  OTA_END ───────────►    │                           │
  │                           │ 校验CRC32                 │
  │                           │ 写入升级标志到W25Q128      │
  │  ◄── OTA_OK              │                           │
  │                           │ NVIC_SystemReset()        │
  │                           │         ↓                 │
  │                           │    ┌────────────┐         │
  │                           │    │ MCU 重启   │         │
  │                           │    └────┬───────┘         │
  │                           │         ↓                 │
  │                           │         │  ◄──────────── 从0x08000000启动
  │                           │         │                 │
  │                           │         │  检测到升级标志  │
  │                           │         │  W25Q128→内部Flash搬运
  │                           │         │  CRC校验通过     │
  │                           │         │  清除升级标志    │
  │                           │         │  跳转到APP       │
  │                           │         ↓                 │
  │                           │  新固件运行               │
```

---

## 当前安全基线（重要！）

在开始任何操作之前，请确认你的硬件当前处于以下状态：

| 配置项 | 当前值 | 文件位置 |
|--------|--------|----------|
| VECT_TAB_OFFSET | `0x00000000` | `Core/Src/system_stm32f4xx.c` |
| Scatter file 起始地址 | `0x08000000` | `MDK-ARM/f4/f4.sct` |
| Keil IROM 起始地址 | `0x08000000` | `MDK-ARM/f4.uvprojx` |
| APP 编译大小 | `0x00100000` (1MB) | scatter file + uvprojx |

**这三个配置必须始终保持一致。单独改其中一个会导致黑屏！**

---

## 阶段一：验证蓝牙OTA数据传输（不需要Bootloader，零风险）

### 目的

确认 APP 能通过蓝牙正确接收固件数据并写入 W25Q128 外部 Flash。
这一步完全不涉及 Bootloader，不改变任何编译配置，不会重启设备，零风险。

### 前提条件

- [x] 硬件正常运行（屏幕亮，蓝牙可连接）
- [x] APP 从 0x08000000 启动（当前状态）
- [x] VECT_TAB_OFFSET = 0x00000000（当前状态）
- [x] W25Q128 已初始化且正常工作（Logo 上传功能可用说明 W25Q128 正常）

### 步骤 1.1：确认 STM32 代码中 OTA 模块已集成

打开 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/main.c`，确认：

```c
// 在 main() 函数中，while(1) 之前应有：
OTA_Init();

// 在 while(1) 循环中应有：
OTA_CheckTimeout();
```

打开 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/rx.c`，确认 BLE 命令路由中有：

```c
// 在 BLE_ParseCommand() 或类似函数中，应有类似逻辑：
if (strncmp(cmd, "OTA_", 4) == 0) {
    OTA_ParseCommand(cmd);
    return;
}
```

### 步骤 1.2：确认 Keil 工程包含 OTA 源文件

在 Keil 中打开 `f4.uvprojx` 工程，检查以下文件是否已加入工程：
- `Core/Src/ota.c`
- `Core/Inc/ota.h`

如果没有，在 Keil 左侧 Project 面板中右键 Source Group → Add Existing Files → 添加这两个文件。

### 步骤 1.3：编译并烧录 APP 固件

1. 在 Keil 中编译 f4_26_1.1 工程（F7 或 Build 按钮）
2. 确认编译无错误
3. 通过 ST-Link/J-Link 烧录到 STM32（F8 或 Download 按钮）
4. 上电确认屏幕正常显示、蓝牙可连接

### 步骤 1.4：在 Flutter APP 中测试 OTA 版本查询

1. 打开 RideWind APP
2. 连接蓝牙设备
3. 进入 OTA 升级页面（固件升级）
4. 页面应自动发送 `OTA_VERSION` 命令
5. 预期收到响应：`OTA_VERSION:1.0.0`（版本号在 `ota.h` 中定义）

**如果收到版本号** → OTA 命令路由正常，继续下一步
**如果显示"未知"** → 检查 rx.c 中的 OTA_ 命令路由是否正确

### 步骤 1.5：测试 OTA 数据传输（关键步骤）

这一步我们用一个小的测试 bin 文件来验证整个数据传输链路。

#### 准备测试固件文件

你需要一个 .bin 文件用于测试。可以直接使用当前 APP 编译输出的 .bin 文件：

1. 在 Keil 中，Project → Options for Target → Output 标签页
2. 勾选 "Create HEX File"（如果还没勾选的话）
3. 重新编译
4. 在 `MDK-ARM/f4/` 目录下找到编译输出的 `.bin` 文件
   - 如果只有 .hex 没有 .bin，可以在 User 标签页的 After Build 中添加：
     `fromelf --bin --output=.\f4\f4.bin .\f4\f4.axf`
5. 将 .bin 文件复制到手机上（通过 USB、微信、AirDrop 等方式）

#### 执行测试

1. 在 RideWind APP 中进入 OTA 升级页面
2. 点击「本地升级」
3. 选择刚才准备的 .bin 文件
4. 观察传输过程：

```
预期日志输出顺序：
[OTA] 固件大小: XXXXX bytes, CRC32: 0xXXXXXXXX
[OTA] 发送: OTA_START:XXXXX:XXXXXXXXXX
[OTA] 状态: erasing
[OTA] STM32 正在擦除 Flash...          ← 等待约 2-3 秒
[OTA] STM32 就绪，开始传输
[OTA] 状态: uploading
[OTA] 总包数: XXXX
[OTA] 收到响应: OTA_ACK:15             ← 每 16 包一个 ACK
[OTA] 收到响应: OTA_ACK:31
...
[OTA] 所有数据包发送完成
[OTA] 发送 OTA_END
[OTA] 状态: verifying
[OTA] 收到响应: OTA_OK                 ← CRC32 校验通过
[OTA] 状态: rebooting
```

**⚠️ 重要：在阶段一中，OTA_OK 之后设备会自动重启（NVIC_SystemReset）！**

因为当前没有 Bootloader，重启后 MCU 会直接从 0x08000000 启动当前 APP（不会执行固件搬运），所以设备会正常恢复运行。W25Q128 中的升级标志会一直保留，但因为没有 Bootloader 去读取它，所以不会有任何影响。

### 步骤 1.6：验证结果判断

| 现象 | 含义 | 下一步 |
|------|------|--------|
| 传输完成，显示 OTA_OK，设备重启后正常 | ✅ 数据传输链路完全正常 | 进入阶段二 |
| OTA_ERASING 后长时间无响应 | W25Q128 擦除超时 | 检查 SPI 连接和 W25Q128 初始化 |
| OTA_DATA 发送后无 ACK | 蓝牙数据丢失或 STM32 处理异常 | 检查蓝牙波特率、rx.c 缓冲区大小 |
| OTA_FAIL:CRC | CRC32 不匹配 | 检查 Flutter 和 STM32 的 CRC32 算法是否一致 |
| OTA_FAIL:SIZE | 接收大小不匹配 | 可能有数据包丢失，检查蓝牙稳定性 |
| 传输中蓝牙断开 | 蓝牙不稳定 | 缩短手机与设备距离，检查 JDY-08 天线 |

### 阶段一完成标志

- [x] OTA_VERSION 返回正确版本号
- [x] 完整固件数据传输成功（OTA_OK）
- [x] 设备重启后正常运行

---

## 阶段二：验证 Bootloader + APP 双固件启动链

### 目的

验证 Bootloader 能正确启动并跳转到 APP。这一步不涉及 OTA 传输，只验证双固件的启动链。

### ⚠️ 风险提示

这一步需要修改编译配置，操作不当会导致黑屏。请严格按照步骤操作。
**建议在操作前备份整个 f4_26_1.1 工程目录。**

### 步骤 2.1：修复 Bootloader Keil 工程（编译问题）

当前 Bootloader 工程 (`f4_26_1.1/Bootloader/Bootloader.uvprojx`) 存在以下问题：

**问题：缺少必要的源文件**

Bootloader 代码中 `#include "w25q128.h"` 引用了 W25Q128 驱动，但 Keil 工程中没有包含这些文件。

需要添加的文件：

1. **w25q128.c / w25q128.h** — W25Q128 Flash 驱动
2. **stm32f4xx_hal_*.c** — HAL 库文件（至少需要 GPIO、SPI、UART、Flash、RCC、Cortex）
3. **startup_stm32f405rgtx.s** — 启动文件
4. **system_stm32f4xx.c** — 系统初始化（Bootloader 自己的，VECT_TAB_OFFSET=0）
5. **stm32f4xx_it.c** — 中断处理（至少需要 USART2_IRQHandler）

#### 具体操作步骤

在 Keil 中打开 `Bootloader.uvprojx`：

**A. 添加 W25Q128 驱动**

从 APP 工程中复制 w25q128.c 和 w25q128.h 到 Bootloader 工程目录：
```
复制源: f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/w25q128.c
复制源: f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/w25q128.h
复制到: f4_26_1.1/Bootloader/Core/Src/w25q128.c
复制到: f4_26_1.1/Bootloader/Core/Inc/w25q128.h
```

在 Keil 中右键 Source Group 1 → Add Existing Files → 添加 `w25q128.c`

**B. 添加 HAL 库**

Bootloader 需要以下 HAL 模块（从 STM32CubeF4 包或 APP 工程的 Drivers 目录复制）：

```
需要的 HAL 源文件（放入 Bootloader 工程）：
- stm32f4xx_hal.c
- stm32f4xx_hal_cortex.c
- stm32f4xx_hal_gpio.c
- stm32f4xx_hal_rcc.c
- stm32f4xx_hal_rcc_ex.c
- stm32f4xx_hal_pwr.c
- stm32f4xx_hal_pwr_ex.c
- stm32f4xx_hal_spi.c
- stm32f4xx_hal_uart.c
- stm32f4xx_hal_flash.c
- stm32f4xx_hal_flash_ex.c
- stm32f4xx_hal_dma.c
```

**C. 添加启动文件和系统文件**

```
需要的文件：
- startup_stm32f405rgtx.s（从 APP 工程的 MDK-ARM 目录复制）
- system_stm32f4xx.c（从 APP 工程复制，但 VECT_TAB_OFFSET 保持 0x00000000）
- stm32f4xx_hal_conf.h（从 APP 工程复制）
- stm32f4xx_it.c（需要新建，包含 USART2_IRQHandler）
```

**D. 创建 Bootloader 的中断处理文件**

创建 `f4_26_1.1/Bootloader/Core/Src/stm32f4xx_it.c`：

```c
#include "stm32f4xx_hal.h"

extern UART_HandleTypeDef huart2;

void NMI_Handler(void) { }
void HardFault_Handler(void) { while(1) {} }
void MemManage_Handler(void) { while(1) {} }
void BusFault_Handler(void) { while(1) {} }
void UsageFault_Handler(void) { while(1) {} }
void SVC_Handler(void) { }
void DebugMon_Handler(void) { }
void PendSV_Handler(void) { }
void SysTick_Handler(void) { HAL_IncTick(); }
void USART2_IRQHandler(void) { HAL_UART_IRQHandler(&huart2); }
```

**E. 配置 Include 路径**

在 Keil 中 Options for Target → C/C++ 标签页 → Include Paths 添加：
```
.\Core\Inc
（以及 HAL 库的 Inc 目录路径）
```

**F. 配置预处理宏**

在 C/C++ 标签页 → Define 中添加：
```
STM32F405xx,USE_HAL_DRIVER
```

**G. 配置 Bootloader 的 Flash 地址**

Bootloader 本身从 0x08000000 启动，占用 64KB（Sector 0-3）：

Options for Target → Target 标签页：
- IROM1: Start = 0x08000000, Size = 0x10000 (64KB)
- IRAM1: Start = 0x20000000, Size = 0x20000

Options for Target → Linker 标签页：
- 如果使用 scatter file，确保起始地址为 0x08000000，大小 0x10000
- 如果不使用 scatter file（Use Memory Layout from Target Dialog 勾选），则上面的 IROM 设置即可

**H. 编译 Bootloader**

按 F7 编译，解决所有编译错误。常见问题：
- 找不到头文件 → 检查 Include Paths
- 未定义的函数 → 检查是否缺少 HAL 源文件
- 重复定义 → 检查是否有重复的源文件

### 步骤 2.2：修改 APP 工程编译配置（三件套同时改）

**⚠️ 以下三个修改必须同时进行，缺一不可！**

#### 修改 1：Scatter File (f4.sct)

打开 `f4_26_1.1/f4_26_1.1/f4_26_1.1/MDK-ARM/f4/f4.sct`

```
修改前：
LR_IROM1 0x08000000 0x00100000  {
  ER_IROM1 0x08000000 0x00100000  {

修改后：
LR_IROM1 0x08010000 0x000F0000  {
  ER_IROM1 0x08010000 0x000F0000  {
```

说明：起始地址从 0x08000000 改为 0x08010000（跳过 Bootloader 的 64KB），大小从 1MB 改为 960KB。

#### 修改 2：Keil IROM 设置 (f4.uvprojx)

在 Keil 中打开 f4 工程 → Options for Target → Target 标签页：

```
修改前：
IROM1: Start = 0x08000000, Size = 0x00100000

修改后：
IROM1: Start = 0x08010000, Size = 0x000F0000
```

#### 修改 3：VECT_TAB_OFFSET (system_stm32f4xx.c)

打开 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/system_stm32f4xx.c`

```c
修改前：
#define VECT_TAB_OFFSET         0x00000000U

修改后：
#define VECT_TAB_OFFSET         0x00010000U
```

### 步骤 2.3：编译 APP 固件并生成 .bin 文件

1. 在 Keil 中编译 f4 工程（F7）
2. 确认编译无错误
3. 确认生成了 .bin 文件（在 MDK-ARM/f4/ 目录下）
4. **记录 .bin 文件大小**，后续 OTA 传输需要用到

### 步骤 2.4：烧录 Bootloader 和 APP

**烧录顺序很重要！先烧 Bootloader，再烧 APP。**

#### 方法 A：分别烧录（推荐新手）

**第一步：烧录 Bootloader**

1. 在 Keil 中打开 Bootloader.uvprojx
2. 确认 Flash 配置：
   - Options for Target → Utilities → Settings → Flash Download
   - Programming Algorithm: STM32F4xx 1024KB Flash
   - Start: 0x08000000, Size: 0x100000
   - 勾选 "Erase Sectors"（不要选 Erase Full Chip，否则会擦掉所有内容）
3. 点击 Download（F8）烧录 Bootloader

**第二步：烧录 APP**

1. 在 Keil 中打开 f4.uvprojx
2. 确认 Flash 配置：
   - Options for Target → Utilities → Settings → Flash Download
   - Programming Algorithm: STM32F4xx 1024KB Flash
   - Start: 0x08000000, Size: 0x100000
   - **重要：勾选 "Erase Sectors"（不要选 Erase Full Chip！）**
   - 这样只会擦除 APP 使用的 Sector 4-11，不会擦除 Bootloader 所在的 Sector 0-3
3. 点击 Download（F8）烧录 APP

#### 方法 B：使用 STM32CubeProgrammer 合并烧录

1. 打开 STM32CubeProgrammer
2. 连接 ST-Link
3. 先烧录 Bootloader.bin 到地址 0x08000000
4. 再烧录 f4.bin 到地址 0x08010000
5. 断电重启

### 步骤 2.5：验证启动链

上电后观察：

```
预期启动流程：
1. MCU 从 0x08000000 启动 → 进入 Bootloader
2. Bootloader 初始化 W25Q128
3. Bootloader 检查升级标志 → 无升级标志（或阶段一残留的标志）
4. Bootloader 检查 APP 区有效性 → 0x08010000 处栈指针有效
5. Bootloader 跳转到 APP → APP 正常运行
6. 屏幕正常显示，蓝牙可连接
```

**如果阶段一残留了升级标志：**
- Bootloader 会检测到升级标志
- 尝试从 W25Q128 暂存区搬运固件到 0x08010000
- 如果暂存区的数据恰好是有效固件（阶段一传输的），搬运成功后跳转到 APP
- 如果 CRC 校验失败，Bootloader 清除升级标志，然后检查 APP 区有效性并跳转

### 步骤 2.6：验证结果判断

| 现象 | 含义 | 解决方案 |
|------|------|----------|
| 屏幕正常显示，蓝牙可连接 | ✅ 启动链正常 | 进入阶段三 |
| 黑屏，PC13 LED 慢闪（500ms） | Bootloader 运行但 APP 无效 | 检查 APP 是否正确烧录到 0x08010000 |
| 黑屏，PC13 LED 快闪（100ms） | Bootloader 正在执行固件搬运 | 等待搬运完成（几秒钟） |
| 黑屏，无 LED | Bootloader 本身有问题 | 检查 Bootloader 编译配置和启动文件 |
| 黑屏，LED 常亮 | Bootloader Error_Handler | 检查时钟配置、SPI/UART 初始化 |

**紧急恢复方法：**

如果黑屏无法恢复，使用 STM32CubeProgrammer 执行 Full Chip Erase，然后：
1. 将 APP 工程的三件套改回原始值（0x08000000 / 0x00100000 / 0x00000000）
2. 重新编译烧录 APP
3. 回到安全基线状态

### 阶段二完成标志

- [x] Bootloader 编译通过
- [x] APP 编译通过（新地址配置）
- [x] 双固件烧录后设备正常启动
- [x] 屏幕显示正常，蓝牙可连接

---

## 阶段三：端到端 OTA 升级测试

### 目的

完整跑通 OTA 流程：手机 APP 发送新固件 → STM32 接收到 W25Q128 → 重启 → Bootloader 搬运 → 新固件运行。

### 前提条件

- [x] 阶段二完成，Bootloader + APP 双固件正常启动
- [x] APP 编译配置已改为 0x08010000

### 步骤 3.1：准备一个"新版本"固件

为了验证 OTA 确实生效，我们需要让新固件和旧固件有可见的区别。

**最简单的方法：修改版本号**

打开 `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/ota.h`，修改版本号：

```c
// 修改前
#define FW_VERSION_MAJOR      1
#define FW_VERSION_MINOR      0
#define FW_VERSION_PATCH      0

// 修改后（升级到 1.1.0）
#define FW_VERSION_MAJOR      1
#define FW_VERSION_MINOR      1
#define FW_VERSION_PATCH      0
```

你也可以加一些更明显的变化，比如修改 LCD 显示的某个文字或颜色。

### 步骤 3.2：编译新版本固件并导出 .bin

1. 在 Keil 中编译 f4 工程
2. 确认编译无错误
3. 在 `MDK-ARM/f4/` 目录下找到 `f4.bin` 文件
4. **记录文件大小**（例如 156,432 bytes）
5. 将 .bin 文件传输到手机

**注意：不要烧录这个新固件！我们要通过 OTA 来升级。**

### 步骤 3.3：通过 APP 执行 OTA 升级

1. 确保设备当前运行的是旧版本（v1.0.0）
2. 打开 RideWind APP，连接蓝牙
3. 进入 OTA 升级页面
4. 确认当前版本显示为 `v1.0.0`
5. 点击「本地升级」
6. 选择刚才准备的新版本 .bin 文件
7. 观察升级过程：

```
完整预期流程：

[APP 端]
1. 计算 CRC32
2. 发送 OTA_START:156432:3847291056
3. 等待 OTA_ERASING → OTA_READY（约 2-3 秒）
4. 分包发送 OTA_DATA（每包 16 字节，每 16 包等 ACK）
   - 总包数 = ceil(156432/16) = 9777 包
   - 预计传输时间 = 9777 × 8ms ÷ 16 ≈ 5 秒（理论值，实际可能更长）
5. 发送 OTA_END
6. 等待 OTA_OK

[STM32 APP 端]
7. CRC32 校验通过
8. 写入升级标志到 W25Q128 (0x300000)
9. 发送 OTA_OK
10. 延迟 500ms
11. NVIC_SystemReset() → MCU 重启

[Bootloader]
12. 从 0x08000000 启动
13. 初始化 W25Q128
14. 读取 0x300000 元数据 → 检测到升级标志
15. CRC32 校验 W25Q128 暂存区数据 → 通过
16. 擦除内部 Flash Sector 4-11（APP 区）
17. 从 W25Q128 (0x200000) 搬运固件到内部 Flash (0x08010000)
18. CRC32 校验内部 Flash 写入数据 → 通过
19. 清除升级标志
20. 检查 APP 区有效性 → 有效
21. 跳转到 0x08010000 → 新 APP 启动

[新 APP]
22. 屏幕正常显示
23. 蓝牙可连接
24. OTA_VERSION 返回 1.1.0 ← 升级成功！
```

### 步骤 3.4：验证升级结果

升级完成后（设备重启，约 10 秒）：

1. 重新打开 RideWind APP
2. 连接蓝牙
3. 进入 OTA 升级页面
4. 检查版本号是否变为 `v1.1.0`

**如果版本号变为 1.1.0** → 🎉 OTA 升级完全成功！
**如果版本号仍为 1.0.0** → Bootloader 可能没有执行搬运，检查升级标志
**如果设备黑屏** → 见故障排除章节

### 步骤 3.5：传输时间估算

| 固件大小 | 总包数 | 理论传输时间 | 实际预估时间 |
|----------|--------|-------------|-------------|
| 50 KB | 3,200 | ~1.6 秒 | ~5-10 秒 |
| 100 KB | 6,400 | ~3.2 秒 | ~10-20 秒 |
| 200 KB | 12,800 | ~6.4 秒 | ~20-40 秒 |
| 500 KB | 32,000 | ~16 秒 | ~50-100 秒 |
| 960 KB | 61,440 | ~30 秒 | ~100-200 秒 |

实际时间受蓝牙带宽、ACK 等待、重传等因素影响，通常是理论值的 3-5 倍。

### 阶段三完成标志

- [x] OTA 传输成功（OTA_OK）
- [x] 设备自动重启
- [x] Bootloader 执行固件搬运
- [x] 新固件正常运行
- [x] 版本号更新确认

---

## 故障排除指南

### 问题 1：OTA_VERSION 无响应

**症状：** APP 发送 OTA_VERSION 后显示"未知"

**排查步骤：**
1. 确认蓝牙已连接（设备连接页面显示已连接）
2. 检查 `rx.c` 中是否有 OTA_ 命令路由：
   ```c
   if (strncmp(cmd, "OTA_", 4) == 0) {
       OTA_ParseCommand(cmd);
       return;
   }
   ```
3. 检查 `ota.c` 是否已加入 Keil 工程
4. 检查 `main.c` 中是否调用了 `OTA_Init()`
5. 用串口调试工具直接发送 `OTA_VERSION\n` 看是否有响应

### 问题 2：OTA_START 后无响应或超时

**症状：** 发送 OTA_START 后没有收到 OTA_ERASING 或 OTA_READY

**排查步骤：**
1. 检查 W25Q128 是否正常初始化（Logo 上传功能是否正常）
2. W25Q128 擦除 16 个 64KB Block 需要约 2-3 秒，确保 APP 端超时设置足够长（当前 15 秒）
3. 检查 STM32 是否在 OTA_START 处理中卡死（可能是 W25Q128_EraseBlock 阻塞）
4. 用 ST-Link 调试器单步跟踪 OTA_ParseCommand 函数

### 问题 3：传输中途 ACK 超时

**症状：** 传输到一半时 APP 报告 ACK 超时

**可能原因：**
- 蓝牙信号不稳定
- STM32 处理 OTA_DATA 时间过长
- UART 缓冲区溢出

**解决方案：**
1. 缩短手机与设备的距离
2. 检查 `rx.c` 中 UART 接收缓冲区大小是否足够（建议 ≥ 512 字节）
3. 增加 APP 端的 `packetDelayMs`（从 8ms 增加到 15-20ms）
4. 增加 APP 端的 `ackTimeoutMs`（从 5000ms 增加到 10000ms）

### 问题 4：OTA_FAIL:CRC

**症状：** OTA_END 后收到 CRC 校验失败

**排查步骤：**
1. 确认 Flutter 端和 STM32 端使用相同的 CRC32 算法：
   - 多项式：0xEDB88320 (reflected)
   - 初始值：0xFFFFFFFF
   - 最终异或：0xFFFFFFFF
2. 用一个已知数据测试两端 CRC32 是否一致：
   - 测试数据：`"123456789"` (9 字节)
   - 预期 CRC32：`0xCBF43926`
3. 如果 CRC 不一致，检查 HexDecode 是否有 bug（可能丢失了最后几个字节）
4. 检查 W25Q128 写入是否完整（可以在 STM32 端添加调试输出，打印实际写入字节数）

### 问题 5：Bootloader 不跳转到 APP（LED 慢闪）

**症状：** 烧录 Bootloader + APP 后，PC13 LED 慢闪，屏幕黑屏

**含义：** Bootloader 进入了等待模式，说明 APP 区无效

**排查步骤：**
1. 确认 APP 确实烧录到了 0x08010000（不是 0x08000000）
2. 用 STM32CubeProgrammer 读取 0x08010000 地址的内容，确认不是全 0xFF
3. 检查 0x08010000 处的前 4 字节（栈指针），应该在 0x20000000-0x20030000 范围内
4. 确认 APP 的 scatter file 起始地址确实是 0x08010000

### 问题 6：OTA 升级后黑屏

**症状：** OTA 传输成功（OTA_OK），设备重启后黑屏

**可能原因：**
- Bootloader 搬运失败
- 搬运的固件 VECT_TAB_OFFSET 不正确
- 搬运的固件 scatter file 地址不正确

**排查步骤：**
1. 观察 PC13 LED：
   - 快闪 → Bootloader 正在搬运，等待完成
   - 慢闪 → 搬运失败或 APP 无效
   - 无闪烁 → Bootloader 本身有问题
2. 确认 OTA 传输的 .bin 文件是用 0x08010000 配置编译的
3. 确认 .bin 文件中 VECT_TAB_OFFSET = 0x00010000

**紧急恢复：**
1. 用 STM32CubeProgrammer 连接设备
2. 执行 Full Chip Erase
3. 将 APP 三件套改回 0x08000000 配置
4. 重新编译烧录 APP（不用 Bootloader）
5. 回到安全基线

### 问题 7：Bootloader 编译错误

**常见错误及解决：**

| 错误信息 | 原因 | 解决 |
|----------|------|------|
| `w25q128.h: No such file` | 缺少头文件 | 添加 Include Path |
| `undefined reference to W25Q128_Init` | 缺少源文件 | 添加 w25q128.c 到工程 |
| `undefined reference to HAL_Init` | 缺少 HAL 库 | 添加 stm32f4xx_hal.c |
| `undefined reference to SystemInit` | 缺少系统文件 | 添加 system_stm32f4xx.c |
| `multiple definition of xxx` | 重复包含 | 检查是否有重复的源文件 |
| `L6218E: Undefined symbol SysTick_Handler` | 缺少中断处理 | 添加 stm32f4xx_it.c |

---

## 远程 OTA 升级配置（可选）

当本地 OTA 跑通后，可以配置远程升级功能。

### 步骤 1：准备固件托管

将编译好的 .bin 文件上传到可公开访问的 URL，例如：
- GitHub Releases
- 自建服务器
- 云存储（OSS/S3）

### 步骤 2：更新 firmware.json

编辑项目根目录的 `firmware.json`：

```json
{
  "version": "1.1.0",
  "size": 156432,
  "download_url": "https://github.com/你的用户名/RideWind/releases/download/v1.1.0/f4.bin",
  "changelog": "修复了XXX问题，新增了YYY功能"
}
```

**重要字段说明：**
- `version`: 新固件版本号，必须大于设备当前版本
- `size`: .bin 文件的精确字节数（必须准确！）
- `download_url`: 固件下载地址（必须是 HTTPS）
- `changelog`: 更新日志，会显示在 APP 的更新弹窗中

### 步骤 3：托管 firmware.json

将 `firmware.json` 上传到可公开访问的 URL。

然后在 Flutter 代码中配置这个 URL：
打开 `RideWind/lib/services/firmware_update_service.dart`，找到 firmware.json 的 URL 配置，确保指向正确的地址。

### 步骤 4：测试远程升级

1. 在 RideWind APP 中进入 OTA 升级页面
2. 点击「远程升级」
3. APP 会自动：
   - 获取 firmware.json
   - 比较版本号
   - 如果有新版本，弹窗提示
   - 用户确认后下载 .bin 文件
   - 下载完成后自动开始蓝牙传输
4. 后续流程与本地升级相同

---

## 配置速查表

### 直接烧录模式（不用 Bootloader，当前安全基线）

| 配置项 | 值 |
|--------|-----|
| f4.sct 起始地址 | `0x08000000` |
| f4.sct 大小 | `0x00100000` |
| Keil IROM Start | `0x08000000` |
| Keil IROM Size | `0x00100000` |
| VECT_TAB_OFFSET | `0x00000000` |
| 烧录方式 | Keil 直接烧录 |

### OTA 模式（Bootloader + APP）

| 配置项 | 值 |
|--------|-----|
| f4.sct 起始地址 | `0x08010000` |
| f4.sct 大小 | `0x000F0000` |
| Keil IROM Start | `0x08010000` |
| Keil IROM Size | `0x000F0000` |
| VECT_TAB_OFFSET | `0x00010000` |
| Bootloader 地址 | `0x08000000` (64KB) |
| 烧录方式 | 先烧 Bootloader，再烧 APP |

### W25Q128 地址分配

| 区域 | 起始地址 | 大小 | 用途 |
|------|----------|------|------|
| OTA 暂存区 | `0x200000` | 1MB | 接收的固件数据 |
| OTA 元数据 | `0x300000` | 4KB | 升级标志 + 固件信息 |

### OTA 协议命令一览

| 命令 | 方向 | 格式 | 说明 |
|------|------|------|------|
| OTA_START | APP→STM32 | `OTA_START:size:crc32\n` | 开始升级 |
| OTA_ERASING | STM32→APP | `OTA_ERASING\n` | 正在擦除 |
| OTA_READY | STM32→APP | `OTA_READY\n` | 准备就绪 |
| OTA_DATA | APP→STM32 | `OTA_DATA:seq:hexdata\n` | 数据包 |
| OTA_ACK | STM32→APP | `OTA_ACK:seq\n` | 确认收到 |
| OTA_NAK | STM32→APP | `OTA_NAK:seq\n` | 解码失败 |
| OTA_RESEND | STM32→APP | `OTA_RESEND:seq\n` | 请求重传 |
| OTA_END | APP→STM32 | `OTA_END\n` | 传输结束 |
| OTA_OK | STM32→APP | `OTA_OK\n` | 校验通过 |
| OTA_FAIL | STM32→APP | `OTA_FAIL:reason\n` | 失败原因 |
| OTA_ABORT | APP→STM32 | `OTA_ABORT\n` | 中止升级 |
| OTA_ABORTED | STM32→APP | `OTA_ABORTED\n` | 已中止 |
| OTA_VERSION | APP→STM32 | `OTA_VERSION\n` | 查询版本 |
| OTA_VERSION | STM32→APP | `OTA_VERSION:x.y.z\n` | 返回版本 |

---

## 推荐行动顺序总结

```
第一步：阶段一（零风险）
  └─ 不改任何配置，只测试蓝牙数据传输
  └─ 验证 OTA_VERSION、OTA_START、OTA_DATA、OTA_END 全链路
  └─ 预计耗时：1-2 小时

第二步：阶段二（中等风险，可恢复）
  └─ 修复 Bootloader 编译问题
  └─ 修改 APP 三件套配置
  └─ 烧录双固件，验证启动链
  └─ 预计耗时：2-4 小时（主要花在 Bootloader 编译上）

第三步：阶段三（低风险，阶段二成功后）
  └─ 准备新版本固件
  └─ 通过 APP 执行 OTA 升级
  └─ 验证新固件运行
  └─ 预计耗时：30 分钟

第四步：远程升级配置（可选）
  └─ 配置 firmware.json 和固件托管
  └─ 测试远程升级流程
  └─ 预计耗时：1 小时
```
