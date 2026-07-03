pub fn deep_clean_threat(threat : @jk100/jk100/lib/core.Threat, scan_id : String) -> Array[CleanItem] {
  let items : Array[CleanItem] = []

  if threat.process_id > 0 {
    let ok = @platform.kill_process(threat.process_id)
    let item : CleanItem = {
      op: KillProcess(threat.process_id),
      success: ok,
      message: if ok { "进程已结束" } else { "进程结束失败" },
    }
    items.push(item)
  }

  if threat.run_key_name.length() > 0 {
    let ok = @platform.delete_run_key(threat.run_key_name)
    let item : CleanItem = {
      op: DeleteRunKey("Run", threat.run_key_name),
      success: ok,
      message: if ok { "自启项已删除" } else { "自启项删除失败" },
    }
    items.push(item)
  }

  if threat.service_name.length() > 0 {
    let stop_ok = @platform.stop_service(threat.service_name)
    let del_ok = @platform.delete_service(threat.service_name)
    let item : CleanItem = {
      op: StopDeleteService(threat.service_name),
      success: stop_ok && del_ok,
      message: if stop_ok && del_ok { "服务已停止并删除" } else { "服务操作失败" },
    }
    items.push(item)
  }

  if threat.file_path.length() > 0 {
    let file_name = threat.file_path.replace(old=":", new="").replace(old="\\", new="_")
    let quarantine_path = quarantine_base + "\\" + scan_id + "\\files\\" + file_name
    let file_in_use = @platform.is_file_in_use(threat.file_path)
    if file_in_use {
      let ok = @platform.schedule_delete_on_reboot(threat.file_path)
      let item : CleanItem = {
        op: MoveFileToQuarantine(threat.file_path, quarantine_path),
        success: ok,
        message: "文件被占用，已标记重启后删除",
      }
      items.push(item)
    } else {
      let ok = @platform.move_to_quarantine(threat.file_path, quarantine_path)
      let item : CleanItem = {
        op: MoveFileToQuarantine(threat.file_path, quarantine_path),
        success: ok,
        message: if ok { "文件已移至隔离区" } else { "文件移动失败" },
      }
      items.push(item)
    }
  }

  items
}