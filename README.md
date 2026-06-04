<div align="center">

```
██╗      ██████╗      ██████╗ ██╗   ██╗██╗ ██████╗██╗  ██╗██████╗ ██╗ ██████╗
██║     ██╔════╝     ██╔═══██╗██║   ██║██║██╔════╝██║ ██╔╝██╔══██╗██║██╔════╝
██║     ██║  ███╗    ██║   ██║██║   ██║██║██║     █████╔╝ ██████╔╝██║██║  ███╗
██║     ██║   ██║    ██║▄▄ ██║██║   ██║██║██║     ██╔═██╗ ██╔══██╗██║██║   ██║
███████╗╚██████╔╝    ╚██████╔╝╚██████╔╝██║╚██████╗██║  ██╗██║  ██║██║╚██████╔╝
╚══════╝ ╚═════╝      ╚══▀▀═╝  ╚═════╝ ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝
```

### Flutter-based Android + Linux companion app for Liquid Galaxy.

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
[![Gemini](https://img.shields.io/badge/AI-Gemini%20API-4285F4?style=flat-square&logo=google&logoColor=white)](https://ai.google.dev)

</div>

---

## What is LG QuickRig?

**Liquid Galaxy** is an open-source multi-display platform that renders synchronised panoramic views across a rig of 3–9 Linux machines running Google Earth. Managing it normally means SSH-ing into the master node every single time.

**LG QuickRig** eliminates that friction — control your entire Liquid Galaxy cluster from your Android home screen or Linux desktop without opening a terminal. One tap to reboot, sync, blank screens, or restart slaves. AI-powered voice commands and Gemini-driven log monitoring take it further: speak to your rig and let the system detect anomalies before they become incidents.

---

## App Preview

> Dashboard · LG Commands · SSH Console — dark teal Material 3 theme

```
╔═══════════════════════════════════════════╗   ╔═══════════════════════════════════════════╗
║  LG QuickRig          ● Connected         ║   ║  LG Commands             Connected        ║
╠═══════════════════════════════════════════╣   ╠═══════════════════════════════════════════╣
║                                           ║   ║  ┌─────────────────────────────────────┐  ║
║  ┌─────────────────────────────────────┐  ║   ║  │   Connected — ready to send commands│  ║
║  │ Connection                          │  ║   ║  └─────────────────────────────────────┘  ║
║  │ lg@192.168.2.2  ·  3 nodes          │  ║   ║                                           ║
║  │ ╔═════════════════════════════════╗ │  ║   ║  Commands                                 ║
║  │ ║            Disconnect           ║ │  ║   ║  ┌───────────────┐  ┌───────────────────┐ ║
║  └─────────────────────────────────────┘  ║   ║  │     Reboot    │  │    Shutdown       │ ║
║                                           ║   ║  └───────────────┘  └───────────────────┘ ║
║  Quick Actions                            ║   ║  ┌───────────────┐  ┌───────────────────┐ ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  │     Sync      │  │    Restart Slaves │ ║
║  │     Reboot    │  │    Restart Svcs   │ ║   ║  └───────────────┘  └───────────────────┘ ║
║  └───────────────┘  └───────────────────┘ ║   ║  ┌───────────────┐                        ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  │   Blank Scrn  │                        ║
║  │     Shutdown  │  │    Sync           │ ║   ║  └───────────────┘                        ║
║  └───────────────┘  └───────────────────┘ ║   ║                                           ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  Output                        [Clear]    ║
║  │   Blank Scrn  │  │    Clean KML      │ ║   ║  ┌─────────────────────────────────────┐  ║
║  └───────────────┘  └───────────────────┘ ║   ║  │14:32:01 [OUT] Running: Sync…        │  ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  │14:32:02 [OUT] Sync completed.       │  ║
║  │    LG Cmds    │  │ >_  SSH Console   │ ║   ║  └─────────────────────────────────────┘  ║
║  └───────────────┘  └───────────────────┘ ║   ╚═══════════════════════════════════════════╝
╚═══════════════════════════════════════════╝             LG Commands Screen
              Dashboard
```

---

## Roadmap

| Week | Focus | Key Deliverables |
|:---:|:---|:---|
| **1** ✅ | **SSH Foundation** | `LGSSHClient`, `LGCommandService` (reboot / shutdown / sync / restart slaves / blank screens), secure credential storage, Dashboard, LG Commands screen |
| **2** 🔜 | **Android Widgets + Platform Channels** | Command Bar widget (4×1), Quick Settings tile, `LGCommandChannel.kt` MethodChannel bridge |
| **3** 🔜 | **More Widgets + Background Service** | Live Status widget (2×2), `LGWidgetService` background Flutter engine, real-time SSH state in widgets |
| **4** 🔜 | **Linux Desktop Build** | `linux/` runner, desktop UI polish, release packaging for Debian/Ubuntu |
| **5** 🔜 | **AI Voice Commands + Gemini Integration** | Speech-to-SSH pipeline, Gemini API wiring, natural-language cluster control |
| **6** 🔜 | **Log Monitoring + Anomaly Detection + Adaptive Layout** | Gemini-powered SSH log analysis, anomaly alerts, adaptive widget layout |
| **7** 🔜 | **Testing + Polish** | Unit tests, integration tests, widget tests, UI refinements, edge-case hardening |
| **8** 🔜 | **Documentation + Submission** | Final docs, demo video, submission-ready release |


---

## Architecture

```mermaid
flowchart TD
    subgraph UI["🖼️  UI Layer"]
        DS[DashboardScreen]
        LGC[LGCommandsScreen]
        SS[SSHTestScreen]
        SET[SettingsScreen]
    end

    subgraph CTRL["🎮  Controllers  ·  ChangeNotifier"]
        DC[DashboardController]
        LGCC[LGCommandsController]
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
    LGC --> LGCC
    SS --> SC
    DC --> CMD
    DC --> KML
    LGCC --> CMD
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
│   │   ├── lg_orbit_controller.dart ← flyTo · orbitPlay · orbitStop
│   │   └── lg_tour_controller.dart  ← startTour · stopTour · exitTour
│   │
│   ├── 🖼️ features/
│   │   ├── dashboard/
│   │   │   ├── dashboard_controller.dart  ← auto-connect · quick-action dispatch
│   │   │   └── dashboard_screen.dart      ← connection card + 8-tile action grid
│   │   ├── lg_commands/
│   │   │   ├── lg_commands_controller.dart ← preset command dispatch + output log
│   │   │   └── lg_commands_screen.dart     ← buttons + output log + status header
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

| Layer | Technology | Purpose |
|:---:|:---:|:---|
| ![Flutter](https://img.shields.io/badge/-Flutter-02569B?logo=flutter&logoColor=white) | Flutter 3.38 | Cross-platform UI — Android + Linux from one codebase |
| ![Dart](https://img.shields.io/badge/-Dart-0175C2?logo=dart&logoColor=white) | Dart 3.10 | Null-safe, async-first application logic |
| ![Kotlin](https://img.shields.io/badge/-Kotlin-7F52FF?logo=kotlin&logoColor=white) | Kotlin | Android platform channels, widgets, Quick Settings tile |
| ![XML](https://img.shields.io/badge/-XML-F7931E?logo=html5&logoColor=white) | XML | Android widget layouts (RemoteViews), AppWidgetProviderInfo |
| ![SSH](https://img.shields.io/badge/-SSH-4A90D9?logo=gnubash&logoColor=white) | `dartssh2 ^2.9` | Pure-Dart SSH2 — no JNI, no native libs |
| ![Security](https://img.shields.io/badge/-Secure-E63946?logo=keepassxc&logoColor=white) | `flutter_secure_storage ^9.2` | AES-256-GCM via Keystore / Keychain / libsecret |
| ![DI](https://img.shields.io/badge/-DI-FF9F1C) | `get_it ^8.0` | Zero-codegen service locator |
| ![Gemini](https://img.shields.io/badge/-Gemini-4285F4?logo=google&logoColor=white) | Gemini API | Voice commands, log monitoring, anomaly detection |
| ![State](https://img.shields.io/badge/-State-00B4D8) | `ChangeNotifier` | Reactive UI without extra packages |

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

flutter run            # Android device / emulator
flutter run -d linux   # Linux desktop window
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

`LGSSHClient.connect()` retries up to `maxRetries` times before throwing `LGSSHException`. Auth failures short-circuit immediately — no point retrying a wrong password.

```
Attempt 1 ──► network error        Attempt 1 ──► SSHAuthAbortError
   ⏱ 2 s delay                        │
Attempt 2 ──► network error           └── LGSSHException thrown immediately
   ⏱ 2 s delay                            (no retries — wrong password)
Attempt 3 ──► timeout
   └── LGSSHException thrown
```

### Remote-disconnect detection (zero polling)

When the LG node drops the connection — e.g. immediately after `sudo reboot` — `LGSSHClient` listens on the raw client's `done` future and transitions to `SSHConnectionState.disconnected` without any polling loop. The status badge turns red instantly.

### Execute a command

```dart
final output = await lgSSHClient.executeCommand(
  'df -h /',
  timeout: Duration(seconds: 30),
);
// Returns: stdout (+ "[stderr] ..." prefix when stderr is non-empty)
```

---

## Service Layer

### Predefined commands (`LGCommandService`)

`LGCommandService` wraps `LGSSHClient` with cluster-aware helpers: `executeOnSlave` SSH-hops from the master to each slave node, and the system commands handle the correct teardown order automatically.

```dart
await cmd.reboot();           // slaves 3→2→1 then master; connection drops — expected
await cmd.shutdown();         // same descending order
await cmd.restartServices();  // pkill chrome + lg-relaunch on every node
await cmd.sync();             // ~/scripts/lg-sync on master
await cmd.blankScreens();     // empty KML to each slave + clear kmls.txt
```

### KML management (`LGKMLController`)

`LGKMLController` writes and removes KML files on the master's built-in HTTP server. The cluster browser stack polls `kmls.txt` for URLs to load. UI integration is planned for a later week.

### Orbit / FlyTo (`LGOrbitController`)

`LGOrbitController` sends `flytoview=<LookAt>` commands to `/tmp/query.txt`, the standard LG mechanism for live camera control. No NetworkLink setup required. UI integration is planned for a later week.

### Tour control (`LGTourController`)

`LGTourController` writes `gplaytour=NAME` to `~/gs_cmd`, which the `gsync` process on the master monitors to start and stop KML tours. UI integration is planned for a later week.

---

## Dependency Injection

All services are registered as **lazy singletons** via GetIt. They are instantiated on first access and live for the app's entire lifetime — the SSH connection is never dropped and re-opened as screens are pushed and popped.

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
// Resolve anywhere — no BuildContext, no Provider
final client = sl<LGSSHClient>();
final cmd    = sl<LGCommandService>();
```

> **Rule:** Controllers that receive a singleton via `sl<T>()` must **never** call `.dispose()` on it. The singleton's lifetime is the app's lifetime.

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
        │                  requires minSdk = 23
        │
        ├─ 🍎 iOS ──────► Keychain Services
        │                  hardware-backed on devices with Secure Enclave
        │
        └─ 🐧 Linux ────► libsecret / GNOME keyring
                           encrypted file fallback when no keyring daemon runs
```

All 5 fields (`host`, `port`, `username`, `password`, `nodeCount`) go into the same enclave. The password is **never** logged, never written to `SharedPreferences`, never stored in plain text.

---

## Android Platform Channels

> Android App Widgets and Quick Settings tiles run inside the **launcher / System UI process** — a completely different process from the Flutter app. A background `FlutterEngine` is spawned and Dart logic invoked via `MethodChannel`.

```
┌──────────────────────┐        MethodChannel         ┌─────────────────────────┐
│   Android Widget     │  ───────────────────────►   │   Dart / Flutter        │
│   (launcher process) │  "com.liqtech.lg_quickrig   │   (background engine)   │
│                      │    /commands"               │                         │
│  LGHomeWidgetProvider│ ◄───────────────────────── │   LGCommandChannel.kt   │
│  LGQuickSettingsTile │        result.success()     │   → LGCommandService    │
└──────────────────────┘                             └─────────────────────────┘
```

The Kotlin `MethodChannel` handler and background engine wiring are planned for Week 2.

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
<summary>🩺  Diagnostics</summary>

```bash
# All LG-related processes
ps aux | grep -E 'chrome|earth|lg'

# Disk space on master
df -h /

# Ping slave 2
ping -c 3 lg2

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

# 3. Open a PR against main
```

### Adding a new predefined command

```
1. lib/services/lg_command_service.dart
   └── add your method

2. lib/features/dashboard/dashboard_controller.dart
   └── expose it via _runAction('Label', commandService.yourMethod)

3. lib/features/dashboard/dashboard_screen.dart
   └── add a _TileConfig entry in _QuickActionsGrid

4. lib/features/lg_commands/lg_commands_controller.dart + lg_commands_screen.dart
   └── add a button in _CommandButtons

5. If destructive → route through _confirmAndRun() / _confirmThenRun()
```

### Adding a new service

New services should receive `LGCommandService` as a constructor parameter — never import `LGSSHClient` directly. Register the service as a lazy singleton in `lib/core/di/service_locator.dart` following the existing pattern.

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
[![Gemini](https://img.shields.io/badge/Gemini%20API-4285F4?logo=google&logoColor=white)](https://ai.google.dev)
&nbsp;
[![Keystore](https://img.shields.io/badge/Secured%20by-Platform%20Keystore-red?logo=keepassxc&logoColor=white)](https://pub.dev/packages/flutter_secure_storage)

<br/>

*Liquid Galaxy is an open-source project maintained by the Liquid Galaxy community.*
*LG QuickRig is an independent companion tool, not affiliated with Google.*

<br/>

⭐ Star this repo if it saves you an SSH session

</div>
