# Vita ResQ — Current Feature Notepad

## 1. One-Line Product Description

Vita ResQ is a mission-critical civilian bystander emergency response application featuring dual-transport SOS dispatch (Cloud Firestore and Google Nearby Connections direct P2P), autonomous sensor-assisted crash detection, and geofenced mutual-aid routing for rapid community-first emergency intervention.

---

## 2. USER & ACCOUNT FEATURES

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Email/Password Registration** | ✅ IMPLEMENTED | Registers a new user account with display name, email, password, role, blood group, and vehicle number. | `AuthService.registerWithEmailAndPassword` via Firebase Auth + Firestore `users/{uid}`. |
| **Email/Password Login** | ✅ IMPLEMENTED | Authenticates registered users and initializes local profile caching. | `AuthService.loginWithEmailAndPassword` via Firebase Auth with automatic local profile sync. |
| **Firebase Auth Session Persistence** | ✅ IMPLEMENTED | Automatically restores logged-in session on app launch without re-authenticating. | `SplashScreen._checkAuthState` inspecting `FirebaseAuth.currentUser`. |
| **Offline Local Session Access** | ✅ IMPLEMENTED | Allows users to access the app and dispatch offline emergencies even when launched without internet. | `AuthService.getUserProfile` fallback to `SharedPreferences` (`local_user_profile_v2`). |
| **User Profile Management** | ✅ IMPLEMENTED | Allows users to view and update their name, phone number, blood group, role, and vehicle number. | `ProfileScreen` calling `AuthService.updateUserProfile` with local + cloud write. |
| **Responder Role Customization** | ✅ IMPLEMENTED | Supports 4 distinct responder roles: `CITIZEN`, `AMBULANCE_DRIVER`, `POLICE_PCR`, and `DOCTOR`. | Stored in `UserModel.userRole`; dynamically controls map icons, siren sounds, and HUD subtitles. |
| **Medical Profile (Blood Group)** | ✅ IMPLEMENTED | Tracks patient blood group (A+, A-, B+, B-, AB+, AB-, O+, O-) for emergency medical responders. | Displayed on `EmergencyDetailsScreen`, `EmergencyMapScreen`, and injected into emergency SMS/WhatsApp. |
| **Vehicle Number Association** | ✅ IMPLEMENTED | Associates emergency vehicle identification (e.g. 108 Ambulance ID, Police PCR Unit ID) with responder profile. | Configurable in `ProfileScreen` and displayed on victim HUD when emergency vehicle responds. |
| **Profile Cache Isolation** | ✅ IMPLEMENTED | Strictly enforces that requested UID matches authenticated user before returning local cached data, preventing cross-user contamination. | `AuthService.getUserProfile` verifies `requestedUid == currentAuthUid` before reading local cache. |
| **Sign Out & Token Purge** | ✅ IMPLEMENTED | Clears local user profile, marks user offline in Firestore, revokes FCM device token, and signs out. | `AuthService.signOut` clears `local_user_profile_v2`, deletes `fcmToken`, and invokes `_auth.signOut()`. |
| **Phone OTP Authentication** | ❌ REMOVED | Legacy SMS phone OTP registration and login routines. | Completely removed from `AuthService` in Phase P3 to eliminate dead code and unauthenticated bypasses. |

---

