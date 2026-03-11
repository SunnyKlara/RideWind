/**
  ******************************************************************************
  * @file    bootloader.c
  * @brief   Bootloader 核心实现
  * @note    Bootloader 是独立于 APP 的二进制文件，存储在 Sector 0-3。
  *          需要自己的 CRC32 实现（从 ota.c 复制，因为是独立工程）。
  *          W25Q128 驱动通过复用现有 w25q128.c/w25q128.h 实现。
  ******************************************************************************
  */

#include "bootloader.h"
#include "w25q128.h"
#include <string.h>

/* ═══════════════════════════════════════════════════════════════
 *          CRC32 查找表 (多项式 0xEDB88320, reflected)
 *          从 ota.c 复制 — Bootloader 是独立二进制，需要自己的副本
 * ═══════════════════════════════════════════════════════════════ */
static const uint32_t crc32_table[256] = {
    0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F,
    0xE963A535, 0x9E6495A3, 0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
    0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91, 0x1DB71064, 0x6AB020F2,
    0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
    0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9,
    0xFA0F3D63, 0x8D080DF5, 0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
    0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B, 0x35B5A8FA, 0x42B2986C,
    0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
    0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423,
    0xCFBA9599, 0xB8BDA50F, 0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
    0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D, 0x76DC4190, 0x01DB7106,
    0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
    0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D,
    0x91646C97, 0xE6635C01, 0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
    0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457, 0x65B0D9C6, 0x12B7E950,
    0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
    0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7,
    0xA4D1C46D, 0xD3D6F4FB, 0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
    0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9, 0x5005713C, 0x270241AA,
    0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
    0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81,
    0xB7BD5C3B, 0xC0BA6CAD, 0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
    0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683, 0xE3630B12, 0x94643B84,
    0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
    0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB,
    0x196C3671, 0x6E6B06E7, 0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
    0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5, 0xD6D6A3E8, 0xA1D1937E,
    0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
    0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55,
    0x316E8EEF, 0x4669BE79, 0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
    0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F, 0xC5BA3BBE, 0xB2BD0B28,
    0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
    0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F,
    0x72076785, 0x05005713, 0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
    0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21, 0x86D3D2D4, 0xF1D4E242,
    0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
    0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69,
    0x616BFFD3, 0x166CCF45, 0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
    0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB, 0xAED16A4A, 0xD9D65ADC,
    0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
    0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD706B3,
    0x54DE5729, 0x23D967BF, 0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
    0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D
};


/* ═══════════════════════════════════════════════════════════════
 *          CRC32 校验函数实现
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  计算内存数据的 CRC32
 * @param  data: 数据指针
 * @param  len:  数据长度（字节）
 * @retval CRC32 校验值
 * @note   多项式 0xEDB88320 (reflected), 初始值 0xFFFFFFFF, 最终异或 0xFFFFFFFF
 *         用于内部 Flash 数据校验（Bootloader 写入后验证）
 */
uint32_t CRC32_Calculate(uint8_t* data, uint32_t len)
{
    uint32_t crc = 0xFFFFFFFF;
    for (uint32_t i = 0; i < len; i++) {
        crc = (crc >> 8) ^ crc32_table[(crc ^ data[i]) & 0xFF];
    }
    return crc ^ 0xFFFFFFFF;
}

/**
 * @brief  从 W25Q128 分块读取并计算 CRC32
 * @param  addr: W25Q128 起始地址
 * @param  len:  数据长度（字节）
 * @retval CRC32 校验值
 * @note   以 256 字节为单位分块读取，避免大缓冲区占用
 *
 *         循环不变量:
 *         - crc 包含 [addr, currentAddr) 范围数据的部分 CRC
 *         - remaining + (currentAddr - addr) == len
 */
uint32_t CRC32_CalculateFlash(uint32_t addr, uint32_t len)
{
    uint32_t crc = 0xFFFFFFFF;
    uint8_t buffer[256];
    uint32_t remaining = len;
    uint32_t currentAddr = addr;

    while (remaining > 0) {
        uint16_t chunkSize = (remaining > 256) ? 256 : (uint16_t)remaining;
        W25Q128_BufferRead(buffer, currentAddr, chunkSize);

        for (uint16_t i = 0; i < chunkSize; i++) {
            crc = (crc >> 8) ^ crc32_table[(crc ^ buffer[i]) & 0xFF];
        }

        currentAddr += chunkSize;
        remaining -= chunkSize;
    }

    return crc ^ 0xFFFFFFFF;
}

/* ═══════════════════════════════════════════════════════════════
 *          Bootloader 核心函数
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  跳转到 APP 固件
 * @param  appAddr: APP 起始地址 (通常为 APP_ADDR = 0x08010000)
 * @note   关闭所有中断和 SysTick，设置 SCB->VTOR，设置 MSP，跳转到 Reset_Handler
 *         此函数不会返回
 */
void Bootloader_JumpToApp(uint32_t appAddr)
{
    typedef void (*pFunction)(void);
    uint32_t appStack = *(__IO uint32_t*)appAddr;
    uint32_t appEntry = *(__IO uint32_t*)(appAddr + 4);
    __disable_irq();
    for (uint8_t i = 0; i < 8; i++) {
        NVIC->ICER[i] = 0xFFFFFFFF;
        NVIC->ICPR[i] = 0xFFFFFFFF;
    }
    SysTick->CTRL = 0;
    SysTick->LOAD = 0;
    SysTick->VAL  = 0;
    SCB->VTOR = appAddr;
    __set_MSP(appStack);
    __enable_irq();
    pFunction jumpToApp = (pFunction)appEntry;
    jumpToApp();
}

