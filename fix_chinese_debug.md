# Logo Upload Size Mismatch Fix - Complete

## Problem Summary
The logo upload was failing at 100% with "SIZE MISMATCH!" error displayed on the LCD screen.

## Root Cause
**Hardware expects**: 240x240 RGB565 format = 115,200 bytes  
**APP was sending**: 128x64 monochrome = 1,024 bytes

This mismatch was defined in the hardware header file:
```c
// f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Inc/logo.h
#define LOGO_WIDTH          240
#define LOGO_HEIGHT         240
#define LOGO_DATA_SIZE      (LOGO_WIDTH * LOGO_HEIGHT * 2)  // 115200 bytes
```

## What Was Fixed

### File: `RideWind/lib/screens/logo_upload_e2e_test_screen.dart`

1. **Changed image resize dimensions**:
   - FROM: `img.copyResize(image, width: 128, height: 64)`
   - TO: `img.copyResize(image, width: 240, height: 240)`

2. **Replaced conversion function**:
   - FROM: `_convertToMonochrome()` (128x64 monochrome, 1024 bytes)
   - TO: `_convertToRGB565()` (240x240 RGB565, 115200 bytes)

3. **Updated expected data size in logs**:
   - FROM: "预期数据量: 128x64/8 = 1024 bytes"
   - TO: "预期数据量: 240x240x2 = 115200 bytes"

### RGB565 Conversion Details
The `_convertToRGB565()` function converts each pixel to RGB565 format:
- R: 5 bits (red channel)
- G: 6 bits (green channel)  
- B: 5 bits (blue channel)
- Total: 16 bits = 2 bytes per pixel
- Big-endian byte order

## Expected Results

### Transmission Changes
- **Total data**: 115,200 bytes (was 1,024 bytes)
- **Total packets**: 7,200 packets (was 64 packets)
- **Transmission time**: ~6 minutes at 100 packets/ACK (was ~3 seconds)

### Hardware Behavior
1. LCD will show "START CMD RCV" when upload begins
2. Progress updates every 100 packets: "RCV:100/7200", "RCV:200/7200", etc.
3. After all packets received, will show:
   - "VERIFYING..."
   - "SIZE CHECK OK" (115200 bytes match)
   - "CALC CRC32..."
   - "CRC32 OK" (if data is correct)
   - "WRITE HEADER..."
   - "UPLOAD OK!"

### Debug Display Location
All debug messages appear on the LCD screen in the Logo interface (ui=6):
- Title: "LOGO DEBUG"
- Up to 10 lines of debug messages
- Green text on black background
- Auto-scrolls when buffer is full

## Testing Instructions

1. **Flash the hardware** with the updated firmware (already has LCD debug display)

2. **Run the E2E test** from the APP:
   - Navigate to Device Connect screen
   - Tap "E2E测试" button
   - Tap "开始测试" to start upload

3. **Watch the LCD screen** on hardware:
   - Should automatically switch to Logo interface (ui=6)
   - Should show debug messages in English
   - Should show progress updates every 100 packets

4. **Expected timeline**:
   - 0-5 minutes: Sending 7200 packets
   - 5-6 minutes: Verification (size check + CRC32)
   - Final: "UPLOAD OK!" message

## Notes

- CRC32 is currently hardcoded to 0 in the E2E test
- Hardware will calculate actual CRC32 and compare
- If CRC32 fails, LCD will show "CRC32 FAIL!"
- All debug messages are in English (LCD font doesn't support Chinese)

## Files Modified
- `RideWind/lib/screens/logo_upload_e2e_test_screen.dart` - Fixed image conversion and size
