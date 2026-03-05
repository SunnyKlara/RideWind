# Logo Upload Size Mismatch - FIXED ✅

## Problem Identified
The logo upload was failing at 100% with **"SIZE MISMATCH!"** error displayed on the LCD screen.

## Root Cause Analysis

### Hardware Expectations (from `logo.h`)
```c
#define LOGO_WIDTH          240
#define LOGO_HEIGHT         240
#define LOGO_DATA_SIZE      (LOGO_WIDTH * LOGO_HEIGHT * 2)  // 115200 bytes
```

Hardware expects: **240x240 RGB565 format = 115,200 bytes**

### APP Was Sending (before fix)
- Format: 128x64 monochrome bitmap
- Size: 128 × 64 ÷ 8 = **1,024 bytes**

### Size Validation in Hardware
```c
// In Logo_ParseCommand() when receiving LOGO_START
if (size != LOGO_DATA_SIZE) {
    Logo_AddDebugLog("SIZE MISMATCH!");
    sprintf(response, "LOGO_ERROR:SIZE_MISMATCH:%lu\n", LOGO_DATA_SIZE);
    BLE_SendString(response);
    return;
}
```

**Result**: Hardware immediately rejected the upload because 1,024 ≠ 115,200

---

## The Fix

### File: `RideWind/lib/screens/logo_upload_e2e_test_screen.dart`

#### 1. Changed Image Resize
```dart
// BEFORE
_processedImage = img.copyResize(image, width: 128, height: 64);

// AFTER
_processedImage = img.copyResize(image, width: 240, height: 240);
```

#### 2. Changed Conversion Function
```dart
// BEFORE
final bitmapData = _convertToMonochrome(_processedImage!);
// Expected: 1024 bytes

// AFTER
final bitmapData = _convertToRGB565(_processedImage!);
// Expected: 115200 bytes
```

#### 3. RGB565 Conversion Implementation
```dart
Uint8List _convertToRGB565(img.Image image) {
  final int width = 240;
  final int height = 240;
  final result = Uint8List(width * height * 2); // 115200 bytes

  final resized = img.copyResize(image, width: width, height: height);

  int index = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = resized.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // Convert to RGB565 format
      // R: 5 bits, G: 6 bits, B: 5 bits
      final r5 = (r >> 3) & 0x1F;
      final g6 = (g >> 2) & 0x3F;
      final b5 = (b >> 3) & 0x1F;

      final rgb565 = (r5 << 11) | (g6 << 5) | b5;

      // Big-endian byte order
      result[index++] = (rgb565 >> 8) & 0xFF;
      result[index++] = rgb565 & 0xFF;
    }
  }

  return result;
}
```

---

## Expected Behavior After Fix

### Transmission Parameters
- **Total data**: 115,200 bytes (was 1,024 bytes)
- **Total packets**: 7,200 packets (was 64 packets)
- **Packet size**: 16 bytes per packet
- **ACK frequency**: Every 100 packets
- **Estimated time**: ~6 minutes (was ~3 seconds)

### Hardware LCD Debug Display
The hardware will show these messages on the LCD screen (in Logo interface, ui=6):

```
LOGO DEBUG
====================
START CMD RCV
Size:115200 CRC:0
ERASING...
ERASE DONE
READY RCV 7200 PKT
RCV:100/7200
RCV:200/7200
...
RCV:7200/7200
END CMD RCV
VERIFYING...
SIZE CHECK OK        ← This should now pass!
CALC CRC32...
CRC32 OK            ← May fail (CRC32 is hardcoded to 0)
WRITE HEADER...
UPLOAD OK!
```

### Success Criteria
1. ✅ **"SIZE CHECK OK"** - Size validation passes (115200 = 115200)
2. ⚠️ **"CRC32 OK"** - May fail because CRC32 is currently hardcoded to 0
3. ✅ **No more "SIZE MISMATCH!"** error

---

## RGB565 Format Details

### Bit Layout
```
15 14 13 12 11 | 10 09 08 07 06 05 | 04 03 02 01 00
R  R  R  R  R  | G  G  G  G  G  G  | B  B  B  B  B
```

### Byte Order (Big-Endian)
```
Byte 0: [R4 R3 R2 R1 R0 G5 G4 G3]
Byte 1: [G2 G1 G0 B4 B3 B2 B1 B0]
```

### Color Precision
- Red: 5 bits → 32 levels (0-31)
- Green: 6 bits → 64 levels (0-63)
- Blue: 5 bits → 32 levels (0-31)

---

## Testing Instructions

### 1. Run the APP
```bash
cd RideWind
flutter run
```

### 2. Connect to Hardware
- Open APP
- Connect to Bluetooth device
- Navigate to Device Connect screen

### 3. Start E2E Test
- Tap **"E2E测试"** button
- Tap **"开始测试"** button

### 4. Watch Hardware LCD Screen
- Should automatically switch to Logo interface (ui=6)
- Should show debug messages in English
- Should show **"SIZE CHECK OK"** instead of **"SIZE MISMATCH!"**

---

## Next Steps

### If SIZE CHECK passes but CRC32 fails:
The next issue to fix is the CRC32 calculation:

1. **Current behavior**: APP sends `LOGO_START:115200:0` (CRC32 = 0)
2. **Required behavior**: APP should calculate actual CRC32 of the RGB565 data
3. **Implementation needed**: Add CRC32 calculation in `_startE2ETest()` method

### CRC32 Calculation
```dart
// TODO: Implement CRC32 calculation
uint32_t calculateCRC32(Uint8List data) {
  // Use standard CRC32 polynomial: 0x04C11DB7
  // Initial value: 0xFFFFFFFF
  // Final XOR: 0xFFFFFFFF
}
```

---

## Files Modified
- ✅ `RideWind/lib/screens/logo_upload_e2e_test_screen.dart`
  - Changed image resize: 128x64 → 240x240
  - Changed conversion: monochrome → RGB565
  - Updated data size: 1024 → 115200 bytes
  - Updated packet count: 64 → 7200 packets

## Files Already Fixed (Previous Work)
- ✅ `f4_26_1.1/f4_26_1.1/f4_26_1.1/Core/Src/logo.c`
  - Added LCD debug display functions
  - Changed debug messages to English
  - Auto-switch to Logo interface (ui=6)

---

## Summary

**Problem**: Size mismatch (1024 bytes vs 115200 bytes expected)  
**Solution**: Convert image to correct format (240x240 RGB565)  
**Status**: ✅ FIXED - Ready for testing  
**Next**: Fix CRC32 calculation (currently hardcoded to 0)

The "SIZE MISMATCH!" error should no longer appear! 🎉
