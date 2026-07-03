#include "cwrap.h"
#include <stdio.h>
#include <string.h>

moonbit_string_t jk100_cstr_to_moonbit(const char* s) {
  if (s == NULL) return moonbit_make_string(0, 0);
  int32_t len = (int32_t)strlen(s);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int i = 0; i < len; i++) {
    ms[i] = (uint16_t)(unsigned char)s[i];
  }
  return ms;
}

// 将 MoonBit String (UTF-16) 转换为 C char* (UTF-8)
// buf_size 是 buf 的容量,返回实际写入的长度(不含\0)
// 如果 buf 为 NULL 或 buf_size 不够,只返回所需长度
int32_t jk100_moonbit_to_cstr(moonbit_string_t s, char* buf, int32_t buf_size) {
  if (s == NULL) {
    if (buf && buf_size > 0) buf[0] = 0;
    return 0;
  }
  int32_t str_len = Moonbit_array_length(s);
  // 先计算需要的 UTF-8 长度
  int32_t utf8_len = WideCharToMultiByte(CP_UTF8, 0, (LPCWSTR)s, str_len, NULL, 0, NULL, NULL);
  if (buf == NULL || buf_size < utf8_len + 1) {
    return utf8_len;
  }
  WideCharToMultiByte(CP_UTF8, 0, (LPCWSTR)s, str_len, buf, buf_size, NULL, NULL);
  buf[utf8_len] = 0;
  return utf8_len;
}

void jk100_free_cstr_array(char** arr, int32_t count) {
  if (arr == NULL) return;
  for (int i = 0; i < count; i++) { free(arr[i]); }
  free(arr);
}

void jk100_free_int_array(int32_t* arr) {
  if (arr) free(arr);
}

int32_t jk100_enum_processes(int32_t** pids, char*** names, int32_t* count) {
  HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snap == INVALID_HANDLE_VALUE) return -1;
  int32_t cap = 256, n = 0;
  *pids = (int32_t*)malloc(cap * sizeof(int32_t));
  *names = (char**)malloc(cap * sizeof(char*));
  PROCESSENTRY32 pe;
  pe.dwSize = sizeof(PROCESSENTRY32);
  if (Process32First(snap, &pe)) {
    do {
      if (n >= cap) {
        cap *= 2;
        *pids = (int32_t*)realloc(*pids, cap * sizeof(int32_t));
        *names = (char**)realloc(*names, cap * sizeof(char*));
      }
      (*pids)[n] = pe.th32ProcessID;
      (*names)[n] = _strdup(pe.szExeFile);
      n++;
    } while (Process32Next(snap, &pe));
  }
  CloseHandle(snap);
  *count = n;
  return 0;
}

int32_t jk100_kill_process(int32_t pid) {
  HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
  if (h == NULL) return -1;
  BOOL ok = TerminateProcess(h, 1);
  CloseHandle(h);
  return ok ? 0 : -1;
}

int32_t jk100_is_process_running(int32_t pid) {
  HANDLE h = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (h == NULL) return 0;
  CloseHandle(h);
  return 1;
}

int32_t jk100_enum_run_keys(char*** names, char*** values, int32_t* count) {
  const char* run_paths[] = {
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
  };
  HKEY roots[] = { HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE };
  int32_t cap = 64, n = 0;
  *names = (char**)malloc(cap * sizeof(char*));
  *values = (char**)malloc(cap * sizeof(char*));
  for (int r = 0; r < 2; r++) {
    for (int p = 0; p < 2; p++) {
      HKEY key;
      if (RegOpenKeyExA(roots[r], run_paths[p], 0, KEY_READ, &key) != ERROR_SUCCESS) continue;
      DWORD idx = 0;
      char name[256];
      DWORD name_len;
      BYTE value[1024];
      DWORD value_len;
      while (1) {
        name_len = sizeof(name);
        value_len = sizeof(value);
        LONG err = RegEnumValueA(key, idx, name, &name_len, NULL, NULL, value, &value_len);
        if (err != ERROR_SUCCESS) break;
        if (n >= cap) {
          cap *= 2;
          *names = (char**)realloc(*names, cap * sizeof(char*));
          *values = (char**)realloc(*values, cap * sizeof(char*));
        }
        (*names)[n] = _strdup(name);
        (*values)[n] = _strdup((char*)value);
        n++;
        idx++;
      }
      RegCloseKey(key);
    }
  }
  *count = n;
  return 0;
}

