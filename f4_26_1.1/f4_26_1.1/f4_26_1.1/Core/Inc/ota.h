/**
  ******************************************************************************
  * @file    ota.h
  * @brief   OTA 固件升级模块
  * @note    支持通过蓝牙接收固件数据到 W25Q128 暂存区，
  *          由 Bootloader 完成固件搬运和升级。
  *          协议: OTA_START / OTA_DATA / OTA_END + CRC32 校验 + ACK 流控
  ******************************************************************************
  */

#ifndef OTA_H
#define OTA_H

#include "main.h"
#include <stdint.h>
#include <stdbool.h>

/* ═══════════════════════════════════════════════════════════════
 *          Flash 地址与大小定义
 * ═══════════════════════════════════════════════════════════════ */

/* Bootloader 区域 */
#define BOOTLOADER_ADDR       0x08000000

/* APP 固件区域 (Sector 4-11) */
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
 *          固件版本号定义
 * ═══════════════════════════════════════════════════════════════ */

#define FW_VERSION_MAJOR      1
#define FW_VERSION_MINOR      0
#define FW_VERSION_PATCH      0

/* ═══════════════════════════════════════════════════════════════
 *          OTA 状态枚举
 * ═══════════════════════════════════════════════════════════════ */

typedef enum {
    OTA_STATE_IDLE = 0,       /* 空闲，等待 OTA 命令 */
    OTA_STATE_ERASING,        /* 正在擦除 W25Q128 暂存区 */
    OTA_STATE_RECEIVING,      /* 正在接收固件数据 */
    OTA_STATE_VERIFYING,      /* 正在校验 CRC32 */
    OTA_STATE_COMPLETE,       /* 校验通过，即将重启 */
    OTA_STATE_ERROR           /* 错误状态 */
} OtaState_t;

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
 *          OTA 核心函数
 * ═══════════════════════════════════════════════════════════════ */

/* 初始化 OTA 模块 */
void OTA_Init(void);

/* 解析 OTA 命令 (从 BLE_ParseCommand 调用) */
void OTA_ParseCommand(char* cmd);

/* 获取当前 OTA 状态 */
OtaState_t OTA_GetState(void);

/* 获取传输进度百分比 (0-100) */
uint8_t OTA_GetProgress(void);

/* 检查 OTA 接收超时，在 main 循环中调用 */
/* RECEIVING 状态下超时无活动则自动恢复 IDLE (需求 9.2) */
void OTA_CheckTimeout(void);

/* ═══════════════════════════════════════════════════════════════
 *          OTA 元数据操作函数
 * ═══════════════════════════════════════════════════════════════ */

/* 写入 OTA 元数据到 W25Q128 (先擦除扇区再写入) */
void OTA_WriteMetadata(OtaMeta_t* meta);

/* 从 W25Q128 读取 OTA 元数据并校验魔数和版本号 */
/* 返回: true=读取成功且校验通过, false=无效元数据 */
bool OTA_ReadMetadata(OtaMeta_t* meta);

/* 清除升级标志 (擦除元数据区扇区) */
void OTA_ClearUpgradeFlag(void);

/* ═══════════════════════════════════════════════════════════════
 *          CRC32 校验函数
 * ═══════════════════════════════════════════════════════════════ */

/* 计算内存数据的 CRC32 */
uint32_t CRC32_Calculate(uint8_t* data, uint32_t len);

/* 从 W25Q128 分块读取并计算 CRC32 */
uint32_t CRC32_CalculateFlash(uint32_t addr, uint32_t len);

#endif /* OTA_H */
