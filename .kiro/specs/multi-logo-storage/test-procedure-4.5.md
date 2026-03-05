# 测试程序 4.5: 槽位满时自动覆盖

## 测试目标
验证当所有3个Logo槽位都已满时，上传新Logo（不指定槽位）会自动覆盖Slot 0。

## 代码审查结果

### 1. Logo_GetAutoUploadSlot() 函数实现 ✅

**位置**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c` (第620-632行)

```c
uint8_t Logo_GetAutoUploadSlot(void)
{
    // 优先查找空槽位
    for (uint8_t i = 0; i < LOGO_MAX_SLOTS; i++) {
        if (!Logo_IsSlotValid(i)) {
            printf("[LOGO] Auto upload slot: %d (empty)\r\n", i);
            return i;
        }
    }
    // 所有槽位都满，返回Slot 0（自动覆盖最旧的）
    printf("[LOGO] Auto upload slot: 0 (all slots full, overwrite)\r\n");
    return 0;
}
```

**验证点**:
- ✅ 优先查找空槽位（从Slot 0到Slot 2顺序检查）
- ✅ 所有槽位都满时返回0（自动覆盖最旧的）
- ✅ 有调试日志输出便于追踪

### 2. Logo_ParseCommand 两参数格式处理 ✅

**位置**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c` (第824-841行)

```c
// 解析参数 - 支持两种格式:
// LOGO_START:size:crc32 (两参数，自动选择槽位)
// LOGO_START:slot:size:crc32 (三参数，指定slot)
char* p = cmd + 11;
uint32_t first_num = strtoul(p, &p, 10);

if (*p == ':') {
    uint32_t second_num = strtoul(p + 1, &p, 10);
    if (*p == ':') {
        // 三参数格式: slot:size:crc32
        slot = (uint8_t)first_num;
        size = second_num;
        crc = strtoul(p + 1, NULL, 10);
    } else {
        // 两参数格式: size:crc32 (自动选择槽位)
        slot = Logo_GetAutoUploadSlot();  // ← 关键调用
        size = first_num;
        crc = second_num;
    }
}
```

**验证点**:
- ✅ 两参数格式 `LOGO_START:size:crc32` 调用 `Logo_GetAutoUploadSlot()`
- ✅ 三参数格式 `LOGO_START:slot:size:crc32` 使用指定槽位
- ✅ 向后兼容旧协议

### 3. Flash写入地址计算 ✅

**位置**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c` (第851-852行)

```c
logo_current_slot = slot;  // 设置当前上传目标槽位
uint32_t flash_addr = Logo_GetSlotAddress(slot);
```

**验证点**:
- ✅ 使用 `Logo_GetSlotAddress(slot)` 计算正确的Flash地址
- ✅ 新Logo数据写入到选定槽位的地址

### 4. 槽位地址定义 ✅

**位置**: `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/logo.h`

```c
#define LOGO_SLOT_0_ADDR    0x100000    // 槽位0地址 (1MB位置)
#define LOGO_SLOT_1_ADDR    0x120000    // 槽位1地址 (1.125MB位置)
#define LOGO_SLOT_2_ADDR    0x140000    // 槽位2地址 (1.25MB位置)
#define LOGO_SLOT_ADDR(slot) (LOGO_SLOT_0_ADDR + (slot) * LOGO_SLOT_SIZE)
```

**验证点**:
- ✅ 各槽位地址独立，不重叠
- ✅ 覆盖Slot 0不会影响Slot 1和Slot 2的数据

## 硬件测试步骤

### 前置条件
- 硬件设备已连接并正常工作
- APP已安装并能正常连接蓝牙
- 所有槽位初始为空（可先执行删除操作清空）

### 测试步骤

#### 步骤1: 填满3个槽位
1. 使用APP上传Logo A到Slot 0（使用 `LOGO_START:0:115200:crc32`）
2. 使用APP上传Logo B到Slot 1（使用 `LOGO_START:1:115200:crc32`）
3. 使用APP上传Logo C到Slot 2（使用 `LOGO_START:2:115200:crc32`）
4. 验证所有3个槽位都有有效Logo（通过旋钮切换确认）

#### 步骤2: 上传新Logo（不指定槽位）
1. 使用APP上传Logo D，使用两参数格式 `LOGO_START:115200:crc32`
2. 观察串口日志，应显示：
   ```
   [LOGO] Auto upload slot: 0 (all slots full, overwrite)
   [LOGO] START slot=0 size=115200 crc=...
   ```

#### 步骤3: 验证覆盖结果
1. 进入UI6 Logo界面
2. 旋转旋钮查看各槽位：
   - **Slot 0**: 应显示Logo D（新上传的）
   - **Slot 1**: 应显示Logo B（保持不变）
   - **Slot 2**: 应显示Logo C（保持不变）

### 预期结果
| 检查项 | 预期结果 |
|--------|----------|
| Logo_GetAutoUploadSlot() 返回值 | 0（所有槽位满时） |
| 新Logo写入位置 | Slot 0 (0x100000) |
| Slot 0 内容 | 被新Logo覆盖 |
| Slot 1 内容 | 保持不变 |
| Slot 2 内容 | 保持不变 |
| 用户体验 | 透明覆盖，无需额外确认 |

## 符合需求验证

### US-6: 槽位满时自动覆盖
| 验收标准 | 实现状态 |
|----------|----------|
| 6.1 上传时检测所有槽位是否已满 | ✅ Logo_GetAutoUploadSlot() 遍历检查 |
| 6.2 如果槽位已满，自动删除Slot 0的Logo | ✅ 返回0，Flash擦除时覆盖 |
| 6.3 新Logo写入Slot 0位置 | ✅ 使用Logo_GetSlotAddress(0) |
| 6.4 原Slot 1和Slot 2的Logo保持不变 | ✅ 独立地址空间 |
| 6.5 覆盖操作对用户透明，无需额外确认 | ✅ 自动处理，无提示 |

### P7: 自动覆盖正确性（设计文档属性）
| 属性 | 验证状态 |
|------|----------|
| 当所有槽位都有效时，Logo_GetAutoUploadSlot() == 0 | ✅ 代码实现正确 |
| 当存在空槽位时，Logo_GetAutoUploadSlot() 返回第一个空槽位 | ✅ 代码实现正确 |

## 结论

代码审查确认自动覆盖功能实现正确：
1. `Logo_GetAutoUploadSlot()` 正确实现了优先空槽位、满时返回0的逻辑
2. `Logo_ParseCommand` 在两参数格式时正确调用自动槽位选择
3. Flash地址计算正确，各槽位数据独立
4. 符合所有验收标准和设计属性

**代码已准备好进行硬件测试。**
