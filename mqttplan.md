To meet both your professor's requirements with the **fastest and minimal effort**, the optimal architecture is to position your **Raspberry Pi as a Central Gateway & MQTT Broker** between Firebase and your ESP32.

---

### System Architecture

```
┌─────────────────┐       Firestore API      ┌───────────────────────┐
│   Flutter App   │ ◄─────────────────────► │   Firebase Firestore  │
└─────────────────┘                          └───────────┬───────────┘
                                                         │
                                            (Python Firestore SDK)
                                                         │
                                                         ▼
                                             ┌───────────────────────┐
                                             │     Raspberry Pi      │
                                             │ • Mosquitto Broker    │
                                             │ • Python Bridge Script│
                                             └───────────┬───────────┘
                                                         │
                                               (MQTT over Wi-Fi)
                                                         │
                                                         ▼
                                             ┌───────────────────────┐
                                             │         ESP32         │
                                             │ (Sensors, Screen, LEDs│
                                             └───────────────────────┘
```

1. **0 Flutter App Changes**: The mobile app continues reading and writing to Firebase Firestore as usual.
2. **ESP32 is simplified**: ESP32 drops the complex Firebase library and communicates purely over local Wi-Fi via lightweight **MQTT** (`PubSubClient`).
3. **Raspberry Pi handles central logic**: Raspberry Pi hosts the **Mosquitto MQTT Broker** and runs a Python script that bridges Firebase and MQTT.

---

### Step 1: Set Up Mosquitto MQTT Broker on Raspberry Pi (5 mins)

Open a terminal on your Raspberry Pi and execute:

```bash
# 1. Update and install Mosquitto MQTT broker & clients
sudo apt update
sudo apt install -y mosquitto mosquitto-clients

# 2. Configure Mosquitto to allow local network connections
sudo bash -c 'cat <<EOF > /etc/mosquitto/conf.d/default.conf
listener 1883
allow_anonymous true
EOF'

# 3. Restart and enable Mosquitto service
sudo systemctl restart mosquitto
sudo systemctl enable mosquitto
```

---

### Step 2: Raspberry Pi Python Bridge Script (10 mins)

On your Raspberry Pi, install `paho-mqtt` and `firebase-admin`:

```bash
pip3 install paho-mqtt firebase-admin
```

Create a file named `pi_bridge.py` on your Raspberry Pi:

```python
import json
import time
import paho.mqtt.client as mqtt
import firebase_admin
from firebase_admin import credentials, firestore

# --- 1. FIREBASE INITIALIZATION ---
# Download your serviceAccountKey.json from Firebase Console:
# Project Settings -> Service accounts -> Generate new private key
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- 2. MQTT CONFIGURATION ---
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
TOPIC_SCHEDULE = "smart_medicine/schedule"
TOPIC_EVENTS = "smart_medicine/events"
TOPIC_HEARTBEAT = "smart_medicine/heartbeat"

def on_connect(client, userdata, flags, rc):
    print(f"[Pi Bridge] Connected to MQTT Broker with result code {rc}")
    client.subscribe(TOPIC_EVENTS)
    client.subscribe(TOPIC_HEARTBEAT)

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode('utf-8'))
        print(f"[Pi Bridge] Received on {msg.topic}: {payload}")

        if msg.topic == TOPIC_EVENTS:
            # Sync logs from ESP32 -> Firebase Firestore
            user_id = payload.get("userId", "default_user")
            db.collection("users").doc(user_id).collection("logs").add({
                "compartment": payload.get("compartment", 1),
                "eventType": payload.get("eventType", "TAKEN"),
                "details": payload.get("details", ""),
                "timestamp": firestore.SERVER_TIMESTAMP
            })
            print("[Pi Bridge] Log synced to Firebase!")

        elif msg.topic == TOPIC_HEARTBEAT:
            # Sync ESP32 heartbeat to Firebase
            user_id = payload.get("userId", "default_user")
            dev_id = payload.get("deviceId", "ESP32_001")
            db.collection("users").doc(user_id).collection("deviceState").doc(dev_id).set({
                "isOnline": True,
                "lastSeen": firestore.SERVER_TIMESTAMP,
                "batteryLevel": payload.get("batteryLevel", 100)
            }, merge=True)

    except Exception as e:
        print(f"[Pi Bridge] Error processing message: {e}")

# Setup MQTT Client
mqtt_client = mqtt.Client()
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
mqtt_client.loop_start()

# --- 3. FIRESTORE REAL-TIME LISTENER FOR SCHEDULES ---
def listen_schedules():
    def on_snapshot(col_snapshot, changes, read_time):
        for change in changes:
            if change.type.name in ['ADDED', 'MODIFIED']:
                doc = change.document.to_dict()
                doc['id'] = change.document.id
                print(f"[Pi Bridge] Schedule updated in Firebase: {doc}")
                # Publish updated schedule to ESP32 over MQTT
                mqtt_client.publish(TOPIC_SCHEDULE, json.dumps(doc))

    # Listen to medicines collection (adjust user_id as needed)
    db.collection_group("medicines").on_snapshot(on_snapshot)

print("[Pi Bridge] Gateway running. Listening for Firebase changes & MQTT messages...")
listen_schedules()

# Keep script running
while True:
    time.sleep(1)
```

