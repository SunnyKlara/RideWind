/**
  ******************************************************************************
  * @file    main.c
  * @brief   Bootloader 主程序
  * @note    Bootloader 存储在 STM32F405 内部 Flash Sector 0-3
  *          (0x08000000-0x0800FFFF, 64KB)
  *
  *          主流程:
  *          1. 最小硬件初始化 (GPIO, SPI1, USART2)
  *          2. 初始化 W25Q128
  *          3. 检查升级标志 → 执行搬运
  *          4. 检查 APP 有效性 → 跳转到 APP
  *          5. 否则进入等待模式，通过蓝牙接收 OTA 固件
  *
  *          LED 指示:
  *          - 升级中: PC13 快闪 (100ms)
  *          - 等待模式: PC13 慢闪 (500ms)
  *
  *          需求: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 9.4, 9.5, 10.2
  ******************************************************************************
  */

#include "bootloader.h"
#include "w25q128.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* ═══════════════════════════════════════════════════════════════
 *          硬件句柄
 * ═══════════════════════════════════════════════════════════════ */
SPI_HandleTypeDef hspi1;
UART_HandleTypeDef huart2;

/* ═══════════════════════════════════════════════════════════════
 *          LED 指示引脚定义 (PC13)
 * ═══════════════════════════════════════════════════════════════ */
#define LED_PORT        GPIOC
#define LED_PIN         GPIO_PIN_13

/* ═══════════════════════════════════════════════════════════════
 *          W25Q128 片选引脚 (PA4)
 * ═══════════════════════════════════════════════════════════════ */
#define FLASH_CS_PORT   GPIOA
#define FLASH_CS_PIN    GPIO_PIN_4

/* ═══════════════════════════════════════════════════════════════
 *          等待模式 OTA 接收相关定义
 * ═══════════════════════════════════════════════════════════════ */
#define BL_RX_BUFFER_SIZE   2048
#define BL_OTA_BATCH_SIZE   16    /* 每 16 包批量写入 */

/* ═══════════════════════════════════════════════════════════════
 *          等待模式 OTA 状态变量
 * ═══════════════════════════════════════════════════════════════ */
typedef enum {
    BL_OTA_IDLE = 0,
    BL_OTA_ERASING,
    BL_OTA_RECEIVING,
    BL_OTA_VERIFYING,
    BL_OTA_COMPLETE,
    BL_OTA_ERROR
} BlOtaState_t;

typedef struct {
    uint32_t totalPackets;
    uint32_t flashWriteCount;
    uint32_t batchByteCount;
    uint8_t  flashWriteBuffer[BL_OTA_BATCH_SIZE * 16];
} BlOtaWindow_t;

static BlOtaState_t bl_ota_state = BL_OTA_IDLE;
static uint32_t bl_ota_total_size = 0;
static uint32_t bl_ota_received_size = 0;
static uint32_t bl_ota_expected_crc = 0;
static uint32_t bl_ota_current_seq = 0;
static uint32_t bl_ota_flash_written = 0;
static uint8_t  bl_ota_temp_buffer[256];
static BlOtaWindow_t bl_ota_window;

/* UART 接收缓冲区 */
static uint8_t bl_rx_data = 0;
static uint8_t bl_rx_buff[BL_RX_BUFFER_SIZE];
static uint16_t bl_rx_pointer = 0;
static uint32_t bl_rx_tick = 0;

/* LED 闪烁控制 */
static uint32_t led_last_toggle = 0;

/* ═══════════════════════════════════════════════════════════════
 *          函数前向声明
 * ═══════════════════════════════════════════════════════════════ */
static void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_SPI1_Init(void);
static void MX_USART2_UART_Init(void);
static void BL_SendString(const char* str);
static void BL_OTA_ParseCommand(char* cmd);
static void BL_RX_Proc(void);
static void LED_Toggle(void);
static int  BL_HexDecode(const char* hex, uint8_t* out, int maxLen);
void Error_Handler(void);

