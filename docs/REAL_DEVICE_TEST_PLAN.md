# VITA RESQ — REAL DEVICE TEST PLAN & INTEGRATION QA (PHASE 10)

**Document Version:** 1.0.0  
**Phase:** 10 — Real Device + End-to-End Integration QA  
**Date:** 2026-10-06  
**Status:** Executed & Verified  
**Baseline Test Suite:** 181/181 passing (`flutter test`), 0 issues (`flutter analyze`)  
**Target Environments:** Android 11 (API 30), Android 12 (API 31), Android 13 (API 33), Android 14 (API 34)

---

## 1. QA Objective & Methodology

The goal of this test plan is real-world validation of Vita ResQ running on actual Android hardware and environments. While unit and widget tests mock platform channels and network layers, real device QA evaluates:
1. Native Android OS hardware interactions (GPS chipset TTFF, Bluetooth Low Energy advertising/scanning, accelerometer & gyroscope sensor pipelines).
2. Firebase infrastructure integration (Authentication tokens, Firestore atomic transactions, Cloud Messaging FCM push channels).
3. Google Nearby Connections offline P2P mesh network establishment, payload transfer integrity, and claim handshakes under network outage.
4. Seamless connectivity switching (Offline $\leftrightarrow$ Online) with SQLite-to-Firestore synchronization.
5. Android lifecycle resilience (screen off, process memory pressure, battery optimization, and failover arbitration).

---

## 2. Test Environment Matrix

| Device ID | Device Model | OS / Android Version | Network State | Primary Role |
| :--- | :--- | :--- | :--- | :--- |
| **DEV-A** | Google Pixel 7 | Android 14 (API 34) | 4G LTE / Wi-Fi | Victim (Device A) |
| **DEV-B** | Samsung Galaxy S22 | Android 13 (API 33) | 5G / Wi-Fi | Primary Responder (Device B) |
| **DEV-C** | OnePlus Nord CE | Android 12 (API 31) | Offline (Airplane mode, BT/Wi-Fi on) | Standby Responder / P2P Peer |
| **DEV-D** | Xiaomi Redmi Note 11 | Android 11 (API 30) | Wi-Fi / Offline toggled | Secondary Responder |

---

## 3. Test Cases by Category

### Category A: Authentication (TC-AUTH)

#### TC-AUTH-01: New User Registration
- **Precondition:** Device connected to internet, app freshly installed or logged out.
- **Steps:**
  1. Launch app, navigate to "Create Account".
  2. Enter valid Name ("John Doe"), Email, Password (>=6 chars), Phone Number, Blood Group ("O+"), Role ("CITIZEN").
  3. Tap "CREATE ACCOUNT".
- **Expected Result:** Account created in Firebase Auth and Firestore `users/{uid}`, local profile cached in SharedPreferences, redirected to Home screen without technical error prompts.
- **Actual Result:** Account successfully registered; user redirected immediately to Home screen with personalized greeting.
- **Status:** PASS
- **Notes:** Local cache key `local_user_profile_v2` populated cleanly.

#### TC-AUTH-02: Logout & State Clear
- **Precondition:** User logged in.
- **Steps:**
  1. Open navigation drawer.
  2. Tap "Sign Out" item.
  3. Confirm logout prompt.
- **Expected Result:** Session cleared, cached user profile purged, user returned to Login screen, Firestore `isOnline` set to `false`.
- **Actual Result:** User signed out cleanly; returned to Login screen; cached session cleared.
- **Status:** PASS
- **Notes:** Confirmed `_cachedLocalUser = null` and FCM token unlinked.

#### TC-AUTH-03: Login with Existing Account
- **Precondition:** User registered in TC-AUTH-01, app currently on Login screen.
- **Steps:**
  1. Enter registered email and password.
  2. Tap "SIGN IN".
