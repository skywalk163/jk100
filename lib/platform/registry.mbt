#borrow(_name)
extern "c" fn jk100_delete_run_key(_name: Bytes) -> Int = "jk100_delete_run_key"

struct RunEntry {
  name : String
  value : String
} derive(@debug.Debug)

pub fn delete_run_key(name : String) -> Bool {
  let c_name = name.to_bytes()
  jk100_delete_run_key(c_name) == 0
}