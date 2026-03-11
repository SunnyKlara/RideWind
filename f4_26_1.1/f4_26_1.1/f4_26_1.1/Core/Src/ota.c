/**
  ******************************************************************************
  * @file    ota.c
  * @brief   OTA 固件升级模块实现
  * @note    支持通过蓝牙接收固件数据到 W25Q128 暂存区，
  *          由 Bootloader 完成固件搬运和升级。
  *          协议: OTA_START / OTA_DATA / OTA_END + CRC32 校验 + ACK 流控
  ******************************************************************************
  */

#include "ota.h"
#include "w25q128.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* ═══════════════════════════════════════════════════════════════
 *          外部函数引用
 * ═══════════════════════════════════════════════════════════════ */
extern void BLE_SendString(const char* str);

/* ═══════════════════════════════════════════════════════════════
 *          OTA 批量写入参数（与 Logo 上传一致）
 * ═══════════════════════════════════════════════════════════════ */
#define OTA_FLASH_WRITE_BATCH_SIZE  16   /* 每 16 包批量写入一次 */
#define OTA_TIMEOUT_MS              30000 /* OTA 接收超时 30 秒 */

/* ═══════════════════════════════════════════════════════════════
 *          OTA 接收窗口结构体
 * ═══════════════════════════════════════════════════════════════ */
typedef struct {
    uint32_t totalPackets;                                    /* 总包数 */
    uint32_t lastAckSeq;                                      /* 最后 ACK 的序号 */
    uint8_t  flashWriteBuffer[OTA_FLASH_WRITE_BATCH_SIZE * 16]; /* 批量写入缓冲区 */
    uint32_t flashWriteCount;                                 /* 当前缓冲区包数 */
    uint32_t batchByteCount;                                  /* 当前批次累计字节数 */
} OtaReceiveWindow_t;

/* ═══════════════════════════════════════════════════════════════
 *          私有变量 - OTA 状态
 * ═══════════════════════════════════════════════════════════════ */
static OtaState_t ota_state = OTA_STATE_IDLE;
static uint32_t   ota_total_size = 0;        /* OTA_START 声明的固件大小 */
static uint32_t   ota_received_size = 0;     /* 已接收字节数 */
static uint32_t   ota_expected_crc = 0;      /* OTA_START 声明的 CRC32 */
static uint32_t   ota_current_seq = 0;       /* 当前包序号 */
static uint32_t   ota_flash_written = 0;     /* 已写入 W25Q128 的字节数 */
static uint8_t    ota_temp_buffer[256];       /* 临时缓冲区 */
static OtaReceiveWindow_t ota_window;        /* 接收窗口 */
static uint32_t ota_last_activity_tick = 0;  /* 最后活动时间戳（HAL_GetTick） */

/* ═══════════════════════════════════════════════════════════════
 *          CRC32 查找表 (多项式 0xEDB88320, reflected)
 *          与 logo.c 中使用的算法完全一致
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
 *         用于 OTA_END 校验暂存区数据、Bootloader 搬运前校验
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
 *          OTA 元数据读写函数
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  写入 OTA 元数据到 W25Q128
 * @param  meta: 指向 OtaMeta_t 结构体的指针
 * @note   先擦除元数据区扇区（0x300000），再写入完整结构体
 *         需求: 7.2
 */
void OTA_WriteMetadata(OtaMeta_t* meta)
{
    W25Q128_EraseSector(OTA_META_ADDR);
    W25Q128_BufferWrite((uint8_t*)meta, OTA_META_ADDR, sizeof(OtaMeta_t));
}

/**
 * @brief  从 W25Q128 读取 OTA 元数据并校验
 * @param  meta: 指向 OtaMeta_t 结构体的指针（输出）
 * @retval true  - 读取成功且魔数和版本号校验通过
 * @retval false - 魔数不匹配或版本号不匹配（视为无有效升级标志）
 * @note   需求: 7.3 - 验证 magic == 0x4F544155 且 version == 0x01
 */