int32_t jk100_delete_run_key(moonbit_string_t name_s) {
  char name[MAX_PATH];
  jk100_moonbit_to_cstr(name_s, name, MAX_PATH);
  const char* run_paths[] = {
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
  };
  HKEY roots[] = { HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE };
  for (int r = 0; r < 2; r++) {
    for (int p = 0; p < 2; p++) {
      HKEY key;
      if (RegOpenKeyExA(roots[r], run_paths[p], 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) continue;
      RegDeleteValueA(key, name);
      RegCloseKey(key);
    }
  }
  return 0;
}

int32_t jk100_enum_services(char*** names, char*** display_names, int32_t** states, int32_t* count) {
  SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_ENUMERATE_SERVICE);
  if (scm == NULL) return -1;
  DWORD bytes_needed = 0, svc_count = 0, resume = 0;
  EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_STATE_ALL,
                        NULL, 0, &bytes_needed, &svc_count, &resume, NULL);
  BYTE* buf = (BYTE*)malloc(bytes_needed);
  EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_STATE_ALL,
                        buf, bytes_needed, &bytes_needed, &svc_count, &resume, NULL);
  *names = (char**)malloc(svc_count * sizeof(char*));
  *display_names = (char**)malloc(svc_count * sizeof(char*));
  *states = (int32_t*)malloc(svc_count * sizeof(int32_t));
  ENUM_SERVICE_STATUS_PROCESSA* ssp = (ENUM_SERVICE_STATUS_PROCESSA*)buf;
  for (DWORD i = 0; i < svc_count; i++) {
    (*names)[i] = _strdup(ssp[i].lpServiceName);
    (*display_names)[i] = _strdup(ssp[i].lpDisplayName);
    (*states)[i] = (int32_t)ssp[i].ServiceStatusProcess.dwCurrentState;
  }
  *count = (int32_t)svc_count;
  free(buf);
  CloseServiceHandle(scm);
  return 0;
}

int32_t jk100_stop_service(moonbit_string_t name_s) {
  char name[MAX_PATH];
  jk100_moonbit_to_cstr(name_s, name, MAX_PATH);
  SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_CONNECT);
  if (scm == NULL) return -1;
  SC_HANDLE svc = OpenServiceA(scm, name, SERVICE_STOP | SERVICE_QUERY_STATUS);
  if (svc == NULL) { CloseServiceHandle(scm); return -1; }
  SERVICE_STATUS status;
  ControlService(svc, SERVICE_CONTROL_STOP, &status);
  for (int i = 0; i < 100; i++) {
    Sleep(100);
    QueryServiceStatus(svc, &status);
    if (status.dwCurrentState == SERVICE_STOPPED) break;
  }
  CloseServiceHandle(svc);
  CloseServiceHandle(scm);
  return 0;
}

int32_t jk100_delete_service(moonbit_string_t name_s) {
  char name[MAX_PATH];
  jk100_moonbit_to_cstr(name_s, name, MAX_PATH);
  SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_CONNECT);
  if (scm == NULL) return -1;
  SC_HANDLE svc = OpenServiceA(scm, name, DELETE);
  if (svc == NULL) { CloseServiceHandle(scm); return -1; }
  BOOL ok = DeleteService(svc);
  CloseServiceHandle(svc);
  CloseServiceHandle(scm);
  return ok ? 0 : -1;
}

int32_t jk100_move_file_to_quarantine(moonbit_string_t src_s, moonbit_string_t dst_s) {
  char src[MAX_PATH], dst[MAX_PATH];
  jk100_moonbit_to_cstr(src_s, src, MAX_PATH);
  jk100_moonbit_to_cstr(dst_s, dst, MAX_PATH);
  char dir[MAX_PATH];
  strncpy(dir, dst, MAX_PATH - 1);
  dir[MAX_PATH - 1] = 0;
  char* last_slash = strrchr(dir, '\\');
  if (last_slash) {
    *last_slash = 0;
    char tmp[MAX_PATH];
    strncpy(tmp, dir, MAX_PATH - 1);
    tmp[MAX_PATH - 1] = 0;
    for (char* p = tmp + 3; *p; p++) {
      if (*p == '\\') {
        *p = 0;
        CreateDirectoryA(tmp, NULL);
        *p = '\\';
      }
    }
    CreateDirectoryA(tmp, NULL);
  }
  return MoveFileA(src, dst) ? 0 : -1;
}

