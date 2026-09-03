#include <Arduino.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <ESP8266WebServer.h>
#include <ESP8266WiFi.h>
#include <espnow.h>
extern "C" {
#include <user_interface.h>
}

#include "controller_config.h"

#ifndef CONTROLLER_ROLE_MASTER
#define CONTROLLER_ROLE_MASTER 1
#endif

namespace {
constexpr uint32_t PACKET_MAGIC = 0x5356544CUL;  // SVTL
constexpr uint8_t PACKET_VERSION = 1;
constexpr uint32_t PLAN_MAGIC = 0x5356504CUL;    // SVPL

enum class LampColor : uint8_t { red = 0, yellow = 1, green = 2 };
enum class Phase : uint8_t {
  stopped = 0,
  aGreen = 1,
  aYellow = 2,
  allRedAToB = 3,
  bGreen = 4,
  bYellow = 5,
  allRedBToA = 6,
};
enum class PacketKind : uint8_t { sync = 1, ack = 2 };

struct __attribute__((packed)) RadioPacket {
  uint32_t magic;
  uint8_t version;
  uint8_t kind;
  uint8_t phase;
  uint8_t color;
  uint32_t sequence;
  uint32_t remainingMs;
  uint32_t checksum;
};

struct PlanStorage {
  uint32_t magic;
  char movementA[41];
  char movementB[41];
  uint16_t greenA;
  uint16_t yellowA;
  uint16_t allRedAToB;
  uint16_t greenB;
  uint16_t yellowB;
  uint16_t allRedBToA;
  uint32_t checksum;
};

PlanStorage plan{};
LampColor currentColor = LampColor::red;
Phase currentPhase = Phase::stopped;
bool running = false;
bool emergencyRed = true;
uint32_t phaseStartedAt = 0;
uint32_t phaseDurationMs = 0;
uint32_t sequenceNumber = 0;
uint32_t lastRadioSendAt = 0;
volatile uint32_t lastPeerContactAt = 0;
volatile uint32_t lastPeerSequence = 0;
String fault;
#if !CONTROLLER_ROLE_MASTER
bool reportedPeerLinked = false;
#endif

#if CONTROLLER_ROLE_MASTER
ESP8266WebServer server(80);
#endif

uint32_t checksumBytes(const uint8_t* bytes, size_t length) {
  uint32_t hash = 2166136261UL;
  for (size_t i = 0; i < length; ++i) {
    hash ^= bytes[i];
    hash *= 16777619UL;
  }
  for (const uint8_t byte : ESPNOW_KEY) {
    hash ^= byte;
    hash *= 16777619UL;
  }
  return hash;
}

template <typename T>
uint32_t structChecksum(const T& value) {
  return checksumBytes(reinterpret_cast<const uint8_t*>(&value),
                       sizeof(T) - sizeof(value.checksum));
}

bool macConfigured(const uint8_t* mac) {
  for (uint8_t i = 0; i < 6; ++i) {
    if (mac[i] != 0) return true;
  }
  return false;
}

bool productionConfigurationReady() {
  constexpr uint8_t defaultEspNowKey[16] = {
      0x53, 0x56, 0x2D, 0x32, 0x30, 0x32, 0x36, 0x2D,
      0x43, 0x41, 0x4D, 0x42, 0x49, 0x41, 0x52, 0x21,
  };
  return macConfigured(MASTER_MAC) && macConfigured(FOLLOWER_MAC) &&
         String(API_ACCESS_KEY) != "CAMBIAR-CLAVE-CONTROLADOR" &&
         String(AP_PASSWORD) != "CAMBIAR-AP-2026" &&
         memcmp(ESPNOW_KEY, defaultEspNowKey, sizeof(defaultEspNowKey)) != 0;
}

void writeOutput(uint8_t pin, bool active) {
  digitalWrite(pin, active == OUTPUT_ACTIVE_LOW ? LOW : HIGH);
}

void applyColor(LampColor color) {
  if (color == currentColor) return;
  writeOutput(PIN_RED, false);
  writeOutput(PIN_YELLOW, false);
  writeOutput(PIN_GREEN, false);
  delayMicroseconds(BREAK_BEFORE_MAKE_US);
  writeOutput(PIN_RED, color == LampColor::red);
  writeOutput(PIN_YELLOW, color == LampColor::yellow);
  writeOutput(PIN_GREEN, color == LampColor::green);
  currentColor = color;
}

void initializeSafeOutputs() {
  const uint8_t inactive = OUTPUT_ACTIVE_LOW ? HIGH : LOW;
  digitalWrite(PIN_RED, inactive);
  digitalWrite(PIN_YELLOW, inactive);
  digitalWrite(PIN_GREEN, inactive);
  pinMode(PIN_RED, OUTPUT);
  pinMode(PIN_YELLOW, OUTPUT);
  pinMode(PIN_GREEN, OUTPUT);
  currentColor = LampColor::yellow;
  applyColor(LampColor::red);
}

void defaultPlan() {
  memset(&plan, 0, sizeof(plan));
  plan.magic = PLAN_MAGIC;
  strlcpy(plan.movementA, "Semáforo A", sizeof(plan.movementA));
  strlcpy(plan.movementB, "Semáforo B", sizeof(plan.movementB));
  plan.greenA = 30;
  plan.yellowA = 3;
  plan.allRedAToB = 2;
  plan.greenB = 30;
  plan.yellowB = 3;
  plan.allRedBToA = 2;
  plan.checksum = structChecksum(plan);
}

void loadPlan() {
  EEPROM.begin(sizeof(PlanStorage));
  EEPROM.get(0, plan);
  if (plan.magic != PLAN_MAGIC || plan.checksum != structChecksum(plan)) {
    defaultPlan();
    EEPROM.put(0, plan);
    EEPROM.commit();
  }
}

void savePlan() {
  plan.magic = PLAN_MAGIC;
  plan.checksum = structChecksum(plan);
  EEPROM.put(0, plan);
  EEPROM.commit();
}

const char* colorName(LampColor color) {
  switch (color) {
    case LampColor::green: return "green";
    case LampColor::yellow: return "yellow";
    default: return "red";
  }
}

const char* phaseName(Phase phase) {
  switch (phase) {
    case Phase::aGreen: return "A verde";
    case Phase::aYellow: return "A ámbar";
    case Phase::allRedAToB: return "Todo rojo A → B";
    case Phase::bGreen: return "B verde";
    case Phase::bYellow: return "B ámbar";
    case Phase::allRedBToA: return "Todo rojo B → A";
    default: return "Detenido en rojo";
  }
}

LampColor masterColorFor(Phase phase) {
  if (phase == Phase::aGreen) return LampColor::green;
  if (phase == Phase::aYellow) return LampColor::yellow;
  return LampColor::red;
}

LampColor followerColorFor(Phase phase) {
  if (phase == Phase::bGreen) return LampColor::green;
  if (phase == Phase::bYellow) return LampColor::yellow;
  return LampColor::red;
}

uint32_t remainingMs() {
  if (!running || phaseDurationMs == 0) return 0;
  const uint32_t elapsed = millis() - phaseStartedAt;
  return elapsed >= phaseDurationMs ? 0 : phaseDurationMs - elapsed;
}

bool peerLinked() {
  return lastPeerContactAt != 0 && millis() - lastPeerContactAt <= PEER_TIMEOUT_MS;
}

RadioPacket makePacket(PacketKind kind, LampColor color) {
  RadioPacket packet{};
  packet.magic = PACKET_MAGIC;
  packet.version = PACKET_VERSION;
  packet.kind = static_cast<uint8_t>(kind);
  packet.phase = static_cast<uint8_t>(currentPhase);
  packet.color = static_cast<uint8_t>(color);
  packet.sequence = sequenceNumber;
  packet.remainingMs = remainingMs();
  packet.checksum = structChecksum(packet);
  return packet;
}

bool validPacket(const RadioPacket& packet) {
  return packet.magic == PACKET_MAGIC && packet.version == PACKET_VERSION &&
         packet.checksum == structChecksum(packet) &&
         packet.color <= static_cast<uint8_t>(LampColor::green);
}

void sendRadio(const uint8_t* peer, PacketKind kind, LampColor color) {
  if (!macConfigured(peer)) return;
  const RadioPacket packet = makePacket(kind, color);
  esp_now_send(const_cast<uint8_t*>(peer),
               reinterpret_cast<uint8_t*>(const_cast<RadioPacket*>(&packet)),
               sizeof(packet));
}

void onRadioReceive(uint8_t* mac, uint8_t* data, uint8_t length) {
  if (length != sizeof(RadioPacket)) return;
  RadioPacket packet{};
  memcpy(&packet, data, sizeof(packet));
  if (!validPacket(packet)) return;

#if CONTROLLER_ROLE_MASTER
  if (memcmp(mac, FOLLOWER_MAC, 6) != 0 ||
      packet.kind != static_cast<uint8_t>(PacketKind::ack)) return;
  lastPeerContactAt = millis();
  lastPeerSequence = packet.sequence;
#else
  if (memcmp(mac, MASTER_MAC, 6) != 0 ||
      packet.kind != static_cast<uint8_t>(PacketKind::sync)) return;
  lastPeerContactAt = millis();
  lastPeerSequence = packet.sequence;
  sequenceNumber = packet.sequence;
  currentPhase = static_cast<Phase>(packet.phase);
  phaseDurationMs = packet.remainingMs;
  phaseStartedAt = millis();
  applyColor(static_cast<LampColor>(packet.color));
  sendRadio(MASTER_MAC, PacketKind::ack, currentColor);
#endif
}

bool initializeEspNow() {
#if CONTROLLER_ROLE_MASTER
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(AP_SSID, AP_PASSWORD, ESPNOW_CHANNEL, false, 4);
#else
  WiFi.mode(WIFI_STA);
#endif
  wifi_set_channel(ESPNOW_CHANNEL);
  if (esp_now_init() != 0) return false;
  esp_now_set_kok(const_cast<uint8_t*>(ESPNOW_KEY), sizeof(ESPNOW_KEY));
  esp_now_register_recv_cb(onRadioReceive);
#if CONTROLLER_ROLE_MASTER
  esp_now_set_self_role(ESP_NOW_ROLE_CONTROLLER);
  return !macConfigured(FOLLOWER_MAC) ||
         esp_now_add_peer(const_cast<uint8_t*>(FOLLOWER_MAC), ESP_NOW_ROLE_SLAVE,
                          ESPNOW_CHANNEL, const_cast<uint8_t*>(ESPNOW_KEY),
                          sizeof(ESPNOW_KEY)) == 0;
#else
  esp_now_set_self_role(ESP_NOW_ROLE_SLAVE);
  return !macConfigured(MASTER_MAC) ||
         esp_now_add_peer(const_cast<uint8_t*>(MASTER_MAC),
                          ESP_NOW_ROLE_CONTROLLER, ESPNOW_CHANNEL,
                          const_cast<uint8_t*>(ESPNOW_KEY),
                          sizeof(ESPNOW_KEY)) == 0;
#endif
}

#if CONTROLLER_ROLE_MASTER
void enterPhase(Phase phase, uint16_t seconds) {
  currentPhase = phase;
  phaseStartedAt = millis();
  phaseDurationMs = static_cast<uint32_t>(seconds) * 1000UL;
  ++sequenceNumber;
  applyColor(masterColorFor(phase));
  sendRadio(FOLLOWER_MAC, PacketKind::sync, followerColorFor(phase));
}

void forceAllRed(const String& reason, bool emergency) {
  running = false;
  emergencyRed = emergency;
  currentPhase = Phase::stopped;
  phaseDurationMs = 0;
  ++sequenceNumber;
  fault = reason;
  applyColor(LampColor::red);
  sendRadio(FOLLOWER_MAC, PacketKind::sync, LampColor::red);
}

void advancePhase() {
  switch (currentPhase) {
    case Phase::aGreen: enterPhase(Phase::aYellow, plan.yellowA); break;
    case Phase::aYellow: enterPhase(Phase::allRedAToB, plan.allRedAToB); break;
    case Phase::allRedAToB: enterPhase(Phase::bGreen, plan.greenB); break;
    case Phase::bGreen: enterPhase(Phase::bYellow, plan.yellowB); break;
    case Phase::bYellow: enterPhase(Phase::allRedBToA, plan.allRedBToA); break;
    default: enterPhase(Phase::aGreen, plan.greenA); break;
  }
}

bool authenticated() {
  if (!server.hasHeader("X-SV-Controller-Key")) return false;
  const String supplied = server.header("X-SV-Controller-Key");
  if (supplied.length() != strlen(API_ACCESS_KEY)) return false;
  uint8_t difference = 0;
  for (size_t i = 0; i < supplied.length(); ++i) {
    difference |= supplied[i] ^ API_ACCESS_KEY[i];
  }
  return difference == 0;
}

void addPlanJson(JsonObject target) {
  target["movement_a_name"] = plan.movementA;
  target["movement_b_name"] = plan.movementB;
  target["green_a_seconds"] = plan.greenA;
  target["yellow_a_seconds"] = plan.yellowA;
  target["all_red_a_to_b_seconds"] = plan.allRedAToB;
  target["green_b_seconds"] = plan.greenB;
  target["yellow_b_seconds"] = plan.yellowB;
  target["all_red_b_to_a_seconds"] = plan.allRedBToA;
}

String statusJson() {
  JsonDocument doc;
  doc["running"] = running;
  doc["peer_linked"] = peerLinked();
  doc["emergency_all_red"] = emergencyRed;
  doc["mode"] = fault.isEmpty()
                    ? (running ? (peerLinked() ? "Ciclo sincronizado"
                                               : "Ciclo autónomo del maestro")
                               : "Todo rojo")
                    : "Falla segura";
  doc["phase"] = phaseName(currentPhase);
  doc["fault"] = fault;
  doc["remaining_seconds"] = (remainingMs() + 999) / 1000;
  doc["sequence"] = sequenceNumber;
  addPlanJson(doc["plan"].to<JsonObject>());
  JsonObject a = doc["node_a"].to<JsonObject>();
  a["name"] = plan.movementA;
  a["color"] = colorName(masterColorFor(currentPhase));
  a["online"] = true;
  a["remaining_seconds"] = (remainingMs() + 999) / 1000;
  JsonObject b = doc["node_b"].to<JsonObject>();
  b["name"] = plan.movementB;
  b["color"] = colorName(followerColorFor(currentPhase));
  b["online"] = peerLinked();
  b["remaining_seconds"] = (remainingMs() + 999) / 1000;
  String output;
  serializeJson(doc, output);
  return output;
}

void sendJson(int code, const String& body) {
  server.send(code, "application/json; charset=utf-8", body);
}

bool requireAuthentication() {
  if (authenticated()) return true;
  sendJson(401, "{\"message\":\"Clave del controlador incorrecta.\"}");
  return false;
}

bool validSeconds(int value, int minimum, int maximum) {
  return value >= minimum && value <= maximum;
}

void handlePlan() {
  if (!requireAuthentication()) return;
  if (running) {
    sendJson(409, "{\"message\":\"Detén el ciclo antes de cambiar el plan.\"}");
    return;
  }
  JsonDocument input;
  if (deserializeJson(input, server.arg("plain"))) {
    sendJson(400, "{\"message\":\"Plan JSON inválido.\"}");
    return;
  }
  const String nameA = input["movement_a_name"] | "";
  const String nameB = input["movement_b_name"] | "";
  const int greenA = input["green_a_seconds"] | 0;
  const int yellowA = input["yellow_a_seconds"] | 0;
  const int redAB = input["all_red_a_to_b_seconds"] | 0;
  const int greenB = input["green_b_seconds"] | 0;
  const int yellowB = input["yellow_b_seconds"] | 0;
  const int redBA = input["all_red_b_to_a_seconds"] | 0;
  if (nameA.isEmpty() || nameB.isEmpty() || nameA.length() > 40 ||
      nameB.length() > 40 || !validSeconds(greenA, 5, 180) ||
      !validSeconds(greenB, 5, 180) || !validSeconds(yellowA, 2, 10) ||
      !validSeconds(yellowB, 2, 10) || !validSeconds(redAB, 1, 10) ||
      !validSeconds(redBA, 1, 10)) {
    sendJson(422, "{\"message\":\"Tiempos o nombres fuera de los límites seguros.\"}");
    return;
  }
  forceAllRed("", false);
  strlcpy(plan.movementA, nameA.c_str(), sizeof(plan.movementA));
  strlcpy(plan.movementB, nameB.c_str(), sizeof(plan.movementB));
  plan.greenA = greenA;
  plan.yellowA = yellowA;
  plan.allRedAToB = redAB;
  plan.greenB = greenB;
  plan.yellowB = yellowB;
  plan.allRedBToA = redBA;
  savePlan();
  sendJson(200, statusJson());
}

void initializeHttp() {
  server.collectHeaders("X-SV-Controller-Key");
  server.on("/api/status", HTTP_GET, [] {
    if (requireAuthentication()) sendJson(200, statusJson());
  });
  server.on("/api/plan", HTTP_PUT, handlePlan);
  server.on("/api/start", HTTP_POST, [] {
    if (!requireAuthentication()) return;
    if (!productionConfigurationReady()) {
      sendJson(409, "{\"message\":\"Faltan MAC o claves definitivas en controller_config.h.\"}");
      return;
    }
    fault = "";
    emergencyRed = false;
    running = true;
    enterPhase(Phase::aGreen, plan.greenA);
    sendJson(200, statusJson());
  });
  server.on("/api/stop", HTTP_POST, [] {
    if (!requireAuthentication()) return;
    forceAllRed("", false);
    sendJson(200, statusJson());
  });
  server.on("/api/emergency-red", HTTP_POST, [] {
    if (!requireAuthentication()) return;
    forceAllRed("Paro manual activado desde la app.", true);
    sendJson(200, statusJson());
  });
  server.onNotFound([] {
    sendJson(404, "{\"message\":\"Ruta no disponible.\"}");
  });
  server.begin();
}
#endif
}  // namespace

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.printf("SV semáforo %s | MAC STA: %s\n",
                CONTROLLER_ROLE_MASTER ? "MAESTRO" : "SECUNDARIO",
                WiFi.macAddress().c_str());
  initializeSafeOutputs();
  loadPlan();
  if (!initializeEspNow()) {
    fault = "No se pudo iniciar ESP-NOW.";
    Serial.println(fault);
  }

#if CONTROLLER_ROLE_MASTER
  Serial.printf("AP %s | IP %s\n", AP_SSID,
                WiFi.softAPIP().toString().c_str());
  if (!productionConfigurationReady()) {
    fault = "Configuración de fábrica: el ciclo está bloqueado.";
  }
  initializeHttp();
#endif
}

void loop() {
#if CONTROLLER_ROLE_MASTER
  server.handleClient();
  if (running && remainingMs() == 0) advancePhase();
  if (millis() - lastRadioSendAt >= SYNC_INTERVAL_MS) {
    lastRadioSendAt = millis();
    sendRadio(FOLLOWER_MAC, PacketKind::sync,
              running ? followerColorFor(currentPhase) : LampColor::red);
  }
#else
  const bool linked = peerLinked();
  if (linked != reportedPeerLinked) {
    reportedPeerLinked = linked;
    Serial.printf("ENLACE MAESTRO: %s | secuencia %lu\n",
                  linked ? "CONFIRMADO" : "PERDIDO",
                  static_cast<unsigned long>(lastPeerSequence));
  }
  if (!linked) {
    applyColor(LampColor::red);
    currentPhase = Phase::stopped;
    phaseDurationMs = 0;
  }
#endif
  yield();
}
