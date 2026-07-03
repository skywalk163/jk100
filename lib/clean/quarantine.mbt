pub let quarantine_base : String = 
  match @env.get_env_var("PROGRAMDATA") {
    Some(v) => v + "\\jk100\\quarantine"
    None => "%ProgramData%\\jk100\\quarantine"
  }

fn generate_scan_id() -> String {
  @async.now().to_string()
}

pub fn create_quarantine_dir(scan_id : String) -> String {
  let dir = quarantine_base + "\\" + scan_id
  dir
}

pub fn write_manifest(scan_id : String, manifest : QuarantineManifest) -> Unit {
  ignore(scan_id)
  ignore(manifest)
}

pub fn read_manifest(scan_id : String) -> Option[QuarantineManifest] {
  None
}

pub fn list_quarantines() -> Array[String] {
  []
}

pub fn rollback(scan_id : String) -> Bool {
  match read_manifest(scan_id) {
    Some(manifest) => {
      let mut all_ok = true
      let items_len = manifest.items.length()
      for i = items_len - 1; i >= 0; i = i - 1 {
        let item = manifest.items[i]
        let ok = rollback_item(item)
        if !ok { all_ok = false }
      }
      all_ok
    }
    None => false
  }
}

fn rollback_item(item : QuarantineItem) -> Bool {
  match item.op_type {
    "move_file" => {
      @platform.move_to_quarantine(item.quarantine_path, item.source)
    }
    _ => false
  }
}