## 3. EMERGENCY / SOS FEATURES

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Hold-to-Activate SOS Button** | ✅ IMPLEMENTED | Requires continuous 2.0-second press-and-hold to activate SOS, preventing accidental false triggers. | `SOSButton` with animated radial progress ring, heavy haptic click on start, and vibration on completion. |
| **Accidental Tap Protection** | ✅ IMPLEMENTED | Safely cancels SOS activation if user taps briefly or releases finger before 2.0-second threshold. | `SOSButton._onHoldEnd` resets progress controller and provides light haptic cancel click. |
| **Dual-Transport SOS Dispatch** | ✅ IMPLEMENTED | Automatically selects active transport: dispatches to Cloud Firestore if online, or advertises via Google Nearby Connections if offline. | `CommunicationManager.broadcastSOS` routes to `OnlineCommunicationService` or `OfflineCommunicationService`. |
| **Initial Safety Radius Enforcement** | ✅ IMPLEMENTED | Bounds initial emergency search radius strictly to 500 meters to prioritize immediate nearby civilian bystanders. | `EmergencyService.createSOS` uses `AppConstants.initialEmergencyRadiusMeters` (`500.0m`). |
| **Automated Expanding Radius Timer** | ✅ IMPLEMENTED | Incrementally expands search radius if no helper accepts: 500m $\rightarrow$ 1,000m $\rightarrow$ 2,000m $\rightarrow$ 5,000m. | `EmergencyService._startExpandingRadiusTimer` updates `currentRadiusMeters` every 20 seconds. |
| **Emergency Type Classification** | ✅ IMPLEMENTED | Categorizes emergency as `MEDICAL`, `ACCIDENT`, `POLICE`, or general SOS. | Stored in `EmergencyModel.type`; determines alert styling, responder assignment, and SMS templates. |
| **Authoritative Status Lifecycle** | ✅ IMPLEMENTED | Manages 6 distinct emergency lifecycle states: `SEARCHING`, `ASSIGNED`, `APPROACHING`, `ARRIVED`, `COMPLETED`, `CANCELLED`. | Strictly managed by `EmergencyModel.status` across both cloud Firestore and local SQLite/Prefs. |
| **Victim SOS Cancellation** | ✅ IMPLEMENTED | Allows victim to cancel active SOS with confirmation dialog; notifies all active responders immediately. | `EmergencyService.cancelEmergency` updates status to `CANCELLED` and broadcasts P2P cancel packet. |
| **Incident Completion Resolution** | ✅ IMPLEMENTED | Allows Primary Responder to mark incident `COMPLETED` at scene; triggers civic impact points and victim feedback. | `EmergencyService.updateEmergencyStatus(COMPLETED)` + `ImpactRewardService.recordEmergencyCompleted`. |
| **Emergency Timeline Visualizer** | ✅ IMPLEMENTED | Displays horizontal multi-step progress bar showing current emergency state (Reported $\rightarrow$ Dispatched $\rightarrow$ En-Route $\rightarrow$ Arrived $\rightarrow$ Resolved). | `EmergencyTimelineWidget` on `EmergencyDetailsScreen` and `EmergencyMapScreen`. |
| **Active Emergency Card on Home** | ✅ IMPLEMENTED | Floating status banner on Home Dashboard allowing user to instantly resume an in-progress emergency. | `HomeScreen._buildActiveEmergencyBanner` listening to active emergency stream. |
| **Emergency Contact Management** | ✅ IMPLEMENTED | Allows user to save up to 3 trusted emergency contacts (name, phone number, relationship) locally and in cloud profile. | `EmergencyContactsService.saveContacts` / `getContacts` with Firestore sync. |
| **Automated 3-Minute Fallback Timer** | ✅ IMPLEMENTED | 180-second countdown in victim map screen; if no responder claims incident, prompts or dispatches emergency SMS to family. | `EmergencyMapScreen._checkAndStartFallbackTimer` with live countdown HUD. |
| **Play Store-Compliant Emergency SMS** | ✅ IMPLEMENTED | Generates pre-formatted emergency SMS with victim name, blood group, and Google Maps live link, opened via system SMS intent. | `EmergencyContactsService.sendEmergencySMS` via `url_launcher` (`sms:?body=...`) without dangerous `SEND_SMS`. |
| **1-Tap WhatsApp Emergency Dispatch** | ✅ IMPLEMENTED | Formats and dispatches critical emergency alert directly to WhatsApp contacts with live coordinate link. | `EmergencyContactsService.sendEmergencyWhatsApp` via `whatsapp://send` and `https://wa.me/` URLs. |
| **Official Emergency Helplines (112, 108, 100, 101)** | ✅ IMPLEMENTED | Direct 1-tap phone dialer strip on Home Dashboard and Navigation Drawer for national emergency services. | `url_launcher` (`tel:112`, `tel:108`, `tel:100`, `tel:101`). |

---

## 4. ACCIDENT / CRASH DETECTION

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Autonomous Sensor Streaming** | ✅ IMPLEMENTED | Continuously monitors hardware user-accelerometer and gyroscope streams in the background. | `AccidentDetectionService` listening to `sensors_plus` streams (`userAccelerometerEventStream`, `gyroscopeEventStream`). |
| **Multi-Signal Crash Evaluator** | ✅ IMPLEMENTED | Evaluates 5 concurrent physical signals: net impact acceleration, angular rotation, speed drop, vehicle speed context, and stillness. | Pure-Dart deterministic algorithm in `AccidentDetectionEvaluator.evaluate`. |
| **Confidence Scoring Algorithm** | ✅ IMPLEMENTED | Computes a composite crash severity score (0–100): $\ge 70$ triggers `SUSPECTED` crash alarm; 40–69 triggers `POSSIBLE`. | `AccidentEvaluationResult.confidence` and `score`. |
| **False-Positive Desk-Drop Filter** | ✅ IMPLEMENTED | Caps score to 45 if an acceleration spike occurs without secondary vehicle signals (speed drop, rotation, or vehicle speed context). | `AccidentDetectionEvaluator` false-positive guard prevents phone drops from triggering emergency sirens. |
| **15-Second Warning Countdown Modal** | ✅ IMPLEMENTED | Displays full-screen urgent modal warning victim that a suspected collision was detected, with 15-second countdown timer. | `AccidentDetectionDialog` with circular animated progress timer. |
| **Emergency Warning Siren & Audio Ticks** | ✅ IMPLEMENTED | Emits acoustic warning siren and audio countdown ticks to alert dazed or injured occupants. | `EmergencySoundService.playAccidentWarning()` and `playCountdownBeep()`. |
| **"I'M OKAY" User Cancellation** | ✅ IMPLEMENTED | Allows driver/passenger to tap "I'M OKAY" to safely dismiss false alarms, stopping siren and resetting sensors. | Tap action in `AccidentDetectionDialog` calls `service.setConfirmationActive(false)`. |
| **Auto-SOS Dispatch on Expiry** | ✅ IMPLEMENTED | Automatically triggers full emergency SOS dispatch if countdown expires without user intervention. | `AccidentDetectionDialog` invokes `HomeScreen._executeSOS()` when timer reaches zero. |
| **Sensor Lifecycle & Toggle** | ✅ IMPLEMENTED | Allows users to toggle crash detection ON/OFF in Profile Screen; safely cancels sensor subscriptions when disabled. | `AccidentDetectionService.setEnabled` persisted to `SharedPreferences`. |
| **Synthetic Crash Simulation (Judge Demo)** | 🧪 DEMO / SIMULATION | Injects a pre-calibrated 90-point simulated vehicle collision event through the evaluator pipeline to demonstrate crash workflows without crashing a vehicle. | Accessible via Navigation Drawer (`Simulate Crash (Judge Demo)`) and `ProfileScreen`. |
| **Physical Vehicle Crash Testing** | 📱 DEVICE TEST REQUIRED | Real-world validation of sensor thresholds using physical test vehicle or calibrated crash sled. | Mathematical vectors verified in unit tests; physical vehicle testing remains post-MVP validation requirement. |

