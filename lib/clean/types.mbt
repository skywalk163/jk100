pub enum CleanOp {
  KillProcess(Int)
  DeleteRunKey(String, String)
  StopDeleteService(String)
  DeleteScheduledTask(String)
  MoveFileToQuarantine(String, String)
  FixHomepage(String)
} derive(@debug.Debug)

pub struct CleanItem {
  op : CleanOp
  success : Bool
  message : String
} derive(@debug.Debug)

pub struct CleanResult {
  items : Array[CleanItem]
  pending_reboot : Bool
  scan_id : String
} derive(@debug.Debug)

pub struct QuarantineItem {
  op_type : String
  source : String
  quarantine_path : String
  old_value : String
  sha256_before : String
  status : String
} derive(@debug.Debug)

pub struct QuarantineManifest {
  scan_id : String
  timestamp : String
  items : Array[QuarantineItem]
} derive(@debug.Debug)