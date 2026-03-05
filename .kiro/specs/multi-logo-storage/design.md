# 多Logo存储与旋钮选择功能设计

## 1. 系统架构

### 1.1 Flash存储布局

```
W25Q128 Flash Memory Map (Logo区域):
┌─────────────────────────────────────────┐
│ 0x100000 - 0x11FFFF: Logo Slot 0 (128KB)│
├─────────────────────────────────────────┤
│ 0x120000 - 0x13FFFF: Logo Slot 1 (128KB)│
├─────────────────────────────────────────┤
│ 0x140000 - 0x15FFFF: Logo Slot 2 (128KB)│
├─────────────────────────────────────────┤
│ 0x160000 - 0x160FFF: Logo Config (4KB)  │
│   - Active slot selection               │
│   - Slot validity cache                 │
└─────────────────────────────────────────┘
```

### 1.2 槽位数据结构

每个槽位的数据布局：
```
Offset 0x00-0x0F: LogoHeader_t (16字节)
  - magic: 0xAA55 (有效标志)
  - width: 240
  - height: 240
  - reserved1: 0
  - dataSize: 115200
  - checksum: CRC32

Offset 0x10-0x1C20F: Logo数据 (115200字节)
```

### 1.3 配置数据结构

```c
typedef struct {
    uint16_t magic;           // 0xBB66 配置有效标志
    uint8_t  active_slot;     // 当前激活的槽位 (0-2)
    uint8_t  reserved;        // 保留
    uint32_t checksum;        // 配置CRC32
} LogoConfig_t;
```

## 2. 接口设计

### 2.1 新增头文件定义 (logo.h)

```c
// 多槽位存储参数
#define LOGO_MAX_SLOTS      3           // 最大槽位数
#define LOGO_SLOT_SIZE      0x20000     // 每槽位128KB
#define LOGO_SLOT_0_ADDR    0x100000    // 槽位0地址
#define LOGO_SLOT_1_ADDR    0x120000    // 槽位1地址
#define LOGO_SLOT_2_ADDR    0x140000    // 槽位2地址
#define LOGO_CONFIG_ADDR    0x160000    // 配置存储地址
#define LOGO_CONFIG_MAGIC   0xBB66      // 配置有效标志

// 槽位地址计算宏
#define LOGO_SLOT_ADDR(slot) (LOGO_SLOT_0_ADDR + (slot) * LOGO_SLOT_SIZE)

// 新增函数声明
uint32_t Logo_GetSlotAddress(uint8_t slot);
bool Logo_IsSlotValid(uint8_t slot);
void Logo_SetActiveSlot(uint8_t slot);
uint8_t Logo_GetActiveSlot(void);
bool Logo_ShowSlot(uint8_t slot);
uint8_t Logo_NextValidSlot(uint8_t current);
uint8_t Logo_PrevValidSlot(uint8_t current);
uint8_t Logo_CountValidSlots(void);
void Logo_SaveConfig(void);
void Logo_LoadConfig(void);
void Logo_DeleteSlot(uint8_t slot);        // 新增：删除指定槽位
uint8_t Logo_FindEmptySlot(void);          // 新增：查找空槽位
uint8_t Logo_GetAutoUploadSlot(void);      // 新增：获取自动上传目标槽位
```

### 2.2 蓝牙协议扩展

新增协议格式（向后兼容）：
```
LOGO_START:slot:size:crc32    # 指定槽位上传
LOGO_START:size:crc32         # 默认槽位0（兼容旧协议）
GET:LOGO_SLOTS                # 查询所有槽位状态
SET:LOGO_ACTIVE:slot          # 设置激活槽位
```

响应格式：
```
LOGO_SLOTS:v0:v1:v2           # v0/v1/v2 = 0(空) 或 1(有效)
LOGO_ACTIVE:slot              # 当前激活槽位
```

## 3. 实现细节

### 3.1 Logo_ParseCommand 修改

解析 `LOGO_START` 命令时检测槽位参数：
```c
// 解析格式: LOGO_START:slot:size:crc32 或 LOGO_START:size:crc32
if (strncmp(cmd, "LOGO_START:", 11) == 0) {
    char* p = cmd + 11;
    uint32_t first_num = strtoul(p, &p, 10);
    
    if (*p == ':') {
        uint32_t second_num = strtoul(p + 1, &p, 10);
        if (*p == ':') {
            // 三参数格式: slot:size:crc32
            logo_current_slot = first_num;
            size = second_num;
            crc = strtoul(p + 1, NULL, 10);
        } else {
            // 两参数格式: size:crc32 (自动选择槽位)
            logo_current_slot = Logo_GetAutoUploadSlot();
            size = first_num;
            crc = second_num;
        }
    }
    // 使用 LOGO_SLOT_ADDR(logo_current_slot) 计算Flash地址
}
```

### 3.1.1 自动槽位选择逻辑

