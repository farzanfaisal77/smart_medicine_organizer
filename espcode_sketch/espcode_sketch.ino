#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <Firebase_ESP_Client.h>
#include <RTClib.h>
#include <WiFi.h>
#include <Wire.h>
#include <addons/RTDBHelper.h>
#include <addons/TokenHelper.h>
#include <time.h>

// =====================================================
// WI-FI & FIREBASE CONFIGURATION
// =====================================================

#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

#define API_KEY "YOUR_FIREBASE_API_KEY"
#define FIREBASE_PROJECT_ID "YOUR_FIREBASE_PROJECT_ID"
#define DEVICE_ID "ESP32_001"

#define USER_EMAIL "YOUR_USER_EMAIL"
#define USER_PASSWORD "YOUR_USER_PASSWORD"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

const char *ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 19800; // IST UTC+5:30
const int daylightOffset_sec = 0;

// =====================================================
// TFT CONNECTION (ST7735 1.8" SPI)
// =====================================================

#define TFT_CS 5
#define TFT_RST 4
#define TFT_DC 2
#define TFT_SCLK 18
#define TFT_MOSI 23

Adafruit_ST7735 tft =
    Adafruit_ST7735(TFT_CS, TFT_DC, TFT_MOSI, TFT_SCLK, TFT_RST);

// =====================================================
// I2C EXPANDERS (PCF8574)
// =====================================================

#define SDA_PIN 21
#define SCL_PIN 22

#define EXP1 0x20
#define EXP2 0x21

#define ACTIVE_LOW_LEDS false

// =====================================================
// RTC, BUZZER & REED SWITCH PINS
// =====================================================

RTC_DS3231 rtc; 

#define BUZZER 33
#define BUZZER_FREQ 500 // 2.0kHz resonant frequency

const int reedPins[6] = {27, 14, 26, 32, 25, 13};

// =====================================================
// GLOBAL EXPANDER STATES
// =====================================================

byte exp1State = 0x00; // All pins LOW (OFF for active-high)
byte exp2State = 0x00;

// =====================================================
// SYSTEM STATE MACHINE
// =====================================================

enum SystemState { STATE_IDLE, STATE_DOSE_ALARM, STATE_POPUP };

SystemState currentState = STATE_IDLE;

// =====================================================
// FIREBASE & SCHEDULE VARIABLES
// =====================================================

int firebaseDoseHour = -1;
int firebaseDoseMin = -1;
int targetCompartment = 0;
String nextMedicineName = "";
String nextDoseTimeString = "";
String nextDosageText = "";
String nextInstructionsText = "";
bool hasPendingDose = false;
int buzzerDuration = 30; // seconds

String compartmentColors[6] = {"OFF", "OFF", "OFF", "OFF", "OFF", "OFF"};

unsigned long lastFirebaseSync = 0;
unsigned long alarmStartTime = 0;
unsigned long lastStateChangeTime = 0;

int lastTriggeredHour = -1;
int lastTriggeredMin = -1;

// =====================================================
// FORWARD DECLARATIONS
// =====================================================

void writeExpander(byte address, byte value);
void setExpPin(byte address, byte pin, bool on);
void setC1(bool on);
void setC2Color(String color);
void setC3Color(String color);
void setC4(bool on);
void setC5(bool on);
void setC6(bool on);
void wrongLED(bool on);
void dosageLED(bool on);
void allLEDsOff();
void applyCompartmentLEDs();

void initBuzzer();
void startBuzzerSound();
void stopBuzzer();
void beep(int duration);
void playSuccessTone();
void playWarningTone();

uint16_t getCompartmentColour(int c);
void drawHeader(DateTime now);
void updateClock(DateTime now);
void drawAllClearScreen();
void drawDoseScreen(DateTime now);

void fetchScheduleFromFirebase();
void updateDeviceHeartbeat();
void syncEventToFirestore(String eventType, String details, int compNum);
void startDose();
bool isReedSwitchTriggered(int compNum);