---

### Step 3: Update ESP32 Sketch to use MQTT (15 mins)

Update your ESP32 code (`espcode_sketch/espcode_sketch.ino`) to use the **`PubSubClient`** library instead of `Firebase_ESP_Client`:

1. Install **PubSubClient** library in Arduino IDE (by Nick O'Leary) if not already installed.
2. Replace the Firebase connection section with MQTT:

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// Raspberry Pi IP on your local Wi-Fi network
const char* mqtt_server = "192.168.X.X"; // Change to your Pi's IP address

WiFiClient espClient;
PubSubClient mqttClient(espClient);

void setupMQTT() {
  mqttClient.setServer(mqtt_server, 1883);
  mqttClient.setCallback(mqttCallback);
}

void reconnectMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Connecting to Raspberry Pi MQTT Broker...");
    if (mqttClient.connect("ESP32_001")) {
      Serial.println("Connected!");
      mqttClient.subscribe("smart_medicine/schedule");
    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" retrying in 5 seconds");
      delay(5000);
    }
  }
}

// Receive schedule updates from Raspberry Pi
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) message += (char)payload[i];
  
  Serial.print("Message arrived on topic [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(message);

  // Parse schedule JSON sent from Pi
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, message);
  if (!error) {
    nextMedicineName = doc["name"].as<String>();
    targetCompartment = doc["compartment"].as<int>();
    // Update local ESP32 dose schedule variables...
  }
}

// Publish Event (TAKEN / MISSED) to Raspberry Pi
void syncEventToPi(String eventType, String details, int compNum) {
  StaticJsonDocument<200> doc;
  doc["deviceId"] = "ESP32_001";
  doc["compartment"] = compNum;
  doc["eventType"] = eventType;
  doc["details"] = details;

  char buffer[256];
  serializeJson(doc, buffer);
  mqttClient.publish("smart_medicine/events", buffer);
}
```

---

### Checklist to Demo to Your Professor

1. **Raspberry Pi**: Running Mosquitto MQTT Broker & `pi_bridge.py`.
2. **MQTT Protocol**: Active communication between ESP32 and Raspberry Pi on port `1883`.
3. **End-to-End Flow**:
   - App updates schedule $\rightarrow$ Firebase $\rightarrow$ Raspberry Pi Python Script $\rightarrow$ MQTT $\rightarrow$ ESP32 Alarms.
   - ESP32 Reed switch opens $\rightarrow$ MQTT $\rightarrow$ Raspberry Pi Python Script $\rightarrow$ Firebase $\rightarrow$ App updates status badge to `TAKEN`.



   Edited mqttplan.md
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Edited espcode_sketch.ino
Viewed mqttplan.md:1-26

Here is why moving to **MQTT + Raspberry Pi** allows you to cut out **over 300+ lines of complex code** from the ESP32:

---

### 1. The Core Secret: Offloading "Cloud Heavy-Lifting" to the Pi

Currently, your ESP32 is acting like a full web client. It has to handle:
* **Firebase Authentication** (logging in with user email & password).
* **SSL/TLS Encryption** (encrypting data over HTTPS for Google servers).
* **Firebase REST API Formatting** (constructing complex Firestore JSON field masks and payload wrappers).
* **Network Polling** (repeatedly querying Firebase every 2 seconds).

When you introduce the **Raspberry Pi**:
* The **Raspberry Pi** handles all the heavy Firebase Auth, SSL certificates, and Firestore database operations (which Python does easily in 10 lines of code).
* The **ESP32** only talks simple, lightweight **MQTT text messages** over your local home Wi-Fi directly to the Pi.

---

### 2. Direct Code Comparison: Before vs. After on ESP32

#### A. Firebase Sync vs. MQTT Sync (Log Event)

**BEFORE (ESP32 directly to Firestore - ~45 lines):**
```cpp
// ESP32 had to build complex Firestore JSON structures manually:
FirebaseJson content;
content.set("fields/eventType/stringValue", eventType);
content.set("fields/details/stringValue", details);
content.set("fields/compartment/integerValue", compNum);
content.set("fields/timestamp/integerValue", rtc.now().unixtime());