```c
uint8_t Logo_GetAutoUploadSlot(void) {
    // 优先查找空槽位
    for (uint8_t i = 0; i < LOGO_MAX_SLOTS; i++) {
        if (!Logo_IsSlotValid(i)) {
            return i;
        }
    }
    // 所有槽位都满，返回Slot 0（自动覆盖最旧的）
    return 0;
}

void Logo_DeleteSlot(uint8_t slot) {
    if (slot >= LOGO_MAX_SLOTS) return;
    
    uint32_t addr = Logo_GetSlotAddress(slot);
    // 擦除槽位的Flash扇区（清除magic标志使其无效）
    W25QXX_Erase_Sector(addr / 4096);
    
    // 如果删除的是激活槽位，重置为第一个有效槽位
    if (slot == Logo_GetActiveSlot()) {
        for (uint8_t i = 0; i < LOGO_MAX_SLOTS; i++) {
            if (Logo_IsSlotValid(i)) {
                Logo_SetActiveSlot(i);
                Logo_SaveConfig();
                return;
            }
        }
        // 无有效槽位，重置为0
        Logo_SetActiveSlot(0);
        Logo_SaveConfig();
    }
}
```

### 3.2 UI6 Logo界面交互

```c
// xuanniu.c 中 ui == 6 的处理
else if(ui == 6) {
    static uint8_t logo_view_slot = 0;  // 当前查看的槽位
    static uint8_t logo_slot_count = 0; // 有效槽位数量
    
    if(chu == 6) {
        chu = 0;
        logo_slot_count = Logo_CountValidSlots();
        logo_view_slot = Logo_GetActiveSlot();
        
        if (logo_slot_count > 0) {
            Logo_ShowSlot(logo_view_slot);
            // 纯净显示，不显示槽位指示器
        } else {
            // 无有效Logo，显示默认
            Logo_ShowBoot();
        }
    }
    
    // 旋转切换槽位
    if (encoder_delta != 0 && logo_slot_count > 1) {
        if (encoder_delta > 0) {
            logo_view_slot = Logo_NextValidSlot(logo_view_slot);
        } else {
            logo_view_slot = Logo_PrevValidSlot(logo_view_slot);
        }
        Logo_ShowSlot(logo_view_slot);
        // 纯净显示，不显示槽位指示器
    }
    
    // 按钮确认选择（静默保存）
    if (key_down == 1 && logo_slot_count > 0) {
        Logo_SetActiveSlot(logo_view_slot);
        Logo_SaveConfig();
        // 静默保存，不显示任何反馈文字
    }
    
    // 长按删除当前Logo（≥2秒）
    if (key_long_press && logo_slot_count > 0) {
        Logo_DeleteSlot(logo_view_slot);
        logo_slot_count = Logo_CountValidSlots();
        
        if (logo_slot_count > 0) {
            // 切换到下一个有效槽位
            logo_view_slot = Logo_NextValidSlot(logo_view_slot);
            Logo_ShowSlot(logo_view_slot);
        } else {
            // 无有效Logo，显示默认
            Logo_ShowBoot();
        }
        // 静默删除，不显示任何反馈文字
    }
}
```

### 3.3 开机Logo显示修改

```c
void Logo_ShowBoot(void) {
    // 加载配置获取激活槽位
    Logo_LoadConfig();
    uint8_t active = Logo_GetActiveSlot();
    
    // 尝试显示激活槽位的Logo
    if (Logo_IsSlotValid(active)) {
        Logo_ShowSlot(active);
    } else {
        // 激活槽位无效，尝试找第一个有效槽位
        for (uint8_t i = 0; i < LOGO_MAX_SLOTS; i++) {
            if (Logo_IsSlotValid(i)) {
                Logo_ShowSlot(i);
                return;
            }
        }
        // 无任何有效Logo，显示默认
        uint16_t x = (240 - DEFAULT_LOGO_WIDTH) / 2;
        uint16_t y = (240 - DEFAULT_LOGO_HEIGHT) / 2;
        LCD_ShowPicture(x, y, DEFAULT_LOGO_WIDTH, DEFAULT_LOGO_HEIGHT, gImage_tou_xiang_154_154);
    }
}
```

## 4. 正确性属性

### P1: 槽位地址计算正确性
对于任意有效槽位 slot (0 <= slot < LOGO_MAX_SLOTS):
- Logo_GetSlotAddress(slot) == LOGO_SLOT_0_ADDR + slot * LOGO_SLOT_SIZE

### P2: 槽位有效性检测正确性
对于任意槽位 slot:
- Logo_IsSlotValid(slot) == true 当且仅当该槽位Flash中存储了有效的LogoHeader

### P3: 循环切换正确性
对于有效槽位集合 V (|V| > 0):
- Logo_NextValidSlot 和 Logo_PrevValidSlot 只返回 V 中的元素
- 连续调用 |V| 次 Logo_NextValidSlot 会遍历 V 中所有元素

### P4: 配置持久化正确性
- Logo_SaveConfig() 后重启，Logo_LoadConfig() 能恢复相同的 active_slot 值

### P5: 向后兼容性
- 不带槽位参数的 LOGO_START:size:crc32 命令自动选择空槽位或覆盖Slot 0
- 现有APP无需修改即可正常上传Logo

### P6: 长按删除正确性
- Logo_DeleteSlot(slot) 后，Logo_IsSlotValid(slot) == false
- 删除激活槽位后，active_slot 自动切换到下一个有效槽位

### P7: 自动覆盖正确性
- 当所有槽位都有效时，Logo_GetAutoUploadSlot() == 0
- 当存在空槽位时，Logo_GetAutoUploadSlot() 返回第一个空槽位

## 5. 测试策略

### 5.1 单元测试
- 槽位地址计算测试
- 槽位有效性检测测试
- 配置读写测试

### 5.2 集成测试
- 多槽位上传测试
- 旋钮切换测试
- 开机Logo选择测试
- 向后兼容性测试
