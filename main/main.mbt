#borrow(_s)
extern "C" fn moonbit_println(_s : String) -> Unit = "moonbit_println"

fn print_banner() -> Unit {
  @platform.println("jk100 极快100 防恶意软件 v0.1.0")
  @platform.println("========================================")
  @platform.println("CLI 模式 (绕过 MoonBit native ICE, 核心逻辑用 C FFI)")
  @platform.println("")
}

fn print_help() -> Unit {
  @platform.println("用法:")
  @platform.println("  jk100.exe --cli --scan <路径>     扫描指定目录")
  @platform.println("  jk100.exe --cli --quick          快速扫描用户目录")
  @platform.println("  jk100.exe --cli --guard <路径>   实时守护监控")
  @platform.println("  jk100.exe --cli --help           显示帮助")
  @platform.println("")
  @platform.println("示例:")
  @platform.println("  jk100.exe --cli --scan \"C:\\Users\"")
  @platform.println("  jk100.exe --cli --scan \"C:\\Program Files\"")
  @platform.println("  jk100.exe --cli --guard \"C:\\Users\"")
  @platform.println("")
  @platform.println("守护模式:")
  @platform.println("  监控指定目录及其所有子目录的文件变化")
  @platform.println("  新文件创建时自动扫描,发现威胁立即告警")
  @platform.println("  按 Ctrl+C 停止守护")
}

fn run_cli() -> Unit {
  print_banner()

  let argc = @platform.get_arg_count()
  if argc < 2 {
    print_help()
    return
  }

  let arg1 = @platform.get_arg(1)
  if not(arg1 == "--cli") {
    @platform.println("[错误] 第一个参数必须是 --cli")
    @platform.println("")
    print_help()
    return
  }

  if argc < 3 {
    @platform.println("[错误] 缺少子命令")
    @platform.println("")
    print_help()
    return
  }

  let cmd = @platform.get_arg(2)
  if cmd == "--help" {
    print_help()
  } else if cmd == "--scan" {
    if argc < 4 {
      @platform.println("[错误] --scan 需要指定路径")
      @platform.println("")
      print_help()
      return
    }
    let target = @platform.get_arg(3)
    let threats = @platform.run_scan(target)
    if threats > 0 {
      @platform.println("[结论] 发现 " + @platform.int_to_string(threats) + " 个威胁,建议清理")
    } else {
      @platform.println("[结论] 未发现威胁")
    }
  } else if cmd == "--quick" {
    @platform.println("快速扫描模式: 扫描用户目录")
    @platform.println("")
    let threats = @platform.run_scan("C:\\Users")
    if threats > 0 {
      @platform.println("[结论] 发现 " + @platform.int_to_string(threats) + " 个威胁,建议清理")
    } else {
      @platform.println("[结论] 未发现威胁")
    }
  } else if cmd == "--guard" {
    if argc < 4 {
      @platform.println("[错误] --guard 需要指定监控路径")
      @platform.println("")
      print_help()
      return
    }
    let target = @platform.get_arg(3)
    let threats = @platform.start_guard(target)
    if threats < 0 {
      @platform.println("[错误] 守护模式启动失败")
    } else if threats > 0 {
      @platform.println("[结论] 守护期间发现 " + @platform.int_to_string(threats) + " 个威胁")
    } else {
      @platform.println("[结论] 守护期间未发现威胁")
    }
  } else {
    @platform.println("[错误] 未知子命令: " + cmd)
    @platform.println("")
    print_help()
  }
}

fn main {
  run_cli()
}
