#borrow(_name)
extern "c" fn jk100_stop_service(_name: Bytes) -> Int = "jk100_stop_service"

#borrow(_name)
extern "c" fn jk100_delete_service(_name: Bytes) -> Int = "jk100_delete_service"

struct ServiceInfo {
  name : String
  display_name : String
  state : Int
} derive(@debug.Debug)

pub fn stop_service(name : String) -> Bool {
  let c_name = name.to_bytes()
  jk100_stop_service(c_name) == 0
}

pub fn delete_service(name : String) -> Bool {
  let c_name = name.to_bytes()
  jk100_delete_service(c_name) == 0
}