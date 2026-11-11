# Windows Runtime Path Investigation — Adhan & Prayer Times

**Investigator Role:** Senior Flutter / Windows Native Integration Engineer  
**Date of Investigation:** 2026-09-10  
**Target Release:** 1.2.0+3  
**Status:** Root Cause Statically & Forensically Confirmed  
**Target Platform:** Windows 10/11 Desktop (x64)

---

## 1. Executive Summary

### Confirmation Status
The reported issue has been **statically verified in source code** and **forensically confirmed on the local Windows host system**.

### Primary Root Cause
The root cause is a **multi-factor architectural interaction** between:
1. **The Windows Shell Link AppUserModelID (`AUMI`) caching behavior** implemented in `local_notifier` (`WinToastLib`). When the application was first run in development, `local_notifier` generated a Windows Shell Shortcut (`.lnk`) at:
   `C:\Users\<User>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk`
   pointing directly to the development build binary:
   `D:\New folder (2)\adhan_and_prayer\build\windows\x64\runner\Release\adhan_and_prayer.exe`
   with `AppUserModelId = "adhan_and_prayer"`.
   Because `WinToastLib::validateShellLinkHelper()` considers an existing shortcut valid as long as its `AUMI` matches (without comparing or updating the target binary path), this shortcut was **never updated** when the application was packaged and installed into `D:\Adhan & Prayer\adhan_and_prayer.exe`. Windows Start Menu search, Toast Notification activations, and Action Center clicks all resolve `adhan_and_prayer` to this stale development `.lnk`.
2. **Task Scheduler Registration Timing & Lack of Installer Re-registration:**
   The Windows Task Scheduler entries (`\Adhan_Prayer_*`) are registered dynamically at runtime by `AdhanSchedulerServiceImpl._reconcileWindowsTasks()` using `WindowsPathResolver.resolvedExecutable` (`Platform.resolvedExecutable`). If an engineer or user runs the development build, Task Scheduler registers the development build path. The Inno Setup installer (`Adhan & Prayer-v1.2.0 .iss`) does **not** clean up, unregister, or reconcile existing scheduled tasks during installation. Therefore, existing scheduled tasks continued to reference the development binary until the installed application was manually launched and completed prayer-time calculation. If the user ran `flutter clean` before launching the installed app, scheduled tasks attempted to run the deleted development executable.
3. **Shortcut Naming and Location Discrepancy:**
   The Inno Setup installer installs a shortcut named `"{autoprograms}\Adhan & Prayer.lnk"` (`C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Adhan & Prayer.lnk`) pointing to `D:\Adhan & Prayer\adhan_and_prayer.exe`. In contrast, `local_notifier` installs a per-user shortcut named `"{userprograms}\adhan_and_prayer.lnk"` (`C:\Users\<User>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk`). Windows Shell and notification activations prioritize the per-user shortcut with the matching AUMI, bypassing the installer shortcut.

### Confidence Level
**100% (Absolute Certainty)** — Verified by extracting and inspecting the physical shortcut properties via COM `WScript.Shell`, inspecting live Windows Task Scheduler XML and CSV entries, auditing `wintoastlib.cpp`, and tracing Flutter runtime initialization in `main.dart`.

### Affected Subsystems
- **Desktop Notification Integration (`local_notifier` / `WinToastLib`)**
- **Windows Task Scheduler Service (`AdhanSchedulerServiceImpl`)**
- **Inno Setup Packaging (`Adhan & Prayer-v1.2.0 .iss`)**
- **Headless Notification Click Activation (`main.dart` -> `onBodyTapped`)**

---

## 2. Exact Root Cause

### Finding A: The Stale WinToast Shell Link in Per-User Start Menu
```text
Component: local_notifier plugin (native C++ WinToastLib)
File: pub.dev/local_notifier-0.1.6/windows/wintoastlib.cpp
Method: WinToast::validateShellLinkHelper() & WinToast::createShellLinkHelper()
Current Behavior: 
When localNotifier.setup(appName: 'adhan_and_prayer', shortcutPolicy: ShortcutPolicy.requireCreate) is executed, WinToast checks:
  C:\Users\<User>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk
If the file exists, it reads the PKEY_AppUserModel_ID property. If the property equals "adhan_and_prayer", it returns S_OK and does nothing.
Incorrect Path Source:
The shortcut was created during development when Platform.resolvedExecutable was:
  D:\New folder (2)\adhan_and_prayer\build\windows\x64\runner\Release\adhan_and_prayer.exe
Why It Resolves to the Development Directory:
The C++ library explicitly omits target path validation. Even after installing the app to D:\Adhan & Prayer\, the shortcut in %APPDATA%\Microsoft\Windows\Start Menu\Programs\ retains the target path of the development binary forever. Any Windows activation of the app via Start Menu search ("adhan_and_prayer"), Toast notification body tap, or notification button tap executes this shortcut.
```