// =====================================================
// EXPANDER HARDWARE DRIVERS
// =====================================================

void writeExpander(byte address, byte value) {
  Wire.beginTransmission(address);
  Wire.write(value);
  Wire.endTransmission();
}

void setExpPin(byte address, byte pin, bool on) {
  bool logicLevel = ACTIVE_LOW_LEDS ? !on : on;

  if (address == EXP1) {
    if (logicLevel)
      exp1State |= (1 << pin);
    else
      exp1State &= ~(1 << pin);
    writeExpander(EXP1, exp1State);
  } else if (address == EXP2) {
    if (logicLevel)
      exp2State |= (1 << pin);
    else
      exp2State &= ~(1 << pin);
    writeExpander(EXP2, exp2State);
  }
}

void setC1(bool on) { setExpPin(EXP1, 5, on); }

void setC2Color(String color) {
  color.toUpperCase();
  if (color == "RED") {
    setExpPin(EXP2, 3, true);  setExpPin(EXP2, 4, false); setExpPin(EXP2, 5, false);
  } else if (color == "GREEN") {
    setExpPin(EXP2, 3, false); setExpPin(EXP2, 4, true);  setExpPin(EXP2, 5, false);
  } else if (color == "BLUE") {
    setExpPin(EXP2, 3, false); setExpPin(EXP2, 4, false); setExpPin(EXP2, 5, true);
  } else { // OFF / DEFAULT
    setExpPin(EXP2, 3, false); setExpPin(EXP2, 4, false); setExpPin(EXP2, 5, false);
  }
}

void setC3Color(String color) {
  color.toUpperCase();
  if (color == "RED") {
    setExpPin(EXP2, 1, true);  setExpPin(EXP2, 2, false); setExpPin(EXP2, 3, false);
  } else if (color == "GREEN") {
    setExpPin(EXP2, 1, false); setExpPin(EXP2, 2, true);  setExpPin(EXP2, 3, false);
  } else if (color == "BLUE") {
    setExpPin(EXP2, 1, false); setExpPin(EXP2, 2, false); setExpPin(EXP2, 3, true);
  } else { // OFF / DEFAULT
    setExpPin(EXP2, 1, false); setExpPin(EXP2, 2, false); setExpPin(EXP2, 3, false);
  }
}

void setC4(bool on) { setExpPin(EXP1, 0, on); }
void setC5(bool on) { setExpPin(EXP1, 1, on); }
void setC6(bool on) { setExpPin(EXP1, 2, on); }

void wrongLED(bool on) { setExpPin(EXP1, 3, on); }
void dosageLED(bool on) { setExpPin(EXP1, 4, on); }

void allLEDsOff() {
  setC1(false);
  setC2Color("OFF");
  setC3Color("OFF");
  setC4(false);
  setC5(false);
  setC6(false);
  wrongLED(false);
  dosageLED(false);
}

void applyCompartmentLEDs() {
  allLEDsOff();

  // ONLY light up the target compartment LED during an active dose alarm
  if (currentState == STATE_DOSE_ALARM && targetCompartment >= 1 && targetCompartment <= 6) {
    if (targetCompartment == 1) setC1(true);
    else if (targetCompartment == 2) setC2Color("GREEN");
    else if (targetCompartment == 3) setC3Color("GREEN");
    else if (targetCompartment == 4) setC4(true);
    else if (targetCompartment == 5) setC5(true);
    else if (targetCompartment == 6) setC6(true);

    dosageLED(true);
  }
}

// =====================================================
// AUDIO BUZZER DRIVER
// =====================================================

void initBuzzer() {
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);
}

void startBuzzerSound() {
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, HIGH); // DC 3.3V power for Active Buzzers
  tone(BUZZER, BUZZER_FREQ);  // 2.0kHz resonant AC tone for Passive Buzzers
}

void stopBuzzer() {
  noTone(BUZZER);
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);
}

void beep(int duration) {
  startBuzzerSound();
  delay(duration);
  stopBuzzer();
}