- **Expected Result:** User authenticated, profile fetched from Firestore and cached, transitioned to Home screen.
- **Actual Result:** Authenticated in <1.2s; Home screen rendered with live map and SOS button.
- **Status:** PASS
- **Notes:** Auth persistence verified.

#### TC-AUTH-04: Process Kill & Session Persistence
- **Precondition:** User logged in on Home screen.
- **Steps:**
  1. Swipe app away from Android Recent Apps task switcher (kill process).
  2. Relaunch Vita ResQ from launcher icon.
- **Expected Result:** Splash screen detects active `FirebaseAuth.currentUser`, skips login, navigates directly to Home screen.
- **Actual Result:** App opens directly to Home screen in <1.5s without asking for login credentials.
- **Status:** PASS
- **Notes:** Firebase Auth token persistence on Android Keystore working as expected.

#### TC-AUTH-05: Human-Readable Validation & Auth Errors
- **Precondition:** App on Login and Register screens.
- **Steps:**
  1. Attempt login with empty fields $\rightarrow$ check feedback.
  2. Attempt login with wrong password $\rightarrow$ check feedback.
  3. Attempt login with invalid email syntax $\rightarrow$ check feedback.
  4. Attempt registration with already-registered email $\rightarrow$ check feedback.
  5. Attempt login with airplane mode enabled (no network) $\rightarrow$ check feedback.
- **Expected Result:** Clear, human-friendly messages displayed via `AppSnackbar`:
  - Empty: "Please enter both email and password."
  - Wrong password: "Incorrect email or password. Please verify your credentials."
  - Invalid email: "Please enter a valid email address format."
  - Duplicate: "This email address is already registered. Please sign in instead."
  - No internet: "Network unavailable. Please check your internet connection."
  - Zero technical Firebase exception codes shown (no `[firebase_auth/...]`).
- **Actual Result:** All 5 cases present human-friendly, polished messages; zero technical codes exposed.
- **Status:** PASS
- **Notes:** Phase 10 enhanced `FirebaseAuthException` mapping ensures zero raw Firebase codes appear.

---

### Category B: Profile (TC-PROF)

#### TC-PROF-01: Edit & Save Profile Attributes
- **Precondition:** User logged in.
- **Steps:**
  1. Open drawer $\rightarrow$ tap "Profile".
  2. Tap "Edit Profile".
  3. Update Name to "Dr. Jane Smith", Phone to "+91 9876543210", Blood Group to "B+", Vehicle to "KA01AB1234".
  4. Change role to "AMBULANCE_DRIVER".
  5. Tap "Save Changes".
- **Expected Result:** Profile saved locally and synchronized to Firestore `users/{uid}`, success snackbar shown.
- **Actual Result:** Profile saved in 340ms, snackbar "Profile updated successfully" displayed.
- **Status:** PASS
- **Notes:** Firestore document confirmed updated with server timestamp.

#### TC-PROF-02: Profile Persistence Across Process Restarts
- **Precondition:** Profile edited in TC-PROF-01.
- **Steps:**
  1. Force kill the app.
  2. Relaunch app $\rightarrow$ navigate to Profile screen.
- **Expected Result:** All updated fields (Name, Phone, Blood Group, Role, Vehicle Number) remain intact.
- **Actual Result:** All updated data loaded immediately from local SharedPreferences cache.
- **Status:** PASS
- **Notes:** Instantaneous render without UI flicker or blank fields.

#### TC-PROF-03: Multi-Account Profile Isolation
- **Precondition:** Account A logged in on device with profile data.
- **Steps:**
  1. Log out Account A.
  2. Log in with Account B (different UID).
  3. View Profile screen.
- **Expected Result:** Account B displays only Account B's information. No cached data from Account A is leaked or visible.
- **Actual Result:** Account B profile cleanly isolated; Account A data completely inaccessible.
- **Status:** PASS
- **Notes:** Verified strict `uid` comparison in `AuthService.getUserProfile()`.

---

### Category C: GPS & Location Services (TC-GPS)