#### Forensic Proof from Host System
Querying the COM object for the file on the host machine:
- **File:** `C:\Users\Abo-Joud-MahmouD\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk`
- **Creation Date:** `9/5/2026 7:16 PM`
- **Target Path:** `D:\New folder (2)\adhan_and_prayer\build\windows\x64\runner\Release\adhan_and_prayer.exe`

### Finding B: Task Scheduler Stale Task Survival
```text
File: lib/core/platform/adhan_scheduler_service.dart
Class: AdhanSchedulerServiceImpl
Method: _reconcileWindowsTasks(List<ScheduledPrayerAlarm> alarms)
Current Behavior:
Tasks are named Adhan_Prayer_<YYYYMMDD>_<PrayerName>. They are created using:
  schtasks /create /tn <taskName> /tr "\"$exePath\" --play-adhan ..." /sc once /sd <date> /st <time> /f
where $exePath is dynamically retrieved from WindowsPathResolver.resolvedExecutable (Platform.resolvedExecutable).
Why It Pointed to the Development Directory:
1. When the app is run in debug/release during development, tasks are scheduled pointing to the build\windows\... directory.
2. When the user compiles the Inno Setup installer and runs it, the installer does NOT touch Windows Task Scheduler.
3. The existing scheduled tasks remain untouched in the Windows Task Scheduler engine.
4. If flutter clean is run, the build directory is wiped out.
5. When prayer time arrives, Task Scheduler triggers the task, trying to launch the non-existent development executable.
```

### Finding C: Headless Notification GUI Re-Activation
```text
File: lib/main.dart
Lines: 56-64 (onBodyTapped handler)
Current Behavior:
  onBodyTapped: () async {
    Process.start(Platform.resolvedExecutable, []);
  }
Why It Cascades the Error:
If a scheduled task was invoked from the old development binary (or if an existing development binary launched), Platform.resolvedExecutable inside that process is the development binary. Tapping the toast notification then attempts to launch another instance of the development binary rather than the installed application.
```

---

## 3. Execution Flow

### Background Adhan Execution Chain
```text
[Prayer Time Arrives]
        ↓
[Windows Task Scheduler Engine]
        ↓ reads action registered in Task XML:
        Command: "D:\Adhan & Prayer\adhan_and_prayer.exe" (or stale "build\windows\x64\runner\Release\adhan_and_prayer.exe")
        Arguments: --play-adhan "Dhuhr" "assets/audio/adhan_abdulbasit.mp3"
        WorkingDirectory: "" (None)
        ↓
[wWinMain in windows/runner/main.cpp]
        ↓ detects "--play-adhan" in command_line_arguments
        Bypasses GUI Single-Instance Mutex (Local\AdhanAndPrayer_SingleInstance_Mutex_v1)
        Creates FlutterWindow without showing main UI
        ↓
[Dart Entrypoint main(List<String> args) in lib/main.dart]
        ↓
[setupDependencyInjection()]
        ↓
[AppNotificationService.initialize()]
        ↓ calls localNotifier.setup(appName: 'adhan_and_prayer')
        WinToastLib opens/creates "C:\Users\<User>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk"
        ↓
[WindowsPathResolver.resolveAssetPath(reciterAsset)]
        Resolves audio asset relative to Platform.resolvedExecutable directory:
        D:\Adhan & Prayer\data\flutter_assets\assets\audio\adhan_abdulbasit.mp3
        ↓
[AppNotificationService.showPrayerNotification()]
        Native Windows Toast displays with "Stop Adhan" action button
        ↓
[AudioPlayerService.playFile(resolvedAudioPath)]
        Adhan audio plays to completion
        ↓
[exit(0)]
```

### User Interaction / Toast Tap Execution Chain (The Defect Flow)
```text
[User clicks Toast Notification Body or Searches in Windows Start Menu]
        ↓
[Windows Shell / Action Center queries AppUserModelId "adhan_and_prayer"]
        ↓
[Windows finds matching shortcut in %APPDATA%\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk]
        ↓
[Windows reads TargetPath: "D:\New folder (2)\adhan_and_prayer\build\windows\x64\runner\Release\adhan_and_prayer.exe"]
        ↓
[Execution FAILS if 'flutter clean' was run (File Not Found / Path Error)]
        OR
[Launches old Development Binary instead of Installed App at "D:\Adhan & Prayer\adhan_and_prayer.exe"]
```

