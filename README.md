# 🚨 Vita ResQ — Real-Time Emergency Response & Coordination Platform

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-blue.svg)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](pubspec.yaml)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)

**Vita ResQ** is a real-time emergency coordination platform designed to connect people experiencing an emergency with appropriate nearby assistance.

The core problem is not always the complete absence of help. Sometimes, potentially helpful people or resources are nearby but are not connected to the person who needs assistance.

Vita ResQ aims to reduce this coordination gap through location-aware emergency alerts, responder coordination, and live location sharing. Its architecture includes online communication through Firebase and an offline peer-to-peer communication pathway using Google Nearby Connections.

> **Important:** Vita ResQ does not replace ambulances, medical professionals, or official emergency services. In India, contact **112** or the appropriate emergency service during a life-threatening emergency. Vita ResQ is intended to coordinate additional appropriate assistance where available.

---

## 🌟 Key Features

### 🚨 1. Emergency SOS

- Hold-to-activate SOS interaction designed to reduce accidental triggers.
- Captures the device's current GPS coordinates when location services and permissions are available.
- Creates an emergency request with a unique identifier and status.
- Supports emergency status updates and history.

### 📡 2. Hybrid Online and Offline Communication

**Online communication**
- Firebase Authentication for user identity.
- Cloud Firestore for emergency data and real-time updates.
- Firebase Cloud Messaging (FCM) for push notifications.
- Firebase Cloud Functions for server-side emergency dispatch and nearby-user matching.

**Offline communication**
- Google Nearby Connections for direct peer-to-peer communication between nearby devices.
- Local emergency record storage.
- Synchronization attempts when internet connectivity returns.

The application is designed to select an active communication mode according to connectivity. Offline peer-to-peer communication depends on compatible nearby devices, permissions, and successful connections; it does not guarantee delivery across arbitrary distances.

### 📍 3. Location-Aware Emergency Dispatch

- Uses device GPS coordinates to identify nearby potential responders.
- Supports a staged search radius, beginning at 500 metres and expanding through larger configured distances.
- Notifies multiple eligible online users within the active search radius.
- Tracks notified users to help avoid repeated alerts for the same emergency.
- Uses straight-line distance calculations for initial proximity filtering.

Actual responder availability, location accuracy, notification delivery, and network connectivity can affect dispatch results.

### 🤝 4. Responder Coordination

- Allows users to offer assistance through the emergency claim workflow.
- Supports `PRIMARY` and `STANDBY` responder roles.
- Tracks responder status and location.
- Includes claim-handshake logic intended to coordinate responder acceptance.
- Includes a reliability-monitoring component designed to identify stale location updates or lack of progress and attempt standby promotion.

Automatic handover is a coordination mechanism, not a guarantee that a replacement responder will always be available.

### 🗺️ 5. Maps and Road Routing

- **OpenStreetMap** provides map tiles.
- **Flutter Map** renders maps, markers, and route polylines.
- **Geolocator** obtains device location and location updates.
- **OSRM** provides road-route geometry, distance, and estimated duration.
- **latlong2** supports geographic coordinate operations.

Route estimates are approximate and should not be treated as guaranteed arrival times. Public map-tile and routing endpoints may have usage limits and are not guaranteed production infrastructure.

### 🚗 6. Sensor-Assisted Crash Detection

- Uses motion data from device sensors, including accelerometer-related and gyroscope streams.
- Evaluates acceleration, rotational movement, and available speed context.
- Uses rule-based scoring to classify events as normal, possible, or suspected.
- Includes a confirmation workflow intended to reduce accidental emergency activation.

This is experimental, sensor-assisted detection—not a certified crash-detection system. It requires real-world validation before being relied upon for safety-critical use.

### 🛡️ 7. Security and Data Integrity

- Firebase Authentication and Firestore Security Rules provide identity and access-control mechanisms.
- Emergency creation checks the authenticated user's identity.
- Peer-to-peer messages include an application-level SHA-256 integrity check.
- Emergency records can be retained locally while awaiting synchronization.

These mechanisms are not a substitute for a comprehensive security review. SHA-256 integrity checking alone does not provide encryption or robust authentication against malicious participants.

