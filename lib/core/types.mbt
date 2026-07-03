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

pub enum ScanSpeed {
  Low
  Normal
  High
} derive(@debug.Debug)

pub enum ScanTarget {
  QuickScan
  FullScan
  CustomScan(Array[String])
} derive(@debug.Debug)

pub struct ScanResult {
  threats : Array[Threat]
  mut total_files : Int
  mut scanned_files : Int
  mut skipped_whitelist : Int
  errors : Int
  elapsed_ms : Int
} derive(@debug.Debug)

pub enum CleanOp {
  KillProcess(Int)
  DeleteRunKey(String, String)
  StopDeleteService(String)
  DeleteScheduledTask(String)
  MoveFileToQuarantine(String, String)
  FixHomepage(String)
} derive(@debug.Debug)

pub enum CleanMode {
  Classify
  OneClick
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

pub struct WhitelistEntry {
  signer : String
  hashes_sha256 : Array[String]
  paths : Array[String]
  reason : String
} derive(@debug.Debug, @json.FromJson)

pub struct RogueRule {
  id : String
  name : String
  severity : String
  signatures : Array[String]
  path_patterns : Array[String]
  run_names : Array[String]
  file_names : Array[String]
  hashes_sha256 : Array[String]
  service_names : Array[String]
  homepage : String
  description : String
} derive(@debug.Debug, @json.FromJson)

pub struct RogueRulesDB {
  version : String
  rules : Array[RogueRule]
} derive(@debug.Debug, @json.FromJson)

pub struct WhitelistDB {
  version : String
  entries : Array[WhitelistEntry]
} derive(@debug.Debug, @json.FromJson)

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