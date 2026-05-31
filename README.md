<div align="center">

```
██╗      ██████╗      ██████╗ ██╗   ██╗██╗ ██████╗██╗  ██╗██████╗ ██╗ ██████╗
██║     ██╔════╝     ██╔═══██╗██║   ██║██║██╔════╝██║ ██╔╝██╔══██╗██║██╔════╝
██║     ██║  ███╗    ██║   ██║██║   ██║██║██║     █████╔╝ ██████╔╝██║██║  ███╗
██║     ██║   ██║    ██║▄▄ ██║██║   ██║██║██║     ██╔═██╗ ██╔══██╗██║██║   ██║
███████╗╚██████╔╝    ╚██████╔╝╚██████╔╝██║╚██████╗██║  ██╗██║  ██║██║╚██████╔╝
╚══════╝ ╚═════╝      ╚══▀▀═╝  ╚═════╝ ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝
```

### Control your Liquid Galaxy cluster from your home screen — no terminal needed.

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2023+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![Linux](https://img.shields.io/badge/Linux-Desktop-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://flutter.dev/multi-platform/linux)
[![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)](LICENSE)

<br/>

[![SSH](https://img.shields.io/badge/SSH-dartssh2-4A90D9?style=flat-square&logo=gnubash&logoColor=white)](https://pub.dev/packages/dartssh2)
[![Storage](https://img.shields.io/badge/Storage-flutter__secure__storage-E63946?style=flat-square&logo=keepassxc&logoColor=white)](https://pub.dev/packages/flutter_secure_storage)
[![DI](https://img.shields.io/badge/DI-get__it-FF9F1C?style=flat-square)](https://pub.dev/packages/get_it)
[![KML](https://img.shields.io/badge/Protocol-KML%20%2B%20SSH-2D6A4F?style=flat-square&logo=googlemaps&logoColor=white)](https://developers.google.com/kml)

</div>

---

## What is LG QuickRig?

**Liquid Galaxy** is an open-source multi-display platform that renders
synchronised panoramic views across a rig of 3–9 Linux machines running Google
Earth. Managing it normally means SSH-ing into the master node every single time.

**LG QuickRig** eliminates that friction — one tap from your home screen or
notification shade to reboot, sync, push KML, or fly to any coordinate.

---

## App Preview

> Dashboard · SSH Console · Settings — dark teal Material 3 theme

```
╔═══════════════════════════════════════════╗   ╔═══════════════════════════════════════════╗
║  LG QuickRig          ● Connected         ║   ║  SSH Console          ● Connected         ║
╠═══════════════════════════════════════════╣   ╠═══════════════════════════════════════════╣
║                                           ║   ║  Connection                               ║
║  ┌─────────────────────────────────────┐  ║   ║  ┌──────────────────┐  ┌───────────┐      ║
║  │ Connection                          │  ║   ║  │ Host  192.168.2.2│  │ Port  22  │      ║
║  │                                     │  ║   ║  └──────────────────┘  └───────────┘      ║
║  │ lg@192.168.2.2  ·  3 nodes          │  ║   ║  ┌──────────────────┐  ┌───────────┐      ║
║  │                                     │  ║   ║  │ User   lg        │  │ ••••••••  │      ║
║  │ ╔═════════════════════════════════╗ │  ║   ║  └──────────────────┘  └───────────┘      ║
║  │ ║           Disconnect            ║ │  ║   ║  ╔═══════════════════════════════════╗    ║
║  │ ╚═════════════════════════════════╝ │  ║   ║  ║             Connect               ║    ║
║  └─────────────────────────────────────┘  ║   ║  ╚═══════════════════════════════════╝    ║
║                                           ║   ║                                           ║
║  Quick Actions                            ║   ║  Command                                  ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  ┌─────────────────────────────┐ ┌─────┐  ║
║  │     Reboot    │  │    Restart Svcs   │ ║   ║  │ echo hello LG               │ │ Run │  ║
║  └───────────────┘  └───────────────────┘ ║   ║  └─────────────────────────────┘ └─────┘  ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║                                           ║
║  │     Shutdown  │  │    Sync           │ ║   ║  Output                        [Clear]    ║
║  └───────────────┘  └───────────────────┘ ║   ║  ┌─────────────────────────────────────┐  ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  │14:32:01 [OUT] > echo hello LG       │  ║
║  │   Clean KML   │  │ >_  SSH Console   │ ║   ║  │14:32:01 [OUT] hello LG              │  ║
║  └───────────────┘  └───────────────────┘ ║   ║  │14:32:08 [OUT] > df -h /             │  ║
║                                           ║   ║  │14:32:08 [OUT] Filesystem  Size  Use │  ║
║     Last action: Reboot  ·  14:32:01      ║   ║  │           /dev/sda1   32G  12G  38% │  ║
╚═══════════════════════════════════════════╝   ╚═══════════════════════════════════════════╝
          Dashboard                                          SSH Console
```

---

## Features

| | Feature | Status |
|---|---|---|
| 🔌 | Secure SSH transport — timeout, retry, auto-reconnect | ✅ Done |
| 🔐 | Encrypted credential storage (Keystore / Keychain / libsecret) | ✅ Done |
| 📊 | Dashboard with live connection-status badge | ✅ Done |
| ⚡ | Quick Actions — Reboot, Restart, Shutdown, Sync, Clean KML | ✅ Done |
| 💻 | SSH Console — raw command input with timestamped log | ✅ Done |
| ⚙️ | Settings screen — self-loading, secure-enclave persistence | ✅ Done |
| 🗺️ | KML file management on the master HTTP server | ✅ Done |
| 🌍 | Orbit / FlyTo via `gx:FlyTo` KML + `LookAt` | ✅ Done |
| 🎬 | Tour control via `gs_cmd` mechanism | ✅ Done |
| 🤖 | Kotlin platform channel skeleton for native widgets | ✅ Done |
| 📱 | Android home-screen App Widget | 🔜 Phase 1 |
| 🔔 | Quick Settings tile (one-tap from notification shade) | 🔜 Phase 2 |
| 🖥️ | Multi-node status grid (CPU / RAM / disk per slave) | 🔜 Phase 3 |
| 📁 | KML library — browse, upload, target specific displays | 🔜 Phase 4 |

---

## Architecture

```mermaid
flowchart TD
    subgraph UI["🖼️  UI Layer"]
        DS[DashboardScreen]
        SS[SSHTestScreen]
        SET[SettingsScreen]
    end

    subgraph CTRL["🎮  Controllers  ·  ChangeNotifier"]
        DC[DashboardController]
        SC[SSHTestController]
    end

    subgraph SVC["⚙️  Service Layer  ·  GetIt Singletons"]
        CMD[LGCommandService]
        KML[LGKMLController]
        ORB[LGOrbitController]
        TOUR[LGTourController]
    end

    subgraph CORE["🔩  Core"]
        CLIENT[LGSSHClient\ndartssh2]
        REPO[CredentialsRepository\nflutter_secure_storage]
    end

    DS --> DC
    SS --> SC
    DC --> CMD
    DC --> KML
    SC --> CLIENT
    CMD --> CLIENT
    KML --> CMD
    ORB --> CMD
    TOUR --> CMD
    DC --> REPO
    SET --> REPO

    CLIENT <-->|TCP / SSH| LG[🖥️  LG Master Node\nlg@192.168.2.2:22]
    REPO <-->|AES-256-GCM| KS[🔐  Platform Keystore\nKeystore · Keychain · libsecret]

    style UI fill:#00B4D820,stroke:#00B4D8
    style CTRL fill:#90E0EF20,stroke:#90E0EF
    style SVC fill:#0077B620,stroke:#0077B6
    style CORE fill:#03045E20,stroke:#03045E
```

---

## SSH Connection State Machine

```mermaid
stateDiagram-v2
    [*] --> Disconnected : app launch

    Disconnected --> Connecting : connect()
    Connecting --> Connected : ✅ authenticated
    Connecting --> Disconnected : ❌ auth failure\n(no retry)
    Connecting --> Disconnected : ❌ network error\n(after N retries)

    Connected --> Disconnecting : disconnect()
    Connected --> Disconnected : 🔌 remote closes socket\n(reboot · shutdown · network loss)

    Disconnecting --> Disconnected : socket closed

    note right of Connected
        _watchForRemoteDisconnect()
        subscribes to rawClient.done
        — instant, zero polling
    end note
```

---

## First-launch Flow

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as LGQuickRigApp
    participant DI as ServiceLocator
    participant Repo as CredentialsRepository
    participant SSH as LGSSHClient
    participant LG as LG Master Node

    User->>App: Launch
    App->>DI: ServiceLocator.setup()
    DI-->>App: all singletons registered (lazy)
    App->>App: render DashboardScreen
    App->>Repo: load() — auto-connect attempt
    Repo-->>App: null (first launch, nothing saved)
    App-->>User: Dashboard · Disconnected state

    User->>App: tap ⚙  →  Settings
    User->>App: fill host · port · user · password · nodes
    User->>App: tap Save & Connect
    App->>Repo: save(SSHCredentials)
    Repo-->>App: written to Keystore ✅
    App->>SSH: connect(creds)
    SSH->>LG: TCP handshake → SSH auth
    LG-->>SSH: authenticated ✅
    SSH-->>App: SSHConnectionState.connected
    App-->>User: Dashboard · Connected · actions enabled 🟢
```

---

## Project Structure

```
lg_quickrig/
│
├── 📱 android/app/src/main/
│   ├── AndroidManifest.xml          ← INTERNET permission · widget/tile stubs
│   ├── kotlin/…/
│   │   ├── MainActivity.kt          ← wires LGCommandChannel on engine start
│   │   └── lg/
│   │       └── LGCommandChannel.kt  ← MethodChannel bridge for native widgets
│   └── res/
│       ├── xml/lg_home_widget_info.xml   ← AppWidgetProviderInfo template
│       └── layout/lg_home_widget.xml     ← RemoteViews placeholder
│
├── 🐧 linux/                        ← Linux desktop runner (auto-generated)
│
├── 📦 lib/
│   ├── main.dart                    ← async init · WidgetsFlutterBinding · DI
│   ├── app.dart                     ← MaterialApp · dark teal theme · home=Dashboard
│   │
│   ├── 🔩 core/
│   │   ├── constants.dart           ← LGDefaults (host, port, timeouts, retries)
│   │   ├── di/service_locator.dart  ← GetIt wiring — single source of truth
│   │   └── ssh/
│   │       ├── ssh_client.dart      ← LGSSHClient — transport, retry, state stream
│   │       ├── ssh_credentials.dart ← value object: host/port/user/pass/nodeCount
│   │       └── ssh_exception.dart   ← LGSSHException
│   │
│   ├── 💾 data/repositories/
│   │   └── credentials_repository.dart  ← flutter_secure_storage CRUD
│   │
│   ├── ⚙️ services/
│   │   ├── lg_command_service.dart  ← execute · executeOnSlave · system cmds
│   │   ├── lg_kml_controller.dart   ← sendKML · cleanKML · addKMLReference
│   │   ├── lg_orbit_controller.dart ← flyTo · lookAt · stopOrbit
│   │   └── lg_tour_controller.dart  ← startTour · stopTour · exitTour
│   │
│   ├── 🖼️ features/
│   │   ├── dashboard/
│   │   │   ├── dashboard_controller.dart  ← auto-connect · quick-action dispatch
│   │   │   └── dashboard_screen.dart      ← connection card + 6-tile action grid
│   │   ├── ssh_test/
│   │   │   ├── ssh_test_controller.dart   ← log management · DI-aware
│   │   │   └── ssh_test_screen.dart       ← dev console · timestamped output
│   │   └── settings/
│   │       └── settings_screen.dart       ← self-loading form · secure persistence
│   │
│   └── 🧩 shared/widgets/
│       └── connection_status_badge.dart   ← coloured pill: Disconnected/Connecting/Connected
│
└── 🧪 test/
    └── widget_test.dart             ← smoke test: Dashboard renders disconnected on launch
```

---

## Tech Stack

<div align="center">

| Layer | Package | Version | Purpose |
|:---:|:---:|:---:|:---|
| ![Flutter](https://img.shields.io/badge/-Flutter-02569B?logo=flutter&logoColor=white) | `flutter` | 3.38 | Cross-platform UI for Android + Linux |
| ![Dart](https://img.shields.io/badge/-Dart-0175C2?logo=dart&logoColor=white) | `dart` | 3.10 | Null-safe, async-first language |
| ![SSH](https://img.shields.io/badge/-SSH-4A90D9?logo=gnubash&logoColor=white) | `dartssh2` | ^2.9 | Pure-Dart SSH2 — no JNI, no native libs |
| ![Security](https://img.shields.io/badge/-Secure-E63946?logo=keepassxc&logoColor=white) | `flutter_secure_storage` | ^9.2 | Keystore / Keychain / libsecret |
| ![DI](https://img.shields.io/badge/-DI-FF9F1C) | `get_it` | ^8.0 | Zero-codegen service locator |
| ![Kotlin](https://img.shields.io/badge/-Kotlin-7F52FF?logo=kotlin&logoColor=white) | Kotlin coroutines | bundled | Platform channels for native widgets |
| ![State](https://img.shields.io/badge/-State-00B4D8) | `ChangeNotifier` | built-in | Reactive UI without extra packages |

</div>

---

## Getting Started

### Prerequisites

```
Flutter ≥ 3.16     dart pub get   ✓
Android SDK API 23+               ✓   (minSdk enforced in build.gradle.kts)
LG master node reachable over LAN ✓   SSH port 22 open
```

### Install & run

```bash
git clone https://github.com/your-org/lg-quickrig.git
cd lg-quickrig
flutter pub get
```

```bash
# Android device / emulator
flutter run

# Linux desktop window
flutter run -d linux

# Specific device
flutter run -d <device-id>
```

### First launch in 4 steps

```
① Open the app  ──►  Dashboard · Disconnected state (no credentials yet)
         │
         ▼
② Tap ⚙  ──►  Settings screen opens, form fields pre-filled with defaults
         │
         ▼
③ Enter your LG details:
         Host: 192.168.2.2   Port: 22
         Username: lg         Password: ••••••••
         Node count: 3
         │
         ▼
④ Tap "Save & Connect"
   → Credentials written to Keystore / Keychain
   → SSH handshake begins
   → Status badge turns 🟢  →  Quick Actions activate
```

---

## SSH Module

### Retry & connect

```dart
// lib/core/ssh/ssh_client.dart

await lgSSHClient.connect(
  SSHCredentials(
    host: '192.168.2.2', port: 22,
    username: 'lg', password: 'yourpass',
    nodeCount: 3,
  ),
  maxRetries: 3,         // attempts before giving up
  retryDelay: Duration(seconds: 2),   // delay between attempts
  connectTimeout: Duration(seconds: 10),
);
```

```
Attempt 1 ──► network error        Attempt 1 ──► SSHAuthAbortError
   ⏱ 2 s delay                        │
Attempt 2 ──► network error           └── LGSSHException thrown immediately
   ⏱ 2 s delay                            (no retries — wrong password)
Attempt 3 ──► timeout
   └── LGSSHException thrown
```

### Remote-disconnect detection (zero polling)

```dart
void _watchForRemoteDisconnect() {
  // Fires when the LG node closes the connection — e.g. after sudo reboot
  _rawClient?.done.then(
    (_) => _onRemoteClose(),
    onError: (_) => _onRemoteClose(),
  );
}

void _onRemoteClose() {
  if (_state == SSHConnectionState.connected) {
    _rawClient = null;
    _setState(SSHConnectionState.disconnected); // badge turns 🔴 instantly
  }
}
```

### Execute a command

```dart
final output = await lgSSHClient.executeCommand(
  'df -h /',
  timeout: Duration(seconds: 30),
);
// Returns: stdout (+ "[stderr] ..." prefix if stderr is non-empty)
```

---

## Service Layer

### Cluster-wide commands (`LGCommandService`)

```dart
// Raw execution on master (LG1)
await cmd.execute('echo hello from master');

// Execute on slave 2 via ssh-from-master — uses the stored password
await cmd.executeOnSlave(2, 'df -h /');

// System operations
await cmd.reboot();          // slaves 3→2→1 in order; connection drops after
await cmd.shutdown();        // same order; socket closes
await cmd.restartServices(); // pkill chrome + lg-relaunch on every node
await cmd.sync();            // ~/scripts/lg-sync
```

### KML management (`LGKMLController`)

```dart
// Write KML to the master's built-in HTTP server
await kml.sendKML(myKmlString, slave: 1);

// Target a specific slave display
await kml.sendSlaveKML(kml, 3);

// Register a URL in kmls.txt so the cluster loads it
await kml.addKMLReference('http://lg1/kml/my_scene.kml');

// Remove all QuickRig files + strip their kmls.txt references
await kml.cleanKML();
```

<details>
<summary>📄 Example KML — FlyTo Paris smoothly in 2 seconds</summary>

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <gx:Tour>
      <name>LGQuickRig FlyTo</name>
      <gx:Playlist>
        <gx:FlyTo>
          <gx:duration>2</gx:duration>
          <gx:flyToMode>smooth</gx:flyToMode>
          <LookAt>
            <longitude>2.3522</longitude>
            <latitude>48.8566</latitude>
            <altitude>0</altitude>
            <range>5000</range>
            <tilt>60</tilt>
            <heading>0</heading>
            <altitudeMode>relativeToGround</altitudeMode>
          </LookAt>
        </gx:FlyTo>
      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>
```

</details>

### Orbit / FlyTo (`LGOrbitController`)

```dart
// Fly smoothly to any coordinate
await orbit.flyTo(
  lat: 48.8566, lng: 2.3522,   // Paris, France
  altitude: 0,
  range: 5000,    // metres — zoom level
  tilt: 60,       // 0 = top-down, 90 = horizon
  heading: 45,    // compass bearing
);

await orbit.lookAt(lat: 27.1751, lng: 78.0421, altitudeM: 2000); // Taj Mahal

await orbit.stopOrbit(); // remove the FlyTo override, return to default view
```

### Tour control (`LGTourController`)

```dart
await tour.startTour('World Heritage Sites');  // gplaytour=World Heritage Sites
await tour.stopTour();                          // gplaytour=
await tour.exitTour();                          // gxplaytour=
```

> Tours are triggered by atomically writing to `~/gs_cmd` on the master
> (`/tmp/gs_cmd` → `mv` → `~/gs_cmd`) so the `gsync` watcher never reads
> a partial file.

---

## Dependency Injection

```mermaid
graph LR
    SL["⚡ ServiceLocator.setup()"]

    SL -->|lazy singleton| CR["🔐 CredentialsRepository"]
    SL -->|lazy singleton| SSH["🔌 LGSSHClient"]
    SL -->|lazy singleton| CMD["⚙️  LGCommandService\n(receives LGSSHClient)"]
    CMD -->|lazy singleton| KML["🗺️  LGKMLController"]
    CMD -->|lazy singleton| ORB["🌍 LGOrbitController"]
    CMD -->|lazy singleton| TOUR["🎬 LGTourController"]
```

```dart
// Resolve anywhere in the app — no context, no BuildContext, no Provider
final client = sl<LGSSHClient>();
final cmd    = sl<LGCommandService>();
final kml    = sl<LGKMLController>();
```

> **Rule:** Controllers that receive a singleton via `sl<T>()` must **never**
> call `.dispose()` on it. The singleton's lifetime is the app's lifetime.

---

## Credential Security

```
User enters credentials
        │
        ▼
CredentialsRepository.save(SSHCredentials)
        │
        ├─ 🤖 Android ──► EncryptedSharedPreferences
        │                  backed by Android Keystore
        │                  AES-256-GCM, hardware-backed on modern devices
        │                  requires minSdk = 23  (enforced in build.gradle.kts)
        │
        ├─ 🍎 iOS ──────► Keychain Services
        │                  hardware-backed on devices with Secure Enclave
        │
        └─ 🐧 Linux ────► libsecret / GNOME keyring
                           encrypted file fallback when no keyring daemon runs
```

All 5 fields (`host`, `port`, `username`, `password`, `nodeCount`) go into the
same enclave. The password is **never** logged, never written to
`SharedPreferences`, never stored in plain text.

The Settings screen intentionally does not pre-fill the password on load —
the user must re-type it, confirming knowledge of the credential before it
is written back.

---

## Android Platform Channels

> **Why this exists:** Android App Widgets and Quick Settings tiles run inside
> the **launcher / System UI process** — a completely different process from
> the Flutter app. They cannot call Dart directly. A background `FlutterEngine`
> must be spawned and Dart logic invoked via `MethodChannel`.

```
┌──────────────────────┐        MethodChannel         ┌─────────────────────────┐
│   Android Widget     │  ───────────────────────►   │   Dart / Flutter        │
│   (launcher process) │  "com.liqtech.lg_quickrig   │   (background engine)   │
│                      │    /commands"               │                         │
│   LGHomeWidgetProvider│ ◄───────────────────────── │   LGCommandChannel.kt   │
│   LGQuickSettingsTile│        result.success()     │   → LGCommandService    │
└──────────────────────┘                             └─────────────────────────┘
```

### Kotlin side — current skeleton

```kotlin
// LGCommandChannel.kt
MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
    when (call.method) {
        "executeSSHCommand" -> {
            val cmd = call.argument<String>("command") ?: ""
            // ⚠️  Handler runs on the PLATFORM THREAD — never block it!
            // Move SSH work to Dispatchers.IO:
            CoroutineScope(Dispatchers.IO).launch {
                val output = sshExecute(cmd)          // off main thread
                withContext(Dispatchers.Main) {
                    result.success(output)             // back on main thread
                }
            }
        }
        "getConnectionStatus" -> result.success("unconfigured")
        else -> result.notImplemented()
    }
}
```

### Dart side (widget button tap → SSH command)

```dart
const _ch = MethodChannel('com.liqtech.lg_quickrig/commands');

// Called from PendingIntent handler or TileService.onClick()
final result = await _ch.invokeMethod<String>(
  'executeSSHCommand',
  {'command': 'sudo reboot'},
);
```

---

## Roadmap

```mermaid
gantt
    title LG QuickRig — Release Plan
    dateFormat  YYYY-MM
    axisFormat  %b %Y

    section ✅ Done
    SSH module & DI foundation      :done, 2025-01, 2025-02
    Dashboard + Quick Actions       :done, 2025-02, 2025-03
    KML · Orbit · Tour services     :done, 2025-03, 2025-03
    Secure credential storage       :done, 2025-03, 2025-04

    section 🔜 Phase 1 — Widget
    LGHomeWidgetProvider.kt         :active, 2025-04, 2025-05
    LGWidgetService (FlutterEngine) :active, 2025-04, 2025-05
    Widget layout & RemoteViews     :2025-05, 2025-06

    section 🔜 Phase 2 — QS Tile
    LGQuickSettingsTile.kt          :2025-05, 2025-06
    Tile state sync with SSH        :2025-06, 2025-07

    section 🔜 Phase 3 — Multi-node Status
    Parallel SSH to all slaves      :2025-07, 2025-08
    Per-node CPU/RAM/disk grid      :2025-07, 2025-08

    section 🔜 Phase 4 — KML Library
    File browser + uploader         :2025-08, 2025-10
    Targeted display selector       :2025-09, 2025-10
```

<details>
<summary>📋 Phase 1 — App Widget implementation checklist</summary>

```
android/app/src/main/kotlin/…/lg/

[ ] LGHomeWidgetProvider.kt
    ├── onUpdate()  — inflate RemoteViews from lg_home_widget.xml
    ├── attach PendingIntent to each button (reboot, sync, clean KML)
    └── call AppWidgetManager.updateAppWidget()

[ ] LGWidgetService.kt
    ├── spawn FlutterEngine
    ├── call LGCommandChannel via MethodChannel
    └── update widget with result text

AndroidManifest.xml
[ ] Uncomment <receiver android:name=".lg.LGHomeWidgetProvider"> block
```

</details>

<details>
<summary>📋 Phase 2 — Quick Settings Tile implementation checklist</summary>

```
android/app/src/main/kotlin/…/lg/

[ ] LGQuickSettingsTile.kt  (extends TileService)
    ├── onClick()         → start LGWidgetService with selected action
    ├── onStartListening() → update tile icon/label from SSH state
    └── onStopListening() → unregister state observer

AndroidManifest.xml
[ ] Uncomment <service android:name=".lg.LGQuickSettingsTile"> block
```

</details>

---

## Liquid Galaxy Command Reference

<details>
<summary>🖥️  System management</summary>

```bash
# Reboot master (SSH drops immediately — expected)
sudo reboot

# Reboot a slave from the master
sshpass -p lg ssh -t -o StrictHostKeyChecking=no lg@lg2 'sudo reboot'

# Shut down the entire cluster
sudo shutdown -h now

# Restart browser stack on a node
export DISPLAY=:0; pkill -9 chrome; sleep 2; ~/bin/lg-relaunch

# Sync content master → all slaves
~/scripts/lg-sync
```

</details>

<details>
<summary>🗺️  KML management</summary>

```bash
# Blank all browser content cluster-wide
echo "" > /var/www/html/kmls.txt

# Load a KML URL on the cluster
echo 'http://lg1/kml/my_scene.kml' >> /var/www/html/kmls.txt

# Remove QuickRig KML files
rm -f /var/www/html/kml/lgquickrig_*.kml

# Strip QuickRig references from kmls.txt
sed -i '/lgquickrig/d' /var/www/html/kmls.txt
```

</details>

<details>
<summary>🎬  Tour control</summary>

```bash
# Start a named tour (name must match the gx:Tour name value in the KML)
echo 'gplaytour=My Tour Name' > /tmp/gs_cmd && mv /tmp/gs_cmd ~/gs_cmd

# Stop the current tour
echo 'gplaytour=' > /tmp/gs_cmd && mv /tmp/gs_cmd ~/gs_cmd
```

</details>

<details>
<summary>🩺  Diagnostics</summary>

```bash
# All LG-related processes
ps aux | grep -E 'chrome|earth|lg'

# Disk space on master
df -h /

# Ping slave 2
ping -c 3 lg2

# Which process owns the display
DISPLAY=:0 xdotool search --name "Google Earth"

# Slave SSH connectivity check
sshpass -p lg ssh lg@lg2 'hostname && uptime'
```

</details>

---

## Contributing

```bash
# 1. Fork + create a feature branch
git checkout -b feat/my-feature

# 2. Make changes, then verify
flutter analyze          # must report: No issues found
flutter test             # must report: All tests passed

# 3. For Kotlin changes
cd android && ./gradlew lint

# 4. Open a PR against main
```

### Adding a new Quick Action

```
1. lib/services/lg_command_service.dart
   └── add your method (or create a new service in lib/services/)

2. lib/features/dashboard/dashboard_controller.dart
   └── expose it via _runAction('Label', yourService.yourMethod)

3. lib/features/dashboard/dashboard_screen.dart
   └── add a _TileConfig entry in _QuickActionsGrid

4. If destructive → route through _confirmAndRun() in _DashboardScreenState
```

### Adding a new service

```dart
// lib/services/lg_your_service.dart
class LGYourService {
  final LGCommandService _cmd;
  LGYourService(this._cmd);
  // never import LGSSHClient directly — always go through LGCommandService
}

// lib/core/di/service_locator.dart
sl.registerLazySingleton<LGYourService>(
  () => LGYourService(sl<LGCommandService>()),
);
```

---

## License

```
MIT License  ·  Copyright (c) 2026 LG QuickRig Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

<div align="center">

**Built with**
&nbsp;
[![Flutter](https://img.shields.io/badge/Flutter-blue?logo=flutter&logoColor=white)](https://flutter.dev)
&nbsp;
[![dartssh2](https://img.shields.io/badge/dartssh2-pub.dev-blue)](https://pub.dev/packages/dartssh2)
&nbsp;
[![Keystore](https://img.shields.io/badge/Secured%20by-Platform%20Keystore-red?logo=keepassxc&logoColor=white)](https://pub.dev/packages/flutter_secure_storage)

<br/>

*Liquid Galaxy is an open-source project maintained by the Liquid Galaxy community.*
*LG QuickRig is an independent companion tool, not affiliated with Google.*

<br/>

⭐ Star this repo if it saves you an SSH session

</div>