int32_t jk100_is_file_in_use(moonbit_string_t path_s) {
  char path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  HANDLE h = CreateFileA(path, GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE) return 1;
  CloseHandle(h);
  return 0;
}

int32_t jk100_schedule_delete_on_reboot(moonbit_string_t path_s) {
  char path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  return MoveFileExA(path, NULL, MOVEFILE_DELAY_UNTIL_REBOOT) ? 0 : -1;
}

int32_t jk100_is_elevated() {
  BOOL elevated = FALSE;
  HANDLE token = NULL;
  if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
    TOKEN_ELEVATION e;
    DWORD size;
    if (GetTokenInformation(token, TokenElevation, &e, sizeof(e), &size)) {
      elevated = e.TokenIsElevated;
    }
    CloseHandle(token);
  }
  return elevated ? 1 : 0;
}

int32_t jk100_request_elevation() {
  char path[MAX_PATH];
  GetModuleFileNameA(NULL, path, MAX_PATH);
  SHELLEXECUTEINFOA info = {0};
  info.cbSize = sizeof(info);
  info.lpVerb = "runas";
  info.lpFile = path;
  info.nShow = SW_SHOWNORMAL;
  return ShellExecuteExA(&info) ? 0 : -1;
}

void jk100_set_thread_priority(int32_t priority) {
  int win_priority;
  switch (priority) {
    case 0: win_priority = THREAD_PRIORITY_IDLE; break;
    case 1: win_priority = THREAD_PRIORITY_NORMAL; break;
    case 2: win_priority = THREAD_PRIORITY_ABOVE_NORMAL; break;
    default: win_priority = THREAD_PRIORITY_NORMAL; break;
  }
  SetThreadPriority(GetCurrentThread(), win_priority);
}

void jk100_sleep(int32_t ms) {
  Sleep((DWORD)ms);
}

moonbit_string_t jk100_timestamp() {
  SYSTEMTIME st;
  GetLocalTime(&st);
  char buf[32];
  snprintf(buf, sizeof(buf), "%04d-%02d-%02dT%02d:%02d:%02d",
    st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
  return jk100_cstr_to_moonbit(buf);
}

moonbit_string_t jk100_int_to_string(int32_t n) {
  char buf[32];
  snprintf(buf, sizeof(buf), "%d", n);
  return jk100_cstr_to_moonbit(buf);
}

moonbit_bytes_t jk100_read_file_bytes(moonbit_string_t path_s) {
  char path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  HANDLE h = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  if (h == INVALID_HANDLE_VALUE) return moonbit_make_bytes(0, 0);
  LARGE_INTEGER file_size;
  if (!GetFileSizeEx(h, &file_size)) { CloseHandle(h); return moonbit_make_bytes(0, 0); }
  int32_t size = (int32_t)file_size.QuadPart;
  moonbit_bytes_t buf = moonbit_make_bytes(size, 0);
  DWORD read_bytes;
  ReadFile(h, buf, (DWORD)size, &read_bytes, NULL);
  CloseHandle(h);
  return buf;
}

moonbit_string_t jk100_read_file_text(moonbit_string_t path_s) {
  char path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  HANDLE h = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  if (h == INVALID_HANDLE_VALUE) return moonbit_make_string(0, 0);
  LARGE_INTEGER file_size;
  if (!GetFileSizeEx(h, &file_size)) { CloseHandle(h); return moonbit_make_string(0, 0); }
  int32_t size = (int32_t)file_size.QuadPart;
  char* raw = (char*)malloc(size + 1);
  DWORD read_bytes;
  ReadFile(h, raw, (DWORD)size, &read_bytes, NULL);
  CloseHandle(h);
  int wlen = MultiByteToWideChar(CP_UTF8, 0, raw, (int)read_bytes, NULL, 0);
  moonbit_string_t ms = moonbit_make_string(wlen, 0);
  MultiByteToWideChar(CP_UTF8, 0, raw, (int)read_bytes, (LPWSTR)ms, wlen);
  free(raw);
  return ms;
}

// ============= CLI 参数获取 =============
int32_t jk100_get_arg_count() {
  return (int32_t)__argc;
}

moonbit_string_t jk100_get_arg(int32_t idx) {
  if (idx < 0 || idx >= (int32_t)__argc) return moonbit_make_string(0, 0);
  return jk100_cstr_to_moonbit(__argv[idx]);
}

// ============= 目录枚举 (递归遍历文件) =============
// 全局缓冲区存储枚举结果
static char** g_enum_files = NULL;
static int32_t g_enum_count = 0;
static int32_t g_enum_cap = 0;

static void jk100_enum_add(const char* path) {
  if (g_enum_count >= g_enum_cap) {
    g_enum_cap = g_enum_cap == 0 ? 256 : g_enum_cap * 2;
    g_enum_files = (char**)realloc(g_enum_files, g_enum_cap * sizeof(char*));
  }
  g_enum_files[g_enum_count++] = _strdup(path);
}

static void jk100_enum_recursive(const char* dir) {
  char pattern[MAX_PATH];
  snprintf(pattern, sizeof(pattern), "%s\\*", dir);
  WIN32_FIND_DATAA fd;
  HANDLE h = FindFirstFileA(pattern, &fd);
  if (h == INVALID_HANDLE_VALUE) return;
  do {
    if (strcmp(fd.cFileName, ".") == 0 || strcmp(fd.cFileName, "..") == 0) continue;
    char full[MAX_PATH];
    snprintf(full, sizeof(full), "%s\\%s", dir, fd.cFileName);
    if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      // 限制递归深度避免耗时过长,但仍递归子目录
      jk100_enum_recursive(full);
    } else {
      jk100_enum_add(full);
    }
  } while (FindNextFileA(h, &fd));
  FindClose(h);
}

