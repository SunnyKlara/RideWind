# RideWind Bootloader

STM32F405 Bootloader for OTA firmware upgrade.

## Flash Layout

| Region | Address | Size | Description |
|--------|---------|------|-------------|
| Bootloader | 0x08000000 - 0x0800FFFF | 64KB (Sector 0-3) | This project |
| APP | 0x08010000 - 0x080FFFFF | 960KB (Sector 4-11) | Application firmware |

## Keil Project Configuration

- **Device**: STM32F405RGTx
- **Flash Start**: 0x08000000
- **Flash Size**: 0x10000 (64KB)
- **RAM Start**: 0x20000000
- **RAM Size**: 0x20000 (128KB)

## Dependencies

- STM32F4 HAL Driver
- W25Q128 SPI Flash driver (`w25q128.c` / `w25q128.h` — copied from APP project)
- USART2 driver (`usart.c` / `usart.h` — copied from APP project for BLE communication)

## Boot Flow

1. Power on → Bootloader starts at 0x08000000
2. Initialize minimal hardware (GPIO, SPI2, USART2)
3. Read OTA metadata from W25Q128 (0x300000)
4. If upgrade flag set → perform firmware copy from W25Q128 staging area to APP area
5. If APP valid (stack pointer check) → jump to APP at 0x08010000
6. If APP invalid → enter wait mode, listen for OTA commands via Bluetooth

## Note

The Keil project (.uvprojx) must be created manually by the user. Add the following source files:
- `Core/Src/bootloader.c`
- W25Q128 driver files (copy from APP project)
- USART driver files (copy from APP project)
- STM32F4 HAL library files