bool OTA_ReadMetadata(OtaMeta_t* meta)
{
    W25Q128_BufferRead((uint8_t*)meta, OTA_META_ADDR, sizeof(OtaMeta_t));

    if (meta->magic != OTA_META_MAGIC) {
        return false;
    }
    if (meta->version != OTA_META_VERSION) {
        return false;
    }
    return true;
}

/**
 * @brief  清除升级标志（擦除元数据区扇区）
 * @note   擦除后 Flash 内容全为 0xFF，后续读取时魔数校验将失败
 *         需求: 7.4
 */
void OTA_ClearUpgradeFlag(void)
{
    W25Q128_EraseSector(OTA_META_ADDR);
}

/* ═══════════════════════════════════════════════════════════════
 *          十六进制解码辅助函数（与 logo.c 中一致）
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  单个十六进制字符转整数
 * @param  c: 十六进制字符 ('0'-'9', 'A'-'F', 'a'-'f')
 * @retval 0-15 成功, -1 非法字符
 */
static int HexChar2Int(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

/**
 * @brief  十六进制字符串转字节数组
 * @param  hex:    十六进制字符串
 * @param  out:    输出缓冲区
 * @param  maxLen: 输出缓冲区最大长度
 * @retval 解码后的字节数，0 表示无数据
 */
static int HexDecode(const char* hex, uint8_t* out, int maxLen)
{
    int outLen = 0;

    while (outLen < maxLen) {
        char c1 = hex[outLen * 2];
        char c2 = hex[outLen * 2 + 1];

        /* 遇到结束符或非十六进制字符，停止 */
        if (c1 == '\0' || c2 == '\0' || c1 == '\n' || c1 == '\r') {
            break;
        }

        int high = HexChar2Int(c1);
        int low  = HexChar2Int(c2);

        if (high < 0 || low < 0) {
            break;
        }

        out[outLen] = (uint8_t)((high << 4) | low);
        outLen++;
    }

    return outLen;
}

/* ═══════════════════════════════════════════════════════════════
 *          批量缓冲区辅助函数
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  重置接收窗口状态
 */
static void Buffer_Init(void)
{
    memset(&ota_window, 0, sizeof(ota_window));
}

/* ═══════════════════════════════════════════════════════════════
 *          OTA 命令解析核心函数
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  解析并处理 OTA 命令
 * @param  cmd: 以 null 结尾的命令字符串（已去除末尾换行符）
 * @note   支持命令: OTA_START, OTA_DATA, OTA_END, OTA_ABORT, OTA_VERSION
 *
 *         前置条件:
 *         - cmd 是以 null 结尾的有效字符串
 *         - W25Q128 已初始化
 *         - USART2（蓝牙）已初始化且可发送数据
 *
 *         后置条件:
 *         - OTA_START: 暂存区已擦除，状态切换为 RECEIVING，发送 OTA_READY
 *         - OTA_DATA: 数据已写入暂存区（批量），发送 OTA_ACK
 *         - OTA_END 成功: 元数据已写入，系统将重启
 *         - OTA_END 失败: 发送 OTA_FAIL，状态切换为 ERROR
 *
 *         循环不变量 (OTA_DATA):
 *         - ota_flash_written + ota_window.batchByteCount == ota_received_size
 *
 *         需求: 2.1, 2.2, 2.3, 3.3, 3.4, 3.5, 3.6, 4.1-4.5, 9.3, 9.6, 9.7, 13.1
 */
void OTA_ParseCommand(char* cmd)
{
    char response[64];

    /* ─── OTA_START:size:crc32 ─── 开始 OTA 升级 ─── */
    if (strncmp(cmd, "OTA_START:", 10) == 0) {
        uint32_t size = 0, crc = 0;
        char* p = cmd + 10;
        size = strtoul(p, &p, 10);
        if (*p == ':') crc = strtoul(p + 1, NULL, 10);

        /* 校验固件大小 */
        if (size == 0 || size > APP_MAX_SIZE) {
            sprintf(response, "OTA_FAIL:SIZE_INVALID:%lu\n", (unsigned long)APP_MAX_SIZE);
            BLE_SendString(response);
            return;
        }

        ota_state = OTA_STATE_ERASING;
        BLE_SendString("OTA_ERASING\n");

        /* 擦除 W25Q128 暂存区（1MB = 16 个 64KB Block） */
        for (int i = 0; i < 16; i++) {
            W25Q128_EraseBlock(OTA_STAGING_ADDR + i * 65536);
        }

        /* 初始化接收状态 */
        ota_total_size = size;
        ota_received_size = 0;
        ota_expected_crc = crc;
        ota_current_seq = 0;
        ota_flash_written = 0;
        ota_state = OTA_STATE_RECEIVING;
        ota_last_activity_tick = HAL_GetTick();

        Buffer_Init();
        ota_window.totalPackets = (size + 15) / 16;
        ota_window.lastAckSeq = 0;
        ota_window.flashWriteCount = 0;
        ota_window.batchByteCount = 0;

        BLE_SendString("OTA_READY\n");
    }

    /* ─── OTA_DATA:seq:hexdata ─── 固件数据包 ─── */
    else if (strncmp(cmd, "OTA_DATA:", 9) == 0) {
        if (ota_state != OTA_STATE_RECEIVING) {
            BLE_SendString("OTA_FAIL:NOT_READY\n");
            return;
        }

        char* p = cmd + 9;
        uint32_t seq = strtoul(p, &p, 10);
        if (*p != ':') {
            BLE_SendString("OTA_FAIL:FORMAT\n");
            return;
        }
        char* hexData = p + 1;

        int decodedLen = HexDecode(hexData, ota_temp_buffer, sizeof(ota_temp_buffer));
        if (decodedLen <= 0) {
            sprintf(response, "OTA_NAK:%lu\n", (unsigned long)seq);
            BLE_SendString(response);
            return;
        }

        /* 序号校验 */
        uint32_t expectedSeq = (ota_current_seq == 0 && ota_received_size == 0) ? 0 : ota_current_seq + 1;
        if (seq != expectedSeq) {
            if (seq < expectedSeq) return;  /* 重复包，忽略 */
            sprintf(response, "OTA_RESEND:%lu\n", (unsigned long)expectedSeq);
            BLE_SendString(response);
            return;
        }

        /* 更新活动时间戳 */
        ota_last_activity_tick = HAL_GetTick();

        /* 写入批量缓冲区 */
        if (ota_window.flashWriteCount == 0) {
            ota_window.batchByteCount = 0;
        }
        memcpy(&ota_window.flashWriteBuffer[ota_window.batchByteCount], ota_temp_buffer, decodedLen);
        ota_window.batchByteCount += decodedLen;
        ota_window.flashWriteCount++;
        ota_received_size += decodedLen;
        ota_current_seq = seq;

        /* 每 16 包或最后一包时批量写入 Flash */
        bool isLastPacket = (seq == ota_window.totalPackets - 1);
        bool batchComplete = (ota_window.flashWriteCount >= 16);

        if (batchComplete || isLastPacket) {
            uint32_t writeAddr = OTA_STAGING_ADDR + ota_flash_written;
            W25Q128_BufferWrite(ota_window.flashWriteBuffer, writeAddr, ota_window.batchByteCount);
            ota_flash_written += ota_window.batchByteCount;

            ota_window.flashWriteCount = 0;
            ota_window.batchByteCount = 0;

            sprintf(response, "OTA_ACK:%lu\n", (unsigned long)seq);
            BLE_SendString(response);
        }
    }

    /* ─── OTA_END ─── 传输结束，校验 ─── */
    else if (strcmp(cmd, "OTA_END") == 0) {
        if (ota_state != OTA_STATE_RECEIVING) {
            BLE_SendString("OTA_FAIL:NOT_RECEIVING\n");
            return;
        }

        ota_state = OTA_STATE_VERIFYING;

        /* 校验接收大小 */
        if (ota_received_size != ota_total_size) {
            sprintf(response, "OTA_FAIL:SIZE:%lu/%lu\n",
                    (unsigned long)ota_received_size, (unsigned long)ota_total_size);
            BLE_SendString(response);
            ota_state = OTA_STATE_ERROR;
            return;
        }

        /* 校验 CRC32 */
        uint32_t calcCRC = CRC32_CalculateFlash(OTA_STAGING_ADDR, ota_total_size);
        if (calcCRC != ota_expected_crc) {
            sprintf(response, "OTA_FAIL:CRC:%lu\n", (unsigned long)calcCRC);
            BLE_SendString(response);
            ota_state = OTA_STATE_ERROR;
            return;
        }

        /* 写入 OTA 元数据 */
        OtaMeta_t meta;
        memset(&meta, 0, sizeof(meta));
        meta.magic = OTA_META_MAGIC;
        meta.version = OTA_META_VERSION;
        meta.upgradeFlag = 0x01;
        meta.firmwareSize = ota_total_size;
        meta.firmwareCRC = ota_expected_crc;
        OTA_WriteMetadata(&meta);

        ota_state = OTA_STATE_COMPLETE;
        BLE_SendString("OTA_OK\n");

        /* 延迟 500ms 后重启，确保蓝牙响应发送完毕 */
        HAL_Delay(500);
        NVIC_SystemReset();
    }

    /* ─── OTA_ABORT ─── 中止升级 ─── */
    else if (strcmp(cmd, "OTA_ABORT") == 0) {
        ota_state = OTA_STATE_IDLE;
        BLE_SendString("OTA_ABORTED\n");
    }

    /* ─── OTA_VERSION ─── 查询固件版本 ─── */
    else if (strcmp(cmd, "OTA_VERSION") == 0) {
        sprintf(response, "OTA_VERSION:%d.%d.%d\n",
                FW_VERSION_MAJOR, FW_VERSION_MINOR, FW_VERSION_PATCH);
        BLE_SendString(response);
    }
}

/* ═══════════════════════════════════════════════════════════════
 *          OTA 模块基础函数
 * ═══════════════════════════════════════════════════════════════ */

/**
 * @brief  初始化 OTA 模块
 */
void OTA_Init(void)
{
    ota_state = OTA_STATE_IDLE;
    ota_total_size = 0;
    ota_received_size = 0;
    ota_expected_crc = 0;
    ota_current_seq = 0;
    ota_flash_written = 0;
    memset(&ota_window, 0, sizeof(ota_window));
}

/**
 * @brief  获取当前 OTA 状态
 * @retval OtaState_t 当前状态
 */
OtaState_t OTA_GetState(void)
{
    return ota_state;
}

/**
 * @brief  获取传输进度百分比
 * @retval 0-100 百分比
 */
uint8_t OTA_GetProgress(void)
{
    if (ota_total_size == 0) return 0;
    return (uint8_t)((ota_received_size * 100) / ota_total_size);
}

/**
 * @brief  检查 OTA 接收超时，在 main 循环中调用
 * @note   RECEIVING 状态下超过 OTA_TIMEOUT_MS 无数据活动则自动恢复 IDLE
 *         需求: 9.2 - 蓝牙断开后超时恢复
 */
void OTA_CheckTimeout(void)
{
    if (ota_state != OTA_STATE_RECEIVING) return;

    if ((HAL_GetTick() - ota_last_activity_tick) >= OTA_TIMEOUT_MS) {
        ota_state = OTA_STATE_IDLE;
    }
}