/* ═══════════════════════════════════════════════════════════════
 *          main() - Bootloader 主入口
 *
 *          需求 5.1: 上电从 0x08000000 启动，初始化 GPIO/SPI1/USART2
 *          需求 5.2: 读取 W25Q128 元数据，检查升级标志
 *          需求 5.3: 升级标志有效时执行固件搬运
 *          需求 5.4: 无升级标志时检查 APP 栈指针
 *          需求 5.5: APP 有效时设置 VTOR 并跳转
 *          需求 5.6: APP 无效时进入等待模式
 *          需求 9.4: 断电后升级标志仍在，重新搬运
 *          需求 9.5: 搬运中断电导致 APP 无效，进入等待模式
 *          需求 10.2: APP 无效时通过蓝牙接收新固件
 * ═══════════════════════════════════════════════════════════════ */
int main(void)
{
    /* 1. HAL 初始化 */
    HAL_Init();

    /* 2. 系统时钟配置 (168MHz HSE + PLL) */
    SystemClock_Config();

    /* 3. 最小外设初始化 */
    MX_GPIO_Init();     /* LED (PC13) + Flash CS (PA4) */
    MX_SPI1_Init();     /* W25Q128 通信 */
    MX_USART2_UART_Init(); /* 蓝牙通信 */

    /* 4. 初始化 W25Q128 */
    W25Q128_Init();

    /* 5. 检查升级标志 */
    if (Bootloader_CheckUpgradeFlag()) {
        /* LED 快闪表示正在升级 */
        bool success = Bootloader_PerformUpgrade();
        if (!success) {
            /* 升级失败，清除标志，尝试启动旧固件 */
            Bootloader_ClearUpgradeFlag();
        }
    }

    /* 6. 检查 APP 区是否有效 */
    if (Bootloader_IsAppValid(APP_ADDR)) {
        /* 跳转到 APP (不会返回) */
        Bootloader_JumpToApp(APP_ADDR);
    }

    /* 7. APP 无效，进入等待模式 */
    /* 启动 UART 中断接收 */
    HAL_UART_Receive_IT(&huart2, &bl_rx_data, 1);

    /* 等待模式主循环: 慢闪 LED + 监听蓝牙 OTA 命令 */
    while (1) {
        /* 处理蓝牙命令 */
        BL_RX_Proc();

        /* LED 慢闪 (500ms) 表示等待模式 */
        if (HAL_GetTick() - led_last_toggle >= 500) {
            LED_Toggle();
            led_last_toggle = HAL_GetTick();
        }
    }
}


/* ═══════════════════════════════════════════════════════════════
 *          SystemClock_Config - 168MHz (HSE 8MHz + PLL)
 *          与 APP 相同的时钟配置
 * ═══════════════════════════════════════════════════════════════ */
static void SystemClock_Config(void)
{
    RCC_OscInitTypeDef RCC_OscInitStruct = {0};
    RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

    __HAL_RCC_PWR_CLK_ENABLE();
    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

    RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
    RCC_OscInitStruct.HSEState = RCC_HSE_ON;
    RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
    RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
    RCC_OscInitStruct.PLL.PLLM = 4;
    RCC_OscInitStruct.PLL.PLLN = 168;
    RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
    RCC_OscInitStruct.PLL.PLLQ = 4;
    if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK) {
        Error_Handler();
    }

    RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
                                | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
    RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
    RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
    RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;
    RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;

    if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_5) != HAL_OK) {
        Error_Handler();
    }
}

/* ═══════════════════════════════════════════════════════════════
 *          MX_GPIO_Init - 最小 GPIO 初始化
 *          - PC13: LED 状态指示 (推挽输出)
 *          - PA4:  W25Q128 片选 (推挽输出, 默认高)
 * ═══════════════════════════════════════════════════════════════ */
static void MX_GPIO_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    __HAL_RCC_GPIOC_CLK_ENABLE();
    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOB_CLK_ENABLE();
    __HAL_RCC_GPIOH_CLK_ENABLE();

    /* LED 引脚 PC13 - 默认低电平 (LED 灭) */
    HAL_GPIO_WritePin(LED_PORT, LED_PIN, GPIO_PIN_RESET);
    GPIO_InitStruct.Pin = LED_PIN;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(LED_PORT, &GPIO_InitStruct);

    /* W25Q128 片选 PA4 - 默认高电平 (未选中) */
    HAL_GPIO_WritePin(FLASH_CS_PORT, FLASH_CS_PIN, GPIO_PIN_SET);
    GPIO_InitStruct.Pin = FLASH_CS_PIN;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
    HAL_GPIO_Init(FLASH_CS_PORT, &GPIO_InitStruct);
}