void playSuccessTone() {
  stopBuzzer();
  beep(120);
  delay(80);
  beep(120);
  delay(80);
  beep(250);
}

void playWarningTone() {
  stopBuzzer();
  for (int i = 0; i < 3; i++) {
    beep(120);
    delay(100);
  }
}

// =====================================================
// TFT DISPLAY RENDERING
// =====================================================

uint16_t getCompartmentColour(int c) {
  if (c == 1)
    return ST77XX_GREEN;
  if (c == 2)
    return ST77XX_MAGENTA;
  if (c == 3)
    return ST77XX_CYAN;
  if (c == 4)
    return ST77XX_BLUE;
  if (c == 5)
    return ST77XX_ORANGE;
  if (c == 6)
    return ST77XX_WHITE;
  return ST77XX_WHITE;
}

void drawHeader(DateTime now) {
  tft.fillScreen(ST77XX_BLACK);
  tft.setTextSize(1);
  tft.setTextColor(ST77XX_WHITE);
  tft.setCursor(5, 5);
  tft.print("SMART MEDICINE");

  tft.setCursor(105, 5);
  if (now.hour() < 10)
    tft.print("0");
  tft.print(now.hour());
  tft.print(":");
  if (now.minute() < 10)
    tft.print("0");
  tft.print(now.minute());
  tft.print(":");
  if (now.second() < 10)
    tft.print("0");
  tft.print(now.second());

  tft.drawLine(5, 18, 154, 18, ST77XX_WHITE);
}

void updateClock(DateTime now) {
  tft.fillRect(104, 2, 54, 14, ST77XX_BLACK);
  tft.setTextSize(1);
  tft.setTextColor(ST77XX_WHITE);
  tft.setCursor(105, 5);
  if (now.hour() < 10)
    tft.print("0");
  tft.print(now.hour());
  tft.print(":");
  if (now.minute() < 10)
    tft.print("0");
  tft.print(now.minute());
  tft.print(":");
  if (now.second() < 10)
    tft.print("0");
  tft.print(now.second());
}

void drawAllClearScreen() {
  tft.fillScreen(ST77XX_BLACK);
  tft.setTextSize(2);
  tft.setTextColor(ST77XX_GREEN);
  tft.setCursor(20, 45);
  tft.print("ALL CLEAR!");

  tft.setTextSize(1);
  tft.setTextColor(ST77XX_WHITE);
  tft.setCursor(15, 75);
  tft.print("No pending doses");
  applyCompartmentLEDs();
}

void drawDoseScreen(DateTime now) {
  drawHeader(now);

  if (hasPendingDose && targetCompartment > 0) {
    tft.setTextSize(1);
    tft.setTextColor(ST77XX_CYAN);
    tft.setCursor(8, 26);
    tft.print("NEXT DOSE:");

    tft.setTextSize(2);
    tft.setTextColor(ST77XX_YELLOW);
    tft.setCursor(8, 38);
    String dispName = nextMedicineName;
    if (dispName.length() > 11)
      dispName = dispName.substring(0, 11);
    tft.print(dispName);

    tft.setTextSize(1);
    tft.setTextColor(ST77XX_WHITE);
    tft.setCursor(8, 60);
    tft.print("TIME: ");
    tft.setTextColor(ST77XX_GREEN);
    tft.print(nextDoseTimeString);

    tft.setCursor(8, 74);
    tft.setTextColor(ST77XX_WHITE);
    tft.print("SLOT: C");
    tft.setTextColor(getCompartmentColour(targetCompartment));
    tft.print(targetCompartment);

    if (nextDosageText.length() > 0) {
      tft.setTextColor(ST77XX_WHITE);
      tft.print(" (");
      tft.print(nextDosageText);
      tft.print(")");
    }

    int circleX = 135;
    int circleY = 48;
    tft.fillCircle(circleX, circleY, 10,
                   getCompartmentColour(targetCompartment));
    tft.setTextColor(ST77XX_BLACK);
    tft.setCursor(circleX - 3, circleY - 3);
    tft.print(targetCompartment);
  } else {
    drawAllClearScreen();
  }
}