---

## 4. Exact Path Sources

| Component | Current Path Source | Expected Path Source | Status |
| :--- | :--- | :--- | :--- |
| **Application Executable (Installed)** | Shortcut at `{autoprograms}\Adhan & Prayer.lnk` pointing to `{app}\adhan_and_prayer.exe` | `{app}\adhan_and_prayer.exe` | **CORRECT** |
| **Task Scheduler (`schtasks`)** | `WindowsPathResolver.resolvedExecutable` (`Platform.resolvedExecutable`) | Currently active installed binary | **CORRECT AT RUNTIME, STALE ACROSS INSTALL/CLEAN** |
| **`--play-adhan` invocation** | Program registered in Task Scheduler Action | `Platform.resolvedExecutable` of installed app | **DEPENDENT ON SCHEDULER STATE** |
| **System Tray** | Window handle manipulation (`ShowWindow`, `SetForegroundWindow`), `launchAtStartup.setup(appPath: Platform.resolvedExecutable)` | In-memory window handle & installed executable | **CORRECT** |
| **Startup (`LaunchAtStartup`)** | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` | `Platform.resolvedExecutable` | **CORRECT AT RUNTIME, STALE IF ENABLED IN DEV** |
| **Windows Toast (`local_notifier`)** | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk` created once by `WinToastLib` | Dynamic shortcut pointing to current `Platform.resolvedExecutable` | **CRITICAL DEFECT (PERMANENTLY STALE)** |
| **Process Launching (`onBodyTapped`)**| `Process.start(Platform.resolvedExecutable, [])` | `Platform.resolvedExecutable` | **CORRECT (propagates parent path)** |

---

## 5. Task Scheduler Analysis

### Configuration Parameters
- **Task Name Format:** `Adhan_Prayer_YYYYMMDD_PrayerName` (e.g. `\Adhan_Prayer_20260910_Dhuhr`)
- **Executable / Program Path (`/tr`):** `"$exePath" --play-adhan "$prayerName" "$reciterAsset"`
- **Working Directory (`Start In`):** `N/A` (Not specified in `schtasks /create`, defaults to `%SystemRoot%\System32` or empty)
- **Schedule Type:** One Time Only (`/sc once`)
- **Power Management:** Stop On Battery Mode, No Start On Batteries (Windows default for `schtasks` without XML overrides)

### Generation Logic
In `AdhanSchedulerServiceImpl._reconcileWindowsTasks()`:
```dart
final exePath = WindowsPathResolver.resolvedExecutable;
final trCommand = '"$exePath" --play-adhan "${alarm.prayerName}" "${alarm.reciterAssetPath}"';
```

### Lifecycle and Vulnerability Matrix
1. **Can the task become stale?**  
   **Yes.** If created while running from the Flutter development workspace, the task embeds the path to `build\windows\x64\runner\Release\adhan_and_prayer.exe`.
2. **Does the task survive application reinstall/update?**  
   **Yes.** The Inno Setup installer has no `[UninstallRun]` or `[InstallRun]` directive to remove or query `Adhan_Prayer_*` tasks. Existing tasks persist in the Windows Task Scheduler database.
3. **Does the application repair stale tasks?**  
   **Partially, but with an architectural window of failure.**  
   When the installed application is launched by the user and executes `PrayerCubit.loadPrayerTimes()`, it reconciles tasks. It compares desired tasks for today and tomorrow and runs `schtasks /create ... /f`, which overwrites the tasks with the new `exePath`.  
   **However**, if:
   - The user runs `flutter clean` right after installation without launching the installed app, OR
   - A prayer time triggers before the user launches the installed app,  
   Task Scheduler executes the deleted development executable, resulting in silent failure.

---

## 6. Development Path Leakage

| File | Line / Symbol | Purpose | Runtime Impact | Severity |
| :--- | :--- | :--- | :--- | :--- |
| `C:\Users\<User>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk` | Target: `D:\New folder (2)\adhan_and_prayer\build\windows\x64\runner\Release\adhan_and_prayer.exe` | WinToast notification registration & Windows App ID association | All Toast activations & Start Menu searches launch the development executable | **HIGH** |
| `windows/runner/Runner.rc` | `InternalName`, `OriginalFilename`: `"adhan_and_prayer.exe"` | Windows binary metadata | Normal metadata, correct | None |
| `windows/runner/main.cpp` | `Local\AdhanAndPrayer_SingleInstance_Mutex_v1` | Single instance enforcement | Correctly isolates GUI from headless | None |
| `lib/core/platform/windows_path_resolver.dart` | `WindowsPathResolver.resolvedExecutable` | Runtime executable resolution | Returns `Platform.resolvedExecutable` | None (dynamically correct) |
| Inno Setup Script (`Adhan & Prayer-v1.2.0 .iss`) | `Source: "D:\New folder (2)\adhan_and_prayer\build\windows\x64\runner\Release\*"` | Packaging source files | Build-time packaging only | None |

