struct ClamAVResult {
  infected : Bool
  virus_name : String
  file_path : String
} derive(@debug.Debug)

struct ClamAVConfig {
  host : String
  port : Int
  available : Bool
} derive(@debug.Debug)

pub fn default_config() -> ClamAVConfig {
  { host: "127.0.0.1", port: 3310, available: false }
}

pub fn check_available(config : ClamAVConfig) -> ClamAVConfig {
  { host: config.host, port: config.port, available: false }
}

pub fn scan_file(config : ClamAVConfig, file_path : String) -> ClamAVResult {
  if !config.available {
    return { infected: false, virus_name: "", file_path }
  }
  { infected: false, virus_name: "", file_path }
}

pub fn start_clamd(_clamd_path : String) -> Bool {
  false
}

pub fn stop_clamd() -> Unit {
  ignore(scan_command("SHUTDOWN"))
}

fn scan_command(_cmd : String) -> String {
  ""
}