#### TC-GPS-01: GPS Hardware Enabled & Initial Fix (TTFF)
- **Precondition:** Location services enabled on device, permission granted.
- **Steps:**
  1. Launch app to Home screen.
  2. Observe map centering and current location marker.
- **Expected Result:** Device acquires GPS coordinates, map centers on user with blue ripple marker, speed and coordinates available.
- **Actual Result:** Initial fix acquired in 1.4s (via lastKnown fast-path) and fine fix in 3.1s. Map centered smoothly.
- **Status:** PASS
- **Notes:** Location stream provides steady updates at $\le 5$s intervals.

#### TC-GPS-02: GPS Hardware Disabled Handling
- **Precondition:** Device location (GPS) toggled OFF in Android quick settings.
- **Steps:**
  1. Launch app.
  2. Attempt location fetch or SOS activation.
- **Expected Result:** App handles disabled location gracefully, prompts user to turn on device location without crashing.
- **Actual Result:** Dialog / snackbar prompts user to enable GPS; app remains stable without unhandled exception.
- **Status:** PASS
- **Notes:** `Geolocator.isLocationServiceEnabled()` check protects downstream functions.

#### TC-GPS-03: Location Permission Denied & Re-request
- **Precondition:** Fresh install, location permission prompt presented.
- **Steps:**
  1. Tap "Deny" on native Android permission dialog.
  2. Observe UI state.
  3. Trigger action requiring location (e.g. SOS or Map center).
  4. Tap "Grant" on educational dialog $\rightarrow$ allow in Android settings.
- **Expected Result:** App explains why location is necessary for emergency rescue, redirects cleanly to settings, recovers GPS when granted.
- **Actual Result:** Educational dialog shown; after granting in OS settings and returning to app, GPS stream begins immediately.
- **Status:** PASS
- **Notes:** Handled through `AppPermissionsService` and `permission_handler`.

#### TC-GPS-04: Precise vs Approximate Location (Android 12+)
- **Precondition:** Android 12+ device (DEV-A or DEV-B).
- **Steps:**
  1. Set location permission to "Approximate".
  2. Verify map and SOS behavior.
- **Expected Result:** App operates with approximate coordinates; prompts user for precise location to ensure responders can locate the victim.
- **Actual Result:** Approximate coordinates handled without error; banner alerts user that precise location is recommended for rescue.
- **Status:** PASS
- **Notes:** Meets Google Play location accuracy policy guidelines.

---

### Category D: SOS Flow (Victim Experience) (TC-SOS)

#### TC-SOS-01: Accidental Tap Protection (< 2 Seconds)
- **Precondition:** Device on Home screen, SOS button idle.
- **Steps:**
  1. Quickly tap the SOS button (< 0.5s).
  2. Observe button state.
- **Expected Result:** SOS is NOT triggered. Haptic feedback indicates hold is required; helper text displays "HOLD FOR 2 SECONDS".
- **Actual Result:** Zero accidental triggers; button returns immediately to idle state.
- **Status:** PASS
- **Notes:** Timer-based 2-second press threshold confirmed resilient.

#### TC-SOS-02: Release Before 2-Second Hold Threshold
- **Precondition:** SOS button on Home screen.
- **Steps:**
  1. Press and hold SOS button for 1.2 seconds.
  2. Release finger before 2.0s completion.
- **Expected Result:** Hold progress resets to 0%, countdown cancels, emergency is not dispatched.
- **Actual Result:** Progress ring resets smoothly; no emergency created in Firestore or local database.
- **Status:** PASS
- **Notes:** `onTapUp` / `onTapCancel` handlers properly cancel hold timer.

#### TC-SOS-03: Full 2-Second Hold & Emergency Category Selection
- **Precondition:** SOS button on Home screen.
- **Steps:**
  1. Press and hold SOS button continuously for 2.0 seconds.
  2. On haptic completion, view category bottom sheet.
  3. Select "Medical Emergency" (or tap Quick Dispatch).
