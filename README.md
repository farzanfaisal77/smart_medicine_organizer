# Smart Medicine Companion — Application Requirement Document (ARD)


**Tech Stack:** Mobile Framework (Flutter / React Native / Native Android), Firebase (Auth, Firestore, Cloud Functions, FCM)

**Hardware Integration:** ESP32 Microcontroller (Wi-Fi connected)

---

## Executive Summary & Hardware Context

The **Smart Medicine Companion** app manages hardware settings and medication tracking for a 6-compartment physical organizer powered by an ESP32.

> **Important Hardware Note for Developer:**
> The physical hardware currently has functional **Reed Switches**, **LEDs**, **Buzzer**, **TFT Screen**, and **DS3231 RTC**.
> **Load Cells (HX711) are currently disabled/pending in hardware.** The app must handle intake confirmation strictly using **Reed Switch triggers (Lid Open/Close)** until weight sensing is integrated in Phase 2.

---

## 1. Firebase Firestore Database Schema

Following collection structure in Firebase Firestore:

```text
/users/{userId}
   │
   ├── deviceId: "ESP32_001"
   ├── name: "John Doe"
   ├── email: "john@example.com"
   ├── 
   │
   ├── /medicines/{medicineId}
   │      ├── name: "Aspirin"
   │      ├── compartment: 1          // Range: 1 to 6
   │      ├── dosage: "1 Pill"
   │      ├── instructions: "Take with water after food"
   │      ├── times: ["08:00", "20:00"] // HH:mm 24hr format
   │      ├── days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
   │      ├── active: true
   │      └── createdAt: Timestamp
   │
   ├── /logs/{logId}
   │      ├── compartment: 1
   │      ├── timestamp: Timestamp
   │      ├── eventType: "TAKEN" | "MISSED" | "WRONG_COMPARTMENT"
   │      └── details: "Lid opened on time"
   │
   └── /deviceState/{deviceId}
          ├── isOnline: true
          ├── batteryLevel: 85
          ├── lastSeen: Timestamp
          └── compartmentStatus: [
                { "id": 1, "isOpen": false, "ledOn": false },
                { "id": 2, "isOpen": true,  "ledOn": true  },
                ...
              ]

```

---

## 2. Screen Specifications & UI/UX Requirements

### Screen 1: Authentication & Pairing

* **UI Elements:**
* Clean login interface (Email/Password).
* Sign Up button with basic profile creation.
* **Device ID Pairing Field:** Text input or QR code scanner to bind `deviceId` (printed on ESP32 or serial output) to the user profile.


* **Logic:**
* Authenticate via Firebase Auth.
* Verify `deviceId` against existing hardware registry in Firestore.



---

### Screen 2: Main Dashboard

* **Header:**
* User Greeting & System Connection Status Badge (**Online / Offline** derived from `/deviceState/{deviceId}/isOnline`).
* Battery Percentage indicator.


* **Today's Timeline (Top View):**
* Dynamic list of all scheduled doses for current day sorted by time.
* Status badges: `Pending` (Gray), `Taken` (Green), `Missed` (Red).


* **6-Compartment Visualizer (Bottom Grid):**
* A $2 \times 3$ or $3 \times 2$ interactive grid representing physical Compartments 1 to 6.
* **Slot States:**
* **Empty:** Shows "+" button to add medicine directly to that slot.
* **Occupied:** Displays Medicine Name, Next Dose Time, Lid State (`Closed` / `Open`).
* **Alerting:** Flashes red/yellow when the hardware is actively alarming for that compartment.





---

### Screen 3: Add / Edit Medicine Form

* **Input Fields:**
1. **Medicine Name:** Text Input (Required).
2. **Compartment Selection:** Dropdown/Radio (1–6).
* *Validation:* Disable compartments already occupied. Warn user if reassigning.


3. **Dosage & Notes:** Text Input (e.g., "1 Tablet", "After meal").
4. **Schedule Configurator:**
* Time picker for multiple daily times (e.g., 08:00 AM, 08:00 PM).
* Frequency selector (Daily, Specific Days of the Week).


5. *(Disabled / Hidden in Phase 1)* **Load Cell Calibration/Tare Button:** Keep UI space reserved in code for weight calibration once HX711 hardware is connected.



---

### Screen 4: Deletion & Discontinuation Flow

* **Action:** Triggered via Medicine Details menu.
* **UX Flow:**
1. User selects "Discontinue / Delete Medicine".
2. Modal Popup: *"Please clear physical Compartment [X] before confirming."*
3. App sends payload to Firestore updating `active: false` or deleting document.
4. ESP32 updates immediately, clearing its internal RTC alarm memory and turning off any active LEDs/Buzzers for that compartment.



---

### Screen 5: Real-Time Activity & Adherence Logs

* **Feed Display:** Reverse chronological list of raw and parsed hardware events.
* **Log Entries Example:**
* `[08:01 AM]` ✅ **Compartment 1 Opened** — Dosage taken on schedule.
* `[01:15 PM]` ⚠️ **Compartment 3 Opened** — Unscheduled or wrong compartment opened!
* `[09:00 PM]` ❌ **Compartment 2 Missed** — No lid activity detected within 60 mins.


* **Filtering:** Filter logs by Date Range or Compartment.

---

### Screen 6: App & Device Settings

* **Alert Configurations:**
* Toggle Push Notifications (FCM).
* Toggle SMS / Email notifications


* **Hardware Buzzer / LED Settings:**
* Slider for Buzzer Duration / Volume (writes config values to Firestore, read by ESP32).


---

## 3. Hardware Interfacing & Verification Logic (Phase 1)

Since the **Load Cell is not yet enabled**, Program the cloud validation logic based strictly on the **Reed Switch (Digital HIGH/LOW)** events:

```
                  ┌────────────────────────┐
                  │ Scheduled Time Reached │
                  └───────────┬────────────┘
                              │
                    ESP32 Triggers Alarm 
                   (Buzzer + LED + Screen)
                              │
                   ┌──────────┴──────────┐
                   ▼                     ▼
          Lid Opened within      No Lid Opened within
           Time Window             Grace Period
                   │                     │
                   ▼                     ▼
             Reed Switch            Firebase Cloud
            Trigger HIGH            Function Alerts
                   │                     │
                   ▼                     ▼
             Log: "TAKEN"          Log: "MISSED" +
             Turn off LED          Send Push Alert

```