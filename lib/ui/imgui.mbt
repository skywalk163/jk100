extern "c" fn jk100_ui_init() -> Int = "jk100_ui_init"
extern "c" fn jk100_ui_new_frame() -> Int = "jk100_ui_new_frame"
extern "c" fn jk100_ui_render() -> Unit = "jk100_ui_render"
extern "c" fn jk100_ui_shutdown() -> Unit = "jk100_ui_shutdown"

#borrow(name)
extern "c" fn jk100_ui_begin(name: Bytes) -> Unit = "jk100_ui_begin"

extern "c" fn jk100_ui_end() -> Unit = "jk100_ui_end"

#borrow(text)
extern "c" fn jk100_ui_text(text: Bytes) -> Unit = "jk100_ui_text"

#borrow(label)
extern "c" fn jk100_ui_button(label: Bytes) -> Int = "jk100_ui_button"

extern "c" fn jk100_ui_same_line() -> Unit = "jk100_ui_same_line"
extern "c" fn jk100_ui_separator() -> Unit = "jk100_ui_separator"
extern "c" fn jk100_ui_progress_bar(fraction: Double) -> Unit = "jk100_ui_progress_bar"

#borrow(label)
extern "c" fn jk100_ui_begin_listbox(label: Bytes, height: Int) -> Int = "jk100_ui_begin_listbox"

extern "c" fn jk100_ui_end_listbox() -> Unit = "jk100_ui_end_listbox"

#borrow(label)
extern "c" fn jk100_ui_selectable(label: Bytes, selected: Int) -> Int = "jk100_ui_selectable"

pub fn ui_init() -> Bool {
  jk100_ui_init() == 0
}

pub fn ui_new_frame() -> Bool {
  jk100_ui_new_frame() == 0
}

pub fn ui_render() -> Unit {
  jk100_ui_render()
}

pub fn ui_shutdown() -> Unit {
  jk100_ui_shutdown()
}

pub fn ui_begin(name : String) -> Unit {
  let b = name.to_bytes()
  jk100_ui_begin(b)
}

pub fn ui_end() -> Unit { jk100_ui_end() }

pub fn ui_text(t : String) -> Unit {
  let b = t.to_bytes()
  jk100_ui_text(b)
}

pub fn ui_button(label : String) -> Bool {
  let b = label.to_bytes()
  jk100_ui_button(b) != 0
}

pub fn ui_same_line() -> Unit { jk100_ui_same_line() }

pub fn ui_separator() -> Unit { jk100_ui_separator() }

pub fn ui_progress_bar(fraction : Double) -> Unit {
  jk100_ui_progress_bar(fraction)
}

pub fn ui_begin_listbox(label : String, height : Int) -> Bool {
  let b = label.to_bytes()
  jk100_ui_begin_listbox(b, height) != 0
}

pub fn ui_end_listbox() -> Unit { jk100_ui_end_listbox() }

pub fn ui_selectable(label : String, selected : Bool) -> Bool {
  let b = label.to_bytes()
  jk100_ui_selectable(b, if selected { 1 } else { 0 }) != 0
}