struct ScanCallbacks {
  on_progress : (Int, Int) -> Unit
  on_threat : (Threat) -> Unit
  on_complete : (ScanResult) -> Unit
  on_error : (String) -> Unit
}

pub async fn run_scan(
  db : SigDB,
  clamav : ClamAVConfig,
  target : ScanTarget,
  speed : ScanSpeed,
  callbacks : ScanCallbacks
) -> ScanResult raise {
  let result : ScanResult = {
    threats: [],
    total_files: 0,
    scanned_files: 0,
    skipped_whitelist: 0,
    errors: 0,
    elapsed_ms: 0,
  }

  let files = collect_target_files(target)
  result.total_files = files.length()

  let priority_val = match speed {
    Low => 0
    Normal => 1
    High => 2
  }
  @platform.set_thread_priority(priority_val)

  for path in files {
    let sleep_ms = match speed {
      Low => 100
      Normal => 10
      High => 0
    }
    if sleep_ms > 0 {
      @async.sleep(sleep_ms)
    }

    let file_data = @fs.read_file(path)
    let hash = bytes_sha256(file_data.binary())

    let pe_info = parse_pe_file(path)
    let file_name = path_filename(path)

    if is_whitelisted(db, path, pe_info.signer, hash) {
      result.skipped_whitelist = result.skipped_whitelist + 1
      result.scanned_files = result.scanned_files + 1
      (callbacks.on_progress)(result.scanned_files, result.total_files)
      continue
    }

    let matched_rules = match_rogue_rules(db, path, pe_info.signer, hash, file_name)
    if matched_rules.length() > 0 {
      let rule = matched_rules[0]
      let threat : Threat = {
        threat_type: Rogue,
        severity: Rogue,
        source: Sigdb,
        rule_id: rule.id,
        family_name: rule.name,
        file_path: path,
        file_hash_sha256: hash,
        signer: pe_info.signer,
        process_id: 0,
        service_name: "",
        run_key_name: "",
        scheduled_task: "",
        homepage_hijack: rule.homepage,
        description: rule.description,
      }
      result.threats.push(threat)
      (callbacks.on_threat)(threat)
    }

    if clamav.available {
      let clamav_result = scan_file(clamav, path)
      if clamav_result.infected {
        let threat : Threat = {
          threat_type: Virus,
          severity: Suspicious,
          source: ClamAV,
          rule_id: "",
          family_name: clamav_result.virus_name,
          file_path: path,
          file_hash_sha256: hash,
          signer: pe_info.signer,
          process_id: 0,
          service_name: "",
          run_key_name: "",
          scheduled_task: "",
          homepage_hijack: "",
          description: "ClamAV 检出: " + clamav_result.virus_name,
        }
        result.threats.push(threat)
        (callbacks.on_threat)(threat)
      }
    }

    result.scanned_files = result.scanned_files + 1
    (callbacks.on_progress)(result.scanned_files, result.total_files)
  }

  scan_run_keys(db, result, callbacks)
  scan_services(db, result, callbacks)

  (callbacks.on_complete)(result)
  result
}

fn collect_target_files(target : ScanTarget) -> Array[String] {
  match target {
    QuickScan => []
    FullScan => []
    CustomScan(paths) => paths
  }
}

fn path_filename(path : String) -> String {
  let len = path.length()
  for i = len - 1; i >= 0; i = i - 1 {
    if path.unsafe_get(i).unsafe_to_char() == '\\' {
      return path.substring(start=i + 1, end=len)
    }
  }
  path
}

fn scan_run_keys(db : SigDB, result : ScanResult, callbacks : ScanCallbacks) -> Unit {
  ignore(db)
  ignore(result)
  ignore(callbacks)
}

fn scan_services(db : SigDB, result : ScanResult, callbacks : ScanCallbacks) -> Unit {
  ignore(db)
  ignore(result)
  ignore(callbacks)
}

fn threat_type_to_string(t : ThreatType) -> String {
  match t {
    Rogue => "Rogue"
    Virus => "Virus"
  }
}

pub async fn run_cli() -> Unit raise {
  println("jk100 极快100 防恶意软件 v0.1.0")
  println("========================================")

  if !@platform.is_elevated() {
    println("[警告] 未以管理员身份运行，部分功能受限")
  }

  let db = load("bundled/sigdb/rogue_rules.json", "bundled/sigdb/whitelist.json")
  println("规则库版本: " + db.rules.version)
  println("流氓软件规则数: " + db.rules.rules.length().to_string())
  println("白名单条目数: " + db.whitelist.entries.length().to_string())

  let mut clamav = default_config()
  clamav = check_available(clamav)
  if !clamav.available {
    println("[警告] ClamAV 不可用，仅扫描流氓软件")
  }

  println("\n开始快速扫描...")
  let callbacks : ScanCallbacks = {
    on_progress: (scanned, total) => {
      println("进度: " + scanned.to_string() + "/" + total.to_string())
    },
    on_threat: (threat) => {
      println("[发现] " + threat.family_name + ": " + threat.file_path)
    },
    on_complete: (result) => {
      println("\n扫描完成！")
      println("威胁数: " + result.threats.length().to_string())
    },
    on_error: (msg) => {
      println("[错误] " + msg)
    },
  }

  let result : ScanResult = run_scan(db, clamav, QuickScan, Normal, callbacks)

  if result.threats.length() == 0 {
    println("\n系统安全，未发现威胁。")
  } else {
    println("\n发现 " + result.threats.length().to_string() + " 个威胁：")
    for threat in result.threats {
      println("  [" + threat_type_to_string(threat.threat_type) + "] " + threat.family_name)
      println("    路径: " + threat.file_path)
      println("    描述: " + threat.description)
    }
  }
}