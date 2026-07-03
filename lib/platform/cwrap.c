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

int32_t jk100_delete_run_key(const char* name) {
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

int32_t jk100_stop_service(const char* name) {
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

int32_t jk100_delete_service(const char* name) {
  SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_CONNECT);
  if (scm == NULL) return -1;
  SC_HANDLE svc = OpenServiceA(scm, name, DELETE);
  if (svc == NULL) { CloseServiceHandle(scm); return -1; }
  BOOL ok = DeleteService(svc);
  CloseServiceHandle(svc);
  CloseServiceHandle(scm);
  return ok ? 0 : -1;
}

int32_t jk100_move_file_to_quarantine(const char* src, const char* dst) {
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

int32_t jk100_is_file_in_use(const char* path) {
  HANDLE h = CreateFileA(path, GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE) return 1;
  CloseHandle(h);
  return 0;
}

int32_t jk100_schedule_delete_on_reboot(const char* path) {
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

moonbit_bytes_t jk100_read_file_bytes(const char* path) {
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

moonbit_string_t jk100_read_file_text(const char* path) {
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