---

## 5. LOCATION & TRACKING

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **High-Accuracy GPS Acquisition** | ✅ IMPLEMENTED | Acquires device geographic coordinates using native platform satellite positioning. | `LocationService.getCurrentLocation` using `geolocator` with `LocationAccuracy.best`. |
| **Fast-Path Last Known Location** | ✅ IMPLEMENTED | Instantly checks hardware cached position on startup to eliminate cold-start GPS delay and UI freeze. | `LocationService` queries `Geolocator.getLastKnownPosition()` before initiating fine satellite lock. |
| **Reactive Live Position Stream** | ✅ IMPLEMENTED | Exposes a broadcast stream of live GPS coordinate updates for reactive UI subscribers. | `LocationService.onPositionChanged` broadcast stream subscribed by `HomeScreen` and `EmergencyMapScreen`. |
| **Real-Time Telemetry HUD** | ✅ IMPLEMENTED | Displays live latitude, longitude, movement speed, and GPS satellite fix status on Home Dashboard. | `HomeScreen` telemetry widget updating dynamically on position events. |
| **Live Victim Location Publishing** | ✅ IMPLEMENTED | Streams moving victim coordinates to cloud Firestore document or broadcasts via Nearby Connections P2P packets. | `LocationService.startEmergencyLocationUpdates` publishes coordinate updates with 8-meter movement throttling. |
| **Live Responder Location Tracking** | ✅ IMPLEMENTED | Streams responder coordinates to victim map, updating distance, ETA, and marker position in real time. | `EmergencyService.updateResponderLocation` updates `responders.{uid}` map in Firestore or sends P2P status packet. |
| **OSRM Road Network Polyline Routing** | ✅ IMPLEMENTED | Fetches exact road-following polyline coordinates, driving distance, and travel duration from public OSRM servers. | `OSRMRoutingService.fetchRoadRoute` with 4 cascading fallback endpoints (requires internet). |
| **Direct Haversine Route Fallback** | ✅ IMPLEMENTED | Calculates straight-line bearing, direct distance, and estimated walking ETA when offline or when OSRM fails. | `EmergencyMapScreen` computes direct 2-point line `[origin, destination]` and Haversine distance. |
| **Dynamic Turn-by-Turn ETA Calculation** | ✅ IMPLEMENTED | Calculates remaining travel time in minutes based on real-time road distance and urban emergency vehicle speeds. | Calculated dynamically in `OSRMRoutingService` and `EmergencyMapScreen`. |
| **100-Meter Geofenced Scene Arrival** | ✅ IMPLEMENTED | Automatically verifies whether responder GPS is within 100 meters of victim before allowing "ARRIVED" status. | `EmergencyMapScreen._handleArrivedPressed` checks `Geolocator.distanceBetween <= 100.0m`. |
| **Hospital Discovery & Navigation** | 🔮 FUTURE / NOT IMPLEMENTED | Automated discovery and routing to nearest trauma centers and hospitals. | Not present in current codebase; reserved for future Phase P5 release. |

---

