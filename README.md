<div align="center">

<pre>
██╗      ██████╗      ██████╗ ██╗   ██╗██╗ ██████╗██╗  ██╗██████╗ ██╗ ██████╗
██║     ██╔════╝     ██╔═══██╗██║   ██║██║██╔════╝██║ ██╔╝██╔══██╗██║██╔════╝
██║     ██║  ███╗    ██║   ██║██║   ██║██║██║     █████╔╝ ██████╔╝██║██║  ███╗
██║     ██║   ██║    ██║▄▄ ██║██║   ██║██║██║     ██╔═██╗ ██╔══██╗██║██║   ██║
███████╗╚██████╔╝    ╚██████╔╝╚██████╔╝██║╚██████╗██║  ██╗██║  ██║██║╚██████╔╝
╚══════╝ ╚═════╝      ╚══▀▀═╝  ╚═════╝ ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝
</pre>

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
- **Live Status widget** — a 2x2 widget with a colour-coded dot showing whether the rig is online, auto-refreshed every 5 minutes
- **Quick Settings tile** — toggle connectivity straight from the system shade, with a live SSH ping confirming reachability
- **Full companion app** — Dashboard, LG Commands panel, SSH Console, and Settings, all wired to a shared SSH session that persists across screens
- **Coming:** AI voice commands, Gemini-powered log monitoring, and a Linux desktop build

> The goal is a zero-friction rig operator's tool. If it takes more than one tap, it's too many.

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
║       (green)        ║
║      Connected       ║
║     192.168.2.2      ║
║    Updated 14:32     ║
║                      ║
║  Live Status  (2x2)  ║
╚══════════════════════╝
```

<br/>

---

## Roadmap

<div align="center">

`Progress ████████████░░░░░░░░░░░░░░░░░░░░  3 of 8 weeks`

</div>

<br/>

| | Week | Focus | Deliverables |
|:---:|:---:|:---|:---|
| ✅ | **1** | **SSH Foundation** | `LGSSHClient` · `LGCommandService` · secure credential storage · Dashboard · LG Commands · SSH Console |
| ✅ | **2** | **Android Widgets + Platform Channels** | `LGCommandChannel.kt` · `LGCredentialStore.kt` · `LGSshExecutor.kt` (JSch) · Command Bar widget (4x1) · Quick Settings tile |
| ✅ | **3** | **Live Status Widget** | `LGStatusWidgetProvider.kt` · 2x2 status widget · green/red ping indicator · 5-min auto-refresh |
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
│   ├── AndroidManifest.xml
│   ├── kotlin/com/liqtech/lg_quickrig/
│   │   ├── MainActivity.kt
│   │   └── lg/
│   │       ├── LGCommandChannel.kt       ← MethodChannel bridge: Dart <-> Kotlin
│   │       ├── LGCredentialStore.kt      ← reads EncryptedSharedPreferences (same store as Dart)
│   │       ├── LGSshExecutor.kt          ← JSch SSH client for widget/tile use
│   │       ├── LGHomeWidgetProvider.kt   ← Command Bar widget (4x1)
│   │       ├── LGQuickSettingsTile.kt    ← Quick Settings tile
│   │       └── LGStatusWidgetProvider.kt ← Live Status widget (2x2)
│   └── res/
│       ├── layout/
│       │   ├── lg_home_widget.xml
│       │   └── lg_status_widget.xml
│       ├── xml/
│       │   ├── lg_home_widget_info.xml
│       │   └── lg_status_widget_info.xml
│       ├── drawable/
│       │   ├── status_circle_online.xml
│       │   ├── status_circle_offline.xml
│       │   └── status_circle_pending.xml
│       └── values/strings.xml
│
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants.dart
│   │   ├── di/service_locator.dart
│   │   └── ssh/
│   │       ├── ssh_client.dart
│   │       ├── ssh_credentials.dart
│   │       └── ssh_exception.dart
│   ├── data/repositories/
│   │   └── credentials_repository.dart
│   ├── services/
│   │   ├── lg_command_service.dart
│   │   ├── lg_kml_controller.dart
│   │   ├── lg_orbit_controller.dart
│   │   └── lg_tour_controller.dart
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

**To add the Live Status widget:** same widget picker → drag a 2x2 slot.

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
