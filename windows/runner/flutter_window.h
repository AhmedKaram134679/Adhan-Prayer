#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>
#include <string>

#include "win32_window.h"

// Registered window message for single-instance activation.
extern const UINT WM_ACTIVATE_APP_INSTANCE;

// WM_COPYDATA identifier for structured Adhan activation JSON payloads.
constexpr ULONG_PTR kCopyDataActivationPayload = 0x4144484E;  // 'ADHN'

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Restores and brings this window to foreground.
  void ActivateWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Custom Win32 platform method channel.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      windows_channel_;

  // Buffered activation payload received via WM_COPYDATA before Flutter reads it.
  std::optional<std::string> pending_activation_payload_;

  // Sets up custom Win32 platform method channels (e.g. elevated update installer).
  void RegisterCustomMethodChannels();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