String documentPath = "users/" + String(USER_UID) + "/logs";
if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.raw())) {
    Serial.println("Logged to Firestore!");
} else {
    Serial.println(fbdo.errorReason());
}
```

**AFTER (ESP32 via MQTT to Pi - 3 lines!):**
```cpp
// ESP32 just sends a simple 1-line text message to the Pi:
String payload = "{\"comp\":" + String(compNum) + ",\"event\":\"" + eventType + "\"}";
mqttClient.publish("smart_medicine/events", payload.c_str());
```
*(The Pi's Python script receives this 1 line and writes it to Firestore!)*

---

#### B. Heavy Firebase Libraries vs. Lightweight MQTT

| Metric / Task | Current ESP32 (Firebase Direct) | New ESP32 (MQTT via Pi) |
| :--- | :--- | :--- |
| **Header Library** | `Firebase_ESP_Client.h` (~500KB Flash Memory) | `PubSubClient.h` (~10KB Flash Memory) |
| **Authentication** | Email, Password, API Key, Refresh Tokens | None needed (Local Wi-Fi connection to Pi) |
| **Network Protocol** | HTTPS / TLS REST API (Slow, heavy headers) | MQTT Packets (Ultra-fast, ~20 byte header) |
| **Receiving Schedules**| Polls Firebase every 2 seconds in `loop()` | Pi **pushes** schedule to ESP32 instantly via callback |
| **ESP32 Code Size** | ~850 lines of C++ | **~450 lines of C++ (50% reduction!)** |

---

### Summary of What Gets Removed from ESP32:

1. **Delete** `Firebase_ESP_Client.h`, `RTDBHelper.h`, `TokenHelper.h`.
2. **Delete** `USER_EMAIL`, `USER_PASSWORD`, `API_KEY`, `FIREBASE_PROJECT_ID` macros.
3. **Delete** `fetchScheduleFromFirebase()`, `updateDeviceHeartbeat()`, and `syncEventToFirestore()`.
4. **Delete** 2-second `millis()` timer loops for Firestore syncing.

### What Replaces It:
* A lightweight 30-line `PubSubClient` MQTT setup that connects to your Raspberry Pi's IP address. 
* All hardware control logic (LCD, LEDs, Buzzer, Reed switches) remains untouched!


Viewed mqttplan.md:231-254
Edited mqttplan.md

### What is MQTT?

**MQTT** (*Message Queuing Telemetry Transport*) is a super lightweight messaging protocol designed specifically for **IoT (Internet of Things)** devices.

Think of MQTT like a **Post Office** or a **Radio Station**. 

Instead of devices talking directly to each other or making heavy web requests, they communicate through a central middleman called the **MQTT Broker** (which runs on your Raspberry Pi).

---

### The Core Concept: Publish & Subscribe

MQTT works on 3 basic concepts:

1. **Broker (The Central Station / Raspberry Pi)**
   * Holds the connections, receives all messages, and routes them to the right devices.
   * Runs the software called `Mosquitto`.

2. **Topics (The Radio Channels / Mailing Addresses)**
   * Messages are categorized under named paths called **Topics**.
   * Examples:
     * `smart_medicine/schedule` (Channel for medication schedules)
     * `smart_medicine/events` (Channel for lid openings / alarms)

3. **Publish & Subscribe**
   * **Publish (Send)**: A device broadcasts a message to a topic.
     * *Example*: When compartment 1 lid opens, ESP32 **publishes**: `{"comp": 1, "event": "TAKEN"}` to `smart_medicine/events`.
   * **Subscribe (Listen)**: A device tunes into a topic to get instant updates.
     * *Example*: ESP32 **subscribes** to `smart_medicine/schedule`. The exact millisecond the Pi sends a new alarm schedule, the ESP32 receives it instantly.

---

### Why MQTT is Perfect for IoT (vs HTTP/REST)

| Feature | Standard Web (HTTP / REST) | MQTT |
| :--- | :--- | :--- |
| **Connection Style** | Opens & closes a new connection every request | Keeps 1 tiny persistent connection open |
| **Communication** | **Polling**: ESP32 asks server *"Any news?"* every 2s | **Push**: Raspberry Pi notifies ESP32 *immediately* when data changes |
| **Header Size** | ~500 to 2000 bytes (Heavy) | **2 bytes** (Extremely lightweight) |
| **RAM / Power Usage**| High (Needs SSL encryption, complex parsing) | Minimal (Perfect for microcontrollers like ESP32) |

---

### In Simple Words for Your Project:

* **ESP32**: *"Hey Pi, I'm listening to `smart_medicine/schedule`."*
* **Pi**: *"Got it! Whenever Firebase gets a new schedule, I'll push it right to you."*
* **ESP32 (User takes pill)**: *"Hey Pi, publishing `Pill Taken` to `smart_medicine/events`!"*
* **Pi**: *"Got it! Writing that to Firebase for the Flutter App right now!"*