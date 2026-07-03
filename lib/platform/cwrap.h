#ifndef JK100_CWRAP_H
#define JK100_CWRAP_H

#include <windows.h>
#include <psapi.h>
#include <shlobj.h>
#include <tlhelp32.h>
#include <moonbit.h>

int32_t jk100_enum_processes(int32_t** pids, char*** names, int32_t* count);
int32_t jk100_kill_process(int32_t pid);
int32_t jk100_is_process_running(int32_t pid);

int32_t jk100_enum_run_keys(char*** names, char*** values, int32_t* count);
int32_t jk100_delete_run_key(moonbit_string_t name);

int32_t jk100_enum_services(char*** names, char*** display_names, int32_t** states, int32_t* count);
int32_t jk100_stop_service(moonbit_string_t name);
int32_t jk100_delete_service(moonbit_string_t name);

int32_t jk100_move_file_to_quarantine(moonbit_string_t src, moonbit_string_t dst);
int32_t jk100_is_file_in_use(moonbit_string_t path);
int32_t jk100_schedule_delete_on_reboot(moonbit_string_t path);

int32_t jk100_is_elevated();
int32_t jk100_request_elevation();

void jk100_set_thread_priority(int32_t priority);

moonbit_string_t jk100_cstr_to_moonbit(const char* s);
int32_t jk100_moonbit_to_cstr(moonbit_string_t s, char* buf, int32_t buf_size);
void jk100_free_cstr_array(char** arr, int32_t count);
void jk100_free_int_array(int32_t* arr);

void jk100_sleep(int32_t ms);
moonbit_string_t jk100_timestamp();
moonbit_string_t jk100_int_to_string(int32_t n);
moonbit_bytes_t jk100_read_file_bytes(moonbit_string_t path);
moonbit_string_t jk100_read_file_text(moonbit_string_t path);

// CLI 参数
int32_t jk100_get_arg_count();
moonbit_string_t jk100_get_arg(int32_t idx);

// 目录枚举
int32_t jk100_enum_files(moonbit_string_t path);
moonbit_string_t jk100_get_enum_file(int32_t idx);
void jk100_free_enum_files();

// 文件大小
int64_t jk100_file_size(moonbit_string_t path);

// 路径子串匹配 (大小写不敏感)
int32_t jk100_path_contains(moonbit_string_t path, moonbit_string_t sub);

// 完整扫描 (C 端实现): 枚举+匹配+输出,返回威胁数
int32_t jk100_run_scan(moonbit_string_t path);

// 实时守护监控: 监控目录文件变化,新文件自动扫描,返回威胁数
int32_t jk100_start_guard(moonbit_string_t path);
void jk100_stop_guard();

#endif