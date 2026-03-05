# Logo上传功能任务清单

> **功能名称**: 用户自定义Logo上传与显示  
> **版本**: v1.0  
> **创建日期**: 2026-01-17

---

## 任务概览

- **总任务数**: 20
- **预计工期**: 10个工作日
- **优先级**: P0 (核心功能)

---

## 1. APP端开发任务

### 1.1 图片处理模块

- [ ] 1.1.1 集成image_picker插件，实现相册选择功能
  - 添加依赖到pubspec.yaml
  - 配置Android/iOS权限
  - 实现_pickImage方法

- [ ] 1.1.2 集成image_cropper插件，实现图片裁剪功能
  - 添加依赖到pubspec.yaml
  - 配置裁剪参数（1:1正方形）
  - 实现_cropImage方法

- [ ] 1.1.3 实现图片转RGB565格式功能
  - 使用dart:ui调整图片尺寸到154x154
  - 转换RGBA到RGB565格式
  - 生成Uint8List数据（47432字节）
  - 实现_convertImageToRGB565方法

- [ ] 1.1.4 实现CRC32校验和计算
  - 实现标准CRC32算法
  - 使用查找表优化性能
  - 实现_calculateCRC32方法

### 1.2 蓝牙传输模块

- [ ] 1.2.1 扩展ProtocolService，添加Logo上传协议
  - 添加LOGO_START命令编码
  - 添加LOGO_DATA命令编码（十六进制）
  - 添加LOGO_END命令编码
  - 添加GET:LOGO查询命令
  - 添加LOGO_DELETE删除命令

- [ ] 1.2.2 实现分包传输逻辑
  - 每包16字节数据
  - 十六进制编码（32字符）
  - 包序号管理（0-N）
  - 实现_sendLogoPacket方法

- [ ] 1.2.3 实现ACK/NAK响应处理
  - 解析LOGO_ACK响应
  - 解析LOGO_NAK响应
  - 实现重传逻辑（最多3次）
  - 实现_waitForLogoResponse方法

- [ ] 1.2.4 实现传输进度管理
  - 计算总包数
  - 实时更新进度百分比
  - 计算预计剩余时间
  - 更新UI进度条

### 1.3 UI界面开发

- [ ] 1.3.1 创建LogoUploadScreen页面
  - 创建lib/screens/logo_upload_screen.dart
  - 实现基础页面结构
  - 添加到路由配置

- [ ] 1.3.2 实现Logo预览区域
  - 圆形预览容器（响应式尺寸）
  - 显示选中的图片
  - 空状态显示"点击添加Logo"
  - 实现_buildLogoPreview方法

- [ ] 1.3.3 实现进度条组件
  - LinearProgressIndicator
  - 进度百分比文字
  - 状态文字提示
  - 实现_buildProgressBar方法

- [ ] 1.3.4 实现操作按钮组
  - "选择图片"按钮
  - "上传到设备"按钮
  - "恢复默认"按钮
  - "测试通信"按钮（调试用）
  - 实现_buildBottomActions方法

- [ ] 1.3.5 实现图片来源选择弹窗
  - ModalBottomSheet
  - "从相册选择"选项
  - "拍照"选项
  - 实现_showImageSourceDialog方法

- [ ] 1.3.6 实现调试信息面板
  - 显示蓝牙响应
  - 显示错误信息
  - 显示传输统计
  - 可折叠/展开

### 1.4 状态管理

- [ ] 1.4.1 扩展BluetoothProvider，添加Logo相关方法
  - uploadLogo(Uint8List data, int crc32)
  - queryCustomLogo()
  - deleteCustomLogo()
  - 添加logoUploadProgress流

- [ ] 1.4.2 实现Logo状态缓存
  - 使用shared_preferences
  - 缓存设备Logo状态
  - 多设备独立管理

---

## 2. 硬件端开发任务

### 2.1 蓝牙协议处理

- [ ] 2.1.1 实现LOGO_START命令处理
  - 解析size和crc32参数
  - 校验数据大小（必须47432字节）
  - 初始化接收状态
  - 擦除Flash扇区（12个4KB扇区）
  - 发送LOGO_READY响应

- [ ] 2.1.2 实现LOGO_DATA命令处理
  - 解析包序号和十六进制数据
  - 十六进制解码为字节数组
  - 写入临时缓冲区
  - 写入Flash存储
  - 发送LOGO_ACK响应
  - 处理重复包（幂等性）

- [ ] 2.1.3 实现LOGO_END命令处理
  - 校验接收数据大小
  - 计算Flash中数据的CRC32
  - 对比CRC32校验和
  - 写入Logo头部信息
  - 发送LOGO_OK或LOGO_FAIL响应

- [ ] 2.1.4 实现GET:LOGO查询处理
  - 读取Flash头部信息
  - 校验Magic标志
  - 响应LOGO:1或LOGO:0

- [ ] 2.1.5 实现LOGO_DELETE删除处理
  - 擦除第一个扇区
  - 使头部无效
  - 响应LOGO_DELETED

### 2.2 Flash存储管理

