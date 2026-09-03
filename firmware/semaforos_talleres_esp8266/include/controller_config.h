#pragma once

#include <Arduino.h>

#if __has_include("controller_secrets.h")
#include "controller_secrets.h"
#else
// Valores de plantilla: el ciclo queda bloqueado hasta crear
// include/controller_secrets.h a partir del archivo .example.
constexpr char AP_SSID[] = "SV-SEMAFORO-MAESTRO";
constexpr char AP_PASSWORD[] = "CAMBIAR-AP-2026";
constexpr char API_ACCESS_KEY[] = "CAMBIAR-CLAVE-CONTROLADOR";
constexpr uint8_t MASTER_MAC[6] = {0, 0, 0, 0, 0, 0};
constexpr uint8_t FOLLOWER_MAC[6] = {0, 0, 0, 0, 0, 0};
constexpr uint8_t ESPNOW_KEY[16] = {
    0x53, 0x56, 0x2D, 0x32, 0x30, 0x32, 0x36, 0x2D,
    0x43, 0x41, 0x4D, 0x42, 0x49, 0x41, 0x52, 0x21,
};
#endif

constexpr uint8_t ESPNOW_CHANNEL = 1;

// Pines NodeMCU seguros para las entradas de un módulo optoacoplador.
// Confirma en banco qué canal corresponde a cada color antes de energizar potencia.
constexpr uint8_t PIN_RED = D1;     // GPIO5
constexpr uint8_t PIN_YELLOW = D2;  // GPIO4
constexpr uint8_t PIN_GREEN = D5;   // GPIO14
constexpr bool OUTPUT_ACTIVE_LOW = true;

constexpr uint32_t PEER_TIMEOUT_MS = 1500;
constexpr uint32_t SYNC_INTERVAL_MS = 200;
constexpr uint32_t BREAK_BEFORE_MAKE_US = 20000;
