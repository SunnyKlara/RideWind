# 实现计划: 图片预处理优化

## 概述

本计划采用增量实现方式，优先确保核心功能正确性和上传可靠性，然后逐步添加优化功能。遵循"最小可行性优先"原则。

## 当前状态分析

已有实现:
- `ImagePreprocessingService` 已存在，包含基本的 `resizeImage` 和 `convertToRGB565` 方法
- `SimpleLogoUploader` 已实现完整的上传逻辑
- `ImageCompressionService` 已实现 CRC32 计算
- E2E测试界面已存在，但使用154x154尺寸

待实现:
- `EnhancedImagePreprocessor` 类（中心裁剪、高质量缩放、圆形裁剪）
- `UploadValidator` 类
- 属性测试
- E2E界面更新为240x240

## 任务

- [x] 1. 创建增强图片预处理服务
  - [x] 1.1 创建 `enhanced_image_preprocessor.dart` 文件
    - 定义 `ProcessedImageResult` 数据类
    - 定义 `EnhancedImagePreprocessor` 类框架
    - 实现 `processImage` 主方法签名
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  
  - [x] 1.2 实现中心裁剪功能
    - 实现 `cropToSquare` 方法
    - 处理非正方形图片的中心裁剪
    - _Requirements: 1.2_
  
  - [x] 1.3 实现高质量缩放功能
    - 实现 `highQualityResize` 方法
    - 使用 Lanczos/Cubic 插值算法
    - 支持放大和缩小场景
    - _Requirements: 1.1, 1.3, 1.4_
  
  - [x] 1.4 编写属性测试：图片尺寸不变性
    - **Property 1: 图片尺寸不变性**
    - **Validates: Requirements 1.1, 1.3, 1.4**

- [x] 2. 实现圆形裁剪功能
  - [x] 2.1 实现 `cropToCircle` 方法
    - 将圆形外部区域设置为黑色
    - 保持圆形内部像素不变
    - _Requirements: 2.1, 2.2_
  
  - [x] 2.2 编写属性测试：圆形裁剪外部背景
    - **Property 3: 圆形裁剪外部背景**
    - **Validates: Requirements 2.1, 2.2**

- [x] 3. 检查点 - 确保图片处理功能正常
  - 运行所有测试，确保通过
  - 如有问题请询问用户

- [x] 4. 实现RGB565转换和验证
  - [x] 4.1 优化 `convertToRGB565` 方法
    - 确保使用大端序存储
    - 确保输出数据大小为115200字节
    - _Requirements: 4.1, 4.2, 4.4_
  
  - [x] 4.2 编写属性测试：RGB565数据大小不变性
    - **Property 4: RGB565数据大小不变性**
    - **Validates: Requirements 4.4, 5.1**
  
  - [x] 4.3 编写属性测试：RGB565转换往返一致性
    - **Property 5: RGB565转换往返一致性**
    - **Validates: Requirements 4.1, 4.2**

- [x] 5. 实现上传验证器
  - [x] 5.1 创建 `upload_validator.dart` 文件
    - 实现 `UploadValidator` 类
    - 实现 `validate` 方法
    - 实现 `validateDataSize` 方法
    - _Requirements: 5.1, 5.3_
  
  - [x] 5.2 实现CRC32计算
    - 复用现有 `ImageCompressionService` 中的 CRC32 实现
    - 确保与硬件端一致
    - _Requirements: 5.2_
  
  - [x] 5.3 编写属性测试：数据验证完整性
    - **Property 7: 数据验证完整性**
    - **Validates: Requirements 5.1, 5.3**

- [x] 6. 检查点 - 确保数据处理和验证功能正常
  - 运行所有测试，确保通过
  - 如有问题请询问用户

- [x] 7. 更新E2E测试界面
  - [x] 7.1 修改 `logo_upload_e2e_test_screen.dart`
    - 将图片尺寸从154x154改为240x240
    - 集成 `EnhancedImagePreprocessor`
    - 添加圆形预览显示
    - _Requirements: 6.1, 6.2_
  
  - [x] 7.2 添加测试图片生成功能
    - 实现纯色测试图片生成（240x240）
    - 实现渐变测试图片生成
    - _Requirements: 6.1_
  
  - [x] 7.3 添加原图与处理后图片对比显示
    - 显示原图缩略图
    - 显示处理后的圆形图片预览
    - _Requirements: 6.5_

- [x] 8. 集成和兼容性处理
  - [x] 8.1 更新 `image_preprocessing_service.dart`
    - 修改 `resizeImage` 方法目标尺寸为240
    - 保持接口兼容性
    - _Requirements: 7.1, 7.2_
  
  - [x] 8.2 更新 `simple_logo_uploader.dart` 调用
    - 确保使用新的预处理结果
    - 保持上传逻辑不变
    - _Requirements: 7.1, 7.4_
  
  - [x] 8.3 编写属性测试：蓝牙协议格式一致性
    - **Property 8: 蓝牙协议格式一致性**
    - **Validates: Requirements 7.4**

- [x] 9. 最终检查点 - 完整E2E测试
  - 运行完整的E2E测试流程
  - 使用测试图片验证上传功能
  - 确保所有测试通过
  - 如有问题请询问用户

## 注意事项

- 每个任务都引用了具体的需求以便追溯
- 检查点用于确保增量验证
- 属性测试验证通用正确性属性
- 单元测试验证特定示例和边界情况
- 所有任务都是必须执行的，包括属性测试
- 现有 `ImageCompressionService` 已包含 CRC32 实现，可直接复用
