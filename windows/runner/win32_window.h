#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  void Show();

  RECT GetClientArea();

  HWND GetHandle();

  void SetQuitOnClose(bool quit_on_close);

  bool OnCreate();

  void OnDestroy();

 protected:
  virtual LRESULT MessageHandler(HWND window, UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  void SetChildContent(HWND content);

 private:
  friend class FlutterWindow;

  static LRESULT CALLBACK WndProc(HWND const window, UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  HWND window_handle_ = nullptr;

  bool quit_on_close_ = false;

  bool destroyed_ = false;
};

#endif  // RUNNER_WIN32_WINDOW_H_
