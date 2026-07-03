#borrow(_name)
extern "c" fn jk100_delete_run_key(_name: String) -> Int = "jk100_delete_run_key"

struct RunEntry {
  name : String
  value : String
} derive(@debug.Debug)

pub fn delete_run_key(name : String) -> Bool {
  jk100_delete_run_key(name) == 0
}