// =====================================================
// DEBOUNCED REED SWITCH READ
// =====================================================

bool isReedSwitchTriggered(int compNum) {
  if (compNum < 1 || compNum > 6)
    return false;
  int pin = reedPins[compNum - 1];

  if (digitalRead(pin) == LOW) {
    delay(30); // 30ms Hardware debounce
    return (digitalRead(pin) == LOW);
  }
  return false;
}

// =====================================================
// FIREBASE & SYNC METHODS
// =====================================================

void fetchScheduleFromFirebase() {
  if (!Firebase.ready())
    return;

  String path = "deviceState/" DEVICE_ID;
  if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "",
                                     path.c_str())) {
    FirebaseJson json;
    FirebaseJsonData jsonData;
    json.setJsonData(fbdo.payload());

    String timeStr = "";
    String medName = "";
    String dosage = "";
    String instructions = "";
    int comp = 0;
    bool pending = false;
    int dur = 30;

    if (json.get(jsonData, "fields/nextMedicineName/stringValue"))
      medName = jsonData.stringValue;
    if (json.get(jsonData, "fields/nextDoseTime/stringValue"))
      timeStr = jsonData.stringValue;
    if (json.get(jsonData, "fields/nextDosage/stringValue"))
      dosage = jsonData.stringValue;
    if (json.get(jsonData, "fields/nextInstructions/stringValue"))
      instructions = jsonData.stringValue;
    if (json.get(jsonData, "fields/nextCompartment/integerValue"))
      comp = jsonData.intValue;
    if (json.get(jsonData, "fields/hasPendingDose/booleanValue"))
      pending = jsonData.boolValue;
    if (json.get(jsonData, "fields/buzzerDuration/integerValue"))
      dur = jsonData.intValue;

    for (int i = 1; i <= 6; i++) {
      String key = "fields/c" + String(i) + "Color/stringValue";
      if (json.get(jsonData, key.c_str())) {
        compartmentColors[i - 1] = jsonData.stringValue;
      }
    }

    bool scheduleChanged =
        (nextMedicineName != medName || nextDoseTimeString != timeStr ||
         targetCompartment != comp || hasPendingDose != pending);

    nextMedicineName = medName;
    nextDoseTimeString = timeStr;
    nextDosageText = dosage;
    nextInstructionsText = instructions;
    targetCompartment = comp;
    hasPendingDose = pending;
    buzzerDuration = dur;

    if (timeStr.length() >= 5) {
      int colonIdx = timeStr.indexOf(':');
      if (colonIdx > 0) {
        firebaseDoseHour = timeStr.substring(0, colonIdx).toInt();
        firebaseDoseMin = timeStr.substring(colonIdx + 1).toInt();
      }
    } else {
      firebaseDoseHour = -1;
      firebaseDoseMin = -1;
    }

    applyCompartmentLEDs();

    if (currentState == STATE_IDLE && scheduleChanged) {
      DateTime now = rtc.now();
      drawDoseScreen(now);
    }
  }
}

void updateDeviceHeartbeat() {
  if (!Firebase.ready())
    return;
  String path = "deviceState/" DEVICE_ID;
  FirebaseJson content;
  content.set("fields/isOnline/booleanValue", true);
  content.set("fields/batteryLevel/integerValue", 95);

  String updateMask = "isOnline,batteryLevel";
  for (int i = 0; i < 6; i++) {
    bool isOpen = (digitalRead(reedPins[i]) == LOW);
    String key = "c" + String(i + 1) + "Open";
    content.set("fields/" + key + "/booleanValue", isOpen);
    updateMask += "," + key;
  }

  Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", path.c_str(),
                                   content.raw(), updateMask.c_str());
}