int32_t jk100_enum_files(moonbit_string_t path_s) {
  // 释放上一次的结果
  if (g_enum_files) {
    for (int i = 0; i < g_enum_count; i++) free(g_enum_files[i]);
    g_enum_count = 0;
  }
  char path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  // 去除末尾反斜杠
  int len = (int)strlen(path);
  if (len > 0 && path[len - 1] == '\\') path[len - 1] = 0;
  jk100_enum_recursive(path);
  return g_enum_count;
}

moonbit_string_t jk100_get_enum_file(int32_t idx) {
  if (idx < 0 || idx >= g_enum_count) return moonbit_make_string(0, 0);
  return jk100_cstr_to_moonbit(g_enum_files[idx]);
}

void jk100_free_enum_files() {
  if (g_enum_files) {
    for (int i = 0; i < g_enum_count; i++) free(g_enum_files[i]);
    free(g_enum_files);
    g_enum_files = NULL;
    g_enum_count = 0;
    g_enum_cap = 0;
  }
}

// ============= 文件大小获取 (用于跳过大文件) =============
int64_t jk100_file_size(moonbit_string_t path_s) {
  char path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  WIN32_FILE_ATTRIBUTE_DATA fad;
  if (!GetFileAttributesExA(path, GetFileExInfoStandard, &fad)) return -1;
  LARGE_INTEGER size;
  size.LowPart = fad.nFileSizeLow;
  size.HighPart = fad.nFileSizeHigh;
  return size.QuadPart;
}

