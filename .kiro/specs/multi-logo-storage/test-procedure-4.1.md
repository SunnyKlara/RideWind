# 任务 4.1 测试多槽位上传 - 测试程序文档

## 概述

本文档描述了多槽位Logo上传功能的集成测试程序。该测试验证固件和APP能够正确地将Logo上传到三个独立的Flash槽位。

## 代码审查结果

### ✅ 固件实现 (logo.c / logo.h)

**多槽位定义已实现:**
```c
#define LOGO_MAX_SLOTS      3           // 最大槽位数
#define LOGO_SLOT_SIZE      0x20000     // 每槽位128KB

#define LOGO_SLOT_0_ADDR    0x100000    // 槽位0地址 (1MB位置)
#define LOGO_SLOT_1_ADDR    0x120000    // 槽位1地址 (1.125MB位置)
#define LOGO_SLOT_2_ADDR    0x140000    // 槽位2地址 (1.25MB位置)
```

**协议解析已支持槽位参数:**
- ✅ `LOGO_START:slot:size:crc32` - 三参数格式，指定槽位上传
- ✅ `LOGO_START:size:crc32` - 两参数格式，自动选择槽位（向后兼容）
- ✅ `GET:LOGO_SLOTS` - 查询所有槽位状态
- ✅ `SET:LOGO_ACTIVE:slot` - 设置激活槽位
- ✅ `LOGO_DELETE:slot` - 删除指定槽位

**关键函数已实现:**
- ✅ `Logo_GetSlotAddress(slot)` - 计算槽位Flash地址
- ✅ `Logo_IsSlotValid(slot)` - 检查槽位有效性
- ✅ `Logo_GetAutoUploadSlot()` - 自动选择上传槽位
- ✅ `Logo_ShowSlot(slot)` - 显示指定槽位Logo

### ✅ APP实现 (logo_upload_e2e_test_screen.dart)

**槽位选择UI已实现:**
- ✅ 槽位选择下拉框 (0/1/2)
- ✅ 槽位状态显示 (✓ 已占用 / ○ 空)
- ✅ 激活槽位标记 (*)
- ✅ 刷新槽位状态按钮

**协议支持:**
- ✅ `_sendStartCommand` 使用三参数格式: `LOGO_START:$_selectedSlot:$dataSize:$crc32`
- ✅ `_querySlotStatus` 发送 `GET:LOGO_SLOTS` 查询
- ✅ 解析响应 `LOGO_SLOTS:v0:v1:v2:active`

---

## 测试程序

### 前置条件
1. 硬件设备已开机并进入蓝牙可连接状态
2. APP已安装并能连接到设备
3. 设备Flash已清空或已知状态

### 测试步骤

#### 测试1: 上传Logo到Slot 0

1. **打开APP** → 进入"Logo上传"界面
2. **选择槽位** → 从下拉框选择"槽0 ○"
3. **选择图片** → 使用测试图片"纯红色"或选择自定义图片
4. **点击"开始上传"**
5. **预期结果:**
   - APP显示: `📤 发送: LOGO_START:0:115200:xxxxxxxx`
   - APP显示: `✅ 硬件就绪！`
   - 进度条从0%增长到100%
   - APP显示: `🎉 测试成功！Logo已成功上传到槽位 0`
   - 设备LCD显示: `SUCCESS! SLOT 0 UPLOADED`
   - 槽位状态刷新后显示: `槽0 ✓`

#### 测试2: 上传Logo到Slot 1

1. **选择槽位** → 从下拉框选择"槽1 ○"
2. **选择图片** → 使用测试图片"纯绿色"
3. **点击"开始上传"**
4. **预期结果:**
   - APP显示: `📤 发送: LOGO_START:1:115200:xxxxxxxx`
   - 上传成功，设备LCD显示: `SUCCESS! SLOT 1 UPLOADED`
   - 槽位状态: `槽0 ✓` `槽1 ✓` `槽2 ○`

#### 测试3: 上传Logo到Slot 2

1. **选择槽位** → 从下拉框选择"槽2 ○"
2. **选择图片** → 使用测试图片"纯蓝色"
3. **点击"开始上传"**
4. **预期结果:**
   - APP显示: `📤 发送: LOGO_START:2:115200:xxxxxxxx`
   - 上传成功，设备LCD显示: `SUCCESS! SLOT 2 UPLOADED`
   - 槽位状态: `槽0 ✓` `槽1 ✓` `槽2 ✓`

#### 测试4: 验证各槽位数据独立

1. **进入设备UI6界面** (Logo界面)
2. **旋转旋钮** → 切换显示不同槽位的Logo
3. **预期结果:**
   - 旋转显示红色Logo (Slot 0)
   - 旋转显示绿色Logo (Slot 1)
   - 旋转显示蓝色Logo (Slot 2)
   - 三个Logo颜色不同，证明数据独立存储

---

## Flash地址验证

| 槽位 | Flash地址 | 地址范围 |
|------|-----------|----------|
| Slot 0 | 0x100000 | 0x100000 - 0x11FFFF |
| Slot 1 | 0x120000 | 0x120000 - 0x13FFFF |
| Slot 2 | 0x140000 | 0x140000 - 0x15FFFF |

每个槽位占用128KB (0x20000字节)，地址不重叠。

---

## 协议格式验证

### 上传命令格式
```
LOGO_START:0:115200:3456789012   → 上传到Slot 0
LOGO_START:1:115200:3456789012   → 上传到Slot 1
LOGO_START:2:115200:3456789012   → 上传到Slot 2
```

### 响应格式
```
LOGO_READY:0                     → 槽位0准备就绪
LOGO_OK:0                        → 槽位0上传成功
LOGO_SLOTS:1:1:1:0               → 三个槽位都有效，激活槽位0
```

---

## 测试通过标准

- [x] 代码审查: 固件支持槽位参数 ✅
- [x] 代码审查: APP支持槽位选择 ✅
- [ ] 硬件测试: Slot 0 上传成功
- [ ] 硬件测试: Slot 1 上传成功
- [ ] 硬件测试: Slot 2 上传成功
- [ ] 硬件测试: 各槽位数据独立

---

## 结论

**代码实现已完成，可以进行硬件测试。**

固件和APP的多槽位上传功能代码已经完整实现:
1. 固件正确解析三参数格式 `LOGO_START:slot:size:crc32`
2. 固件使用 `Logo_GetSlotAddress(slot)` 计算正确的Flash地址
3. APP UI支持槽位选择并发送正确的协议命令
4. 槽位状态查询和显示功能正常

等待实际硬件测试验证功能正确性。
