enum ThreatCategory {
  Processes
  RunKeys
  Services
  ScheduledTasks
  Files
  Homepage
}

struct CategorizedThreats {
  processes : Array[@jk100/jk100/lib/core.Threat]
  run_keys : Array[@jk100/jk100/lib/core.Threat]
  services : Array[@jk100/jk100/lib/core.Threat]
  scheduled_tasks : Array[@jk100/jk100/lib/core.Threat]
  files : Array[@jk100/jk100/lib/core.Threat]
  homepage : Array[@jk100/jk100/lib/core.Threat]
} derive(@debug.Debug)

pub fn categorize(threats : Array[@jk100/jk100/lib/core.Threat]) -> CategorizedThreats {
  let result : CategorizedThreats = {
    processes: [],
    run_keys: [],
    services: [],
    scheduled_tasks: [],
    files: [],
    homepage: [],
  }
  for threat in threats {
    if threat.process_id > 0 {
      result.processes.push(threat)
    }
    if threat.run_key_name.length() > 0 {
      result.run_keys.push(threat)
    }
    if threat.service_name.length() > 0 {
      result.services.push(threat)
    }
    if threat.scheduled_task.length() > 0 {
      result.scheduled_tasks.push(threat)
    }
    if threat.file_path.length() > 0 {
      result.files.push(threat)
    }
    if threat.homepage_hijack.length() > 0 {
      result.homepage.push(threat)
    }
  }
  result
}

pub fn clean_selected(
  selected : Array[@jk100/jk100/lib/core.Threat],
  scan_id : String
) -> CleanResult {
  let items : Array[CleanItem] = []
  let mut pending_reboot = false
  for threat in selected {
    let clean_items = deep_clean_threat(threat, scan_id)
    for item in clean_items {
      items.push(item)
      if item.message.contains("重启") {
        pending_reboot = true
      }
    }
  }
  let result : CleanResult = {
    items: items,
    pending_reboot: pending_reboot,
    scan_id: scan_id,
  }
  result
}