- [ ] 2.2.1 定义Logo存储结构
  - 存储地址：0x100000（1MB位置）
  - 头部结构：LogoHeader_t（16字节）
  - 数据大小：47432字节
  - 总大小：47448字节

- [ ] 2.2.2 实现Logo头部读写
  - Logo_WriteHeader()
  - Logo_ReadHeader()
  - Logo_ValidateHeader()

- [ ] 2.2.3 实现Logo数据读写
  - Logo_WriteData(offset, data, len)
  - Logo_ReadData(offset, buffer, len)
  - 分块读写优化

### 2.3 LCD显示集成

- [ ] 2.3.1 实现Logo显示函数
  - Logo_ShowOnLCD(x, y)
  - 优先显示自定义Logo
  - 无自定义Logo时显示默认Logo
  - 流式读取Flash避免RAM溢出

- [ ] 2.3.2 集成到开机流程
  - 在LCD_ui0()中调用Logo_ShowBoot()
  - 居中显示（43, 43位置）

### 2.4 工具函数

- [ ] 2.4.1 实现CRC32计算函数
  - CRC32_Calculate(data, len)
  - CRC32_CalculateFlash(addr, len)
  - 使用标准查找表

- [ ] 2.4.2 实现十六进制解码函数
  - HexChar2Int(char c)
  - HexDecode(hex_string, out_buffer, max_len)

---

## 3. 测试任务

### 3.1 单元测试

- [ ] 3.1.1 测试图片转RGB565功能
  - 测试不同尺寸图片
  - 测试不同格式图片（JPG/PNG/WEBP）
  - 验证输出数据大小（47432字节）

- [ ] 3.1.2 测试CRC32计算
  - 测试已知数据的CRC32
  - 对比APP和硬件计算结果
  - 验证一致性

- [ ] 3.1.3 测试十六进制编解码
  - 测试编码正确性
  - 测试解码正确性
  - 测试往返转换

### 3.2 集成测试

- [ ] 3.2.1 测试完整上传流程
  - 选择图片 → 裁剪 → 上传 → 显示
  - 验证每个步骤
  - 记录耗时

- [ ] 3.2.2 测试异常场景
  - 蓝牙断开时上传
  - 传输中断后重试
  - CRC校验失败
  - Flash写入失败

- [ ] 3.2.3 测试多设备场景
  - 不同设备独立Logo
  - 切换设备后Logo状态
  - 删除Logo后恢复默认

### 3.3 性能测试

- [ ] 3.3.1 测试上传速度
  - 记录完整上传时间
  - 优化到60秒以内
  - 测试不同手机性能

- [ ] 3.3.2 测试Flash读写性能
  - 擦除时间
  - 写入时间
  - 读取时间

---

## 4. 文档任务

- [ ] 4.1 编写用户使用文档
  - 功能说明
  - 操作步骤
  - 常见问题

- [ ] 4.2 编写开发者文档
  - 协议规范
  - API文档
  - 调试指南

- [ ] 4.3 更新PROTOCOL_SPECIFICATION.md
  - 添加Logo上传协议章节
  - 更新命令表
  - 添加示例

---

## 5. 发布任务

- [ ] 5.1 代码审查
  - APP端代码审查
  - 硬件端代码审查
  - 修复审查问题

- [ ] 5.2 版本发布
  - 更新版本号
  - 编写Release Notes
  - 打包发布

---

## 任务依赖关系

```
APP端:
1.1.1 → 1.1.2 → 1.1.3 → 1.1.4 → 1.2.1 → 1.2.2 → 1.2.3 → 1.2.4
                                    ↓
1.3.1 → 1.3.2 → 1.3.3 → 1.3.4 → 1.3.5 → 1.3.6
                                    ↓
                                  1.4.1 → 1.4.2

硬件端:
2.1.1 → 2.1.2 → 2.1.3 → 2.1.4 → 2.1.5
   ↓       ↓       ↓
2.2.1 → 2.2.2 → 2.2.3
           ↓
2.3.1 → 2.3.2
   ↓
2.4.1 → 2.4.2

测试:
(APP端完成 + 硬件端完成) → 3.1.x → 3.2.x → 3.3.x

文档:
(测试完成) → 4.1 → 4.2 → 4.3

发布:
(文档完成) → 5.1 → 5.2
```

---

## 里程碑

| 里程碑 | 完成标准 | 预计日期 |
|--------|---------|---------|
| M1: APP端图片处理完成 | 任务1.1.x全部完成 | Day 2 |
| M2: APP端蓝牙传输完成 | 任务1.2.x全部完成 | Day 4 |
| M3: APP端UI完成 | 任务1.3.x全部完成 | Day 6 |
| M4: 硬件端协议完成 | 任务2.1.x全部完成 | Day 5 |
| M5: 硬件端存储完成 | 任务2.2.x全部完成 | Day 7 |
| M6: 硬件端显示完成 | 任务2.3.x全部完成 | Day 8 |
| M7: 集成测试完成 | 任务3.x全部完成 | Day 9 |
| M8: 文档与发布 | 任务4.x和5.x完成 | Day 10 |

---

**文档版本**: v1.0  
**最后更新**: 2026-01-17