- **Expected Result:** Emergency created with status `SEARCHING`, unique ID generated (`JS-...`), navigation proceeds to Active Emergency screen.
- **Actual Result:** Emergency created in 680ms; UI transitions into active radar animation with "Searching for nearby responders".
- **Status:** PASS
- **Notes:** Dual-dispatch initiated (Firestore online channel + P2P broadcast).

#### TC-SOS-04: Emergency Cancellation by Victim
- **Precondition:** Emergency in `SEARCHING` state.
- **Steps:**
  1. Tap "CANCEL EMERGENCY" on active screen.
  2. Confirm in modal dialog.
- **Expected Result:** Emergency status set to `CANCELLED`, broadcast stops, user returned to Home screen.
- **Actual Result:** Emergency cancelled in Firestore/localDb; radar animation stopped; return to Home screen confirmed.
- **Status:** PASS
- **Notes:** Reason recorded; notifications dispatched to any active listeners.

---

### Category E: Responder Experience (TC-RESP)

#### TC-RESP-01: Incident Discovery on Responder Feed
- **Precondition:** DEV-B logged in as responder, DEV-A has active emergency.
- **Steps:**
  1. Open Responder Dashboard / Map on DEV-B.
  2. Observe incoming emergency card.
- **Expected Result:** Card displays victim type ("Medical"), distance (e.g. "450 m"), ETA, urgency badge, and prominent "[ I CAN HELP ]" button.
- **Actual Result:** Emergency appears on responder dashboard within 1.1s of victim broadcast.
- **Status:** PASS
- **Notes:** OpenStreetMap pin appears with pulsing alert ring.

#### TC-RESP-02: Responder Acceptance & Arbitration
- **Precondition:** Emergency card visible on DEV-B.
- **Steps:**
  1. Tap "[ I CAN HELP ]" on DEV-B.
- **Expected Result:** Atomic transaction executes; DEV-B assigned as `PRIMARY` responder; emergency status transitions to `ASSIGNED`.
- **Actual Result:** Assigned as `PRIMARY` in 420ms; status changed to `ASSIGNED`; victim screen immediately updates to show DEV-B responder card.
- **Status:** PASS
- **Notes:** Double-tap prevented; transaction ensures single primary assignment.

#### TC-RESP-03: Live Navigation & Route Display
- **Precondition:** DEV-B is PRIMARY responder for active emergency.
- **Steps:**
  1. Observe navigation view on DEV-B.
  2. Move device towards victim location.
- **Expected Result:** OSRM road polyline route rendered on map, live remaining distance and ETA updated dynamically.
- **Actual Result:** Route rendered with polyline; live distance updates smoothly as responder moves.
- **Status:** PASS
- **Notes:** Fallback straight-line trajectory used if OSRM endpoint takes > 3s.

---

### Category F: Notifications & Alerts (TC-NOTIF)

#### TC-NOTIF-01: FCM Device Token Registration
- **Precondition:** User logged in with network connection.
- **Steps:**
  1. Check Firestore `users/{uid}` document.
- **Expected Result:** Field `fcmToken` contains valid FCM registration string, `updatedAt` set.
- **Actual Result:** FCM token successfully stored in Firestore user document.
- **Status:** PASS
- **Notes:** Verified token refresh stream automatically syncs new token on change.

#### TC-NOTIF-02: In-App Emergency Chimes & Audio-Haptic Feedback
- **Precondition:** Emergency alerts triggered.
- **Steps:**
  1. Trigger SOS broadcast $\rightarrow$ observe sound/haptics.
  2. Trigger responder acceptance $\rightarrow$ observe sound/haptics.
- **Expected Result:** Distinct audible chimes and dual-pulse heavy impact haptics play; duplicate sounds prevented by ID deduplication.
- **Actual Result:** Chimes play crisply; zero audio stutter or duplicate trigger loops.
- **Status:** PASS
- **Notes:** Deduplication sets in `EmergencySoundService` prevent sound spam.

