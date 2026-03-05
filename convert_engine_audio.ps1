# ============================================================================
# MP3 to C Array Converter for STM32 Embedded Audio
# ============================================================================
# Description: Converts engine.mp3 to a C header file for embedded playback
# Author: RideWind Team
# Date: 2026-01-04
# Usage: Run this script in PowerShell from the project directory
# ============================================================================

$inputFile = "engine.mp3"
$outputFile = "f4_26_1.1\f4_26_1.1\f4_26_1.1\Core\Inc\engine_audio.h"
$arrayName = "engine_audio_data"
$sizeMacro = "ENGINE_AUDIO_SIZE"

Write-Host "============================================"
Write-Host "MP3 to C Array Converter"
Write-Host "============================================"

# Check if input file exists
if (-not (Test-Path $inputFile)) {
    Write-Host "Error: $inputFile not found!" -ForegroundColor Red
    exit 1
}

# Read the binary file
Write-Host "Reading $inputFile..."
$bytes = [System.IO.File]::ReadAllBytes($inputFile)
$size = $bytes.Length

Write-Host "File size: $size bytes"

# Find MP3 frame header (skip ID3 tag)
$audioStartOffset = 0
for ($i = 0; $i -lt ($size - 1); $i++) {
    if ($bytes[$i] -eq 0xFF -and ($bytes[$i + 1] -band 0xE0) -eq 0xE0) {
        $audioStartOffset = $i
        Write-Host "MP3 frame header found at offset: $audioStartOffset (0x$($audioStartOffset.ToString('X4')))"
        break
    }
}

# Generate the header file content
Write-Host "Generating C header file..."

$header = @"
/**
 ******************************************************************************
 * @file    engine_audio.h
 * @brief   Engine sound audio data array (Auto-generated)
 * @author  RideWind Team
 * @date    $(Get-Date -Format "yyyy-MM-dd")
 * @note    Source: $inputFile, Size: $size bytes
 *          MP3 audio start offset: $audioStartOffset
 ******************************************************************************
 */

#ifndef __ENGINE_AUDIO_H
#define __ENGINE_AUDIO_H

#ifdef __cplusplus
extern "C" {
#endif

#include "main.h"

/* Audio data size in bytes */
#define $sizeMacro $size

/* MP3 frame header offset (skip ID3 tag) */
#define ENGINE_AUDIO_START_OFFSET $audioStartOffset

/* Audio data array - stored in Flash */
static const uint8_t ${arrayName}[$sizeMacro] = {
"@

# Convert bytes to hex array with 16 bytes per line
$hexLines = @()
$line = "    "
$lineCount = 0

for ($i = 0; $i -lt $size; $i++) {
    $hex = "0x{0:X2}" -f $bytes[$i]
    
    if ($i -lt ($size - 1)) {
        $hex += ", "
    }
    
    $line += $hex
    $lineCount++
    
    # 16 bytes per line
    if ($lineCount -eq 16) {
        $hexLines += $line
        $line = "    "
        $lineCount = 0
    }
}

# Add remaining bytes
if ($lineCount -gt 0) {
    $hexLines += $line
}

$footer = @"

};

/* ======================== Function Declarations ======================== */

/**
 * @brief  Initialize engine audio module
 * @note   Call this after VS1003_Init()
 */
void EngineAudio_Init(void);

/**
 * @brief  Start engine audio playback
 * @note   Called when entering throttle mode
 */
void EngineAudio_Start(void);

/**
 * @brief  Stop engine audio playback
 * @note   Called when exiting throttle mode
 */
void EngineAudio_Stop(void);

/**
 * @brief  Process engine audio playback (call in main loop)
 * @note   Should be called frequently (every 1-10ms) for smooth playback
 */
void EngineAudio_Process(void);

/**
 * @brief  Check if engine audio is currently playing
 * @retval 1: playing, 0: not playing
 */
uint8_t EngineAudio_IsPlaying(void);

/**
 * @brief  Set engine audio volume (0-100%)
 * @param  volume: Volume percentage (0-100)
 */
void EngineAudio_SetVolume(uint8_t volume);

#ifdef __cplusplus
}
#endif

#endif /* __ENGINE_AUDIO_H */
"@

# Write the output file
$content = $header + ($hexLines -join "`r`n") + $footer
[System.IO.File]::WriteAllText($outputFile, $content, [System.Text.Encoding]::UTF8)

Write-Host "============================================"
Write-Host "Conversion complete!" -ForegroundColor Green
Write-Host "Output file: $outputFile"
Write-Host "Array name: $arrayName"
Write-Host "Array size: $size bytes"
Write-Host "MP3 start offset: $audioStartOffset"
Write-Host "============================================"

