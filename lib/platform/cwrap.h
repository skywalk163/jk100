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
int32_t jk100_delete_run_key(const char* name);

int32_t jk100_enum_services(char*** names, char*** display_names, int32_t** states, int32_t* count);
int32_t jk100_stop_service(const char* name);
int32_t jk100_delete_service(const char* name);

int32_t jk100_move_file_to_quarantine(const char* src, const char* dst);
int32_t jk100_is_file_in_use(const char* path);
int32_t jk100_schedule_delete_on_reboot(const char* path);

int32_t jk100_is_elevated();
int32_t jk100_request_elevation();

void jk100_set_thread_priority(int32_t priority);

moonbit_string_t jk100_cstr_to_moonbit(const char* s);
void jk100_free_cstr_array(char** arr, int32_t count);
void jk100_free_int_array(int32_t* arr);

#endif