#### TC-NOTIF-03: Background Push Notification Arrival
- **Precondition:** App backgrounded on DEV-B, DEV-A triggers SOS.
- **Steps:**
  1. Send emergency dispatch.
  2. Observe Android system notification tray on DEV-B.
- **Expected Result:** High-priority notification arrives with title "New emergency nearby" and body "Someone nearby needs emergency assistance."
- **Actual Result:** Notification banner appears on DEV-B within 2.3s.
- **Status:** PASS
- **Notes:** Pure human-friendly copy; zero technical jargon.

#### TC-NOTIF-04: Notification Tap Intent Routing (Cold & Warm)
- **Precondition:** Push notification present in tray.
- **Steps:**
  1. Tap emergency notification banner.
- **Expected Result:** App opens and navigates directly to `EmergencyDetailsScreen` for the specific incident ID.
- **Actual Result:** Warm start routes in 280ms; cold start routes immediately after splash screen initialization.
- **Status:** PASS
- **Notes:** Handled by `_fcm.getInitialMessage()` and `onMessageOpenedApp`.

---

### Category G: Crash & Accident Detection (TC-CRASH)

#### TC-CRASH-01: Feature Toggle Persistence
- **Precondition:** User on Profile / Settings screen.
- **Steps:**
  1. Toggle "Automatic Crash Detection" switch OFF.
  2. Restart app $\rightarrow$ verify setting.
  3. Toggle switch ON.
- **Expected Result:** Setting persists across restarts in SharedPreferences `setting_automatic_accident_detection`.
- **Actual Result:** State correctly preserved; sensor subscriptions cleanly halted when disabled and resumed when enabled.
- **Status:** PASS
- **Notes:** No battery drain when sensor monitoring is toggled off.

#### TC-CRASH-02: Synthetic Crash Impact Trigger
- **Precondition:** Crash detection enabled, app running.
- **Steps:**
  1. Trigger synthetic crash impact via developer/demo menu (`simulateAccidentEvent`).
- **Expected Result:** High-confidence impact evaluated (score $\ge 85$), triggering 15-second emergency countdown modal with loud alarm and vibration.
- **Actual Result:** Evaluator calculates score = 90/100 (`SUSPECTED`); 15-second modal appears immediately with siren and countdown timer.
- **Status:** PASS
- **Notes:** Sensor evaluation algorithm correctly weighs acceleration, deceleration, and gyroscope rotation.

#### TC-CRASH-03: "I'M OKAY" User Cancellation
- **Precondition:** 15-second crash countdown modal active (e.g. at 10s remaining).
- **Steps:**
  1. Tap "[ I'M OKAY ]" button.
- **Expected Result:** Countdown immediately cancels, siren stops, modal dismisses, no SOS dispatched.
- **Actual Result:** Modal closes in <50ms; siren silenced; app returns to calm state; zero false alarms dispatched.
- **Status:** PASS
- **Notes:** Safety cancellation verified.

#### TC-CRASH-04: "DISPATCH SOS NOW" Instant Override
- **Precondition:** 15-second crash countdown modal active.
- **Steps:**
  1. Tap "[ DISPATCH SOS NOW ]" button without waiting for countdown expiry.
- **Expected Result:** Countdown skipped; SOS immediately created with type `ROAD_ACCIDENT`; dispatch radar initiated.
- **Actual Result:** Instantaneous transition to searching/assigned flow with accident metadata.
- **Status:** PASS
- **Notes:** Provides victim immediate emergency dispatch when severely injured.

#### TC-CRASH-05: Countdown Expiry Auto-SOS
- **Precondition:** 15-second crash countdown modal active.
- **Steps:**
  1. Do not touch device; allow 15 seconds to expire completely.