void syncEventToFirestore(String eventType, String details, int compNum) {
  if (!Firebase.ready())
    return;
  String path = "deviceState/" DEVICE_ID;
  FirebaseJson content;
  content.set("fields/isOnline/booleanValue", true);
  content.set("fields/lastEvent/stringValue", eventType);
  content.set("fields/lastEventDetails/stringValue", details);
  content.set("fields/lastEventCompartment/integerValue", compNum);
  content.set("fields/hasPendingDose/booleanValue", false);
  content.set("fields/lastEventTimestamp/integerValue", (int)millis());

  Firebase.Firestore.patchDocument(
      &fbdo, FIREBASE_PROJECT_ID, "", path.c_str(), content.raw(),
      "isOnline,lastEvent,lastEventDetails,lastEventCompartment,hasPendingDose,"
      "lastEventTimestamp");
}

void startDose() {
  currentState = STATE_DOSE_ALARM;
  alarmStartTime = millis();

  applyCompartmentLEDs();
  startBuzzerSound();

  DateTime now = rtc.now();
  drawDoseScreen(now);

  Serial.println("\n==============================");
  Serial.println("DOSAGE ALARM STARTED");
  Serial.printf("Target Compartment: C%d (%s)\n", targetCompartment,
                nextMedicineName.c_str());
  Serial.printf("Alarm Duration: %d seconds\n", buzzerDuration);
  Serial.println("==============================");
}

// =====================================================
// SETUP
// =====================================================

void setup() {
  Serial.begin(115200);
  Wire.begin(SDA_PIN, SCL_PIN);

  exp1State = 0x00;
  exp2State = 0x00;
  writeExpander(EXP1, exp1State);
  writeExpander(EXP2, exp2State);
  allLEDsOff();

  for (int i = 0; i < 6; i++) {
    pinMode(reedPins[i], INPUT_PULLUP);
  }

  initBuzzer();

  tft.initR(INITR_BLACKTAB);
  tft.setRotation(1);
  tft.fillScreen(ST77XX_BLACK);

  // Non-blocking WiFi connection with 15-second timeout
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting Wi-Fi...");
  tft.setTextColor(ST77XX_YELLOW);
  tft.setCursor(10, 45);
  tft.setTextSize(1);
  tft.print("Connecting Wi-Fi...");

  unsigned long wifiStart = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < 15000) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWi-Fi Connected! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWi-Fi connection timed out. Booting offline mode.");
  }

  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  if (!rtc.begin()) {
    Serial.println("RTC ERROR");
    tft.setTextColor(ST77XX_RED);
    tft.setTextSize(2);
    tft.setCursor(25, 55);
    tft.print("RTC ERROR");
    while (1)
      ;
  }

  struct tm timeinfo;
  int ntpRetry = 0;
  while (!getLocalTime(&timeinfo) && ntpRetry < 10) {
    delay(500);
    ntpRetry++;
  }

  if (getLocalTime(&timeinfo)) {
    rtc.adjust(DateTime(timeinfo.tm_year + 1900, timeinfo.tm_mon + 1,
                        timeinfo.tm_mday, timeinfo.tm_hour, timeinfo.tm_min,
                        timeinfo.tm_sec));
    Serial.println("RTC successfully synced with NTP time.");
  }

  config.api_key = API_KEY;
  config.database_url =
      "https://smart-medicine-organizer-default-rtdb.firebaseio.com";
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  currentState = STATE_IDLE;
  fetchScheduleFromFirebase();
}

// =====================================================
// MAIN LOOP
// =====================================================

