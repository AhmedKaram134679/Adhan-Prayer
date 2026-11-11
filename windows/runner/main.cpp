#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Check if launched in headless Adhan mode.
  // Headless mode is invoked by Windows Task Scheduler to play scheduled Adhans
  // independently and MUST NOT participate in or be blocked by GUI Single-Instance.
  bool is_headless_adhan = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--play-adhan") {
      is_headless_adhan = true;
      break;
    }
  }

  HANDLE single_instance_mutex = nullptr;
  if (!is_headless_adhan) {
    // Deterministic unique named mutex for the normal GUI application.
    single_instance_mutex = ::CreateMutexW(
        nullptr, TRUE, L"Local\\AdhanAndPrayer_SingleInstance_Mutex_v1");
    if (single_instance_mutex != nullptr &&
        ::GetLastError() == ERROR_ALREADY_EXISTS) {
      // Find the window of the existing instance.
      HWND existing_hwnd =
          ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Adhan & Prayer Times");
      if (!existing_hwnd) {
        existing_hwnd =
            ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"adhan_and_prayer");
      }
      if (!existing_hwnd) {
        ::EnumWindows(
            [](HWND hwnd, LPARAM lparam) -> BOOL {
              wchar_t class_name[256];
              if (::GetClassNameW(hwnd, class_name, 256) > 0) {
                if (wcscmp(class_name, L"FLUTTER_RUNNER_WIN32_WINDOW") == 0) {
                  *reinterpret_cast<HWND*>(lparam) = hwnd;
                  return FALSE;  // Found, stop enumeration
                }
              }
              return TRUE;
            },
            reinterpret_cast<LPARAM>(&existing_hwnd));
      }

      if (existing_hwnd) {
        if (WM_ACTIVATE_APP_INSTANCE != 0) {
          ::PostMessageW(existing_hwnd, WM_ACTIVATE_APP_INSTANCE, 0, 0);
        }
        if (::IsIconic(existing_hwnd)) {
          ::ShowWindow(existing_hwnd, SW_RESTORE);
        } else {
          ::ShowWindow(existing_hwnd, SW_SHOW);
        }
        ::SetWindowPos(existing_hwnd, HWND_TOP, 0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
        ::SetForegroundWindow(existing_hwnd);
      }

      ::CloseHandle(single_instance_mutex);
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"adhan_and_prayer", origin, size)) {
    if (single_instance_mutex != nullptr) {
      ::CloseHandle(single_instance_mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (single_instance_mutex != nullptr) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