/**
 * @brief  检查 APP 区是否有效（栈指针检查）
 * @param  appAddr: APP 起始地址
 * @retval true  - APP 区栈指针在 RAM 范围内 (0x20000000-0x20030000)
 * @retval false - APP 区栈指针无效
 */
bool Bootloader_IsAppValid(uint32_t appAddr)
{
    uint32_t stackPtr = *(__IO uint32_t*)appAddr;
    return (stackPtr >= 0x20000000 && stackPtr <= 0x20030000);
}

/**
 * @brief  检查是否需要升级
 * @retval true  - W25Q128 元数据中升级标志有效
 * @retval false - 无有效升级标志
 * @note   读取 W25Q128 OTA 元数据，校验 magic、version 和 upgradeFlag
 */
bool Bootloader_CheckUpgradeFlag(void)
{
    OtaMeta_t meta;
    W25Q128_BufferRead((uint8_t*)&meta, OTA_META_ADDR, sizeof(OtaMeta_t));
    if (meta.magic != OTA_META_MAGIC) return false;
    if (meta.version != OTA_META_VERSION) return false;
    if (meta.upgradeFlag != 0x01) return false;
    return true;
}

/**
 * @brief  执行固件搬运：W25Q128 暂存区 → 内部 Flash APP 区
 * @retval true  - 搬运成功，CRC32 校验通过，升级标志已清除
 * @retval false - 搬运失败（元数据无效、CRC 校验失败、Flash 擦除/写入失败等）
 *
 * @note   流程: 读取元数据 → CRC32 校验暂存区 → 擦除 Sector 4-11
 *         → 256 字节分块写入 → 写入后 CRC32 校验 → 清除升级标志
 *
 *         循环不变量:
 *         - srcAddr - OTA_STAGING_ADDR == dstAddr - APP_ADDR
 *         - remaining + (dstAddr - APP_ADDR) == meta.firmwareSize
 */
bool Bootloader_PerformUpgrade(void)
{
    OtaMeta_t meta;
    uint8_t buffer[256];

    // 1. Read and validate metadata
    W25Q128_BufferRead((uint8_t*)&meta, OTA_META_ADDR, sizeof(meta));
    if (meta.magic != OTA_META_MAGIC || meta.upgradeFlag != 0x01) {
        return false;
    }
    if (meta.firmwareSize == 0 || meta.firmwareSize > APP_MAX_SIZE) {
        return false;
    }

    // 2. Verify staging area CRC32
    uint32_t crc = CRC32_CalculateFlash(OTA_STAGING_ADDR, meta.firmwareSize);
    if (crc != meta.firmwareCRC) {
        Bootloader_ClearUpgradeFlag();
        return false;
    }

    // 3. Unlock internal Flash
    HAL_FLASH_Unlock();

    // 4. Erase APP area (Sector 4-11) — with sector range guard
    FLASH_EraseInitTypeDef eraseInit;
    uint32_t sectorError;
    eraseInit.TypeErase = FLASH_TYPEERASE_SECTORS;
    eraseInit.Sector = APP_SECTOR_FIRST;
    eraseInit.NbSectors = APP_SECTOR_COUNT;
    eraseInit.VoltageRange = FLASH_VOLTAGE_RANGE_3;

    /* Safety: reject if erase config somehow targets outside Sector 4-11 */
    if (eraseInit.Sector < APP_SECTOR_FIRST ||
        (eraseInit.Sector + eraseInit.NbSectors - 1) > APP_SECTOR_LAST) {
        HAL_FLASH_Lock();
        return false;
    }

    if (HAL_FLASHEx_Erase(&eraseInit, &sectorError) != HAL_OK) {
        HAL_FLASH_Lock();
        return false;
    }

    // 5. Copy firmware from W25Q128 to internal Flash
    uint32_t remaining = meta.firmwareSize;
    uint32_t srcAddr = OTA_STAGING_ADDR;
    uint32_t dstAddr = APP_ADDR;

    /* Safety: verify initial destination is within APP area */
    if (!Bootloader_IsAddrSafe(dstAddr)) {
        HAL_FLASH_Lock();
        return false;
    }

    while (remaining > 0) {
        uint32_t chunkSize = (remaining > 256) ? 256 : remaining;
        W25Q128_BufferRead(buffer, srcAddr, chunkSize);

        for (uint32_t i = 0; i < chunkSize; i += 4) {
            uint32_t writeAddr = dstAddr + i;
            /* Guard: never write outside APP area [APP_ADDR, APP_END_ADDR) */
            if (!Bootloader_IsAddrSafe(writeAddr)) {
                HAL_FLASH_Lock();
                return false;
            }
            uint32_t word = *(uint32_t*)&buffer[i];
            if (HAL_FLASH_Program(FLASH_TYPEPROGRAM_WORD, writeAddr, word) != HAL_OK) {
                HAL_FLASH_Lock();
                return false;
            }
        }

        srcAddr += chunkSize;
        dstAddr += chunkSize;
        remaining -= chunkSize;
    }

    HAL_FLASH_Lock();

    // 6. Verify written data CRC32
    uint32_t verifyCrc = CRC32_Calculate((uint8_t*)APP_ADDR, meta.firmwareSize);
    if (verifyCrc != meta.firmwareCRC) {
        return false;
    }

    // 7. Clear upgrade flag
    Bootloader_ClearUpgradeFlag();

    return true;
}

/**
 * @brief  清除升级标志（擦除 W25Q128 元数据区扇区）
 * @note   擦除后 Flash 内容全为 0xFF，后续读取时魔数校验将失败
 */
void Bootloader_ClearUpgradeFlag(void)
{
    W25Q128_EraseSector(OTA_META_ADDR);
}