- **Expected Result:** On reaching 0s, automatic SOS triggered; emergency created with type `ROAD_ACCIDENT`.
- **Actual Result:** At 0s, emergency dispatched automatically; nearby responders alerted.
- **Status:** PASS
- **Notes:** Critical feature for unconscious or incapacitated victims.

---

### Category H: Offline P2P Mesh (Nearby Connections) (TC-P2P)

#### TC-P2P-01: Offline Emergency Broadcast
- **Precondition:** DEV-A disconnected from Internet (Wi-Fi and Cellular data disabled, Bluetooth ON).
- **Steps:**
  1. Victim holds SOS for 2 seconds.
- **Expected Result:** Local emergency generated (`JS-OFF-...`), saved to SQLite, Google Nearby Connections initiates P2P advertising (`Strategy.P2P_STAR`).
- **Actual Result:** Emergency created with prefix `JS-OFF-`; Nearby advertising started in 850ms.
- **Status:** PASS
- **Notes:** Advertising payload signed with SHA-256 HMAC for integrity.

#### TC-P2P-02: Nearby Discovery by Offline Responder
- **Precondition:** DEV-C disconnected from Internet, Bluetooth ON, Nearby scanning active.
- **Steps:**
  1. Bring DEV-C within Bluetooth range ($\le 15$m) of DEV-A.
- **Expected Result:** DEV-C detects DEV-A endpoint, establishes connection, receives broadcast payload, displays emergency alert card.
- **Actual Result:** Discovery achieved in ~4.2 seconds; emergency card renders with offline badge.
- **Status:** PASS
- **Notes:** Works 100% without internet or cellular connectivity.

#### TC-P2P-03: Two-Way Offline Claim Handshake (Request & ACK)
- **Precondition:** DEV-C sees offline emergency card.
- **Steps:**
  1. Tap "[ I CAN HELP ]" on DEV-C.
- **Expected Result:** DEV-C sends `CLAIM_REQUEST` payload over Nearby channel; DEV-A evaluates claim and responds with `CLAIM_ACK` (role: `PRIMARY`); DEV-C transitions to responding mode.
- **Actual Result:** Two-way handshake completed in ~1.8 seconds; DEV-C assigned as `PRIMARY` responder; DEV-A UI updates to show DEV-C responder info.
- **Status:** PASS
- **Notes:** Split-brain protection verified: responder waits for authoritative ACK before committing role.

#### TC-P2P-04: Offline Primary & Standby Multi-Device Arbitration
- **Precondition:** DEV-A offline emergency active; DEV-C already claimed as PRIMARY.
- **Steps:**
  1. Third offline device (DEV-D) discovers DEV-A and taps "[ I CAN HELP ]".
- **Expected Result:** DEV-A receives DEV-D's claim request; since PRIMARY already exists, returns `CLAIM_ACK` with role: `STANDBY`.
- **Actual Result:** DEV-D assigned as `STANDBY`; DEV-C remains `PRIMARY`.
- **Status:** PASS
- **Notes:** Strict deterministic offline arbitration prevents duplicate primary responders.

---

### Category I: Connectivity Switching (Offline $\leftrightarrow$ Online) (TC-CONN)

#### TC-CONN-01: Offline-to-Online Transition & Cloud Sync
- **Precondition:** DEV-A created offline emergency `JS-OFF-...` while disconnected.
- **Steps:**
  1. Re-enable Wi-Fi / Cellular data on DEV-A.
  2. Observe ConnectivityService and CommunicationManager behavior.
- **Expected Result:** ConnectivityService detects live internet probe, switches mode to `online`, triggers `syncOfflineEmergencyToFirestore()`, synchronizes unsynced SQLite records to Firestore.
- **Actual Result:** Mode switched to `online` within 3.5s; unsynced emergency uploaded to Firestore `emergencies/` collection; local database marked `isSynced = 1`.
- **Status:** PASS
- **Notes:** Zero duplicate records created; offline ID preserved in sync metadata.

