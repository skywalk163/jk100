#borrow(_src, _dst)
extern "c" fn jk100_move_file_to_quarantine(_src: Bytes, _dst: Bytes) -> Int = "jk100_move_file_to_quarantine"

#borrow(_path)
extern "c" fn jk100_is_file_in_use(_path: Bytes) -> Int = "jk100_is_file_in_use"

#borrow(_path)
extern "c" fn jk100_schedule_delete_on_reboot(_path: Bytes) -> Int = "jk100_schedule_delete_on_reboot"

pub fn move_to_quarantine(src : String, dst : String) -> Bool {
  let c_src = src.to_bytes()
  let c_dst = dst.to_bytes()
  jk100_move_file_to_quarantine(c_src, c_dst) == 0
}

pub fn is_file_in_use(path : String) -> Bool {
  let c_path = path.to_bytes()
  jk100_is_file_in_use(c_path) != 0
}

pub fn schedule_delete_on_reboot(path : String) -> Bool {
  let c_path = path.to_bytes()
  jk100_schedule_delete_on_reboot(c_path) == 0
}