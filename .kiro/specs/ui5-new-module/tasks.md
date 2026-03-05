# UI5 新模块控制界面 - 实现任务

📅 创建日期: 2026-01-14
📋 需求文档: #[[file:.kiro/specs/ui5-new-module/requirements.md]]
📐 设计文档: #[[file:.kiro/specs/ui5-new-module/design.md]]

---

## 任务概览

| 阶段 | 任务数 | 状态 |
|------|--------|------|
| 阶段 1: 变量与宏定义 | 2 | ⏳ 待开始 |
| 阶段 2: LCD 界面实现 | 3 | ⏳ 待开始 |
| 阶段 3: UI 状态机扩展 | 3 | ⏳ 待开始 |
| 阶段 4: 蓝牙协议扩展 | 4 | ⏳ 待开始 |
| 阶段 5: 测试与验证 | 3 | ⏳ 待开始 |

---

## 阶段 1: 变量与宏定义

### Task 1.1: 添加 Module5 变量声明
- [ ] **文件**: `Core/Inc/xuanniu.h`
- [ ] **内容**:
  ```c
  // UI5 新模块控制变量
  extern int16_t Module5_Num;
  extern int16_t Module5_Num_old;
  extern uint8_t module5_unit;
  ```
- [ ] **验证**: 编译通过，无重复定义错误

### Task 1.2: 添加 Module5 变量定义
- [ ] **文件**: `Core/Src/xuanniu.c`
- [ ] **内容**:
  ```c
  // UI5 新模块控制变量
  int16_t Module5_Num = 0;
  int16_t Module5_Num_old = 0;
  uint8_t module5_unit = 0;
  ```
- [ ] **验证**: 编译通过，变量初始化正确

---

## 阶段 2: LCD 界面实现

### Task 2.1: 添加 LCD_ui5 函数声明
- [ ] **文件**: `Core/Inc/lcd.h`
- [ ] **内容**:
  ```c
  void LCD_ui5(void);
  void LCD_ui5_update(int16_t num);
  ```
- [ ] **验证**: 编译通过

### Task 2.2: 实现 LCD_ui5 界面绘制
- [ ] **文件**: `Core/Src/lcd.c`
- [ ] **内容**: 复制 LCD_ui1() 的实现，修改为 UI5 专用
  ```c
  void LCD_ui5(void)
  {
      LCD_ShowPicture(0, 0, LCD_WIDTH, LCD_HEIGHT, gImage_beijing_240_240);
      LCD_ShowPicture(fengshubiao_x, fengshubiao_y, 
                      fengshubiao_width, fengshubiao_high, 
                      gImage_fengshubiao_202_43);
  }
  ```
- [ ] **验证**: 切换到 UI5 时显示正确界面

### Task 2.3: 实现 LCD_ui5_update 数值更新
- [ ] **文件**: `Core/Src/lcd.c`
- [ ] **内容**: 复用 LCD_picture() 逻辑
  ```c
  void LCD_ui5_update(int16_t num)
  {
      // 复用现有数字显示逻辑
      LCD_picture(num, module5_unit);
  }
  ```
- [ ] **验证**: 数值变化时 LCD 正确更新

---

## 阶段 3: UI 状态机扩展

### Task 3.1: 扩展 UI 切换范围
- [ ] **文件**: `Core/Src/xuanniu.c`
- [ ] **位置**: `Encoder()` 函数中的长按处理
- [ ] **修改**:
  ```c
  // 原: if (ui > 4) ui = 0;
  // 改:
  if (ui > 5) ui = 0;
  ```
- [ ] **验证**: 长按可切换到 UI5，再次长按回到 UI0

### Task 3.2: 添加 UI5 初始化逻辑
- [ ] **文件**: `Core/Src/xuanniu.c`
- [ ] **位置**: `LCD()` 函数末尾
- [ ] **内容**:
  ```c
  else if(ui == 5)
  {
      if(chu == 5 || chu == 0)  // 从 UI4 或 UI0 进入
      {
          chu = 6;  // 设置下一个初始化标志
          LCD_ui5();
          LCD_ui5_update(Module5_Num);
      }
      // ... 编码器处理逻辑
  }
  ```
- [ ] **验证**: 进入 UI5 时正确初始化界面

### Task 3.3: 添加 UI5 编码器控制逻辑
- [ ] **文件**: `Core/Src/xuanniu.c`
- [ ] **位置**: `LCD()` 函数的 UI5 分支
- [ ] **内容**:
  ```c
  // 编码器控制
  int16_t delta = Encoder_GetDelta();
  Module5_Num += delta;
  if(Module5_Num > 100) Module5_Num = 100;
  if(Module5_Num < 0) Module5_Num = 0;
  
  // 数值变化时更新
  if(Module5_Num != Module5_Num_old)
  {
      LCD_ui5_update(Module5_Num);
      // PWM5_Update(Module5_Num);  // 待 PWM 配置确认后启用
      BLE_ReportModule5(Module5_Num);
      Module5_Num_old = Module5_Num;
  }
  ```