#### TC-CONN-02: Online-to-Offline Fallback During Active Emergency
- **Precondition:** Active emergency running online via Firestore.
- **Steps:**
  1. Turn on Airplane mode (enable Bluetooth).
- **Expected Result:** App detects network loss within 8s (ping timer), switches transport to `offline`, falls back to Nearby Connections mesh without crashing.
- **Actual Result:** Mode switched to `offline`; status banner indicates "Offline Mode — Bluetooth Mesh Active"; tracking continues locally.
- **Status:** PASS
- **Notes:** Resilient state machine prevents emergency termination on network loss.

---

### Category J: Background & Lifecycle Behavior (TC-BACK)

#### TC-BACK-01: Screen Locked During Active Rescue
- **Precondition:** Active emergency session on DEV-A and DEV-B.
- **Steps:**
  1. Press power button to turn off screen / lock device.
  2. Keep screen locked for 60 seconds.
  3. Turn screen back on and unlock device.
- **Expected Result:** Emergency session remains fully active, GPS updates resume, state is not terminated by Android OS.
- **Actual Result:** Session remains in exact same state (`APPROACHING`); map and telemetry resume instantly.
- **Status:** PASS
- **Notes:** Tested across Android 11, 12, 13, and 14.

#### TC-BACK-02: App Backgrounded via Home Gesture
- **Precondition:** Active emergency running.
- **Steps:**
  1. Swipe up to go to Android Home screen.
  2. Open other apps (e.g. Chrome, Settings) for 45 seconds.
  3. Return to Vita ResQ from Recent Apps.
- **Expected Result:** App recovers state immediately from memory or local cache; emergency details remain intact.
- **Actual Result:** Zero state reset; active emergency restored seamlessly.
- **Status:** PASS
- **Notes:** Memory footprint remains well within Android LMK (Low Memory Killer) safe thresholds (~110 MB RAM).

---

### Category K: Failover & Responder Reliability (TC-FAIL)

#### TC-FAIL-01: Primary Responder Stalled / Inactive Detection
- **Precondition:** Active emergency with PRIMARY responder (DEV-B) and STANDBY responder (DEV-C).
- **Steps:**
  1. PRIMARY responder stops making progress towards victim for $>120$ seconds (or heartbeat stale $>60$s).
- **Expected Result:** `ResponderReliabilityMonitor` detects lack of progress, marks PRIMARY as `AT_RISK` in Firestore.
- **Actual Result:** At threshold, primary status set to `AT_RISK`; notification dispatched.
- **Status:** PASS
- **Notes:** Monitored via periodic evaluation timer (10s interval).

#### TC-FAIL-02: Automatic Standby Promotion to Primary
- **Precondition:** Primary marked `AT_RISK` in TC-FAIL-01.
- **Steps:**
  1. Monitor system failover execution.
- **Expected Result:** `promoteStandbyToPrimary()` executes atomic transaction; STANDBY responder (DEV-C) promoted to `PRIMARY`; original primary demoted or removed; victim screen updates with new primary responder details.
- **Actual Result:** Standby promoted in 480ms; DEV-C becomes `PRIMARY`; victim notified with "Responder updated — New helper approaching".
- **Status:** PASS
- **Notes:** Failover arbitration guarantees victim is never abandoned by an unresponsive responder.

---

### Category L: Geofence Arrival & Completion (TC-COMP)

#### TC-COMP-01: Arrival Geofence Enforcement (> 100 Meters)
- **Precondition:** Responder navigating to victim; current distance is 350 meters.
- **Steps:**
  1. Responder taps "[ CONFIRM ARRIVAL ]" while 350m away.
- **Expected Result:** Arrival is REJECTED. Dialog informs responder: "Not At Victim Location — Current Distance: 350 m away. To protect the victim and ensure safety, you must be within 100 meters."
- **Actual Result:** Arrival rejected; dialog displayed with exact distance; status remains `APPROACHING`.
- **Status:** PASS
- **Notes:** 100m geofence protection prevents fraudulent or premature arrival claims.

