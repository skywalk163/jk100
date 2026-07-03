enum AppState {
  Home
  Scanning
  Results
  Cleaning
  CleanDone
  Quarantine
  Settings
} derive(@debug.Debug)

struct AppModel {
  mut state : AppState
  scan_result : ScanResult
  scan_speed : ScanSpeed
  clamav_available : Bool
  progress : Double
  selected_threats : Array[Bool]
  mut clean_mode : CleanMode
  clean_result : CleanResult
} derive(@debug.Debug)

pub enum ScanSpeed {
  Low
  Normal
  High
} derive(@debug.Debug)

pub enum CleanMode {
  Classify
  OneClick
} derive(@debug.Debug)

pub struct Threat {
  threat_type : ThreatType
  severity : Severity
  source : DetectionSource
  rule_id : String
  family_name : String
  file_path : String
  file_hash_sha256 : String
  signer : String
  process_id : Int
  service_name : String
  run_key_name : String
  scheduled_task : String
  homepage_hijack : String
  description : String
} derive(@debug.Debug)

pub enum ThreatType {
  Rogue
  Virus
} derive(@debug.Debug)

pub enum Severity {
  Rogue
  Suspicious
} derive(@debug.Debug)

pub enum DetectionSource {
  Sigdb
  ClamAV
} derive(@debug.Debug)

pub struct ScanResult {
  threats : Array[Threat]
  total_files : Int
  scanned_files : Int
  skipped_whitelist : Int
  errors : Int
  elapsed_ms : Int
} derive(@debug.Debug)

pub struct CleanItem {
  op : CleanOp
  success : Bool
  message : String
} derive(@debug.Debug)

pub enum CleanOp {
  KillProcess(Int)
  DeleteRunKey(String, String)
  StopDeleteService(String)
  DeleteScheduledTask(String)
  MoveFileToQuarantine(String, String)
  FixHomepage(String)
} derive(@debug.Debug)

pub struct CleanResult {
  items : Array[CleanItem]
  pending_reboot : Bool
  scan_id : String
} derive(@debug.Debug)

fn init_model() -> AppModel {
  {
    state: Home,
    scan_result: { threats: [], total_files: 0, scanned_files: 0, skipped_whitelist: 0, errors: 0, elapsed_ms: 0 },
    scan_speed: Normal,
    clamav_available: false,
    progress: 0.0,
    selected_threats: [],
    clean_mode: Classify,
    clean_result: { items: [], pending_reboot: false, scan_id: "" },
  }
}

pub fn run_gui() -> Unit {
  if !ui_init() {
    println("ImGui 初始化失败")
    return
  }

  let model = init_model()

  let mut running = true
  while running {
    if !ui_new_frame() {
      running = false
      break
    }

    render_frame(model)
    ui_render()
  }

  ui_shutdown()
}

fn render_frame(model : AppModel) -> Unit {
  match model.state {
    Home => render_home(model)
    Scanning => render_scanning(model)
    Results => render_results(model)
    Cleaning => render_cleaning(model)
    CleanDone => render_clean_done(model)
    Quarantine => render_quarantine(model)
    Settings => render_settings(model)
  }
}

fn render_home(model : AppModel) -> Unit {
  ui_begin("jk100 极快100 防恶意软件")
  ui_text("jk100 极快100 v0.1.0")
  ui_separator()
  ui_text("选择扫描模式：")
  if ui_button("快速扫描") {
    model.state = Scanning
  }
  ui_same_line()
  if ui_button("全盘扫描") {
    model.state = Scanning
  }
  ui_separator()
  if ui_button("隔离区") {
    model.state = Quarantine
  }
  ui_same_line()
  if ui_button("设置") {
    model.state = Settings
  }
  if !model.clamav_available {
    ui_text("[提示] ClamAV 不可用，仅扫描流氓软件")
  }
  ui_end()
}

fn render_scanning(model : AppModel) -> Unit {
  ui_begin("扫描中...")
  ui_text("正在扫描，请稍候...")
  ui_progress_bar(model.progress)
  ui_text("已扫描: " + model.scan_result.scanned_files.to_string() + " / " + model.scan_result.total_files.to_string())
  if model.scan_result.threats.length() > 0 {
    ui_text("已发现威胁: " + model.scan_result.threats.length().to_string())
  }
  if ui_button("取消扫描") {
    model.state = Results
  }
  ui_end()
}

fn render_results(model : AppModel) -> Unit {
  ui_begin("扫描结果")
  let threat_count = model.scan_result.threats.length()
  ui_text("发现 " + threat_count.to_string() + " 个威胁")
  ui_separator()

  if threat_count > 0 {
    if ui_button("一键深度清理") {
      model.clean_mode = OneClick
      model.state = Cleaning
    }
    ui_same_line()
    if ui_button("分类引导清理") {
      model.clean_mode = Classify
      model.state = Cleaning
    }
  }

  if ui_begin_listbox("威胁列表", 300) {
    for i in 0..<model.scan_result.threats.length() {
      let threat = model.scan_result.threats[i]
      let label = threat.family_name + " - " + threat.file_path
      ignore(ui_selectable(label, false))
    }
    ui_end_listbox()
  }

  ui_separator()
  if ui_button("返回首页") {
    model.state = Home
  }
  ui_end()
}

fn render_cleaning(model : AppModel) -> Unit {
  ui_begin("清理中...")
  ui_text("正在清理威胁...")
  ui_end()
}

fn render_clean_done(model : AppModel) -> Unit {
  ui_begin("清理完成")
  let mut success_count = 0
  let mut fail_count = 0
  for item in model.clean_result.items {
    if item.success { success_count = success_count + 1 } else { fail_count = fail_count + 1 }
  }
  ui_text("成功: " + success_count.to_string() + "  失败: " + fail_count.to_string())
  if model.clean_result.pending_reboot {
    ui_text("[提示] 部分操作需要重启后完成")
  }
  if ui_button("返回首页") {
    model.state = Home
  }
  ui_end()
}

fn render_quarantine(model : AppModel) -> Unit {
  ui_begin("隔离区")
  let quarantines : Array[String] = []
  if quarantines.length() == 0 {
    ui_text("隔离区为空")
  } else {
    if ui_begin_listbox("隔离记录", 300) {
      for qid in quarantines {
        ignore(ui_selectable(qid, false))
      }
      ui_end_listbox()
    }
  }
  ui_separator()
  if ui_button("返回") { model.state = Home }
  ui_end()
}

fn render_settings(model : AppModel) -> Unit {
  ui_begin("设置")
  ui_text("扫描速度档位：")
  ui_separator()
  if ui_button("返回") { model.state = Home }
  ui_end()
}