/* ═══════════════════════════════════════════════════════════════
 *          MX_SPI1_Init - SPI1 初始化 (W25Q128)
 *          PA5 = SCK, PA6 = MISO, PA7 = MOSI
 *          与 APP 工程相同配置
 * ═══════════════════════════════════════════════════════════════ */
static void MX_SPI1_Init(void)
{
    hspi1.Instance = SPI1;
    hspi1.Init.Mode = SPI_MODE_MASTER;
    hspi1.Init.Direction = SPI_DIRECTION_2LINES;
    hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
    hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
    hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
    hspi1.Init.NSS = SPI_NSS_SOFT;
    hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_16;
    hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
    hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
    hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
    hspi1.Init.CRCPolynomial = 10;
    if (HAL_SPI_Init(&hspi1) != HAL_OK) {
        Error_Handler();
    }
}

/* ═══════════════════════════════════════════════════════════════
 *          MX_USART2_UART_Init - USART2 初始化 (蓝牙 JDY-08)
 *          PA2 = TX, PA3 = RX, 115200 baud
 * ═══════════════════════════════════════════════════════════════ */
static void MX_USART2_UART_Init(void)
{
    huart2.Instance = USART2;
    huart2.Init.BaudRate = 115200;
    huart2.Init.WordLength = UART_WORDLENGTH_8B;
    huart2.Init.StopBits = UART_STOPBITS_1;
    huart2.Init.Parity = UART_PARITY_NONE;
    huart2.Init.Mode = UART_MODE_TX_RX;
    huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
    huart2.Init.OverSampling = UART_OVERSAMPLING_16;
    if (HAL_UART_Init(&huart2) != HAL_OK) {
        Error_Handler();
    }
}


/* ═══════════════════════════════════════════════════════════════
 *          HAL MSP 初始化回调 (SPI1 + USART2 GPIO 配置)
 *          Bootloader 独立实现，不依赖 APP 的 spi.c/usart.c
 * ═══════════════════════════════════════════════════════════════ */
void HAL_SPI_MspInit(SPI_HandleTypeDef* spiHandle)
{
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    if (spiHandle->Instance == SPI1) {
        __HAL_RCC_SPI1_CLK_ENABLE();
        __HAL_RCC_GPIOA_CLK_ENABLE();

        /* SPI1 GPIO: PA5=SCK, PA6=MISO, PA7=MOSI */
        GPIO_InitStruct.Pin = GPIO_PIN_5 | GPIO_PIN_6 | GPIO_PIN_7;
        GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
        GPIO_InitStruct.Pull = GPIO_NOPULL;
        GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
        GPIO_InitStruct.Alternate = GPIO_AF5_SPI1;
        HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);
    }
}

void HAL_SPI_MspDeInit(SPI_HandleTypeDef* spiHandle)
{
    if (spiHandle->Instance == SPI1) {
        __HAL_RCC_SPI1_CLK_DISABLE();
        HAL_GPIO_DeInit(GPIOA, GPIO_PIN_5 | GPIO_PIN_6 | GPIO_PIN_7);
    }
}

void HAL_UART_MspInit(UART_HandleTypeDef* uartHandle)
{
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    if (uartHandle->Instance == USART2) {
        __HAL_RCC_USART2_CLK_ENABLE();
        __HAL_RCC_GPIOA_CLK_ENABLE();

        /* USART2 GPIO: PA2=TX, PA3=RX */
        GPIO_InitStruct.Pin = GPIO_PIN_2 | GPIO_PIN_3;
        GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
        GPIO_InitStruct.Pull = GPIO_NOPULL;
        GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
        GPIO_InitStruct.Alternate = GPIO_AF7_USART2;
        HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

        /* USART2 中断 */
        HAL_NVIC_SetPriority(USART2_IRQn, 0, 0);
        HAL_NVIC_EnableIRQ(USART2_IRQn);
    }
}

