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
<td align="center"><b>5 / 8</b><br/><sub>Weeks done</sub></td>
<td align="center"><b>2</b><br/><sub>Platforms</sub></td>
<td align="center"><b>8</b><br/><sub>Kotlin files</sub></td>
<td align="center"><b>4</b><br/><sub>Android surfaces</sub></td>
<td align="center"><b>0</b><br/><sub>Plaintext secrets</sub></td>
</tr>
</table>

</div>

<br/>

---

## What is LG QuickRig?

[**Liquid Galaxy**](https://www.liquidgalaxy.eu/) is an open-source panoramic display platform — 3 to 9 Linux machines running Google Earth in sync across a curved wall of screens. Magnificent to look at. Tedious to manage: every reboot, sync, or slave restart means cracking open a terminal and SSHing in by hand.

**LG QuickRig** removes that entirely.

- **One tap from your home screen** — a customizable 4x1 Command Bar widget: pick any 4 of 10 rig actions, no app open required
- **Live Status widget** — a 2x2 widget with a colour-coded dot (auto-refreshed every 5 minutes) plus 3 customizable action buttons
- **Quick Settings tile** — toggle connectivity straight from the system shade, with a live SSH ping confirming reachability
- **Camera control on the rig** — Fly To, Orbit, image overlays, colour-coded map markers, and a one-tap KML Test that proves the whole pipeline
- **Floating widget dialogs** — widget buttons open a translucent dialog over the launcher; the full app never has to come forward
- **Linux system tray** — full menu of rig actions, live status icon (green/red), and the camera dialogs, no window needed
- **Gemini Copilot** — a floating chat assistant: "fly to Rome, pin it and orbit" in plain language, dispatched onto the same services the buttons use. Opt-in, runs on your own free-tier API key, with live token/cost tracking so it never surprises you. **Coming:** connection diagnosis and location content as balloons on the rig

> The goal is a zero-friction rig operator's tool. If it takes more than one tap, it's too many.

<br/>

---

## App Preview

<div align="center">

*Material 3 · Dashboard + Overlay dialog (images, pins & markers)*

</div>

```
╔═══════════════════════════════════════════╗   ╔═══════════════════════════════════════════╗
║  LG QuickRig          Connected           ║   ║  Overlay                                  ║
╠═══════════════════════════════════════════╣   ╠═══════════════════════════════════════════╣
║                                           ║   ║                                           ║
║  ┌─────────────────────────────────────┐  ║   ║  (Image) (Red Pin) (Yellow Pin)           ║
║  │ Connection                          │  ║   ║  (Green Pin) (Blue Pin) (Flag) (Target)   ║
║  │ lg@192.168.2.2  ·  3 nodes          │  ║   ║                                           ║
║  │ ┌─────────────────────────────────┐ │  ║   ║  ┌─────────────────────────────────────┐  ║
║  │ │           Disconnect            │ │  ║   ║  │             Pick image              │  ║
║  └─────────────────────────────────────┘  ║   ║  └─────────────────────────────────────┘  ║
║                                           ║   ║                                           ║
║  Quick Actions                            ║   ║  Latitude     blank = current view        ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║  Longitude    blank = current view        ║
║  │     Reboot    │  │  Restart Services │ ║   ║  Size (km)    1                           ║
║  └───────────────┘  └───────────────────┘ ║   ║                                           ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ║                   ⌖ Use current view      ║
║  │    Shutdown   │  │       Sync        │ ║   ║                                           ║
║  └───────────────┘  └───────────────────┘ ║   ║                   Cancel      [ Send ]    ║
║  ┌───────────────┐  ┌───────────────────┐ ║   ╚═══════════════════════════════════════════╝
║  │   Blank Scrn  │  │     Clean KML     │ ║
║  └───────────────┘  └───────────────────┘ ║
║  ┌───────────────┐  ┌───────────────────┐ ║
║  │    Overlay    │  │     KML Test      │ ║
║  └───────────────┘  └───────────────────┘ ║
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
║  (green) Connected   ║
║          192.168.2.2 ║
║                      ║
║  ┌─────┬─────┬─────┐ ║
║  │FlyTo│Orbit│Ovrly│ ║
║  └─────┴─────┴─────┘ ║
║                      ║
║  Live Status  (2x2)  ║
╚══════════════════════╝
```

Both widgets are customizable in-app — the Command Bar's 4 slots and the Live
Status widget's 3 action buttons each accept any of the 10 catalog actions.

<br/>

---

## Roadmap

<div align="center">

`Progress ████████████████████░░░░░░░░░░░░  5 of 8 weeks  (week 6 in progress)`

</div>

<br/>

| | Week | Focus | Deliverables |
|:---:|:---:|:---|:---|
| ✅ | **1** | **SSH Foundation** | `LGSSHClient` · `LGCommandService` · secure credential storage · Dashboard |
| ✅ | **2** | **Android Widgets + Platform Channels** | `LGCommandChannel.kt` · `LGCredentialStore.kt` · `LGSshExecutor.kt` (JSch) · Command Bar widget (4x1) · Quick Settings tile |
| ✅ | **3** | **Live Status Widget + Rig Camera Control** | `LGStatusWidgetProvider.kt` · 2x2 status widget · 5-min auto-refresh · Fly To / Orbit / Overlay dialogs · floating `CameraDialogActivity` |
| ✅ | **4** | **Linux Desktop + KML Features** | `linux/` runner · system tray · image overlays · map markers · KML Test · widget customization for both widgets |
| ✅ | **5** | **Gemini Copilot — Core** | Floating FAB + chat sheet · context snapshot · function-calling dispatcher (fly to / orbit / drop pin / clean KML) · opt-in toggle + live token/cost display · self-serve API key |
| - | **6** | **Gemini Copilot — Doctor + Content** | Connection diagnosis from real errors · location content as balloons on the rig |
| 🔜 | **7** | **Testing + Polish** | Unit · integration · widget tests · Debian/Ubuntu packaging |
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
│   │   ├── CameraDialogActivity.kt       ← translucent task: widget dialogs float over the launcher
│   │   └── lg/
│   │       ├── LGCommandChannel.kt       ← MethodChannel bridge: Dart <-> Kotlin
│   │       ├── LGCredentialStore.kt      ← reads EncryptedSharedPreferences (same store as Dart)
│   │       ├── LGSshExecutor.kt          ← JSch SSH client for widget/tile use
│   │       ├── LGHomeWidgetProvider.kt   ← Command Bar widget (4x1) + shared action catalog
│   │       ├── LGQuickSettingsTile.kt    ← Quick Settings tile
│   │       └── LGStatusWidgetProvider.kt ← Live Status widget (2x2, customizable buttons)
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
│   ├── app.dart                          ← routes widget intents to the right dialog
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
│   │   ├── copilot_service.dart          ← Gemini chat + function-calling dispatcher
│   │   ├── lg_command_service.dart       ← SSH commands + camera-target readback
│   │   ├── lg_kml_controller.dart        ← KML slots, overlays, pins/markers, clean
│   │   └── lg_orbit_controller.dart      ← flyTo, orbit, currentTarget fallback
│   ├── features/
│   │   ├── copilot/
│   │   │   └── copilot_sheet.dart        ← chat UI: disabled/no-key/chat states, live cost display
│   │   ├── dashboard/
│   │   │   ├── dashboard_controller.dart
│   │   │   └── dashboard_screen.dart     ← quick actions + widget customization dialog
│   │   ├── lg_commands/
│   │   │   ├── camera_action_dialog.dart ← Fly To / Orbit
│   │   │   ├── current_view.dart         ← shared "use current view" helper
│   │   │   └── image_overlay_dialog.dart ← image overlays + pins & markers
│   │   └── settings/
│   │       └── settings_screen.dart
│   ├── shared/widgets/
│   │   └── connection_status_badge.dart
│   └── tray/
│       └── lg_tray.dart                  ← Linux system tray (tray_manager)
│
├── linux/                                ← Flutter Linux runner
│
└── test/
    ├── copilot_service_test.dart
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
| ![Tray](https://img.shields.io/badge/-tray__manager-FCC624?logo=linux&logoColor=black) | **tray\_manager ^0.2** | Linux system tray — rig actions without opening the window |
| ![Gemini](https://img.shields.io/badge/-Gemini_API-4285F4?logo=google&logoColor=white) | **Gemini API** | Copilot: natural-language rig control via function calling. Opt-in, user-supplied key, live cost tracking. Connection doctor + content balloons next |

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

**To customize widget buttons:** in the app, tap the widgets icon in the app bar → *Customize widget buttons* — both the Command Bar's 4 slots and the Live Status widget's 3 buttons.

**To enable Copilot:** in Settings, flip *Enable Copilot* on and paste a free Gemini API key from [aistudio.google.com](https://aistudio.google.com) — no credit card required. It's off by default since it spends your own API credits; the chat header shows live token/cost usage for every message.

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

This project is licensed under the MIT License. See the LICENSE file for details.

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
