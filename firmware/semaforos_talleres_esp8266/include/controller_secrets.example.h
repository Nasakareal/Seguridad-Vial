#pragma once

#include <Arduino.h>

constexpr char AP_SSID[] = "SV-SEMAFORO-MAESTRO";
constexpr char AP_PASSWORD[] = "CAMBIAR-AP-2026";
constexpr char API_ACCESS_KEY[] = "CAMBIAR-CLAVE-CONTROLADOR";
constexpr uint8_t MASTER_MAC[6] = {0, 0, 0, 0, 0, 0};
constexpr uint8_t FOLLOWER_MAC[6] = {0, 0, 0, 0, 0, 0};
constexpr uint8_t ESPNOW_KEY[16] = {
    0x53, 0x56, 0x2D, 0x32, 0x30, 0x32, 0x36, 0x2D,
    0x43, 0x41, 0x4D, 0x42, 0x49, 0x41, 0x52, 0x21,
};
