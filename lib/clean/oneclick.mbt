pub fn one_click_clean(
  threats : Array[@jk100/jk100/lib/core.Threat],
  scan_id : String
) -> CleanResult {
  if !@platform.is_elevated() {
    let elevated = @platform.request_elevation()
    if !elevated {
      let result : CleanResult = {
        items: [],
        pending_reboot: false,
        scan_id: scan_id,
      }
      return result
    }
  }

  ignore(create_quarantine_dir(scan_id))

  let all_items : Array[CleanItem] = []
  let mut pending_reboot = false
  let manifest_items : Array[QuarantineItem] = []

  for threat in threats {
    let clean_items = deep_clean_threat(threat, scan_id)
    for item in clean_items {
      all_items.push(item)
      if item.message.contains("重启") {
        pending_reboot = true
      }
    }
  }

  let manifest : QuarantineManifest = {
    scan_id: scan_id,
    timestamp: @async.now().to_string(),
    items: manifest_items,
  }
  write_manifest(scan_id, manifest)

  let result : CleanResult = {
    items: all_items,
    pending_reboot: pending_reboot,
    scan_id: scan_id,
  }
  result
}