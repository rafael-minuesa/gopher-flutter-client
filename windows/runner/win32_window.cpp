#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

}  // namespace

Win32Window::Win32Window() {}

Win32Window::~Win32Window() {
  Destroy();
}

void Win32Window::InitializeChild(HWND parent_window,
                                  LPRECT rect) {}

bool Win32Window::Create(const std::wstring& title, const Point& origin,
                        const Size& size) {
  Destroy();

  const wchar_t* window_class =
      GetWindowClass(GetModuleHandle(nullptr));

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

void Win32Window::Destroy() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_autorelease_pool) {
    g_autorelease_pool->Release();
    g_autorelease_pool = nullptr;
  }

  destroyed_ = true;
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window, UINT const message,
                                     WPARAM const wparam,
                                     LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                    reinterpret_cast<LONG_PTR>(cs->lpCreateParams));

    auto that = static_cast<Win32Window*>(cs->lpCreateParams);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd, UINT const message, WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;
  }
  return DefWindowProc(window_handle_, message, wparam, lparam);
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::SetChildContent(HWND content) {
  if (content != nullptr) {
    ::SetParent(content, window_handle_);
    RECT frame = GetClientArea();

    MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
              frame.bottom - frame.top, true);

    SetFocus(content);
  }
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() { return window_handle_; }

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

const wchar_t* GetWindowClass(HINSTANCE hInstance) {
  static const wchar_t* window_class = nullptr;
  if (window_class == nullptr) {
    WNDCLASS window_class_object = {};
    window_class_object.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class_object.lpszClassName = kWindowClassName;
    window_class_object.style = CS_HREDRAW | CS_VREDRAW;
    window_class_object.cbClsExtra = 0;
    window_class_object.cbWndExtra = 0;
    window_class_object.hInstance = hInstance;
    window_class_object.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class_object.hbrBackground = 0;
    window_class_object.lpszMenuName = nullptr;
    window_class_object.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class_object);
    window_class = kWindowClassName;
  }
  return window_class;
}

int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

Win32Window* GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}
