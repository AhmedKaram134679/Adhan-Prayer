import 'dart:ffi';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:ffi/ffi.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

typedef _OpenMutexNative = IntPtr Function(
  Uint32 dwDesiredAccess,
  Int32 bInheritHandle,
  Pointer<Utf16> lpName,
);
typedef _OpenMutexDart = int Function(
  int dwDesiredAccess,
  int bInheritHandle,
  Pointer<Utf16> lpName,
);

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

/// Utility for checking Windows Single Instance states across processes.
class WindowsSingleInstance {
  WindowsSingleInstance._();

  static const String guiMutexName = r'Local\AdhanAndPrayer_SingleInstance_Mutex_v1';
  static const int _synchronizeAccess = 0x00100000;

  /// Checks whether a main GUI instance of the application is currently active.
  ///
  /// On Windows, the main GUI runner creates and holds [guiMutexName].
  /// When a background Task Scheduler task runs (`--play-adhan`), this method
  /// queries whether the mutex exists. If it exists, the GUI application is alive
  /// (either in foreground, minimized, or running in the system tray) and will
  /// authoritatively handle prayer alerts and in-app audio playback.
  static bool isGuiInstanceRunning() {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final openMutex = kernel32.lookupFunction<_OpenMutexNative, _OpenMutexDart>('OpenMutexW');
      final closeHandle = kernel32.lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');

      final namePtr = guiMutexName.toNativeUtf16();
      final handle = openMutex(_synchronizeAccess, 0, namePtr);
      calloc.free(namePtr);

      if (handle != 0) {
        closeHandle(handle);
        return true;
      }
      return false;
    } catch (e, stack) {
      AppLogger.warning('Failed to query single instance mutex: $e\n$stack', 'WINDOWS_SINGLE_INSTANCE');
      return false;
    }
  }
}