---

## 🏗️ Architecture Overview

```text
                     User activates SOS
                             |
                       Obtain GPS
                             |
                  Create emergency request
                             |
                Connectivity / Mode Manager
                       /           \
                      /             \
               ONLINE MODE       OFFLINE MODE
                  |                   |
           Firebase services    Nearby Connections
                  |              Peer-to-peer
            Firestore + FCM      Local storage
            Cloud Functions          |
                  |                   |
                  +---------+---------+
                            |
                  Emergency coordination
                            |
                 Responder claim workflow
                  PRIMARY / STANDBY
                            |
                Live location and routing
                            |
                Arrival and status updates
                            |
                   Emergency completion
```

The online and offline communication paths have different capabilities. Cloud notifications and synchronization require internet connectivity, while peer-to-peer communication depends on local device discovery and connectivity.

---

## 🧰 Technology Stack

| Layer | Technologies |
|---|---|
| Mobile application | Flutter, Dart |
| Authentication | Firebase Authentication |
| Cloud database | Cloud Firestore |
| Push notifications | Firebase Cloud Messaging |
| Backend dispatch | Firebase Cloud Functions, Node.js, JavaScript |
| Offline communication | Google Nearby Connections |
| Maps | OpenStreetMap, Flutter Map |
| Location | Geolocator |
| Road routing | OSRM |
| Geographic utilities | latlong2 |
| Sensor data | sensors_plus |
| Local persistence | shared_preferences |
| Permissions and external intents | permission_handler, url_launcher |
| Testing and linting | Flutter Test, flutter_lints, ESLint |

---

## 📁 Repository Structure

```text
├── android/                       # Android configuration
├── ios/                           # iOS configuration
├── functions/                     # Firebase Cloud Functions
├── lib/
│   ├── core/                      # Theme, constants, navigation
│   ├── models/                    # User, emergency, responder models
│   ├── screens/                   # App screens
│   ├── services/                  # Dispatch, networking, GPS, routing
│   └── widgets/                   # Reusable UI components
├── test/                          # Automated tests
├── pubspec.yaml                   # Flutter dependencies
├── firebase.json                  # Firebase project configuration
├── firestore.rules                # Firestore access rules
├── VITA_RESQ_FEATURES.md           # Feature reference
└── VITA_RESQ_MASTER_CHANGELOG.md   # Project changelog and specifications
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK compatible with the project.
- Android Studio and Android SDK for Android development.
- A configured Firebase project for online functionality.
- Firebase CLI for deploying Cloud Functions and security rules.
- Compatible physical devices for testing peer-to-peer communication.

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/Ayushp-123/vita-resq.git
   cd vita-resq
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Configure Firebase credentials and platform configuration files as required for your environment.

4. Run the automated tests:

   ```bash
   flutter test
   ```

5. Launch the app on a connected device:

   ```bash
   flutter run
   ```

6. If deploying backend functions, install the Node.js dependencies inside `functions/` and deploy using the Firebase CLI.

**Note:** The repository's actual branch, project configuration, Firebase setup, and device requirements should be verified before following these steps. Online and offline features should be tested separately on physical devices.

---

## 🧪 Testing and Validation

Important areas to validate include:

- SOS creation and emergency status transitions.
- Authentication and authorization rules.
- Multiple-recipient notification delivery.
- Duplicate-notification prevention.
- Responder acceptance and role assignment.
- GPS accuracy and live location updates.
- Search-radius expansion.
- Offline peer discovery and emergency exchange.
- Online/offline transitions and record synchronization.
- False-positive behavior in sensor-assisted crash detection.
- Access control for sensitive user and emergency location data.

Automated tests are useful, but successful physical-device tests are essential for evaluating emergency workflows.

---

## 🎯 Project Objective

Vita ResQ aims to make emergency assistance more coordinated by connecting a person in need with appropriate nearby help when it is available.

**The guiding principle is simple:**

> The problem is not always the absence of help. It can also be the lack of coordination between available help and the person who needs it.

Vita ResQ is designed to work alongside existing professional emergency services by providing an additional layer for nearby assistance and responder coordination.