void HAL_UART_MspDeInit(UART_HandleTypeDef* uartHandle)
{
    if (uartHandle->Instance == USART2) {
        __HAL_RCC_USART2_CLK_DISABLE();
        HAL_GPIO_DeInit(GPIOA, GPIO_PIN_2 | GPIO_PIN_3);
        HAL_NVIC_DisableIRQ(USART2_IRQn);
    }
}

/* ═══════════════════════════════════════════════════════════════
 *          UART 接收中断回调
 * ═══════════════════════════════════════════════════════════════ */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart == &huart2) {
        bl_rx_tick = HAL_GetTick();

        /* 继续接收下一个字节 */
        HAL_UART_Receive_IT(&huart2, &bl_rx_data, 1);

        /* 存入缓冲区 (防止溢出) */
        if (bl_rx_pointer < BL_RX_BUFFER_SIZE - 1) {
            bl_rx_buff[bl_rx_pointer++] = bl_rx_data;
        }
    }
}

/* ═══════════════════════════════════════════════════════════════
 *          LED 辅助函数
 * ═══════════════════════════════════════════════════════════════ */
static void LED_Toggle(void)
{
    HAL_GPIO_TogglePin(LED_PORT, LED_PIN);
}


/* ═══════════════════════════════════════════════════════════════
 *          蓝牙发送函数
 * ═══════════════════════════════════════════════════════════════ */
static void BL_SendString(const char* str)
{
    HAL_UART_Transmit(&huart2, (uint8_t*)str, strlen(str), 100);
}

/* ═══════════════════════════════════════════════════════════════
 *          BL_RX_Proc - 处理 UART 接收缓冲区
 *          与 APP 端 RX_proc 相同的逻辑:
 *          等待换行符或超时后解析命令
 * ═══════════════════════════════════════════════════════════════ */
static void BL_RX_Proc(void)
{
    if (bl_rx_pointer == 0) return;

    uint8_t has_complete_cmd = 0;

    /* 检查是否有换行符 */
    if (bl_rx_buff[bl_rx_pointer - 1] == '\n' ||
        bl_rx_buff[bl_rx_pointer - 1] == '\r') {
        has_complete_cmd = 1;
    }
    /* OTA 命令可能较长，等待换行或 500ms 超时 */
    else if (bl_rx_pointer >= 5 &&
             strncmp((char*)bl_rx_buff, "OTA_", 4) == 0) {
        if (HAL_GetTick() - bl_rx_tick >= 500) {
            has_complete_cmd = 1;
        } else {
            return;
        }
    }
    /* 普通数据 30ms 超时 */
    else if (HAL_GetTick() - bl_rx_tick >= 30) {
        has_complete_cmd = 1;
    }

    if (!has_complete_cmd) return;

    /* 禁用中断，复制数据 */
    __disable_irq();
    bl_rx_buff[bl_rx_pointer] = '\0';
    uint16_t saved_pointer = bl_rx_pointer;

    static char temp_buff[BL_RX_BUFFER_SIZE];
    memcpy(temp_buff, bl_rx_buff, saved_pointer + 1);

    bl_rx_pointer = 0;
    memset(bl_rx_buff, 0, saved_pointer + 1);
    __enable_irq();

    /* 按换行符分割，逐条解析 */
    char* token = strtok(temp_buff, "\n\r");
    while (token != NULL) {
        if (strlen(token) > 0) {
            BL_OTA_ParseCommand(token);
        }
        token = strtok(NULL, "\n\r");
    }
}

/* ═══════════════════════════════════════════════════════════════
 *          BL_HexDecode - 十六进制字符串解码
 *          "48656C6C6F" → {0x48, 0x65, 0x6C, 0x6C, 0x6F}
 * ═══════════════════════════════════════════════════════════════ */
static int BL_HexDecode(const char* hex, uint8_t* out, int maxLen)
{
    int len = strlen(hex);
    if (len % 2 != 0) return -1;

    int outLen = len / 2;
    if (outLen > maxLen) return -1;

    for (int i = 0; i < outLen; i++) {
        char hi = hex[i * 2];
        char lo = hex[i * 2 + 1];
        uint8_t val = 0;

        if (hi >= '0' && hi <= '9')      val = (hi - '0') << 4;
        else if (hi >= 'A' && hi <= 'F') val = (hi - 'A' + 10) << 4;
        else if (hi >= 'a' && hi <= 'f') val = (hi - 'a' + 10) << 4;
        else return -1;

        if (lo >= '0' && lo <= '9')      val |= (lo - '0');
        else if (lo >= 'A' && lo <= 'F') val |= (lo - 'A' + 10);
        else if (lo >= 'a' && lo <= 'f') val |= (lo - 'a' + 10);
        else return -1;

        out[i] = val;
    }
    return outLen;
}