- [ ] **验证**: 旋转编码器可调节 Module5_Num

---

## 阶段 4: 蓝牙协议扩展

### Task 4.1: 添加 BLE_ReportModule5 函数声明
- [ ] **文件**: `Core/Inc/rx.h`
- [ ] **内容**:
  ```c
  void BLE_ReportModule5(int16_t value);
  ```
- [ ] **验证**: 编译通过

### Task 4.2: 实现 BLE_ReportModule5 函数
- [ ] **文件**: `Core/Src/rx.c`
- [ ] **内容**:
  ```c
  void BLE_ReportModule5(int16_t value)
  {
      char buf[24];
      sprintf(buf, "MOD5_REPORT:%d\n", value);
      BLE_SendString(buf);
  }
  ```
- [ ] **验证**: 数值变化时蓝牙正确上报

### Task 4.3: 添加 MOD5 命令解析
- [ ] **文件**: `Core/Src/rx.c`
- [ ] **位置**: `Protocol_Process()` 或 `BLE_Process()` 函数
- [ ] **内容**:
  ```c
  // MOD5:xx - 设置新模块值
  else if(strncmp(cmd, "MOD5:", 5) == 0)
  {
      int value = atoi(cmd + 5);
      if(value >= 0 && value <= 100)
      {
          Module5_Num = (int16_t)value;
          // PWM5_Update(Module5_Num);  // 待确认
          
          if(ui == 5)
          {
              LCD_ui5_update(Module5_Num);
          }
          
          printf("[BLE] MOD5 set to %d\r\n", value);
      }
  }
  ```
- [ ] **验证**: 发送 `MOD5:50\n` 可设置 Module5_Num

### Task 4.4: 添加 GET:MOD5 查询命令
- [ ] **文件**: `Core/Src/rx.c`
- [ ] **位置**: `Protocol_Process()` 或 `BLE_Process()` 函数
- [ ] **内容**:
  ```c
  // GET:MOD5 - 查询新模块值
  else if(strcmp(cmd, "GET:MOD5") == 0 || strcmp(cmd, "GET:MOD5\n") == 0)
  {
      char buf[20];
      sprintf(buf, "MOD5:%d\r\n", Module5_Num);
      BLE_SendString(buf);
  }
  ```
- [ ] **验证**: 发送 `GET:MOD5\n` 返回当前值

---

## 阶段 5: 测试与验证

### Task 5.1: 编译验证
- [ ] 使用 Keil MDK 编译项目
- [ ] 确保无编译错误和警告
- [ ] 检查代码大小是否在 Flash 限制内

### Task 5.2: 功能测试
- [ ] 测试 UI 切换 (0→1→2→3→4→5→0)
- [ ] 测试编码器控制 (UI5 界面)
- [ ] 测试蓝牙命令 (MOD5:xx, GET:MOD5)
- [ ] 测试状态上报 (MOD5_REPORT)

### Task 5.3: 集成测试
- [ ] 测试与 APP 的完整交互流程
- [ ] 测试 UI 切换时的状态保持
- [ ] 测试异常情况处理 (超范围值、无效命令)

---

## 待办事项 (Blocked)

以下任务需要用户确认后才能开始：

### Task B.1: PWM 硬件配置
- **阻塞原因**: 需要确认使用哪个 PWM 通道
- **待确认**: PC8 (TIM8_CH1) 或 PC12 或其他
- **内容**: 配置定时器、启动 PWM、实现 PWM5_Update()

### Task B.2: 自定义显示格式
- **阻塞原因**: 需要确认显示格式
- **待确认**: 百分比 / 映射值 / 自定义单位
- **内容**: 修改 LCD_ui5_update() 的显示逻辑

### Task B.3: 油门模式支持
- **阻塞原因**: 需要确认是否需要油门模式
- **待确认**: 是否支持三击进入油门模式
- **内容**: 复制 UI1 的油门模式逻辑到 UI5

---

## 进度跟踪

```
阶段 1: [  ] [  ] .......................... 0%
阶段 2: [  ] [  ] [  ] ..................... 0%
阶段 3: [  ] [  ] [  ] ..................... 0%
阶段 4: [  ] [  ] [  ] [  ] ................ 0%
阶段 5: [  ] [  ] [  ] ..................... 0%
─────────────────────────────────────────────
总进度: 0/15 任务完成 (0%)
```

---

**文档状态**: 📝 草稿 - 等待用户确认后开始实现
**最后更新**: 2026-01-14