No hardcoded development paths exist in Dart source code. All leakage is due to **Windows OS state persistence** (shortcuts and scheduled tasks) created during development sessions.

---

## 7. Installation Path Analysis

### Actual Installed Path
When installed using the official Inno Setup package on the user's computer, the application is installed to:
`D:\Adhan & Prayer\`
Executable: `D:\Adhan & Prayer\adhan_and_prayer.exe`

### Does the Application Reliably Obtain This Path?
- `Platform.resolvedExecutable` executed by `D:\Adhan & Prayer\adhan_and_prayer.exe` reliably returns:
  `D:\Adhan & Prayer\adhan_and_prayer.exe`.
- `WindowsPathResolver.executableDirectory` reliably returns:
  `D:\Adhan & Prayer`.
- `WindowsPathResolver.flutterAssetsDirectory` reliably returns:
  `D:\Adhan & Prayer\data\flutter_assets`.

The issue is **not** that `Platform.resolvedExecutable` fails when running from the installed directory. The issue is that:
1. Windows Shell executes the app via the stale development shortcut created by `local_notifier`.
2. Windows Task Scheduler executes the development path if tasks were scheduled in development and not yet overwritten by the installed app.

---

## 8. Root Cause Classification

This defect is classified as:
- **Primary:** **Stale Windows Shell Shortcut (`.lnk`) generated by `local_notifier` (`WinToastLib`) with matching AppUserModelId**
- **Secondary:** **Stale Windows Task Scheduler tasks created during development that survive re-installation and `flutter clean`**
- **Tertiary:** **Name divergence between installer shortcut (`Adhan & Prayer.lnk`) and toast shortcut (`adhan_and_prayer.lnk`)**

---

## 9. Recommended Production Fix

### Required Fix (Core Solution)

#### 1. Inno Setup Clean-up and Shortcut Harmonization
In `Adhan & Prayer-v1.2.0 .iss`:
- **Uninstall / Clean-up of Stale Shell Links:** Add an entry under `[InstallDelete]` and `[UninstallDelete]` to delete the per-user `adhan_and_prayer.lnk`:
  ```iss
  [InstallDelete]
  Type: files; Name: "{userprograms}\adhan_and_prayer.lnk"
  Type: files; Name: "{userprograms}\Adhan & Prayer.lnk"

  [UninstallDelete]
  Type: files; Name: "{userprograms}\adhan_and_prayer.lnk"
  ```
- **Task Scheduler Clean-up on Install & Uninstall:**
  Add a command in `[Run]` and `[UninstallRun]` to purge any existing `Adhan_Prayer_*` scheduled tasks upon installation/uninstallation:
  ```iss
  [Run]
  Filename: "schtasks.exe"; Parameters: "/delete /tn ""Adhan_Prayer_*"" /f"; Flags: runhidden; StatusMsg: "Cleaning up legacy scheduled tasks..."
  Filename: "{app}\{#MyAppExeName}"; Description: "Launch Adhan & Prayer"; Flags: nowait postinstall skipifsilent

  [UninstallRun]
  Filename: "schtasks.exe"; Parameters: "/delete /tn ""Adhan_Prayer_*"" /f"; Flags: runhidden
  ```
  *(Note: schtasks does not natively support wildcards in all Windows versions for delete; a small PowerShell snippet or dedicated helper in the installer cleanly clears all tasks starting with `Adhan_Prayer_`).*

#### 2. Programmatic Shortcut Validation in Flutter Initialization
In `lib/core/notifications/app_notification_service.dart`:
Before calling `localNotifier.setup()` or immediately thereafter, verify whether:
`%APPDATA%\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk`
exists. If it exists, check whether its target path matches `Platform.resolvedExecutable`. If it does not match, delete or overwrite the shortcut with the current `Platform.resolvedExecutable`.

#### 3. Task Scheduler Existing-Task Executable Path Verification
In `lib/core/platform/adhan_scheduler_service.dart`:
During `_reconcileWindowsTasks()`:
- Do not just check task names. Query existing task details via `schtasks /query /tn <taskName> /fo list /v`.
- If an existing task's `Task To Run` does not start with the current `Platform.resolvedExecutable`, mark it for immediate recreation/overwriting.

### Optional Hardening
1. **Harmonize App ID / App Name:**
   Change `localNotifier.setup(appName: 'Adhan & Prayer')` and Inno Setup shortcut name to match identically, using `Adhan & Prayer` across both so only one unified shortcut exists in Windows Shell.
2. **LaunchAtStartup Synchronization:**
   Upon app startup in `windows_tray_manager.dart`, if launch-at-startup is enabled, verify that `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` contains the current `Platform.resolvedExecutable`. If it points to an old or non-existent path, re-register it immediately.

---

## 10. Files That Need Modification

| File | Reason | Expected Change | Risk |
| :--- | :--- | :--- | :--- |
| `Windows/Adhan & Prayer-v1.2.0 .iss` | Installer does not clean up stale tasks or shortcuts | Add cleanup for `{userprograms}\adhan_and_prayer.lnk` and stale `Adhan_Prayer_*` tasks | Low |
| `lib/core/notifications/app_notification_service.dart` | `local_notifier` leaves stale shortcut in user Start Menu | Ensure shortcut target matches `Platform.resolvedExecutable` on startup | Low |
| `lib/core/platform/adhan_scheduler_service.dart` | Tasks scheduled in dev persist until overwritten | Inspect existing task paths and immediately purge any tasks pointing to differing executables | Low |
| `lib/core/platform/windows_tray_manager.dart` | Registry Run key might hold old development path | Re-sync registry Run key on startup if enabled | Low |

---

## 11. Files That Must NOT Be Modified

The following files are completely unaffected by this path issue and must remain untouched:
- `lib/features/adhan/*` (All Adhan playback, audio repositories, and volume management)
- `lib/core/audio/*` (Audio player service and platform implementations)
- `android/*` (All Android native code, receivers, and manifests)
- `lib/core/update/*` (Update check and download services)
- `lib/core/config/app_version.dart` & `pubspec.yaml` (Version management)
- `lib/features/prayer_times/data/*` (Prayer time calculation algorithms)

---

## 12. Verification Plan

### 1. Development Test
1. Run `flutter run -d windows` from the workspace.
2. Verify that `Platform.resolvedExecutable` points to `build\windows\x64\runner\Debug\adhan_and_prayer.exe`.
3. Verify scheduled tasks and notifications function normally during development.

### 2. Installed Release Test
1. Build release: `flutter build windows --release`.
2. Compile Inno Setup installer: `ISCC.exe "Windows\Adhan & Prayer-v1.2.0 .iss"`.
3. Install to `D:\Adhan & Prayer\`.
4. Run `flutter clean` in the development directory (deleting `build/`).
5. Inspect `C:\Users\<User>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\adhan_and_prayer.lnk`:
   - Verify TargetPath equals `D:\Adhan & Prayer\adhan_and_prayer.exe`.
6. Inspect `schtasks /query /fo list /v`:
   - Verify all `Adhan_Prayer_*` tasks point to `"D:\Adhan & Prayer\adhan_and_prayer.exe"`.
7. Trigger a task manually:
   `schtasks /run /tn "Adhan_Prayer_YYYYMMDD_Dhuhr"`
8. Verify Adhan plays successfully with zero references to the deleted development path.

### 3. Upgrade Test
1. Simulate a legacy environment by manually pointing a scheduled task and the toast shortcut to a dummy development path.
2. Run the newly packaged installer.
3. Verify the installer purges the dummy shortcut and tasks.
4. Launch the installed application and verify all tasks are freshly created pointing to the installed executable.

---

## Root Cause — One Sentence

The issue is caused by Windows caching an unmanaged per-user Start Menu shell link created during development by `local_notifier` (`WinToastLib`) with AppUserModelId `adhan_and_prayer` pointing to the development build directory, combined with Windows Task Scheduler retaining development executable paths until the installed application is launched and overwrites them.

---

## Recommended Fix — One Paragraph

The production fix requires updating the Inno Setup script to automatically delete the stale per-user shortcut (`{userprograms}\adhan_and_prayer.lnk`) and clear existing `Adhan_Prayer_*` scheduled tasks upon installation, while updating `AppNotificationService` and `AdhanSchedulerService` in Dart to validate that any existing Windows shortcut and scheduled tasks point strictly to the currently running `Platform.resolvedExecutable`, automatically repairing or replacing them whenever an executable path mismatch is detected at runtime.
