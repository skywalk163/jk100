struct SigDB {
  rules : RogueRulesDB
  whitelist : WhitelistDB
} derive(@debug.Debug)

pub async fn load(rules_path : String, whitelist_path : String) -> SigDB raise {
  let rules_data = @fs.read_file(rules_path)
  let whitelist_data = @fs.read_file(whitelist_path)

  let rules = load_rules(rules_data)
  let whitelist = load_whitelist(whitelist_data)

  { rules, whitelist }
}

fn load_rules(data : &@io.Data) -> RogueRulesDB raise {
  let content = data.text()
  let json = @json.parse(content)
  @json.from_json(json)
}

fn load_whitelist(data : &@io.Data) -> WhitelistDB raise {
  let content = data.text()
  let json = @json.parse(content)
  @json.from_json(json)
}

pub fn is_whitelisted(db : SigDB, file_path : String, signer : String, sha256 : String) -> Bool {
  for entry in db.whitelist.entries.iter() {
    if entry.signer.length() > 0 && signer.length() > 0 {
      if signer == entry.signer {
        return true
      }
    }
    for hash in entry.hashes_sha256.iter() {
      if hash == sha256 {
        return true
      }
    }
    for pattern in entry.paths.iter() {
      if path_match(pattern, file_path) {
        return true
      }
    }
  }
  false
}

pub fn match_rogue_rules(db : SigDB, file_path : String, signer : String, sha256 : String, file_name : String) -> Array[RogueRule] {
  let matched : Array[RogueRule] = Array::new()
  for rule in db.rules.rules.iter() {
    let hit = match_rule(rule, file_path, signer, sha256, file_name)
    if hit {
      matched.push(rule)
    }
  }
  matched
}

fn match_rule(rule : RogueRule, file_path : String, signer : String, sha256 : String, file_name : String) -> Bool {
  for sig in rule.signatures.iter() {
    if signer.length() > 0 && signer.contains(sig) {
      return true
    }
  }
  for pattern in rule.path_patterns.iter() {
    let expanded = expand_env(pattern)
    if path_match(expanded, file_path) {
      return true
    }
  }
  for name in rule.file_names.iter() {
    if file_name.to_lower() == name.to_lower() {
      return true
    }
  }
  for hash in rule.hashes_sha256.iter() {
    if hash == sha256 {
      return true
    }
  }
  false
}

pub fn match_run_name(db : SigDB, run_name : String) -> Option[RogueRule] {
  for rule in db.rules.rules.iter() {
    for name in rule.run_names.iter() {
      if run_name.to_lower() == name.to_lower() {
        return Some(rule)
      }
    }
  }
  None
}

pub fn match_service_name(db : SigDB, service_name : String) -> Option[RogueRule] {
  for rule in db.rules.rules.iter() {
    for name in rule.service_names.iter() {
      if service_name.to_lower() == name.to_lower() {
        return Some(rule)
      }
    }
  }
  None
}

fn path_match(pattern : String, path : String) -> Bool {
  let p_lower = pattern.to_lower()
  let s_lower = path.to_lower()
  if p_lower.has_suffix("*") {
    let prefix_len = p_lower.length() - 1
    let prefix = p_lower[0:prefix_len]
    s_lower.has_prefix(prefix)
  } else {
    s_lower == p_lower
  }
}

fn expand_env(path : String) -> String {
  let local_app_data = match @env.get_env_var("LOCALAPPDATA") {
    Some(v) => v
    None => "%LocalAppData%"
  }
  let program_data = match @env.get_env_var("PROGRAMDATA") {
    Some(v) => v
    None => "%ProgramData%"
  }
  let app_data = match @env.get_env_var("APPDATA") {
    Some(v) => v
    None => "%AppData%"
  }
  let system_root = match @env.get_env_var("SYSTEMROOT") {
    Some(v) => v
    None => "%SystemRoot%"
  }
  let program_files = match @env.get_env_var("PROGRAMFILES") {
    Some(v) => v
    None => "%ProgramFiles%"
  }
  path
    .replace(old="%LocalAppData%", new=local_app_data)
    .replace(old="%ProgramData%", new=program_data)
    .replace(old="%AppData%", new=app_data)
    .replace(old="%SystemRoot%", new=system_root)
    .replace(old="%ProgramFiles%", new=program_files)
}