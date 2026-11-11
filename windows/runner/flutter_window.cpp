#include "flutter_window.h"

#include <optional>
#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterCustomMethodChannels();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

const UINT WM_ACTIVATE_APP_INSTANCE =
    ::RegisterWindowMessageW(L"AdhanAndPrayer_ActivateInstance_Msg");

void FlutterWindow::ActivateWindow() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  // If minimized or hidden in tray, restore window
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  } else {
    ::ShowWindow(hwnd, SW_SHOW);
  }

  // Bring to top and foreground
  ::SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  ::SetForegroundWindow(hwnd);
  ::SetFocus(hwnd);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_ACTIVATE_APP_INSTANCE && WM_ACTIVATE_APP_INSTANCE != 0) {
    ActivateWindow();
    return TRUE;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterCustomMethodChannels() {
  if (!flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.example.adhan_and_prayer/windows_updater",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "executeInstaller") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("INVALID_ARGUMENT", "Arguments must be a Map");
            return;
          }

          auto path_it = args->find(flutter::EncodableValue("filePath"));
          if (path_it == args->end() || !std::holds_alternative<std::string>(path_it->second)) {
            result->Error("INVALID_ARGUMENT", "filePath is required and must be a string");
            return;
          }

          const std::string file_path_utf8 = std::get<std::string>(path_it->second);
          if (file_path_utf8.empty()) {
            result->Error("INVALID_ARGUMENT", "filePath cannot be empty");
            return;
          }

          // Convert UTF-8 path to wide string
          int wide_len = ::MultiByteToWideChar(CP_UTF8, 0, file_path_utf8.c_str(), -1, nullptr, 0);
          if (wide_len <= 0) {
            result->Error("PATH_CONVERSION_FAILED", "Failed to convert file path to wide string");
            return;
          }

          std::wstring file_path_wide(wide_len, 0);
          ::MultiByteToWideChar(CP_UTF8, 0, file_path_utf8.c_str(), -1, &file_path_wide[0], wide_len);
          // Remove terminating null character accounted for by MultiByteToWideChar
          if (!file_path_wide.empty() && file_path_wide.back() == L'\0') {
            file_path_wide.pop_back();
          }

          // Prepare arguments if provided
          std::wstring arguments_wide;
          auto args_it = args->find(flutter::EncodableValue("arguments"));
          if (args_it != args->end() && std::holds_alternative<std::string>(args_it->second)) {
            const std::string args_utf8 = std::get<std::string>(args_it->second);
            if (!args_utf8.empty()) {
              int args_wide_len = ::MultiByteToWideChar(CP_UTF8, 0, args_utf8.c_str(), -1, nullptr, 0);
              if (args_wide_len > 0) {
                arguments_wide.resize(args_wide_len, 0);
                ::MultiByteToWideChar(CP_UTF8, 0, args_utf8.c_str(), -1, &arguments_wide[0], args_wide_len);
                if (!arguments_wide.empty() && arguments_wide.back() == L'\0') {
                  arguments_wide.pop_back();
                }
              }
            }
          }

          // Configure native Win32 ShellExecuteExW with explicit "runas" verb for UAC elevation
          SHELLEXECUTEINFOW sei = { sizeof(SHELLEXECUTEINFOW) };
          sei.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_FLAG_NO_UI;
          sei.lpVerb = L"runas";
          sei.lpFile = file_path_wide.c_str();
          sei.lpParameters = arguments_wide.empty() ? nullptr : arguments_wide.c_str();
          sei.nShow = SW_SHOWNORMAL;

          BOOL success = ::ShellExecuteExW(&sei);

          if (success && sei.hProcess != nullptr) {
            ::CloseHandle(sei.hProcess);
            flutter::EncodableMap response;
            response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
            result->Success(flutter::EncodableValue(response));
          } else {
            DWORD error_code = ::GetLastError();
            std::string err_msg;
            if (error_code == ERROR_CANCELLED) {
              err_msg = "Elevation was cancelled by the user (UAC prompt declined).";
            } else {
              err_msg = "ShellExecuteW failed with error code: " + std::to_string(error_code);
            }
            flutter::EncodableMap response;
            response[flutter::EncodableValue("success")] = flutter::EncodableValue(false);
            response[flutter::EncodableValue("error")] = flutter::EncodableValue(err_msg);
            response[flutter::EncodableValue("cancelled")] = flutter::EncodableValue(error_code == ERROR_CANCELLED);
            result->Success(flutter::EncodableValue(response));
          }
        } else if (call.method_name() == "activateWindow") {
          this->ActivateWindow();
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  // Keep channel alive by transferring ownership to engine's lifetime
  // MethodChannel is self-managed by the messenger when handler is set
  // To ensure the pointer stays valid across window lifecycle:
  static auto s_channel = std::move(channel);
}

