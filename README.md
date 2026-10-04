# 🚨 Vita ResQ — Autonomous & Civilian Emergency Response Network

[![Flutter Tests](https://img.shields.io/badge/Flutter%20Tests-Passing-brightgreen.svg)](test/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue.svg)](pubspec.yaml)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)

**Vita ResQ** (formerly *Jan Sarthi*) is a resilient, hybrid emergency dispatch and civilian mutual-aid coordination platform engineered to save lives during critical first-response minutes. It combines online cloud infrastructure with offline direct peer-to-peer (P2P) connectivity to guarantee uninterrupted alert delivery even in zero-connectivity disaster zones.

> **Disclaimer:** Vita ResQ is a civilian mutual-aid assistance platform and does **not** replace national emergency services (112 / 911). In life-threatening emergencies, always contact official authorities directly.

---

## 🌟 Key Capabilities

- 🚨 **Hold-to-Activate SOS**: Deliberate 1.5-second press-and-hold trigger with glowing circular progress ring, haptics, and accidental tap cancellation.
- 📡 **Dual-Mode Hybrid Transport**:
  - **Online**: Firebase Firestore streams + Cloud Functions geofencing + FCM push notifications.
  - **Offline**: Google Nearby Connections direct P2P over BLE / Wi-Fi Direct with zero internet dependency.
  - **Application-Layer Integrity**: Pure-Dart FIPS 180-4 SHA-256 payload signing and tamper rejection (`P2PPayloadIntegrity`).
  - **Mutual Exclusion**: Seamless automatic fallback and background sync when network is restored.
- 👥 **Authoritative Two-Way Claim Handshake**: Multi-tier responder pool supporting `PRIMARY` and `STANDBY` roles with authoritative victim-side arbitration preventing split-brain states.
- ⚡ **Dynamic Reliability Watchdog & Auto-Handover**: Continuously monitors responder ETA, progress, and GPS staleness. 120-second stall timer prevents false failovers at traffic lights while detecting genuine responder stalling.
- 🗺️ **Open-Source Navigation**: Powered by OpenStreetMap and OSRM for live road routing, polylines, and dynamic ETA with direct Haversine fallback and 8-meter movement throttling.
- 🛡️ **Zero Dangerous Permissions**: Compliant intent-based emergency SMS via `url_launcher` without requiring Google Play Store-restricted `SEND_SMS` permissions.
- 🚗 **Sensor-Assisted Crash Detection**: Multi-sensor scoring matrix evaluating linear acceleration, angular rotation, velocity drop, and vehicle context with a 15-second cancellable confirmation dialog.

---

## 🏗️ Architecture Overview

```text
                                [ User Holds SOS (1.5s) ]
                                            │
                       ┌────────────────────┴────────────────────┐
                       ▼                                         ▼
               [ Online Mode ]                            [ Offline Mode ]
           Firestore + FCM + OSRM                      Nearby Direct P2P (BLE/Wi-Fi)
                       │                                   + SHA-256 Integrity
                       └────────────────────┬────────────────────┘
                                            ▼
                                [ Two-Way Claim Handshake ]
                                • PRIMARY (Live Route HUD)
                                • STANDBY (Hot Backup)
                                            │
                                            ▼
                           [ ResponderReliabilityMonitor ]
                                • Telemetry Watchdog (>15s)
                                • Stall Watchdog (>120s)
                                • Standby Promotion
```

---

## 📁 Repository Structure

```text
├── android/                        # Android native configuration & manifests
├── functions/                      # Firebase Cloud Functions (backend dispatch)
├── ios/                            # iOS native configuration & Info.plist
├── lib/
│   ├── core/                       # Theme, styling, constants, & navigation
│   ├── models/                     # Schemas for users, emergencies, & responders
│   ├── screens/                    # UI screens (Home, SOS Map, Details, History, Auth)
│   ├── services/                   # Business logic, P2P networking, OSRM routing, integrity
│   └── widgets/                    # Custom UI widgets (Hold SOS button, OSM Map, Banners)
├── test/                           # Automated unit, widget, and integration test suites
├── pubspec.yaml                    # Dependencies and asset declarations
├── VITA_RESQ_FEATURES.md           # Quick-reference feature notepad (122 features)
└── VITA_RESQ_MASTER_CHANGELOG.md   # Canonical master project changelog & specification
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- [Android Studio](https://developer.android.com/studio) / Android SDK (API 21+)
- [Firebase CLI](https://firebase.google.com/docs/cli) (optional for deploying functions)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Ayushp-123/jan-sarthi.git
   cd jan-sarthi
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run tests:**
   ```bash
   flutter test
   ```

4. **Launch the application:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

Run the full automated test suite (93 tests):
```bash
flutter test
```

Tests cover:
- SOS Dispatch Security & Rule Invariants (8 tests: UID impersonation protection, bounded radius, GPS streams)
- P0 Integrity Fixes (cache isolation, GPS thresholds, stall timers, audio assets)
- P1 Core Emergency Experience (reactive streams, intent SMS, two-way claim handshake, mutex persistence)
- P2 UI/UX & Product Identity (Vita ResQ theme, hold SOS button, user-scoped history, accessibility)
- P3 Security & Technical Hardening (SHA-256 integrity, tamper rejection, cache guards)
- P4 Release Validation (crash evaluator, false-positive suppression, dual transport dispatch)
- Master stability, models, and civic impact rewards

---

## 📄 Canonical Documentation

- 👉 **[VITA_RESQ_MASTER_CHANGELOG.md](VITA_RESQ_MASTER_CHANGELOG.md)** — The single canonical source of truth for the complete project history, architecture, feature inventory, security audits, and engineering decision log.
- 👉 **[VITA_RESQ_FEATURES.md](VITA_RESQ_FEATURES.md)** — Quick-reference feature notepad for demo preparation, PPT presentations, and testing.

