import 'dart:io';
import 'package:adhan_and_prayer/core/platform/adhan_activation_payload.dart';
import 'package:adhan_and_prayer/core/platform/windows_path_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

class WindowsTrayManager with TrayListener, WindowListener {
  static final WindowsTrayManager _instance = WindowsTrayManager._internal();
  factory WindowsTrayManager() => _instance;
  WindowsTrayManager._internal();

  static const MethodChannel _windowsChannel =
      MethodChannel('com.example.adhan_and_prayer/windows_updater');

  static const WindowOptions _defaultWindowOptions = WindowOptions(
    size: Size(1100, 750),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: 'Adhan & Prayer Times',
  );

  bool _isInitialized = false;
  bool _hasShownInitialWindow = false;
  VoidCallback? onExitRequested;
  VoidCallback? onShowRequested;
  ValueChanged<AdhanActivationPayload>? onActivationReceived;

  Future<void> initialize({
    VoidCallback? onExit,
    VoidCallback? onShow,
    ValueChanged<AdhanActivationPayload>? onActivation,
  }) async {
    if (!Platform.isWindows || _isInitialized) return;

    onExitRequested = onExit;
    onShowRequested = onShow;
    onActivationReceived = onActivation;

    try {
      await windowManager.ensureInitialized();
      trayManager.addListener(this);
      windowManager.addListener(this);

      // Register native-to-Flutter activation channel listener before runApp
      // so single-instance WM_COPYDATA events are captured immediately.
      _windowsChannel.setMethodCallHandler(_handleNativeMethodCall);

      // Prevent exit on close, minimize to tray instead
      await windowManager.setPreventClose(true);

      // Setup Tray Icon
      await _setupTray();

      // Configure launch at startup metadata
      launchAtStartup.setup(
        appName: 'adhan_and_prayer',
        appPath: Platform.resolvedExecutable,
      );

      // Reconcile launch-at-startup registry entry if already enabled
      await WindowsPathResolver.repairLaunchAtStartupIfNeeded(appName: 'adhan_and_prayer');

      _isInitialized = true;
      AppLogger.info('Windows Desktop & Tray initialized successfully', 'WINDOWS');
    } catch (e, stack) {
      AppLogger.error('Failed to initialize Windows tray', e, stack, 'WINDOWS');
    }
  }

  /// Coordinates showing the native window strictly after Flutter's first frame
  /// has been scheduled/rendered, preventing a blank white window on startup.
  Future<void> showWhenReady() async {
    if (!Platform.isWindows || _hasShownInitialWindow) return;
    _hasShownInitialWindow = true;

    try {
      await windowManager.waitUntilReadyToShow(_defaultWindowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e, stack) {
      AppLogger.error('Failed to show Windows window after first frame', e, stack, 'WINDOWS');
    }
  }

  /// Pulls any activation payload buffered natively in FlutterWindow before
  /// Dart listeners were ready.
  Future<AdhanActivationPayload?> fetchPendingNativeActivation() async {
    if (!Platform.isWindows) return null;
    try {
      final raw = await _windowsChannel.invokeMethod<String>('getPendingActivation');
      if (raw != null && raw.isNotEmpty) {
        return AdhanActivationPayload.fromJsonString(raw);
      }
    } catch (e) {
      AppLogger.warning('Failed to fetch pending native activation: $e', 'WINDOWS');
    }
    return null;
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onActivationPayload') {
      final raw = call.arguments as String?;
      if (raw != null && raw.isNotEmpty) {
        final payload = AdhanActivationPayload.fromJsonString(raw);
        if (payload != null) {
          AppLogger.info('Received native Windows activation payload: $payload', 'WINDOWS');
          onActivationReceived?.call(payload);
          await restoreWindow();
        }
      }
    }
  }

  Future<void> _setupTray() async {
    try {
      await trayManager.setIcon(
        'assets/icons/app_icon.ico', // Windows standard ICO
      );
      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Open Adhan & Prayer Times',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
      await trayManager.setToolTip('Adhan & Prayer Times');
    } catch (e, stack) {
      AppLogger.error('Error setting up tray icon', e, stack, 'WINDOWS');
    }
  }

  @override
  void onTrayIconMouseDown() {
    restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      restoreWindow();
    } else if (menuItem.key == 'exit_app') {
      exitApp();
    }
  }

  @override
  void onWindowClose() async {
    // Minimize to tray instead of quitting
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
      AppLogger.info('Window minimized to tray on close', 'WINDOWS');
    }
  }

  Future<void> restoreWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      // Invoke native Win32 activation (SetWindowPos, SetForegroundWindow, SetFocus)
      const channel = MethodChannel('com.example.adhan_and_prayer/windows_updater');
      await channel.invokeMethod('activateWindow');
    } catch (e) {
      AppLogger.warning('Error during native window activation: $e', 'WINDOWS');
    }
    onShowRequested?.call();
  }

  Future<void> exitApp() async {
    await windowManager.destroy();
    exit(0);
  }

  Future<void> setLaunchAtStartup(bool enable) async {
    if (!Platform.isWindows) return;
    try {
      if (enable) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      AppLogger.info('Launch at startup set to: $enable', 'WINDOWS');
    } catch (e, stack) {
      AppLogger.error('Failed to update launch at startup', e, stack, 'WINDOWS');
    }
  }

  Future<bool> isLaunchAtStartupEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }
}