## 6. ONLINE COMMUNICATION

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Firebase Authentication Integration** | ✅ IMPLEMENTED | Secures user identity, issues signed JWT auth tokens, and validates caller UID on all database interactions. | `firebase_auth` package integrated into `AuthService`. |
| **Cloud Firestore Emergency Channel** | ✅ IMPLEMENTED | Real-time cloud database managing emergency documents, multi-responder maps, and live telemetry. | `cloud_firestore` package targeting collection `/emergencies/{emergencyId}`. |
| **Strict Cloud Security Rules** | ✅ IMPLEMENTED | Canonical production rules enforcing profile ownership, authenticated emergency creation, radius limits, and deny-by-default. | [firestore.rules](file:///D:/vitaxq/firestore.rules) enforcing `request.auth.uid == victimId` and bounded radius. |
| **Nearby Incident Discovery Stream** | ✅ IMPLEMENTED | Streams active `SEARCHING` emergencies within radius to nearby online volunteers and emergency vehicles. | `EmergencyService.streamNearbySearchingEmergencies` with Haversine distance filtering. |
| **Multi-Responder Atomic Claim Transaction** | ✅ IMPLEMENTED | Concurrently manages primary and standby responders without race conditions or split-brain overwrites. | `EmergencyClaimService.acceptAndRespond` using Firestore atomic `runTransaction`. |
| **FCM Push Notification Handling** | ✅ IMPLEMENTED | Handles incoming Firebase Cloud Messaging alert payloads in foreground, background, and cold-start terminated states. | `NotificationService` listening to `FirebaseMessaging.onMessage` and `onMessageOpenedApp`. |
| **Cloud Function Background Dispatch** | ⚠️ PARTIAL / LIMITED | Server-side trigger that calculates Haversine distance to registered users and dispatches FCM notifications on emergency creation. | [functions/index.js](file:///D:/vitaxq/functions/index.js) (`onEmergencyUpdated`); currently performs an $O(N)$ full-collection scan on `users`. |
| **Offline-to-Online Cloud Synchronization** | ✅ IMPLEMENTED | Uploads local offline emergency records (`JS-OFF-`) to Cloud Firestore once internet connectivity is restored. | `CommunicationManager.syncOfflineEmergencyToFirestore` querying unsynced records from `LocalDatabaseService`. |

---

## 7. OFFLINE / P2P COMMUNICATION
*(Operates over Google Nearby Connections direct RF sockets; does not require cellular data, Wi-Fi router, or internet access).*

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Direct P2P Nearby Transport** | ✅ IMPLEMENTED | Establishes direct RF communication using Bluetooth Low Energy (BLE) and Wi-Fi Direct via Google Nearby Connections. | `OfflineNearbyService` using `Strategy.P2P_STAR`. |
| **Autonomous Offline Emergency ID** | ✅ IMPLEMENTED | Generates deterministic, globally unique offline emergency identifiers without contacting cloud servers. | `JS-OFF-<timestamp>` format generated in `OfflineCommunicationService.broadcastSOS`. |
| **Thread-Safe Local Emergency Storage** | ✅ IMPLEMENTED | Persists offline emergency records into isolated storage partitions with in-memory mutex serialization. | `LocalDatabaseService` using isolated keys `offline_emergency_<id>` and asynchronous mutex lock. |
| **P2P SOS Advertising & Discovery** | ✅ IMPLEMENTED | Victim device advertises SOS broadcast beacon; nearby responder devices continuously scan and discover endpoint. | `OfflineNearbyService.startSOSBroadcast` and `startDiscovery`. |
| **Authoritative Two-Way Claim Handshake** | ✅ IMPLEMENTED | Responders transmit `CLAIM_REQUEST`; victim device authoritatively arbitrates and returns signed `CLAIM_ACK`. | Authoritative arbitration in `OfflineNearbyService.processClaimPayload`. |
| **PRIMARY vs. STANDBY Role Arbitration** | ✅ IMPLEMENTED | Victim device designates first responder as `PRIMARY`; subsequent responders are automatically designated `STANDBY`. | Prevents multiple responders from assuming lead role without victim coordination. |
| **Duplicate Claim & Closed Rejection** | ✅ IMPLEMENTED | Idempotently returns existing role assignment if responder re-transmits claim; strictly rejects claims on closed incidents. | Enforced in `OfflineNearbyService.processClaimPayload`. |
| **P2P Live Location & Status Propagation** | ✅ IMPLEMENTED | Transmits coordinate updates and status changes (`ARRIVED`, `COMPLETED`, `CANCELLED`) across direct RF sockets. | `OfflineNearbyService.sendStatusUpdatePayload` with JSON payload transmission. |
| **Pure-Dart SHA-256 Payload Signing** | ✅ IMPLEMENTED | Signs all outgoing P2P JSON byte packets with cryptographic SHA-256 signature using FIPS 180-4 standard algorithm. | `P2PPayloadIntegrity.signPayload` computes signature using canonical payload keys + application salt. |
| **Constant-Time Tamper & Spoof Detection** | ✅ IMPLEMENTED | Validates incoming P2P packets against recomputed hash using constant-time comparison, rejecting tampered coordinates. | `P2PPayloadIntegrity.verifyPayload` detecting payload manipulation or replay attacks. |
| **Physical Multi-Device RF Range Testing** | 📱 DEVICE TEST REQUIRED | Field testing of Bluetooth LE (~10–30m) and Wi-Fi Direct (~50–100m) radio range across multiple physical hardware models. | Validated in automated test suites; physical field testing required for real-world environmental benchmarking. |
| **Multi-Hop / True Mesh Packet Relaying** | 🔮 FUTURE / NOT IMPLEMENTED | Multi-hop store-and-forward relaying across intermediate non-adjacent nodes. | The current architecture is strictly direct 1-hop P2P (`Strategy.P2P_STAR`); multi-hop mesh is a future research goal. |

---

## 8. RESPONDER FEATURES

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Nearby Incident Radar List** | ✅ IMPLEMENTED | Displays live cards of searching emergencies sorted by proximity on Home Dashboard. | Streamed via `EmergencyService.streamNearbySearchingEmergencies` or Nearby P2P discovery. |
| **Incident Details Inspection** | ✅ IMPLEMENTED | Full-screen incident overview showing emergency type, distance, victim blood group, and location map. | `EmergencyDetailsScreen(emergencyId)`. |
| **"I CAN HELP" Claim Action** | ✅ IMPLEMENTED | Allows civilian responder to claim incident, triggering two-way handshake and navigating to live map. | `EmergencyClaimService.acceptAndRespond` / `EmergencyDetailsScreen._handleAcceptEmergency`. |
| **Dedicated Primary Responder HUD** | ✅ IMPLEMENTED | Provides turn-by-turn routing, live distance, ETA, "PROBLEM" reporting, and "ARRIVED" controls. | `EmergencyMapScreen` when `isPrimary == true`. |
| **Standby Responder Reserve State** | ✅ IMPLEMENTED | Informs volunteer that they are in reserve; automatically updates coordinates and awaits primary failover. | `EmergencyMapScreen` displays amber "STANDBY RESPONDER" banner and stand-by instructions. |
| **Live Responder GPS Sharing** | ✅ IMPLEMENTED | Streams volunteer's GPS coordinates to victim map, updating distance and ETA in real time. | `LocationService.startEmergencyLocationUpdates` updating responder subfield. |
| **Geofenced Scene Arrival Confirmation** | ✅ IMPLEMENTED | Allows primary helper to tap "ARRIVED" once within 100m geofence, transitioning status to `ARRIVED`. | `EmergencyMapScreen._handleArrivedPressed` updating status in Firestore / P2P. |
| **Primary Responder Problem / Delay Reporting** | ✅ IMPLEMENTED | Allows primary helper to report traffic delays (minor) or vehicle breakdown/medical emergency (fatal). | `EmergencyService.reportProblem` / `AppDialogs.showReportProblemDialog`. |
| **Automatic Standby-to-Primary Failover** | ✅ IMPLEMENTED | Promotes closest standby volunteer to `PRIMARY` if lead helper reports fatal breakdown; resets to `SEARCHING` if none available. | `EmergencyService.reportProblem` and `ResponderReliabilityMonitor.promoteStandbyToPrimary`. |
| **120-Second Stationary Stall Detection** | ✅ IMPLEMENTED | Monitors primary helper progress toward victim; detects stationary stalls (e.g. trapped in traffic or injured) after 120 seconds. | `ResponderReliabilityMonitor` with `noProgressThresholdSeconds = 120`. |

---

## 9. MAP & NAVIGATION

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **OpenStreetMap Vector Map Rendering** | ✅ IMPLEMENTED | Renders interactive vector map with pinch-to-zoom, pan, and smooth camera tracking. | `flutter_map` package rendering CartoDB / OpenStreetMap tile layers. |
| **Victim & Responder Map Markers** | ✅ IMPLEMENTED | Displays animated pulsating victim marker and role-specific responder markers (Ambulance, Police, Volunteer). | `MapWidget` and `EmergencyMapScreen._buildMapMarkers`. |
| **Live Road Route Polyline** | ✅ IMPLEMENTED | Renders high-precision road network polyline from responder origin to victim destination (requires internet). | `OSRMRoutingService.fetchRoadRoute` providing GeoJSON coordinate lists. |
| **Direct Haversine Fallback Polyline** | ✅ IMPLEMENTED | Renders direct straight-line polyline between victim and responder when offline or without route data. | Direct 2-point polyline rendered in `EmergencyMapScreen`. |
| **Distance & ETA Real-Time HUD** | ✅ IMPLEMENTED | Displays formatted distance (e.g. `450m`, `2.4km`) and travel duration (`3 mins`, `Arriving`). | Floating top telemetry HUD in `EmergencyMapScreen`. |
| **Direct Telephony Intent Calling** | ✅ IMPLEMENTED | 1-tap call button enabling voice calls between victim and responder via device dialer. | `url_launcher` (`tel:<phoneNumber>`) on `EmergencyMapScreen`. |
| **30-Meter Proximity Arrival State** | ✅ IMPLEMENTED | Automatically detects when responder is within 30m of victim and transitions ETA display to "Arriving". | Proximity check in `EmergencyMapScreen._updateRoute`. |
| **Offline Vector Map Tile Pack Caching** | 🔮 FUTURE / NOT IMPLEMENTED | Pre-downloaded offline vector map packs (`.mbtiles`) for visual offline road map rendering. | Offline mode currently renders direct vector polyline, bearing, and distance without pre-cached tile packs. |

---

## 10. NOTIFICATIONS & ALERTING

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **FCM Push Notification Service** | ✅ IMPLEMENTED | Receives cloud emergency alert notifications on responder devices with custom sound and vibration. | `NotificationService` handling `FirebaseMessaging` foreground and background events. |
| **Role-Based Emergency Sirens** | ✅ IMPLEMENTED | Emits distinct audio sirens tailored to responder role: 108 Ambulance siren loop (800ms), Police tactical siren loop (600ms), Citizen alert tone. | `EmergencySoundService.playEmergencyAlert` based on `userRole`. |
| **Vibration & Haptic Feedback Engine** | ✅ IMPLEMENTED | Delivers tactile feedback patterns: heavy impact on hold start, double haptic on crash alarm, pulse on arrival. | `HapticFeedback` method channel integration in `EmergencySoundService` and `SOSButton`. |
| **Accident Warning Siren & Countdown Ticks** | ✅ IMPLEMENTED | Plays warning siren followed by periodic countdown tick sounds during the 15-second collision verification window. | `EmergencySoundService.playAccidentWarning` and `playCountdownBeep`. |
| **SOS Sent Confirmation Chime** | ✅ IMPLEMENTED | Plays audio chime and double haptic confirmation the instant SOS dispatch completes successfully. | `EmergencySoundService.playSOSSentSound`. |
| **Alert Deduplication Protection** | ✅ IMPLEMENTED | Caches processed emergency IDs to prevent duplicate sound/vibration alerts when multiple stream events fire. | In-memory sets in `EmergencySoundService` (`_processedAlertSoundIds`). |

---

## 11. HISTORY / COMMUNITY / IMPACT

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **User-Scoped "Help Asked" Tab** | ✅ IMPLEMENTED | Displays chronological history of emergencies triggered by the current user as a victim. | `EmergencyHistoryScreen` filtered by `EmergencyHistoryFilter.filterHelpAsked(victimId == uid)`. |
| **User-Scoped "Victims Helped" Tab** | ✅ IMPLEMENTED | Displays chronological history of emergency rescues where the current user volunteered as a helper. | `EmergencyHistoryScreen` filtered by `EmergencyHistoryFilter.filterVictimsHelped(helperId == uid)`. |
| **Incident Status Badge Chips** | ✅ IMPLEMENTED | Color-coded status chips indicating historical outcome (`COMPLETED`, `CANCELLED`, `SEARCHING`). | `EmergencyHistoryScreen._buildStatusChip` with theme color tokens. |
| **Verified Civic Points Matrix** | ✅ IMPLEMENTED | Awards anti-cheat civic recognition points: +10 pts for verified 100m arrival, +5 pts for primary helper, +5 pts for offline P2P rescue, +5 pts for crash response, +10 pts for resolution, +10 pts for victim feedback confirmation. | `ImpactRewardService` state machine enforcing verified geofence requirements. |
| **5-Tier Recognition Progression** | ✅ IMPLEMENTED | Ranks volunteers from Level 1 (Community Volunteer, 0–49 pts) up to Level 5 (Vita ResQ Champion, 500+ pts). | Computed in `UserImpactProfile.level` and `UserImpactProfile.title`. |
| **6 Official Civic Badges** | ✅ IMPLEMENTED | Awards collectible recognition badges: *First Response*, *Offline Guardian*, *Rapid Responder*, *Reliable Shield*, *Accident Hero*, and *Night Guardian*. | Evaluated and persisted in `ImpactRewardService.recordEmergencyCompleted`. |
| **Dynamic Reliability Score Formula** | ✅ IMPLEMENTED | Computes responder reliability percentage: $(\text{Verified Assists} / \text{Total Accepted}) \times 100$. | Displayed on `ProfileScreen` and `ResponderProfileCard`. |
| **Printable Digital Civic Certificate** | ✅ IMPLEMENTED | Generates shareable credential certificate (`JS-CERT-xxxx`) showing verified rescues, score, and official badge. | Rendered via `CommunityCertificateDialog` accessible from `ProfileScreen`. |
| **Victim Post-Resolution Feedback Dialog** | ✅ IMPLEMENTED | Prompts victim upon incident completion to confirm whether the primary helper assisted, awarding confirmation bonus. | `VictimFeedbackDialog` rendered post-completion on `EmergencyMapScreen`. |

---

## 12. SAFETY / SECURITY FEATURES

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Authenticated Emergency Creation** | ✅ IMPLEMENTED | Validates that caller has an active Firebase Auth session before allowing emergency document creation. | `EmergencyService.createSOS` null check + Firestore security rule `request.auth != null`. |
| **Caller UID Ownership Enforcement** | ✅ IMPLEMENTED | Verifies that emergency `victimId` strictly matches authenticated caller's UID (`request.auth.uid`), preventing spoofing and impersonation. | Checked in `EmergencyService.createSOS` and enforced in [firestore.rules](file:///D:/vitaxq/firestore.rules). |
| **Profile Cache Isolation** | ✅ IMPLEMENTED | Validates requested profile UID against authenticated device owner before reading local storage, preventing cross-user data leakage. | `AuthService.getUserProfile` identity check on cache reads and writes. |
| **Bounded Radius Security Invariant** | ✅ IMPLEMENTED | Restricts initial emergency search radius to $\le 5,000$ meters at the rule level, preventing unbounded database flood attacks. | Enforced in [firestore.rules](file:///D:/vitaxq/firestore.rules) (`currentRadiusMeters <= 5000.0`). |
| **Protected Deletions Policy** | ✅ IMPLEMENTED | Completely disallows client-side document deletion on user profiles and emergency records to preserve life-safety audit logs. | [firestore.rules](file:///D:/vitaxq/firestore.rules) (`allow delete: if false;`). |
| **Default Deny Firestore Policy** | ✅ IMPLEMENTED | All database collection paths not explicitly declared are rejected by default. | [firestore.rules](file:///D:/vitaxq/firestore.rules) (`match /{document=**} { allow read, write: if false; }`). |
| **P2P Payload Cryptographic Signing** | ✅ IMPLEMENTED | Computes SHA-256 digital signature over canonical payload attributes and secret application salt for all offline packets. | `P2PPayloadIntegrity.signPayload` adding `_sig` field. |
| **Constant-Time P2P Signature Verification** | ✅ IMPLEMENTED | Validates signatures in constant time to prevent timing attacks; rejects tampered coordinates, timestamps, or sender IDs. | `P2PPayloadIntegrity.verifyPayload` using `_constantTimeEquals`. |
| **Self-Claim Prevention Guard** | ✅ IMPLEMENTED | Prevents victims from claiming their own emergencies as responders. | Enforced in `OfflineNearbyService.processClaimPayload` and `EmergencyService.streamNearbySearchingEmergencies`. |
| **Closed-Emergency Claim Rejection** | ✅ IMPLEMENTED | Prevents volunteers from claiming an emergency that has already been completed or cancelled. | Enforced in `OfflineNearbyService.processClaimPayload` and `EmergencyClaimService`. |
| **Asymmetric Public-Key P2P Non-Repudiation** | 🔮 FUTURE / NOT IMPLEMENTED | Per-device Ed25519 asymmetric cryptographic keypairs for individual hardware non-repudiation. | Current P2P integrity uses application-salted SHA-256; asymmetric device keys reserved for future phase. |

---

## 13. CONNECTIVITY / OFFLINE UX

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **HTTP 204 Internet Reachability Probe** | ✅ IMPLEMENTED | Continuously verifies true internet reachability via Google/Cloudflare HTTP 204 probes, not just physical Wi-Fi/cellular connection. | `ConnectivityService` with reactive `modeStream` emitting `online` vs `offline`. |
| **Strict Transport Mutual Exclusion** | ✅ IMPLEMENTED | Enforces that only one communication transport (Online Firestore OR Offline Nearby) is active at any time, preventing duplicate states. | `CommunicationManager` state machine switching transports on connectivity events. |
| **Transparent Offline Bento Banner** | ✅ IMPLEMENTED | Displays informative banner on Home Dashboard explaining that direct P2P mesh is active, without misleading claims of offline maps. | `OfflineModeBentoBanner` widget on `HomeScreen`. |
| **Real-Time Connectivity Pill Indicator** | ✅ IMPLEMENTED | Displays high-visibility pill in Home Screen header showing live connection status (`ONLINE` in green vs `OFFLINE` in slate). | `HomeScreen._buildHeader` reflecting current `CommunicationMode`. |
| **Contextual Emergency Limitations UX** | ✅ IMPLEMENTED | Informs users in emergency map screen that direct line navigation is active when offline, and prompts for SMS/WhatsApp fallback. | Informational cards and dialogs in `EmergencyMapScreen`. |

---

## 14. UI / UX FEATURES

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Vita ResQ Product Identity & Tokens** | ✅ IMPLEMENTED | Comprehensive brand identity featuring Deep Slate Navy (`0xFF0F172A`), Emergency Red (`0xFFDC2626`), Emerald Green, and High-Vis Amber. | Defined in `AppTheme` and applied across all screens. |
| **Ambient Radar Pulse Animation** | ✅ IMPLEMENTED | Renders gentle ambient ripple rings behind idle SOS button to indicate active readiness and guide user focus. | `SOSButton._buildAmbientRadarRing` powered by continuous 2,600ms `AnimationController`. |
| **Press-and-Hold Progress Visualizer** | ✅ IMPLEMENTED | Displays continuous high-contrast circular progress stroke while user holds SOS button, filling completely at 2.0s. | Custom painter in `SOSButton` with linear progress curve. |
| **Floating Status HUD on Map** | ✅ IMPLEMENTED | Floating pill at top of map displaying responder identity, vehicle number, distance, and dynamic ETA. | `EmergencyMapScreen` top HUD with Material 3 elevation. |
| **Quick Emergency Number Action Strip** | ✅ IMPLEMENTED | Quick-dial buttons for national helplines: **112** (All-in-One), **108** (Ambulance), **100** (Police), **101** (Fire). | Persistent horizontal action bar on `HomeScreen`. |
| **User Navigation Drawer** | ✅ IMPLEMENTED | Side drawer providing quick navigation to Profile, Emergency History, Emergency Helplines, and Demo Simulation Tools. | `HomeScreen.drawer` with user header and navigation tiles. |
| **National Emergency Disclaimer** | ✅ IMPLEMENTED | Prominent disclaimer informing users that Vita ResQ is a civilian bystander mobilization tool and does not replace official 112 services. | Displayed on `HomeScreen` footer and in `AppConstants.emergencyDisclaimer`. |
| **WCAG AA Accessible Touch Targets** | ✅ IMPLEMENTED | All interactive controls, SOS buttons, and helpline cards maintain minimum 48x48dp touch targets and high-contrast color ratios. | Verified in `test/p2_ui_test.dart`. |

---

## 15. PLATFORM FEATURES

| Feature | Status | What it does | Where/How it works |
| :--- | :---: | :--- | :--- |
| **Android 14 / compileSdk 36 Compatibility** | ✅ IMPLEMENTED | Built and verified against Android 14 (API 34) and compileSdk 36 with Java 17 toolchain. | Configured in [android/app/build.gradle](file:///D:/vitaxq/android/app/build.gradle). |
| **Google Play Policy-Compliant SMS** | ✅ IMPLEMENTED | Zero dangerous `SEND_SMS` permissions in manifest; dispatches emergency SMS exclusively via system `<queries>` intent. | [android/app/src/main/AndroidManifest.xml](file:///D:/vitaxq/android/app/src/main/AndroidManifest.xml) queries for `android.intent.action.SENDTO` (`sms:`). |
| **Android 12+ Bluetooth Permissions** | ✅ IMPLEMENTED | Requests runtime `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_ADVERTISE`, and `BLUETOOTH_CONNECT`. | [android/app/src/main/AndroidManifest.xml](file:///D:/vitaxq/android/app/src/main/AndroidManifest.xml) and `AppPermissionsService`. |
| **Android 13+ Wi-Fi Direct Permission** | ✅ IMPLEMENTED | Requests `NEARBY_WIFI_DEVICES` (`neverForLocation`) for Wi-Fi Direct peer-to-peer transport. | [android/app/src/main/AndroidManifest.xml](file:///D:/vitaxq/android/app/src/main/AndroidManifest.xml) and `AppPermissionsService`. |
| **Android `<queries>` Intent Visibility** | ✅ IMPLEMENTED | Declares package queries for WhatsApp (`com.whatsapp`, `com.whatsapp.w4b`), telephony (`tel:`), and SMS (`sms:`). | [android/app/src/main/AndroidManifest.xml](file:///D:/vitaxq/android/app/src/main/AndroidManifest.xml). |
| **iOS Privacy Permission Declarations** | ⚠️ PARTIAL / LIMITED | Declares usage descriptions for Location, Bluetooth, and Local Network in `Info.plist`, along with `LSApplicationQueriesSchemes`. | Configured in [ios/Runner/Info.plist](file:///D:/vitaxq/ios/Runner/Info.plist); requires physical iOS device build to validate. |
| **Cross-Platform Android ↔ iOS P2P Interoperability** | 📱 DEVICE TEST REQUIRED | End-to-end P2P Nearby Connections between Android and iOS devices. | Google Nearby Connections on iOS has native platform limitations; requires multi-device testing. |

---

## 16. IMPORTANT LIMITATIONS

### Current Limitations

1. **Nearby Connections Direct RF Range:** Direct P2P operates over Bluetooth Low Energy (~10–30 meters) and Wi-Fi Direct (~50–100 meters). Multi-hop routing across intermediate non-adjacent nodes is not implemented.
2. **Online Map & Road Polyline Internet Dependency:** OpenStreetMap vector tiles and OSRM turn-by-turn routing require active cellular or Wi-Fi data. In offline mode, the app renders a straight-line vector polyline and direct Haversine bearing.
3. **Cloud Function $O(N)$ Collection Scan:** During online emergency dispatch, `functions/index.js` performs an $O(N)$ full-collection read on `users` to calculate proximity.
4. **Volunteer History Query Client Filtering:** `EmergencyHistoryScreen` Tab 2 ("Victims Helped") performs client-side filtering on emergency records rather than a composite indexed array query.
5. **Physical Vehicle Crash Testing:** Sensor evaluation is verified via mathematical models, sensor stream tests, and synthetic demo injection; real-world vehicle collision testing has not been performed.
6. **Shared-Salt P2P Cryptographic Signing:** P2P integrity uses application-salted SHA-256 (FIPS 180-4); per-device asymmetric public/private keypairs (Ed25519) are not yet implemented.
7. **OEM Android Background Restrictions:** Extended background execution and screen-off Nearby scanning can be throttled by aggressive manufacturer battery optimization (Doze mode) unless user exempts app from battery optimization.
8. **Live Cloud Rules Deployment Block:** Canonical production rules are ready in `firestore.rules`, but cloud deployment to Firebase project `vita-resq` requires developer CLI authentication (`firebase login`) or manual publication in Firebase Console.

---

## 17. FUTURE FEATURES
*(Planned architectural enhancements for post-MVP / Phase P5).*

1. **Geohash Spatial Bounding Box Queries (🔮 FUTURE):** Integrate GeoFirestore or Firebase Extensions to replace $O(N)$ Cloud Function scans with $O(\log N)$ spatial queries.
2. **Top-Level `participantUids` Array Schema (🔮 FUTURE):** Schema migration adding `participantUids: string[]` to `/emergencies/{id}` to enable native indexed Firestore queries for volunteer history.
3. **Asymmetric Ed25519 Public-Key Cryptography (🔮 FUTURE):** Generate on-device public/private keypairs to provide cryptographic non-repudiation for offline P2P rescue claims.
4. **Multi-Hop Store-and-Forward Mesh (🔮 FUTURE):** Develop multi-hop packet forwarding across intermediate bystander nodes to extend offline RF range beyond 100 meters.
5. **Bundled Offline Vector Map Tile Packs (🔮 FUTURE):** Pre-download regional vector map tiles (`.mbtiles`) to render full visual street maps without internet.
6. **Public Digital Certificate Verification Portal (🔮 FUTURE):** Public web portal allowing organizations to verify volunteer credential IDs (`JS-CERT-xxxx`).
7. **Automated Hospital & Trauma Center Navigation (🔮 FUTURE):** Automated discovery and navigation to the nearest government trauma center or emergency room based on incident severity.

---

## 18. QUICK DEMO CHECKLIST

Use this checklist for live testing, PPT presentations, and judge demonstrations:

- [ ] **1. User Authentication & Profile:** Log in with email/password; verify name, blood group, role, and vehicle number in Profile Screen.
- [ ] **2. GPS Telemetry Lock:** Launch app on cold start; verify GPS coordinates resolve immediately without freezing on "Acquiring...".
- [ ] **3. Hold-to-Activate SOS:** Press and hold SOS button for 2.0 seconds; observe radial progress ring, haptic feedback, and dispatch transition.
- [ ] **4. Accidental Tap Cancellation:** Tap SOS button briefly (< 1s) and release; confirm hold resets safely without triggering alarm.
- [ ] **5. Emergency Creation & Map:** Verify direct navigation to `EmergencyMapScreen` displaying victim marker, status HUD, and active emergency banner.
- [ ] **6. Proximity Radar Discovery:** Log in as secondary user; verify emergency appears on Home Dashboard radar list with accurate distance.
- [ ] **7. "I CAN HELP" Claim Handshake:** Tap emergency card $\rightarrow$ tap "I CAN HELP"; verify victim map updates to `ASSIGNED` with responder identity.
- [ ] **8. Primary vs. Standby Role:** Claim with a third user; verify third user receives `STANDBY` reserve HUD while first user remains `PRIMARY`.
- [ ] **9. Live Road Routing & ETA:** Verify road-following polyline, distance in meters, and dynamic ETA displayed on Primary Responder map.
- [ ] **10. 100-Meter Geofenced Arrival:** Attempt "ARRIVED" tap from afar (rejected); approach within 100m and tap "ARRIVED" (verified at scene).
- [ ] **11. Primary Breakdown / Failover:** Primary taps "PROBLEM" $\rightarrow$ selects "Vehicle Breakdown"; verify standby helper is automatically promoted to Primary.
- [ ] **12. Incident Resolution & Feedback:** Primary taps "END EMERGENCY"; verify victim receives `VictimFeedbackDialog` and rates assistance.
- [ ] **13. Civic Impact & Digital Certificate:** Open Profile Screen; verify updated rescue count, badges, points, and open `CommunityCertificateDialog`.
- [ ] **14. Crash Detection Demo (Judge Demo):** Open Drawer $\rightarrow$ tap "Simulate Crash (Judge Demo)"; observe 15-second modal warning, siren audio, and "I'M OKAY" button.
- [ ] **15. Autonomous Offline P2P Flow:** Enable Airplane mode on both devices; hold SOS; verify `JS-OFF-` beacon broadcast, discovery, and claim over Nearby Connections.
- [ ] **16. Emergency SMS / WhatsApp Fallback:** Tap "SEND SMS NOW" or "WHATSAPP" on map screen; verify pre-filled coordinates and Google Maps link in external app.
- [ ] **17. Official 112 Helpline Disclaimer:** Verify 112/108 quick-dial strip and prominent civilian bystander disclaimer on Home Dashboard.
