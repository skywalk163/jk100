extern "c" fn jk100_is_elevated() -> Int = "jk100_is_elevated"
extern "c" fn jk100_request_elevation() -> Int = "jk100_request_elevation"

pub fn is_elevated() -> Bool {
  jk100_is_elevated() != 0
}

pub fn request_elevation() -> Bool {
  jk100_request_elevation() == 0
}