void loop() {
  DateTime now = rtc.now();

  // Firestore Sync & Heartbeat every 2 seconds
  if (Firebase.ready() &&
      (millis() - lastFirebaseSync > 2000 || lastFirebaseSync == 0)) {
    lastFirebaseSync = millis();
    updateDeviceHeartbeat();
    if (currentState == STATE_IDLE) {
      fetchScheduleFromFirebase();
    }
  }

  // IDLE STATE — TRIGGER ALARM WHEN TIME MATCHES
  if (currentState == STATE_IDLE && hasPendingDose && firebaseDoseHour >= 0 &&
      firebaseDoseMin >= 0) {
    int nowSecs = now.hour() * 3600 + now.minute() * 60 + now.second();
    int doseSecs = firebaseDoseHour * 3600 + firebaseDoseMin * 60;
    int diffSecs = nowSecs - doseSecs;

    if (diffSecs >= 0 && diffSecs <= 45) {
      if (lastTriggeredHour != now.hour() || lastTriggeredMin != now.minute()) {
        lastTriggeredHour = now.hour();
        lastTriggeredMin = now.minute();
        startDose();
      }
    }
  }

  // ALARM ACTIVE STATE — 30 SECONDS WINDOW
  if (currentState == STATE_DOSE_ALARM) {
    unsigned long elapsedSec = (millis() - alarmStartTime) / 1000;

    // 1. REED SWITCH SENSING (DOSE TAKEN)
    if (targetCompartment > 0 && isReedSwitchTriggered(targetCompartment)) {
      stopBuzzer();
      Serial.printf("\nREED SWITCH TRIGGERED ON C%d — DOSE TAKEN!\n",
                    targetCompartment);
      playSuccessTone();

      currentState = STATE_POPUP;
      tft.fillScreen(ST77XX_BLACK);
      tft.setTextColor(ST77XX_GREEN);
      tft.setTextSize(2);
      tft.setCursor(20, 35);
      tft.print("MEDICINE TAKEN!");
      tft.setTextSize(1);
      tft.setTextColor(ST77XX_WHITE);
      tft.setCursor(25, 65);
      tft.print(nextMedicineName);

      syncEventToFirestore("TAKEN",
                           "C" + String(targetCompartment) +
                               " Dose taken for " + nextMedicineName,
                           targetCompartment);
      delay(2500);

      currentState = STATE_IDLE;
      hasPendingDose = false;
      targetCompartment = 0;
      firebaseDoseHour = -1;
      firebaseDoseMin = -1;
      nextMedicineName = "";
      nextDoseTimeString = "";
      allLEDsOff();

      drawDoseScreen(rtc.now());
      fetchScheduleFromFirebase();
    }

    // 2. 30 SECONDS TIMEOUT EXPIRED (DOSE MISSED)
    if (currentState == STATE_DOSE_ALARM &&
        elapsedSec >= (unsigned long)buzzerDuration) {
      stopBuzzer();
      Serial.println("\n30s Alarm Cutoff Expired — DOSE MISSED!");
      playWarningTone();

      currentState = STATE_POPUP;
      tft.fillScreen(ST77XX_BLACK);
      tft.setTextColor(ST77XX_RED);
      tft.setTextSize(2);
      tft.setCursor(15, 35);
      tft.print("DOSE MISSED!");

      tft.setTextColor(ST77XX_WHITE);
      tft.setTextSize(1);
      tft.setCursor(20, 65);
      tft.print("Box #");
      tft.print(targetCompartment);
      tft.print(" Not Opened");

      syncEventToFirestore("MISSED",
                           "C" + String(targetCompartment) +
                               " Dose missed for " + nextMedicineName,
                           targetCompartment);
      delay(3000);

      currentState = STATE_IDLE;
      hasPendingDose = false;
      targetCompartment = 0;
      firebaseDoseHour = -1;
      firebaseDoseMin = -1;
      nextMedicineName = "";
      nextDoseTimeString = "";
      allLEDsOff();

      drawDoseScreen(rtc.now());
      fetchScheduleFromFirebase();
    }
  }

  // TFT CLOCK UPDATE WHEN IDLE
  if (currentState == STATE_IDLE) {
    static int lastSecond = -1;
    if (now.second() != lastSecond) {
      lastSecond = now.second();
      updateClock(now);
    }
  }

  // MIDNIGHT RESET
  if (now.hour() == 0 && now.minute() == 0) {
    lastTriggeredHour = -1;
    lastTriggeredMin = -1;
  }

  delay(20);
}