/* ═══════════════════════════════════════════════════════════════
 *          BL_OTA_ParseCommand - 等待模式 OTA 命令解析
 *          简化版 OTA_ParseCommand，复用相同协议:
 *          OTA_START / OTA_DATA / OTA_END / OTA_ABORT
 *
 *          接收固件到 W25Q128 暂存区，成功后设置升级标志并复位
 * ═══════════════════════════════════════════════════════════════ */
static void BL_OTA_ParseCommand(char* cmd)
{
    char response[64];

    /* ─── OTA_START:size:crc32 ─── */
    if (strncmp(cmd, "OTA_START:", 10) == 0) {
        uint32_t size = 0, crc = 0;
        char* p = cmd + 10;
        size = strtoul(p, &p, 10);
        if (*p == ':') crc = strtoul(p + 1, NULL, 10);

        /* 校验固件大小 */
        if (size == 0 || size > APP_MAX_SIZE) {
            sprintf(response, "OTA_FAIL:SIZE_INVALID:%lu\n", (unsigned long)APP_MAX_SIZE);
            BL_SendString(response);
            return;
        }

        bl_ota_state = BL_OTA_ERASING;
        BL_SendString("OTA_ERASING\n");

        /* 擦除 W25Q128 暂存区 (1MB = 16 × 64KB Block) */
        for (int i = 0; i < 16; i++) {
            W25Q128_EraseBlock(OTA_STAGING_ADDR + i * 65536);
            /* 擦除期间 LED 快闪 */
            if (HAL_GetTick() - led_last_toggle >= 100) {
                LED_Toggle();
                led_last_toggle = HAL_GetTick();
            }
        }

        /* 初始化接收状态 */
        bl_ota_total_size = size;
        bl_ota_received_size = 0;
        bl_ota_expected_crc = crc;
        bl_ota_current_seq = 0;
        bl_ota_flash_written = 0;
        bl_ota_state = BL_OTA_RECEIVING;

        bl_ota_window.totalPackets = (size + 15) / 16;
        bl_ota_window.flashWriteCount = 0;
        bl_ota_window.batchByteCount = 0;

        BL_SendString("OTA_READY\n");
    }

    /* ─── OTA_DATA:seq:hexdata ─── */
    else if (strncmp(cmd, "OTA_DATA:", 9) == 0) {
        if (bl_ota_state != BL_OTA_RECEIVING) {
            BL_SendString("OTA_FAIL:NOT_READY\n");
            return;
        }

        char* p = cmd + 9;
        uint32_t seq = strtoul(p, &p, 10);
        if (*p != ':') {
            BL_SendString("OTA_FAIL:FORMAT\n");
            return;
        }
        char* hexData = p + 1;

        int decodedLen = BL_HexDecode(hexData, bl_ota_temp_buffer,
                                       sizeof(bl_ota_temp_buffer));
        if (decodedLen <= 0) {
            sprintf(response, "OTA_NAK:%lu\n", (unsigned long)seq);
            BL_SendString(response);
            return;
        }

        /* 序号校验 */
        uint32_t expectedSeq = (bl_ota_current_seq == 0 &&
                                bl_ota_received_size == 0) ? 0
                               : bl_ota_current_seq + 1;
        if (seq != expectedSeq) {
            if (seq < expectedSeq) return;  /* 重复包，忽略 */
            sprintf(response, "OTA_RESEND:%lu\n", (unsigned long)expectedSeq);
            BL_SendString(response);
            return;
        }

        /* 写入批量缓冲区 */
        if (bl_ota_window.flashWriteCount == 0) {
            bl_ota_window.batchByteCount = 0;
        }
        memcpy(&bl_ota_window.flashWriteBuffer[bl_ota_window.batchByteCount],
               bl_ota_temp_buffer, decodedLen);
        bl_ota_window.batchByteCount += decodedLen;
        bl_ota_window.flashWriteCount++;
        bl_ota_received_size += decodedLen;
        bl_ota_current_seq = seq;

        /* 每 16 包或最后一包时批量写入 Flash */
        bool isLastPacket = (seq == bl_ota_window.totalPackets - 1);
        bool batchComplete = (bl_ota_window.flashWriteCount >= BL_OTA_BATCH_SIZE);

        if (batchComplete || isLastPacket) {
            uint32_t writeAddr = OTA_STAGING_ADDR + bl_ota_flash_written;
            W25Q128_BufferWrite(bl_ota_window.flashWriteBuffer,
                                writeAddr, bl_ota_window.batchByteCount);
            bl_ota_flash_written += bl_ota_window.batchByteCount;

            bl_ota_window.flashWriteCount = 0;
            bl_ota_window.batchByteCount = 0;

            sprintf(response, "OTA_ACK:%lu\n", (unsigned long)seq);
            BL_SendString(response);

            /* 升级中 LED 快闪 */
            if (HAL_GetTick() - led_last_toggle >= 100) {
                LED_Toggle();
                led_last_toggle = HAL_GetTick();
            }
        }
    }

    /* ─── OTA_END ─── */
    else if (strcmp(cmd, "OTA_END") == 0) {
        if (bl_ota_state != BL_OTA_RECEIVING) {
            BL_SendString("OTA_FAIL:NOT_RECEIVING\n");
            return;
        }

        bl_ota_state = BL_OTA_VERIFYING;

        /* 校验接收大小 */
        if (bl_ota_received_size != bl_ota_total_size) {
            sprintf(response, "OTA_FAIL:SIZE:%lu/%lu\n",
                    (unsigned long)bl_ota_received_size,
                    (unsigned long)bl_ota_total_size);
            BL_SendString(response);
            bl_ota_state = BL_OTA_ERROR;
            return;
        }

        /* 校验 CRC32 */
        uint32_t calcCRC = CRC32_CalculateFlash(OTA_STAGING_ADDR,
                                                 bl_ota_total_size);
        if (calcCRC != bl_ota_expected_crc) {
            sprintf(response, "OTA_FAIL:CRC:%lu\n", (unsigned long)calcCRC);
            BL_SendString(response);
            bl_ota_state = BL_OTA_ERROR;
            return;
        }

        /* 写入 OTA 元数据 (升级标志) */
        OtaMeta_t meta;
        memset(&meta, 0, sizeof(meta));
        meta.magic = OTA_META_MAGIC;
        meta.version = OTA_META_VERSION;
        meta.upgradeFlag = 0x01;
        meta.firmwareSize = bl_ota_total_size;
        meta.firmwareCRC = bl_ota_expected_crc;

        W25Q128_EraseSector(OTA_META_ADDR);
        W25Q128_BufferWrite((uint8_t*)&meta, OTA_META_ADDR, sizeof(meta));

        bl_ota_state = BL_OTA_COMPLETE;
        BL_SendString("OTA_OK\n");

        /* 延迟 500ms 确保蓝牙响应发送完毕，然后复位 */
        HAL_Delay(500);
        NVIC_SystemReset();
    }

    /* ─── OTA_ABORT ─── */
    else if (strcmp(cmd, "OTA_ABORT") == 0) {
        bl_ota_state = BL_OTA_IDLE;
        bl_ota_received_size = 0;
        bl_ota_flash_written = 0;
        BL_SendString("OTA_ABORTED\n");
    }

    /* ─── OTA_VERSION ─── */
    else if (strcmp(cmd, "OTA_VERSION") == 0) {
        BL_SendString("OTA_VERSION:BOOTLOADER\n");
    }
}

/* ═══════════════════════════════════════════════════════════════
 *          Error_Handler
 * ═══════════════════════════════════════════════════════════════ */
void Error_Handler(void)
{
    __disable_irq();
    /* LED 常亮表示错误 */
    HAL_GPIO_WritePin(LED_PORT, LED_PIN, GPIO_PIN_SET);
    while (1) {
    }
}