// ============= 简易文件名匹配 (检查是否包含子串) =============
int32_t jk100_path_contains(moonbit_string_t path_s, moonbit_string_t sub_s) {
  char path[MAX_PATH];
  char sub[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  jk100_moonbit_to_cstr(sub_s, sub, MAX_PATH);
  // 大小写不敏感
  for (char* p = path; *p; p++) if (*p >= 'A' && *p <= 'Z') *p = *p - 'A' + 'a';
  for (char* p = sub; *p; p++) if (*p >= 'A' && *p <= 'Z') *p = *p - 'A' + 'a';
  return strstr(path, sub) != NULL ? 1 : 0;
}

// ============= 完整扫描逻辑 (在 C 端实现,绕过 MoonBit Array ICE) =============
// 硬编码的流氓软件特征文件名
static const char* ROGUE_PATTERNS[] = {
  "adware.exe", "popup.exe", "ads.exe",
  "hijack.exe", "browserhelper.exe",
  "fakeav.exe", "rogueav.exe", "systemprotector.exe",
  "360notifier.exe", "360tray.exe",
  "recommend.exe", "toutiao.exe", "news.exe",
  "bundle.exe", "setup_helper.exe",
  "hao123.exe", "2345.exe", "duuba.exe",
  "sogouexplorer.exe", "liebao.exe",
  NULL
};

// 硬编码的白名单路径片段
static const char* WHITELIST_PATHS[] = {
  "windows\\system32", "windows\\syswow64",
  "program files\\windowsapps",
  NULL
};

static void to_lower(char* s) {
  for (; *s; s++) if (*s >= 'A' && *s <= 'Z') *s = *s - 'A' + 'a';
}

static int path_has_sub(char* path_lower, const char* sub) {
  return strstr(path_lower, sub) != NULL;
}

static const char* match_rogue_pattern(char* path_lower) {
  for (int i = 0; ROGUE_PATTERNS[i] != NULL; i++) {
    if (strstr(path_lower, ROGUE_PATTERNS[i]) != NULL) {
      return ROGUE_PATTERNS[i];
    }
  }
  return NULL;
}

static int is_whitelisted_path(char* path_lower) {
  for (int i = 0; WHITELIST_PATHS[i] != NULL; i++) {
    if (strstr(path_lower, WHITELIST_PATHS[i]) != NULL) return 1;
  }
  return 0;
}

// 完整扫描: 枚举+匹配+输出,返回发现的威胁数
int32_t jk100_run_scan(moonbit_string_t path_s) {
  char path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, path, MAX_PATH);
  int len = (int)strlen(path);
  if (len > 0 && path[len - 1] == '\\') path[len - 1] = 0;

  printf("正在扫描: %s\n", path);
  printf("----------------------------------------\n");

  // 枚举文件
  if (g_enum_files) {
    for (int i = 0; i < g_enum_count; i++) free(g_enum_files[i]);
    g_enum_count = 0;
  }
  jk100_enum_recursive(path);

  int32_t total = g_enum_count;
  if (total == 0) {
    printf("[警告] 目录为空或不存在: %s\n", path);
    return 0;
  }

  printf("发现文件数: %d\n", total);
  printf("开始扫描...\n\n");

  int32_t scanned = 0, threats = 0, skipped = 0;

  for (int32_t i = 0; i < total; i++) {
    char* file_path = g_enum_files[i];
    scanned++;

    // 转小写用于匹配
    char path_lower[MAX_PATH];
    strncpy(path_lower, file_path, MAX_PATH - 1);
    path_lower[MAX_PATH - 1] = 0;
    to_lower(path_lower);

    // 跳过白名单
    if (is_whitelisted_path(path_lower)) {
      skipped++;
      continue;
    }

    // 跳过大文件 (>50MB)
    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (GetFileAttributesExA(file_path, GetFileExInfoStandard, &fad)) {
      LARGE_INTEGER size;
      size.LowPart = fad.nFileSizeLow;
      size.HighPart = fad.nFileSizeHigh;
      if (size.QuadPart > 52428800LL) continue;
    }

    // 匹配规则
    const char* matched = match_rogue_pattern(path_lower);
    if (matched != NULL) {
      threats++;
      printf("[威胁] %s\n", file_path);
      printf("  匹配规则: %s\n", matched);
    }

    // 每100个文件输出进度
    if (scanned % 100 == 0) {
      printf("[进度] 已扫描 %d / %d 文件\n", scanned, total);
    }
  }

  // 释放枚举结果
  if (g_enum_files) {
    for (int i = 0; i < g_enum_count; i++) free(g_enum_files[i]);
    free(g_enum_files);
    g_enum_files = NULL;
    g_enum_count = 0;
    g_enum_cap = 0;
  }

  printf("\n========================================\n");
  printf("扫描完成\n");
  printf("  总文件数: %d\n", total);
  printf("  已扫描:   %d\n", scanned);
  printf("  白名单跳过: %d\n", skipped);
  printf("  发现威胁: %d\n", threats);
  printf("========================================\n");
  return threats;
}

// ============= 实时守护监控 (定时轮询方案) =============
// 定期扫描目录,对比发现新增文件并扫描,比 ReadDirectoryChangesW 更可靠

static volatile int g_guard_running = 0;

// 检查单个文件是否匹配威胁,返回匹配的模式名(或NULL)
static const char* check_single_file(const char* file_path) {
  char path_lower[MAX_PATH];
  strncpy(path_lower, file_path, MAX_PATH - 1);
  path_lower[MAX_PATH - 1] = 0;
  to_lower(path_lower);

  // 跳过白名单
  if (is_whitelisted_path(path_lower)) return NULL;

  // 跳过大文件
  WIN32_FILE_ATTRIBUTE_DATA fad;
  if (GetFileAttributesExA(file_path, GetFileExInfoStandard, &fad)) {
    LARGE_INTEGER size;
    size.LowPart = fad.nFileSizeLow;
    size.HighPart = fad.nFileSizeHigh;
    if (size.QuadPart > 52428800LL) return NULL;
  }

  return match_rogue_pattern(path_lower);
}

