/**
  ******************************************************************************
  * @file    bootloader.h
  * @brief   Bootloader 核心接口
  * @note    Bootloader 存储在 STM32 内部 Flash Sector 0-3
  *          (0x08000000-0x0800FFFF, 64KB)
  *          负责检查升级标志、执行固件搬运、跳转到 APP
  ******************************************************************************
  */

#ifndef BOOTLOADER_H
#define BOOTLOADER_H

#include "stm32f4xx_hal.h"
#include <stdint.h>
#include <stdbool.h>

/* ═══════════════════════════════════════════════════════════════
 *          Flash 地址与大小定义
 * ═══════════════════════════════════════════════════════════════ */

/* Bootloader 区域 (Sector 0-3, 64KB) */
#define BOOTLOADER_ADDR       0x08000000

/* APP 固件区域 (Sector 4-11, 960KB) */
#define APP_ADDR              0x08010000
#define APP_MAX_SIZE          (960 * 1024)   /* 960KB = 983040 bytes */

/* W25Q128 OTA 暂存区 */
#define OTA_STAGING_ADDR      0x200000       /* 固件暂存区起始地址 */
#define OTA_STAGING_SIZE      (1024 * 1024)  /* 1MB */

/* W25Q128 OTA 元数据区 */
#define OTA_META_ADDR         0x300000       /* 元数据区起始地址 */

/* OTA 元数据常量 */
#define OTA_META_MAGIC        0x4F544155     /* "OTAU" */
#define OTA_META_VERSION      0x01

/* ═══════════════════════════════════════════════════════════════
 *          分区保护 — 防止误写 Bootloader 区域 (Sector 0-3)
 * ═══════════════════════════════════════════════════════════════ */

/* Bootloader 保护区域上界 (Sector 0-3 结束地址, 不含) */
#define BOOTLOADER_END_ADDR   0x08010000

/* APP 区域上界 (Sector 11 结束地址, 不含) */
#define APP_END_ADDR          0x08100000

/* 允许写入的最小 Flash Sector 编号 */
#define APP_SECTOR_FIRST      FLASH_SECTOR_4
#define APP_SECTOR_LAST       FLASH_SECTOR_11
#define APP_SECTOR_COUNT      8

/**
 * @brief  检查目标地址是否在 APP 区安全范围内
 * @param  addr: 待写入的内部 Flash 地址
 * @retval true  - 地址在 APP 区 [APP_ADDR, APP_END_ADDR) 内
 * @retval false - 地址越界，可能覆盖 Bootloader
 */
static inline bool Bootloader_IsAddrSafe(uint32_t addr)
{
    return (addr >= APP_ADDR && addr < APP_END_ADDR);
}

/* ═══════════════════════════════════════════════════════════════
 *          OTA 元数据结构 (16 字节，存储在 W25Q128 @ 0x300000)
 * ═══════════════════════════════════════════════════════════════ */

typedef struct {
    uint32_t magic;           /* 魔数 OTA_META_MAGIC (0x4F544155) */
    uint8_t  version;         /* 元数据格式版本 = 0x01 */
    uint8_t  upgradeFlag;     /* 升级标志: 0x00=无升级, 0x01=待升级 */
    uint8_t  reserved[2];     /* 保留对齐 */
    uint32_t firmwareSize;    /* 固件字节数 (≤ 960KB) */
    uint32_t firmwareCRC;     /* 固件 CRC32 校验值 */
} OtaMeta_t;                  /* sizeof = 16 bytes */

/* ═══════════════════════════════════════════════════════════════
 *          Bootloader 核心函数
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  跳转到 APP 固件
 * @param  appAddr: APP 起始地址 (通常为 APP_ADDR = 0x08010000)
 * @note   关闭所有中断，设置 VTOR 和 MSP，跳转到 Reset_Handler
 *         此函数不会返回
 */
void Bootloader_JumpToApp(uint32_t appAddr);

/**
 * @brief  检查 APP 区是否有效（栈指针检查）
 * @param  appAddr: APP 起始地址
 * @retval true  - APP 区栈指针在 RAM 范围内 (0x20000000-0x20030000)
 * @retval false - APP 区栈指针无效
 */
bool Bootloader_IsAppValid(uint32_t appAddr);

/**
 * @brief  检查是否需要升级
 * @retval true  - W25Q128 元数据中升级标志有效 (magic + upgradeFlag == 0x01)
 * @retval false - 无有效升级标志
 */
bool Bootloader_CheckUpgradeFlag(void);

/**
 * @brief  执行固件搬运：W25Q128 暂存区 → 内部 Flash APP 区
 * @retval true  - 搬运成功，CRC32 校验通过
 * @retval false - 搬运失败（CRC 校验失败、Flash 擦除/写入失败等）
 *
 * @note   流程: 读取元数据 → CRC32 校验暂存区 → 擦除 Sector 4-11
 *         → 256 字节分块写入 → 写入后 CRC32 校验 → 清除升级标志
 *
 *         循环不变量:
 *         - srcAddr - OTA_STAGING_ADDR == dstAddr - APP_ADDR
 *         - remaining + (dstAddr - APP_ADDR) == meta.firmwareSize
 */
bool Bootloader_PerformUpgrade(void);

/**
 * @brief  清除升级标志（擦除 W25Q128 元数据区扇区）
 * @note   擦除后 Flash 内容全为 0xFF，后续读取时魔数校验将失败
 */
void Bootloader_ClearUpgradeFlag(void);

/* ═══════════════════════════════════════════════════════════════
 *          CRC32 校验函数
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  计算内存数据的 CRC32
 * @param  data: 数据指针
 * @param  len:  数据长度（字节）
 * @retval CRC32 校验值
 * @note   多项式 0xEDB88320 (reflected), 初始值 0xFFFFFFFF, 最终异或 0xFFFFFFFF
 */
uint32_t CRC32_Calculate(uint8_t* data, uint32_t len);

/**
 * @brief  从 W25Q128 分块读取并计算 CRC32
 * @param  addr: W25Q128 起始地址
 * @param  len:  数据长度（字节）
 * @retval CRC32 校验值
 * @note   以 256 字节为单位分块读取，避免大缓冲区占用
 */
uint32_t CRC32_CalculateFlash(uint32_t addr, uint32_t len);

#endif /* BOOTLOADER_H */
