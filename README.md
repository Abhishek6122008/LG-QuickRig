<div align="center">

```
██╗      ██████╗      ██████╗ ██╗   ██╗██╗ ██████╗██╗  ██╗██████╗ ██╗ ██████╗
██║     ██╔════╝     ██╔═══██╗██║   ██║██║██╔════╝██║ ██╔╝██╔══██╗██║██╔════╝
██║     ██║  ███╗    ██║   ██║██║   ██║██║██║     █████╔╝ ██████╔╝██║██║  ███╗
██║     ██║   ██║    ██║▄▄ ██║██║   ██║██║██║     ██╔═██╗ ██╔══██╗██║██║   ██║
███████╗╚██████╔╝    ╚██████╔╝╚██████╔╝██║╚██████╗██║  ██╗██║  ██║██║╚██████╔╝
╚══════╝ ╚═════╝      ╚══▀▀═╝  ╚═════╝ ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝
```

**Control your Liquid Galaxy cluster from your pocket.**<br/>
*No terminal. No SSH. One tap.*

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2023+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![Linux](https://img.shields.io/badge/Linux-Desktop-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://flutter.dev/multi-platform/linux)
[![License](https://img.shields.io/badge/License-MIT-8A2BE2?style=for-the-badge)](LICENSE)

<br/>

[![SSH](https://img.shields.io/badge/SSH-dartssh2-4A90D9?style=flat-square&logo=gnubash&logoColor=white)](https://pub.dev/packages/dartssh2)
[![Storage](https://img.shields.io/badge/Keystore-AES--256--GCM-E63946?style=flat-square&logo=keepassxc&logoColor=white)](https://pub.dev/packages/flutter_secure_storage)
[![DI](https://img.shields.io/badge/DI-GetIt-FF9F1C?style=flat-square)](https://pub.dev/packages/get_it)
[![JSch](https://img.shields.io/badge/Kotlin_SSH-JSch-7F52FF?style=flat-square&logo=kotlin&logoColor=white)](https://github.com/mwiede/jsch)
[![Gemini](https://img.shields.io/badge/AI-Gemini_API-4285F4?style=flat-square&logo=google&logoColor=white)](https://ai.google.dev)

<br/>

<table>
<tr>
<td align="center"><b>3 / 8</b><br/><sub>Weeks done</sub></td>
<td align="center"><b>4</b><br/><sub>Flutter screens</sub></td>
<td align="center"><b>6</b><br/><sub>Kotlin files</sub></td>
<td align="center"><b>3</b><br/><sub>Android surfaces</sub></td>
<td align="center"><b>0</b><br/><sub>Plaintext secrets</sub></td>
</tr>
</table>

</div>

<br/>

---

## What is LG QuickRig?

[**Liquid Galaxy**](https://www.liquidgalaxy.eu/) is an open-source panoramic display platform — 3 to 9 Linux machines running Google Earth in sync across a curved wall of screens. Magnificent to look at. Tedious to manage: every reboot, sync, or slave restart means cracking open a terminal and SSHing in by hand.

**LG QuickRig** removes that entirely.

- **One tap from your home screen** — a 4x1 Android widget puts Reboot, Sync, Shutdown, and Blank Screens on your launcher, no app open required
- **Live Status widget** — a 2x2 widget shows real-time connection state with a colour-coded dot, auto-refreshed every 5 minutes
- **Quick Settings tile** — toggle connectivity straight from the system shade, with a live SSH ping confirming reachability
- **Full companion app** — Dashboard, LG Commands panel, SSH Console, and Settings, all wired to a shared SSH session that persists across screens
- **Coming:** AI voice commands, Gemini-powered log monitoring, and a Linux desktop build

> The goal is a zero-friction rig operator's tool. If it takes more than one tap, it's too many.

<br/>

---

## Presentation — June 17

> Talking points for the first project meeting. Seven topics you can go deep on or keep surface-level depending on the audience.

<br/>

<details>
<summary><b>1 · The problem this solves — and why it's not trivial</b></summary>

<br/>

Liquid Galaxy is impressive hardware — up to 9 synced displays running Google Earth — but the operator experience is stuck in the 90s. Every reboot, sync, or slave restart means opening a terminal, SSHing into the master node, and typing commands. On a shared rig this happens constantly.

The obvious solution is "just make an app." The non-obvious part is that the Android home screen widget and Quick Settings tile are processes completely separate from the app — they run inside the launcher and System UI respectively. You can't just call the Flutter engine from there. That process-isolation problem is what drove the entire Kotlin architecture in Week 2.

**One line version:** *"The hard part wasn't SSH — it was making SSH work from the home screen without the app being open."*

</details>

<details>
<summary><b>2 · Two SSH clients — why, and why that's the right call</b></summary>

<br/>

The app has two completely independent SSH implementations:

| | Where | Library | When it's used |
|:---|:---|:---|:---|
| **Dart side** | Flutter engine (main process) | `dartssh2` | App UI is open and running |
| **Kotlin side** | Widget / tile process | `JSch` | Home screen widget tap, QS tile ping |

The reason for two: Android App Widgets are `BroadcastReceiver`s running in the **launcher process**. Quick Settings tiles are bound services in **System UI**. Neither has access to the live Flutter engine or its SSH socket.

The alternatives — spinning up a background FlutterEngine, or using WorkManager to delegate back to Dart — add hundreds of milliseconds of startup latency and a lot of lifecycle complexity for a button that should feel instant.

JSch opens a fresh session per command, runs it, closes it. For fire-and-forget cluster operations (reboot, sync, blank screens) that's exactly right.

**One line version:** *"We have two SSH clients because Android's process model made one impossible."*

</details>

<details>
<summary><b>3 · The EncryptedSharedPreferences trick</b></summary>

<br/>

Credentials are saved by the Flutter Settings screen using `flutter_secure_storage`. On Android that means `EncryptedSharedPreferences` — a file named `"FlutterSecureStorage"` in the app's data directory, encrypted with a `MasterKey` stored in the Android Keystore under the alias `"_androidx_security_master_key"`.

`LGCredentialStore.kt` (the Kotlin credential reader for widgets/tiles) opens the **exact same file** using the **exact same key alias**. The Android Keystore returns the existing key when the alias matches — no new key is created — so both sides decrypt the same values without any cross-process credential passing, no duplicate storage, and no sync step.

This is non-obvious. Most people would introduce a separate storage mechanism or pass credentials through Intent extras (which is a security hole). Sharing the EncryptedSharedPreferences directly is the correct pattern and it's clean.

**One line version:** *"Dart writes the credentials, Kotlin reads them from the same encrypted file — no duplication, no passing secrets through Intents."*

</details>

<details>
<summary><b>4 · A real debugging story — the sudo TTY problem</b></summary>

<br/>

Reboot and shutdown weren't working even though the SSH connection was solid. The SSH Console screen (a raw command runner built into the app) was essential here — running `sudo reboot` directly showed:

```
[stderr] sudo: no tty present and no askpass program specified
```

The problem: `sudo` by default requires either a TTY (pseudo-terminal) to prompt for a password interactively, or `NOPASSWD` configured in sudoers. Our SSH sessions use `ChannelExec` (non-interactive), so no TTY is allocated. And the LG nodes don't have `NOPASSWD` for the `lg` user.

The fix is `sudo -S`, which tells sudo to read the password from stdin instead of a TTY:

```
echo 'password' | sudo -S reboot
```

The SSH Console was built exactly for moments like this — test commands directly against the live node, see raw output, debug without touching the app code. It paid off immediately.

**One line version:** *"The app has a built-in SSH console specifically so we can debug the LG node without leaving the tool."*

</details>

<details>
<summary><b>5 · How camera control works — query.txt vs KML NetworkLink</b></summary>

<br/>

There are two ways to move the Liquid Galaxy camera programmatically:

- **KML NetworkLink** — write a `gx:FlyTo` element to a KML file on the HTTP server and set up a NetworkLink that polls it. Requires per-installation configuration.
- **`/tmp/query.txt`** — write `flytoview=<LookAt>...</LookAt>` to this file on the master node. The LG process monitors it natively. No setup required.

`LGOrbitController` uses `query.txt`. It's the correct mechanism — it's what Google's original LG setup uses — but a lot of third-party apps use the NetworkLink approach because it's more documented. The `query.txt` approach works on a stock LG installation with zero configuration.

The 360° orbit is a `Timer.periodic` loop running every 400ms, incrementing the heading by 6° per step (60 steps x 6° = 360°), firing a new `flytoview` command each tick. The result is a smooth orbit around a geographic point.

**One line version:** *"The camera orbit writes 60 SSH commands over 24 seconds — one every 400ms — and the LG picks them up natively via a file it already watches."*

</details>

<details>
<summary><b>6 · Architecture decisions worth explaining</b></summary>

<br/>

Three choices that come up in Flutter architecture discussions:

**GetIt over Provider/Riverpod**
GetIt is a service locator, not a state management solution. It holds the SSH client singleton and resolves it anywhere without needing a `BuildContext`. Provider and Riverpod are excellent for widget state — they're overkill for "I need the same SSH connection in every screen." GetIt solves the exact right problem here.

**ChangeNotifier over Bloc/Riverpod**
The controllers (`DashboardController`, `LGCommandsController`) extend `ChangeNotifier` and are wrapped with `ListenableBuilder` in the UI. No generated code, no separate events/states, no boilerplate. For an app with simple state (connected/busy/error), the overhead of Bloc or Riverpod isn't justified. If the app grows to Week 6-7 complexity with async log streams and voice input, that call gets revisited.

**Layered service architecture**
`LGSSHClient` → `LGCommandService` → `LGKMLController / LGOrbitController` is a strict one-way dependency chain. Nothing at a higher layer imports something at a lower layer out of order. This means you can swap `LGSSHClient` (e.g., replace `dartssh2` with something else) without touching any controller.

**One line version:** *"The architecture is deliberately boring — the interesting engineering is in the SSH layer, not the state management."*

</details>

<details>
<summary><b>7 · Where it goes from here — Weeks 4–8</b></summary>

<br/>

The foundation (Weeks 1–3) is complete: SSH works, all three Android surfaces work, credentials are secure, the architecture is clean. The remaining five weeks build on top:

| Milestone | What it unlocks |
|:---|:---|
| **Week 4** — Linux desktop build | The same Flutter codebase compiles to a native Linux window for use on the LG operator machine |
| **Week 5** — Gemini voice commands | Speak to the rig: *"fly to the Eiffel Tower"* → SSH command sent |
| **Week 6** — Log monitoring | Gemini reads the LG system logs over SSH and flags anomalies before they become incidents |
| **Weeks 7–8** — Polish + submission | Tests, docs, demo video |

The AI weeks are the project's headline feature. Everything built in Weeks 1–3 is infrastructure that makes those weeks possible without scrambling.

**One line version:** *"Weeks 1–3 are the foundation. Weeks 5 and 6 are why the project is interesting."*

</details>

<br/>

---

## App Preview

<div align="center">

*Dark teal · Material 3 · Dashboard + LG Commands*

</div>

```
╔═══════════════════════════════════════════╗   ╔═══════════════════════════════════════════╗
║  LG QuickRig          Connected           ║   ║  LG Commands             Connected        ║
╠═══════════════════════════════════════════╣   ╠═══════════════════════════════════════════╣
║                                           ║   ║  ┌─────────────────────────────────────┐  ║
║  ┌─────────────────────────────────────┐  ║   ║  │    Connected — ready to send cmds   │  ║
║  │ Connection                          │  ║   ║  └─────────────────────────────────────┘  ║
║  │ lg@192.168.2.2  ·  3 nodes          │  ║   ║                                           ║
║  │ ┌─────────────────────────────────┐ │  ║   ║  Commands                                 ║
║  │ │           Disconnect            │ │  ║   ║  ┌───────────────┐  ┌───────────────────┐ ║
║  └─────────────────────────────────────┘  ║   ║  │     Reboot    │  │     Shutdown      │ ║
║                                           ║   ║  └───────────────┘  └───────────────────┘ ║
║  Quick Actions                            ║   ║  ┌───────────────┐  ┌───────────────────┐ ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  │     Sync      │  │    Restart Slaves │ ║
║  │     Reboot    │  │     Restart Svcs  │ ║   ║  └───────────────┘  └───────────────────┘ ║
║  └───────────────┘  └───────────────────┘ ║   ║  ┌───────────────┐                        ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  │   Blank Scrn  │                        ║
║  │     Shutdown  │  │     Sync          │ ║   ║  └───────────────┘                        ║
║  └───────────────┘  └───────────────────┘ ║   ║                                           ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  Output                         [Clear]   ║
║  │   Blank Scrn  │  │     Clean KML     │ ║   ║  ┌─────────────────────────────────────┐  ║
║  └───────────────┘  └───────────────────┘ ║   ║  │ 14:32:01 [OUT] Running: Sync...     │  ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  │ 14:32:02 [OUT] Sync completed.      │  ║
║  │     LG Cmds   │  │  SSH Console      │ ║   ║  └─────────────────────────────────────┘  ║
║  └───────────────┘  └───────────────────┘ ║   ╚═══════════════════════════════════════════╝
╚═══════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════╗
║  Android Home Screen                                     ║
║                                                          ║
║  ┌───────────────────────────────────────────────────┐   ║
║  │  LG QuickRig                                      │   ║
║  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────┐ │   ║
║  │  │  Reboot  │ │   Sync   │ │  Shutdn  │ │ Blank │ │   ║
║  │  └──────────┘ └──────────┘ └──────────┘ └───────┘ │   ║
║  └───────────────────────────────────────────────────┘   ║
║         Command Bar widget  (4x1)                        ║
╚══════════════════════════════════════════════════════════╝
```

```
╔══════════════════════╗
║  LG QuickRig         ║
║                      ║
║       ( green )      ║
║      Connected       ║
║   192.168.2.2        ║
║   Updated 14:32      ║
║                      ║
║  Live Status  (2x2)  ║
╚══════════════════════╝
```

<br/>

---

## Roadmap

<div align="center">

`Progress ████████████░░░░░░░░░░░░░░░░░░  3 of 8 weeks`

</div>

<br/>

| | Week | Focus | Shipped |
|:---:|:---:|:---|:---|
| ✅ | **1** | **SSH Foundation** | `LGSSHClient` · `LGCommandService` · secure credential storage · Dashboard · LG Commands · SSH Console |
| ✅ | **2** | **Android Widgets + Platform Channels** | `LGCommandChannel.kt` · `LGCredentialStore.kt` · `LGSshExecutor.kt` (JSch) · Command Bar widget (4x1) · Quick Settings tile |
| ✅ | **3** | **Live Status Widget** | `LGStatusWidgetProvider.kt` · 2x2 status widget · green/red ping indicator · AlarmManager 5-min auto-refresh |
| 🔜 | **4** | **Linux Desktop Build** | `linux/` runner · desktop UI polish · Debian/Ubuntu packaging |
| 🔜 | **5** | **AI Voice Commands** | Speech-to-SSH pipeline · Gemini API wiring · natural-language cluster control |
| 🔜 | **6** | **Log Monitoring + Anomaly Detection** | Gemini-powered SSH log analysis · anomaly alerts |
| 🔜 | **7** | **Testing + Polish** | Unit · integration · widget tests · UI refinements |
| 🔜 | **8** | **Docs + Submission** | Final docs · demo video · submission-ready release |

<br/>

---

## Project Structure

```
lg_quickrig/
│
├── android/app/src/main/
│   ├── AndroidManifest.xml             ← INTERNET · widget receivers · QS tile service
│   ├── kotlin/com/liqtech/lg_quickrig/
│   │   ├── MainActivity.kt             ← wires LGCommandChannel on engine start
│   │   └── lg/
│   │       ├── LGCommandChannel.kt     ← MethodChannel bridge: Dart <-> Kotlin
│   │       ├── LGCredentialStore.kt    ← reads EncryptedSharedPreferences (same store as Dart)
│   │       ├── LGSshExecutor.kt        ← JSch SSH client for widget/tile use
│   │       ├── LGHomeWidgetProvider.kt ← Command Bar widget: 4 buttons, PendingIntent routing
│   │       ├── LGQuickSettingsTile.kt  ← TileService: ping-based connect/disconnect toggle
│   │       └── LGStatusWidgetProvider.kt ← Live Status widget: ping, colour dot, AlarmManager refresh
│   └── res/
│       ├── xml/
│       │   ├── lg_home_widget_info.xml    ← AppWidgetProviderInfo (4x1, 300dp)
│       │   └── lg_status_widget_info.xml  ← AppWidgetProviderInfo (2x2, 148dp)
│       ├── layout/
│       │   ├── lg_home_widget.xml         ← Command Bar: Reboot · Sync · Shutdown · Blank
│       │   └── lg_status_widget.xml       ← Live Status: dot · label · host · timestamp
│       ├── drawable/
│       │   ├── status_circle_online.xml   ← green oval
│       │   ├── status_circle_offline.xml  ← red oval
│       │   └── status_circle_pending.xml  ← grey oval
│       └── values/strings.xml
│
├── linux/                              ← Linux desktop runner (Week 4)
│
├── lib/
│   ├── main.dart                       ← async init · DI setup
│   ├── app.dart                        ← MaterialApp · dark teal theme
│   │
│   ├── core/
│   │   ├── constants.dart
│   │   ├── di/service_locator.dart     ← GetIt wiring
│   │   └── ssh/
│   │       ├── ssh_client.dart         ← LGSSHClient — transport, retry, state stream
│   │       ├── ssh_credentials.dart
│   │       └── ssh_exception.dart
│   │
│   ├── data/repositories/
│   │   └── credentials_repository.dart ← flutter_secure_storage CRUD
│   │
│   ├── services/
│   │   ├── lg_command_service.dart     ← execute · executeOnSlave · system commands
│   │   ├── lg_kml_controller.dart
│   │   ├── lg_orbit_controller.dart    ← flyTo · orbitPlay · orbitStop
│   │   └── lg_tour_controller.dart
│   │
│   ├── features/
│   │   ├── dashboard/
│   │   │   ├── dashboard_controller.dart
│   │   │   └── dashboard_screen.dart
│   │   ├── lg_commands/
│   │   │   ├── lg_commands_controller.dart
│   │   │   └── lg_commands_screen.dart
│   │   ├── ssh_test/
│   │   │   ├── ssh_test_controller.dart
│   │   │   └── ssh_test_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   │
│   └── shared/widgets/
│       └── connection_status_badge.dart
│
└── test/
    └── widget_test.dart
```

<br/>

---

## Tech Stack

<div align="center">

| Layer | Technology | What it does |
|:---:|:---:|:---|
| ![Flutter](https://img.shields.io/badge/-Flutter-02569B?logo=flutter&logoColor=white) | **Flutter 3.38** | Cross-platform UI — Android + Linux from a single codebase |
| ![Dart](https://img.shields.io/badge/-Dart-0175C2?logo=dart&logoColor=white) | **Dart 3.10** | Null-safe, async-first application logic |
| ![Kotlin](https://img.shields.io/badge/-Kotlin-7F52FF?logo=kotlin&logoColor=white) | **Kotlin** | Platform channels, App Widgets, Quick Settings tile |
| ![SSH](https://img.shields.io/badge/-dartssh2-4A90D9?logo=gnubash&logoColor=white) | **dartssh2 ^2.9** | Pure-Dart SSH2 — no JNI, no native libs, no C bridge |
| ![JSch](https://img.shields.io/badge/-JSch-555555?logo=openjdk&logoColor=white) | **JSch 0.1.55** | Java SSH for Kotlin widget/tile operations (no Flutter engine needed) |
| ![Security](https://img.shields.io/badge/-AES--256--GCM-E63946?logo=keepassxc&logoColor=white) | **flutter\_secure\_storage ^9.2** | Hardware-backed encryption via Keystore / Keychain / libsecret |
| ![DI](https://img.shields.io/badge/-GetIt-FF9F1C) | **get\_it ^8.0** | Zero-codegen service locator — resolve anywhere, no BuildContext |
| ![State](https://img.shields.io/badge/-ChangeNotifier-00B4D8) | **ChangeNotifier** | Reactive UI without extra state management packages |
| ![Gemini](https://img.shields.io/badge/-Gemini_API-4285F4?logo=google&logoColor=white) | **Gemini API** | *(Week 5+)* Voice commands, log analysis, anomaly detection |

</div>

<br/>

---

## Getting Started

### Prerequisites

```
Flutter >= 3.16     flutter pub get    ✓
Android SDK API 23+                    ✓   minSdk enforced in build.gradle.kts
LG master node reachable over LAN      ✓   SSH port 22 open, sudo -S supported
```

### Install & run

```bash
git clone https://github.com/your-org/lg-quickrig.git
cd lg-quickrig
flutter pub get

flutter run            # Android device / emulator
flutter run -d linux   # Linux desktop window
```

### First launch

```
  1. Open the app
        Dashboard shows Disconnected (no credentials saved yet)

  2. Tap Settings
        Enter host, port, username, password, node count

  3. Tap Save & Connect
        Credentials → Keystore
        SSH handshake → authenticated
        Status badge → Connected, actions enabled
```

**To add the Command Bar widget:** long-press launcher → Widgets → LG QuickRig → drag a 4x1 slot.

**To add the Live Status widget:** same picker → drag a 2x2 slot.

**To add the Quick Settings tile:** pull down the shade → edit tiles → add *LG QuickRig*.

<br/>

---

## Contributing

```bash
git checkout -b feat/your-feature
# make changes
flutter analyze    # must show: No issues found
flutter test       # must show: All tests passed
# open PR -> main
```

New cluster commands go in `lib/services/lg_command_service.dart`. New services take `LGCommandService` as a constructor parameter — never `LGSSHClient` directly — and are registered as lazy singletons in `lib/core/di/service_locator.dart`.

<br/>

---

## License

MIT License · Copyright (c) 2026 LG QuickRig Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. The software is provided "as is", without warranty of any kind.

<br/>

---

<div align="center">

**Built with Flutter · dartssh2 · JSch · Gemini · Platform Keystore**

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-blue?logo=flutter&logoColor=white)](https://flutter.dev)
&nbsp;
[![dartssh2](https://img.shields.io/badge/dartssh2-pub.dev-4A90D9)](https://pub.dev/packages/dartssh2)
&nbsp;
[![Gemini](https://img.shields.io/badge/Gemini_API-4285F4?logo=google&logoColor=white)](https://ai.google.dev)
&nbsp;
[![Keystore](https://img.shields.io/badge/AES--256--GCM-Platform_Keystore-E63946?logo=keepassxc&logoColor=white)](https://pub.dev/packages/flutter_secure_storage)

<br/>

*Liquid Galaxy is an open-source project by the Liquid Galaxy community.*
*LG QuickRig is an independent tool — not affiliated with Google.*

</div>