// 已知文件集合(用简单数组存储,文件数不大时足够)
#define MAX_KNOWN_FILES 10000
static char* g_known_files[MAX_KNOWN_FILES];
static int g_known_count = 0;

static int is_known_file(const char* path) {
  for (int i = 0; i < g_known_count; i++) {
    if (strcmp(g_known_files[i], path) == 0) return 1;
  }
  return 0;
}

static void add_known_file(const char* path) {
  if (g_known_count >= MAX_KNOWN_FILES) return;
  g_known_files[g_known_count++] = _strdup(path);
}

static void clear_known_files() {
  for (int i = 0; i < g_known_count; i++) {
    free(g_known_files[i]);
    g_known_files[i] = NULL;
  }
  g_known_count = 0;
}

// 守护模式: 定时轮询扫描目录
int32_t jk100_start_guard(moonbit_string_t path_s) {
  char watch_path[MAX_PATH];
  jk100_moonbit_to_cstr(path_s, watch_path, MAX_PATH);
  int len = (int)strlen(watch_path);
  if (len > 0 && watch_path[len - 1] == '\\') watch_path[len - 1] = 0;

  // 禁用 stdout 缓冲,确保实时输出
  setbuf(stdout, NULL);

  printf("[守护] 启动实时监控: %s\n", watch_path);
  printf("[守护] 监控目录及所有子目录的文件变化 (轮询间隔: 2秒)\n");
  printf("[守护] 按 Ctrl+C 停止守护\n");
  printf("----------------------------------------\n");

  // 先做一次初始扫描,建立基线
  printf("[守护] 初始扫描中...\n");

  // 释放旧的枚举结果
  if (g_enum_files) {
    for (int i = 0; i < g_enum_count; i++) free(g_enum_files[i]);
    g_enum_count = 0;
  }
  jk100_enum_recursive(watch_path);

  int initial_count = g_enum_count;
  // 将初始文件加入已知列表
  for (int i = 0; i < g_enum_count; i++) {
    add_known_file(g_enum_files[i]);
  }

  // 释放枚举结果
  if (g_enum_files) {
    for (int i = 0; i < g_enum_count; i++) free(g_enum_files[i]);
    free(g_enum_files);
    g_enum_files = NULL;
    g_enum_count = 0;
    g_enum_cap = 0;
  }

  printf("[守护] 基线建立完成,已知文件: %d 个\n", initial_count);
  printf("[守护] 开始实时监控...\n");
  printf("----------------------------------------\n");

  g_guard_running = 1;
  int threat_count = 0;
  int total_new_files = 0;
  int scan_round = 0;

  while (g_guard_running) {
    // 等待 2 秒 (分段等待,每 200ms 检查一次停止标志)
    for (int i = 0; i < 10 && g_guard_running; i++) {
      Sleep(200);
    }
    if (!g_guard_running) break;

    scan_round++;

    // 枚举当前文件
    jk100_enum_recursive(watch_path);
    int current_count = g_enum_count;

    // 检查新增文件
    for (int i = 0; i < current_count; i++) {
      if (!is_known_file(g_enum_files[i])) {
        // 新文件!
        add_known_file(g_enum_files[i]);
        total_new_files++;

        // 扫描新文件
        const char* matched = check_single_file(g_enum_files[i]);
        if (matched != NULL) {
          threat_count++;
          SYSTEMTIME st;
          GetLocalTime(&st);
          printf("[威胁] [%02d:%02d:%02d] 检测到新文件: %s\n",
            st.wHour, st.wMinute, st.wSecond, g_enum_files[i]);
          printf("  匹配规则: %s\n", matched);
          printf("  建议: 立即隔离或删除该文件\n");
        }
      }
    }

    // 释放本轮枚举结果
    if (g_enum_files) {
      for (int i = 0; i < g_enum_count; i++) free(g_enum_files[i]);
      free(g_enum_files);
      g_enum_files = NULL;
      g_enum_count = 0;
      g_enum_cap = 0;
    }
  }

  // 清理已知文件列表
  clear_known_files();
  g_guard_running = 0;

  printf("\n========================================\n");
  printf("守护模式已停止\n");
  printf("  监控目录: %s\n", watch_path);
  printf("  扫描轮次: %d\n", scan_round);
  printf("  新增文件数: %d\n", total_new_files);
  printf("  发现威胁: %d\n", threat_count);
  printf("========================================\n");

  return threat_count;
}

// 停止守护
void jk100_stop_guard() {
  g_guard_running = 0;
}