#### TC-COMP-02: Verified Arrival Within 100-Meter Geofence
- **Precondition:** Responder approaches to within 45 meters of victim location.
- **Steps:**
  1. Responder taps "[ CONFIRM ARRIVAL ]".
- **Expected Result:** Arrival VERIFIED. Status updates to `ARRIVED`; victim alerted with arrival chime; verified impact points awarded to responder.
- **Actual Result:** Status updated to `ARRIVED` in Firestore/localDb; victim UI shows "Responder has arrived"; impact points recorded.
- **Status:** PASS
- **Notes:** `ImpactRewardService.recordArrivalVerified()` called with verified GPS tag.

#### TC-COMP-03: Emergency Completion Flow
- **Precondition:** Emergency in `ARRIVED` state.
- **Steps:**
  1. Responder or victim taps "[ COMPLETE EMERGENCY ]".
  2. Confirm resolution dialog.
- **Expected Result:** Emergency status set to `COMPLETED`; active session closed; incident archived in History; user returned to Home screen; feedback/rating available.
- **Actual Result:** Emergency cleanly finalized; appears in History list with full summary and timeline; Home screen resets to idle.
- **Status:** PASS
- **Notes:** Impact score incremented (+50 pts for verified resolution).

---

### Category M: Security & Safety Sanity (TC-SEC)

#### TC-SEC-01: Victim Self-Claim Prevention
- **Precondition:** User A creates an emergency.
- **Steps:**
  1. User A attempts to claim their own emergency as responder.
- **Expected Result:** Operation strictly rejected with exception "You cannot volunteer for your own emergency."
- **Actual Result:** Claim blocked both online (Firestore transaction check) and offline (local database check).
- **Status:** PASS
- **Notes:** Authoritative check in `EmergencyClaimService.acceptAndRespond()`.

#### TC-SEC-02: Closed Incident Claim Rejection
- **Precondition:** Emergency already in `COMPLETED` or `CANCELLED` status.
- **Steps:**
  1. Responder attempts to send claim request.
- **Expected Result:** Claim rejected with "This emergency is no longer active."
- **Actual Result:** Transaction immediately rejects claim; zero state change.
- **Status:** PASS
- **Notes:** Protects against race conditions after incident resolution.

---

### Category N: Performance & System Metrics (TC-PERF)

#### TC-PERF-01: Cold App Launch Time
- **Metric:** Time from launcher icon tap to interactive Home screen.
- **Target:** $< 3.0$ seconds.
- **Measured (Pixel 7 / Android 14):** 1.42 seconds.
- **Measured (Redmi Note 11 / Android 11):** 2.15 seconds.
- **Status:** PASS

#### TC-PERF-02: GPS Time-to-First-Fix (TTFF)
- **Metric:** Time from app launch to valid GPS coordinate lock.
- **Target:** $< 5.0$ seconds.
- **Measured:** 1.35 seconds (cached fast-path) / 3.10 seconds (fine hardware fix).
- **Status:** PASS

#### TC-PERF-03: SOS Activation Latency
- **Metric:** Time from 2.0s hold completion to active emergency broadcast state.
- **Target:** $< 1.5$ seconds.
- **Measured:** 0.68 seconds.
- **Status:** PASS

#### TC-PERF-04: Offline P2P Discovery Latency
- **Metric:** Time from victim offline broadcast to nearby responder discovery.
- **Target:** $< 15.0$ seconds.
- **Measured:** 4.2 seconds (average across 5 trials: 3.8s to 5.6s).
- **Status:** PASS

#### TC-PERF-05: App Memory (RAM) Consumption
- **Metric:** Memory usage during active emergency navigation with OpenStreetMap tiles.
- **Target:** $< 200$ MB.
- **Measured:** 112 MB (peak: 134 MB during rapid map panning).
- **Status:** PASS
