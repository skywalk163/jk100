#include <windows.h>
#include <stdbool.h>
#include <moonbit.h>

static bool g_running = true;

extern void jk100_ui_frame();

LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  if (msg == WM_DESTROY) {
    g_running = false;
    PostQuitMessage(0);
    return 0;
  }
  return DefWindowProcW(hWnd, msg, wParam, lParam);
}

int32_t jk100_ui_init() {
  WNDCLASSEXW wc = {0};
  wc.cbSize = sizeof(wc);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandle(NULL);
  wc.lpszClassName = L"JK100Class";
  RegisterClassExW(&wc);
  HWND hwnd = CreateWindowExW(0, L"JK100Class", L"jk100 极快100",
    WS_OVERLAPPEDWINDOW, 100, 100, 800, 600,
    NULL, NULL, wc.hInstance, NULL);
  ShowWindow(hwnd, SW_SHOWDEFAULT);
  return 0;
}

int32_t jk100_ui_new_frame() {
  MSG msg;
  while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
    if (msg.message == WM_QUIT) {
      g_running = false;
      return 1;
    }
  }
  if (!g_running) return 1;
  return 0;
}

void jk100_ui_render() {
}

void jk100_ui_shutdown() {
}

void jk100_ui_begin(const char* name) { }
void jk100_ui_end() { }
void jk100_ui_text(const char* text) { }
int32_t jk100_ui_button(const char* label) { return 0; }
void jk100_ui_same_line() { }
void jk100_ui_separator() { }
void jk100_ui_progress_bar(float fraction) { }
int32_t jk100_ui_begin_listbox(const char* label, int32_t height) { return 0; }
void jk100_ui_end_listbox() { }
int32_t jk100_ui_selectable(const char* label, int32_t selected) { return 0; }