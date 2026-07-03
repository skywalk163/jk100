extern "c" fn jk100_set_thread_priority(priority: Int) -> Unit = "jk100_set_thread_priority"

pub fn set_thread_priority(priority : Int) -> Unit {
  jk100_set_thread_priority(priority)
}