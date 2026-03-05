# 需求文档

## 简介

本功能用于优化RideWind Flutter应用中的图片预处理流程，确保手机高像素图片在上传到STM32单片机LCD屏幕后能够清晰显示。核心目标是将图片尺寸调整为240x240圆形，并通过高质量缩放算法减少图片模糊问题，同时保证图片上传的可靠性。

## 术语表

- **Image_Preprocessor**: 图片预处理服务，负责图片加载、缩放、裁剪和格式转换
- **RGB565_Converter**: RGB565格式转换器，将图片转换为LCD屏幕所需的RGB565格式
- **Circular_Cropper**: 圆形裁剪器，将图片裁剪为圆形以适配圆形LCD显示区域
- **Upload_Validator**: 上传验证器，确保图片数据完整性和上传成功
- **LCD_Screen**: STM32单片机上的240x240圆形LCD显示屏
- **CRC32**: 循环冗余校验算法，用于验证数据完整性

## 需求

### 需求 1: 图片尺寸调整

**用户故事:** 作为用户，我希望上传的图片能够自动调整为240x240像素，以便完全覆盖圆形LCD显示区域。

#### 验收标准

1. WHEN 用户选择任意尺寸的图片 THEN Image_Preprocessor SHALL 将图片缩放至240x240像素
2. WHEN 图片宽高比不为1:1 THEN Image_Preprocessor SHALL 先进行中心裁剪再缩放，保持图片主体内容
3. WHEN 图片尺寸小于240x240 THEN Image_Preprocessor SHALL 使用高质量插值算法放大图片
4. WHEN 图片尺寸大于240x240 THEN Image_Preprocessor SHALL 使用Lanczos或Cubic插值算法缩小图片以减少模糊

### 需求 2: 圆形裁剪处理

**用户故事:** 作为用户，我希望图片能够被裁剪为圆形，以便与圆形LCD屏幕完美匹配。

#### 验收标准

1. WHEN 图片缩放完成后 THEN Circular_Cropper SHALL 将图片裁剪为直径240像素的圆形
2. WHEN 进行圆形裁剪时 THEN Circular_Cropper SHALL 将圆形外部区域设置为透明或黑色背景
3. THE Circular_Cropper SHALL 保持圆形边缘平滑，无明显锯齿

### 需求 3: 高质量图片缩放

**用户故事:** 作为用户，我希望高像素手机图片在缩放后仍然清晰，不会变得模糊。

#### 验收标准

1. THE Image_Preprocessor SHALL 使用Lanczos3或更高质量的插值算法进行图片缩放
2. WHEN 图片包含文字或细节时 THEN Image_Preprocessor SHALL 应用锐化处理以增强清晰度
3. WHEN 图片缩放比例超过4倍时 THEN Image_Preprocessor SHALL 分步缩放以保持质量
4. THE Image_Preprocessor SHALL 在缩放前对图片进行适度的对比度增强

### 需求 4: RGB565格式转换

**用户故事:** 作为开发者，我希望图片能够正确转换为RGB565格式，以便LCD屏幕能够正确显示。

#### 验收标准

1. WHEN 图片处理完成后 THEN RGB565_Converter SHALL 将图片转换为RGB565格式（R5G6B5）
2. THE RGB565_Converter SHALL 使用大端序（MSB First）存储RGB565数据
3. WHEN 转换RGB565时 THEN RGB565_Converter SHALL 对颜色进行抖动处理以减少色带
4. THE RGB565_Converter SHALL 生成正好115200字节的数据（240x240x2）

### 需求 5: 上传可靠性保证

**用户故事:** 作为用户，我希望图片上传过程稳定可靠，不会因为预处理改动而导致上传失败。

#### 验收标准

1. THE Upload_Validator SHALL 在上传前验证RGB565数据大小为115200字节
2. THE Upload_Validator SHALL 计算并验证CRC32校验和
3. IF 预处理过程发生错误 THEN Upload_Validator SHALL 返回明确的错误信息并中止上传
4. WHEN 上传完成后 THEN Upload_Validator SHALL 等待硬件返回LOGO_OK确认
5. IF 硬件返回LOGO_FAIL或LOGO_ERROR THEN Upload_Validator SHALL 报告具体错误原因

### 需求 6: 最小可行性测试

**用户故事:** 作为开发者，我希望先实现最小可行性测试，验证核心功能后再进行大规模优化。

#### 验收标准

1. THE E2E_Test_Screen SHALL 提供测试图片（纯色或简单图案）用于验证基本流程
2. THE E2E_Test_Screen SHALL 显示预处理后的图片预览（240x240圆形）
3. THE E2E_Test_Screen SHALL 显示详细的处理日志和上传进度
4. WHEN 测试完成后 THEN E2E_Test_Screen SHALL 显示成功或失败状态及详细信息
5. THE E2E_Test_Screen SHALL 支持对比显示原图和处理后的图片

### 需求 7: 向后兼容性

**用户故事:** 作为开发者，我希望新的预处理逻辑不会破坏现有的上传功能。

#### 验收标准

1. THE Image_Preprocessor SHALL 保持与现有SimpleLogoUploader的接口兼容
2. THE Image_Preprocessor SHALL 保持与现有LogoTransmissionManager的接口兼容
3. IF 新预处理逻辑失败 THEN 系统 SHALL 能够回退到原有的154x154处理逻辑
4. THE 系统 SHALL 保持现有的蓝牙通信协议不变
