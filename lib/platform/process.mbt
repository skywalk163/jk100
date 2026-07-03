extern "c" fn jk100_kill_process(pid: Int) -> Int = "jk100_kill_process"
extern "c" fn jk100_is_process_running(pid: Int) -> Int = "jk100_is_process_running"

struct ProcessInfo {
  pid : Int
  name : String
} derive(@debug.Debug)

pub fn kill_process(pid : Int) -> Bool {
  jk100_kill_process(pid) == 0
}

pub fn is_process_running(pid : Int) -> Bool {
  jk100_is_process_running(pid) != 0
}