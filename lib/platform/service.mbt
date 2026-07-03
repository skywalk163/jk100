#borrow(_name)
extern "c" fn jk100_stop_service(_name: String) -> Int = "jk100_stop_service"

#borrow(_name)
extern "c" fn jk100_delete_service(_name: String) -> Int = "jk100_delete_service"

struct ServiceInfo {
  name : String
  display_name : String
  state : Int
} derive(@debug.Debug)

pub fn stop_service(name : String) -> Bool {
  jk100_stop_service(name) == 0
}

pub fn delete_service(name : String) -> Bool {
  jk100_delete_service(name) == 0
}