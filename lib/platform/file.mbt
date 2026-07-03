#borrow(_src, _dst)
extern "c" fn jk100_move_file_to_quarantine(_src: String, _dst: String) -> Int = "jk100_move_file_to_quarantine"

#borrow(_path)
extern "c" fn jk100_is_file_in_use(_path: String) -> Int = "jk100_is_file_in_use"

#borrow(_path)
extern "c" fn jk100_schedule_delete_on_reboot(_path: String) -> Int = "jk100_schedule_delete_on_reboot"

pub fn move_to_quarantine(src : String, dst : String) -> Bool {
  jk100_move_file_to_quarantine(src, dst) == 0
}

pub fn is_file_in_use(path : String) -> Bool {
  jk100_is_file_in_use(path) != 0
}

pub fn schedule_delete_on_reboot(path : String) -> Bool {
  jk100_schedule_delete_on_reboot(path) == 0
}

extern "c" fn jk100_sleep(ms : Int) -> Unit = "jk100_sleep"
extern "c" fn jk100_timestamp() -> String = "jk100_timestamp"

#borrow(_path)
extern "c" fn jk100_read_file_bytes(_path : String) -> Bytes = "jk100_read_file_bytes"

#borrow(_path)
extern "c" fn jk100_read_file_text(_path : String) -> String = "jk100_read_file_text"

pub fn sleep(ms : Int) -> Unit {
  jk100_sleep(ms)
}

pub fn timestamp() -> String {
  jk100_timestamp()
}

pub fn read_file_bytes(path : String) -> Bytes {
  jk100_read_file_bytes(path)
}

pub fn read_file_text(path : String) -> String {
  jk100_read_file_text(path)
}

// MoonBit 运行时内置的 println (绕过 native 后端 println 代码生成 bug)
#borrow(_s)
extern "C" fn moonbit_println(_s : String) -> Unit = "moonbit_println"

pub fn println(s : String) -> Unit {
  moonbit_println(s)
}

// int 转 string (用 C FFI 实现,绕过 MoonBit native 代码生成 bug)
extern "c" fn jk100_int_to_string(n : Int) -> String = "jk100_int_to_string"

pub fn int_to_string(n : Int) -> String {
  jk100_int_to_string(n)
}

// ============= CLI 参数获取 =============
extern "c" fn jk100_get_arg_count() -> Int = "jk100_get_arg_count"

#borrow(_idx)
extern "c" fn jk100_get_arg(_idx : Int) -> String = "jk100_get_arg"

pub fn get_arg_count() -> Int {
  jk100_get_arg_count()
}

pub fn get_arg(idx : Int) -> String {
  jk100_get_arg(idx)
}

// ============= 目录枚举 =============
#borrow(_path)
extern "c" fn jk100_enum_files(_path : String) -> Int = "jk100_enum_files"

#borrow(_idx)
extern "c" fn jk100_get_enum_file(_idx : Int) -> String = "jk100_get_enum_file"

extern "c" fn jk100_free_enum_files() -> Unit = "jk100_free_enum_files"

pub fn enum_files(path : String) -> Int {
  jk100_enum_files(path)
}

pub fn get_enum_file(idx : Int) -> String {
  jk100_get_enum_file(idx)
}

pub fn free_enum_files() -> Unit {
  jk100_free_enum_files()
}

// ============= 文件大小 =============
#borrow(_path)
extern "c" fn jk100_file_size(_path : String) -> Int64 = "jk100_file_size"

pub fn file_size(path : String) -> Int64 {
  jk100_file_size(path)
}

// ============= 路径子串匹配 =============
#borrow(_path, _sub)
extern "c" fn jk100_path_contains(_path : String, _sub : String) -> Int = "jk100_path_contains"

pub fn path_contains(path : String, sub : String) -> Bool {
  jk100_path_contains(path, sub) != 0
}

// ============= 完整扫描 (C 端实现) =============
#borrow(_path)
extern "c" fn jk100_run_scan(_path : String) -> Int = "jk100_run_scan"

pub fn run_scan(path : String) -> Int {
  jk100_run_scan(path)
}