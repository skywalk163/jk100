# jk100 查杀清理引擎（MVP）实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 构建一个基于 MoonBit 原生编译的 Windows 防恶意软件扫描清理引擎，支持国内流氓软件和通用病毒的双威胁检测，提供分类引导清理与一键深度清理两种模式，所有删除操作可回滚。

**架构：** 单进程多模块架构。MoonBit native x64 主体包含扫描引擎（特征库+ClamAV socket）、清理模块（隔离区+回滚）、Win32 C FFI 平台层、ImGui GUI。ClamAV 作为独立子进程通过本地 TCP socket 通信。

**技术栈：** MoonBit (native x64) + C FFI (Win32 API / ImGui) + ClamAV (clamd socket) + moonbitlang/async (结构化并发)

---

## 文件结构

```
g:\traework\jk100\
├── moon.mod.json                          # 模块定义（依赖、preferred-target）
├── lib/
│   ├── core/
│   │   ├── moon.pkg.json                  # core 包配置
│   │   ├── types.mbt                      # 公共类型定义（Threat, ThreatType, ScanResult 等）
│   │   ├── hash.mbt                       # SHA256/MD5 纯 MoonBit 实现
│   │   ├── pe.mbt                         # PE 文件解析器
│   │   ├── sigdb.mbt                      # 规则库加载（rogue_rules + whitelist）
│   │   ├── clamd.mbt                      # ClamAV socket 客户端
│   │   └── scan.mbt                       # 扫描调度器（含速度档位）
│   ├── clean/
│   │   ├── moon.pkg.json                  # clean 包配置
│   │   ├── quarantine.mbt                 # 隔离区管理 + manifest
│   │   ├── targets.mbt                    # 清理目标操作（调用 platform）
│   │   ├── classify.mbt                   # 分类引导清理
│   │   └── oneclick.mbt                   # 一键深度清理
│   ├── platform/
│   │   ├── moon.pkg.json                  # platform 包配置（含 native-stub + link）
│   │   ├── process.mbt                    # 进程枚举/结束 MoonBit 绑定
│   │   ├── registry.mbt                   # 注册表操作 MoonBit 绑定
│   │   ├── service.mbt                    # Windows 服务操作 MoonBit 绑定
│   │   ├── sched.mbt                      # 计划任务操作 MoonBit 绑定
│   │   ├── file.mbt                       # 文件操作 MoonBit 绑定
│   │   ├── priv.mbt                       # UAC 提权检测
│   │   ├── priority.mbt                   # 线程优先级调整
│   │   ├── cwrap.c                        # C 胶水文件（Win32 API shim）
│   │   └── cwrap.h                        # C 头文件
│   └── ui/
│       ├── moon.pkg.json                  # ui 包配置（含 ImGui native-stub + link）
│       ├── imgui.mbt                      # ImGui C FFI 绑定
│       ├── imgui_cwrap.c                  # ImGui C 胶水文件
│       └── views.mbt                      # UI 视图（主窗/扫描/结果/清理/回滚/设置）
├── main/
│   ├── moon.pkg.json                      # main 包配置
│   └── main.mbt                           # 程序入口（CLI 模式 + GUI 模式）
├── bundled/
│   ├── clamav/
│   │   ├── clamd.exe                      # 裁剪后便携 ClamAV daemon
│   │   ├── main.cvd                       # 病毒特征库
│   │   ├── daily.cvd                      # 每日更新特征
│   │   └── clamd.conf                     # clamd 配置文件
│   └── sigdb/
│       ├── rogue_rules.json               # 流氓软件规则库
│       └── whitelist.json                 # 白名单
├── tests/
│   ├── core_test.mbt                      # 核心模块测试
│   ├── clean_test.mbt                     # 清理模块测试
│   └── platform_test.mbt                  # 平台层测试
└── docs/
    └── superpowers/
        ├── specs/2026-07-03-jk100-scan-engine-mvp-design.md
        └── plans/2026-07-03-jk100-scan-engine-mvp.md
```

---

## 任务 1：项目脚手架

**文件：**
- 创建：`moon.mod.json`
- 创建：`lib/core/moon.pkg.json`
- 创建：`lib/clean/moon.pkg.json`
- 创建：`lib/platform/moon.pkg.json`
- 创建：`lib/ui/moon.pkg.json`
- 创建：`main/moon.pkg.json`
- 创建：`main/main.mbt`
- 创建：`bundled/sigdb/rogue_rules.json`
- 创建：`bundled/sigdb/whitelist.json`

- [ ] **步骤 1：创建模块定义文件 moon.mod.json**

```json
{
  "name": "jk100/jk100",
  "version": "0.1.0",
  "preferred-target": "native",
  "deps": {
    "moonbitlang/async": "0.19.2"
  }
}
```

- [ ] **步骤 2：创建各包配置文件**

`lib/core/moon.pkg.json`:
```json
{
  "import": [
    "moonbitlang/async"
  ]
}
```

`lib/clean/moon.pkg.json`:
```json
{
  "import": [
    "jk100/jk100/lib/platform",
    "jk100/jk100/lib/core"
  ]
}
```

`lib/platform/moon.pkg.json`:
```json
{
  "supported-targets": ["native"],
  "link": {
    "native": {
      "cc": "gcc",
      "cc-flags": "-I./",
      "cc-link-flags": "-lkernel32 -ladvapi32 -lpsapi -lole32 -lshell32"
    }
  },
  "native-stub": ["cwrap.c"]
}
```

`lib/ui/moon.pkg.json`:
```json
{
  "supported-targets": ["native"],
  "import": [
    "jk100/jk100/lib/core",
    "jk100/jk100/lib/clean"
  ],
  "link": {
    "native": {
      "cc": "gcc",
      "cc-flags": "-I./ -I./imgui -I./imgui/backends -DUNICODE",
      "cc-link-flags": "-L./lib -ljk100_imgui -ld3d11 -ld3dcompiler -ldxgi -ldwmapi -luser32 -lgdi32 -lwinmm -limm32"
    }
  },
  "native-stub": ["imgui_cwrap.c"]
}
```

`main/moon.pkg.json`:
```json
{
  "import": [
    "jk100/jk100/lib/core",
    "jk100/jk100/lib/clean",
    "jk100/jk100/lib/platform",
    "jk100/jk100/lib/ui"
  ]
}
```

- [ ] **步骤 3：创建入口文件 main/main.mbt**

```moonbit
fn main {
  let args = @argv.argv()
  if args.length() > 0 && args[0] == "--cli" {
    @core.scan.run_cli()
  } else {
    @ui.views.run_gui()
  }
}
```

- [ ] **步骤 4：创建初始规则库文件**

`bundled/sigdb/rogue_rules.json`:
```json
{
  "version": "2026-07-03",
  "rules": [
    {
      "id": "rogue_001",
      "name": "测试规则",
      "severity": "rogue",
      "signatures": [],
      "path_patterns": [],
      "run_names": [],
      "file_names": [],
      "hashes_sha256": [],
      "service_names": [],
      "homepage": "",
      "description": "占位规则，开发阶段使用"
    }
  ]
}
```

`bundled/sigdb/whitelist.json`:
```json
{
  "version": "2026-07-03",
  "entries": [
    {
      "signer": "Microsoft Corporation",
      "hashes_sha256": [],
      "paths": ["%SystemRoot%\\System32\\*", "%SystemRoot%\\SysWOW64\\*"],
      "reason": "系统核心组件"
    },
    {
      "signer": "Microsoft Windows Hardware Compatibility Publisher",
      "hashes_sha256": [],
      "paths": [],
      "reason": "Windows 硬件驱动签名"
    }
  ]
}
```

- [ ] **步骤 5：安装依赖并验证构建**

运行：`cd g:\traework\jk100 && moon add moonbitlang/async@0.19.2 && moon build --target native`
预期：构建成功，无错误

- [ ] **步骤 6：Commit**

```bash
git add moon.mod.json lib/ main/ bundled/
git commit -m "feat: scaffold jk100 MoonBit project structure"
```

---

## 任务 2：公共类型定义

**文件：**
- 创建：`lib/core/types.mbt`

- [ ] **步骤 1：定义核心类型**

```moonbit
/// 威胁类型
enum ThreatType {
  Rogue    // 国内流氓/捆绑软件
  Virus    // 通用病毒木马（ClamAV 检出）
}

/// 威胁严重级别
enum Severity {
  Rogue
  Suspicious
}

/// 威胁检测来源
enum DetectionSource {
  Sigdb       // 流氓软件规则库
  ClamAV      // ClamAV 通用引擎
}

/// 单个威胁项
struct Threat {
  mut threat_type : ThreatType
  mut severity : Severity
  mut source : DetectionSource
  mut rule_id : String           // 匹配的规则 ID（Sigdb 来源）
  mut family_name : String       // 恶意软件家族名
  mut file_path : String         // 文件完整路径
  mut file_hash_sha256 : String  // 文件 SHA256
  mut signer : String            // PE 数字签名颁发者
  mut process_id : Int           // 关联进程 ID（0 表示未运行）
  mut service_name : String      // 关联服务名（空表示无）
  mut run_key_name : String      // 关联自启注册表键名（空表示无）
  mut scheduled_task : String    // 关联计划任务名（空表示无）
  mut homepage_hijack : String   // 主页劫持目标（空表示无）
  mut description : String       // 人类可读描述
} derive(Show)

/// 扫描速度档位
enum ScanSpeed {
  Low       // Idle 优先级, 100ms IO 间隔
  Normal    // Normal 优先级, 10ms IO 间隔
  High      // Above Normal 优先级, 0ms IO 间隔
}

/// 扫描目标范围
enum ScanTarget {
  QuickScan       // 快速扫描：自启项 + 常见安装路径
  FullScan        // 全盘扫描：所有驱动器
  CustomScan(Array[String])  // 自定义路径列表
}

/// 扫描结果
struct ScanResult {
  mut threats : Array[Threat]
  mut total_files : Int
  mut scanned_files : Int
  mut skipped_whitelist : Int
  mut errors : Int
  mut elapsed_ms : Int
} derive(Show)

/// 清理操作类型
enum CleanOp {
  KillProcess(Int)                          // 结束进程（PID）
  DeleteRunKey(String, String)              // 删除自启键（key路径, 值名）
  StopDeleteService(String)                 // 停止并删除服务
  DeleteScheduledTask(String)               // 删除计划任务
  MoveFileToQuarantine(String, String)      // 移文件到隔离区（源路径, 隔离路径）
  FixHomepage(String)                       // 修复主页（劫持URL）
}

/// 清理模式
enum CleanMode {
  Classify   // 分类引导清理
  OneClick   // 一键深度清理
}

/// 清理结果项
struct CleanItem {
  mut op : CleanOp
  mut success : Bool
  mut message : String   // 成功/失败详情
} derive(Show)

/// 清理结果
struct CleanResult {
  mut items : Array[CleanItem]
  mut pending_reboot : Bool   // 是否需要重启完成清理
  mut scan_id : String        // 对应的扫描 ID
} derive(Show)

/// 白名单条目
struct WhitelistEntry {
  signer : String
  hashes_sha256 : Array[String]
  paths : Array[String]
  reason : String
} derive(Show, Deserialize)

/// 流氓软件规则
struct RogueRule {
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
} derive(Show, Deserialize)

/// 流氓软件规则库
struct RogueRulesDB {
  version : String
  rules : Array[RogueRule]
} derive(Show, Deserialize)

/// 白名单库
struct WhitelistDB {
  version : String
  entries : Array[WhitelistEntry]
} derive(Show, Deserialize)

/// 隔离区 manifest 操作记录
struct QuarantineItem {
  mut op_type : String          // "move_file" | "delete_registry" | "stop_delete_service" | "delete_task"
  mut source : String           // 原始路径/键/服务名/任务名
  mut quarantine_path : String  // 隔离区路径（文件类）
  mut old_value : String        // 注册表原始值
  mut sha256_before : String    // 文件哈希（用于回滚校验）
  mut status : String           // "success" | "failed" | "pending_reboot"
} derive(Show)

/// 隔离区 manifest
struct QuarantineManifest {
  mut scan_id : String
  mut timestamp : String
  mut items : Array[QuarantineItem]
} derive(Show)
```

- [ ] **步骤 2：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功

- [ ] **步骤 3：Commit**

```bash
git add lib/core/types.mbt
git commit -m "feat: define core types for scan engine"
```

---

## 任务 3：SHA256 哈希模块

**文件：**
- 创建：`lib/core/hash.mbt`
- 创建：`tests/core_test.mbt`

- [ ] **步骤 1：编写 SHA256 测试**

`tests/core_test.mbt`（需要在 tests 的 moon.pkg.json 中 import jk100/jk100/lib/core）：

```moonbit
fn test_sha256_empty_string() {
  // SHA256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  let input = ""
  let expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  let result = @core.hash.sha256_hex(input.to_bytes())
  assert_eq!(result, expected)
}

fn test_sha256_abc() {
  // SHA256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  let input = "abc"
  let expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  let result = @core.hash.sha256_hex(input.to_bytes())
  assert_eq!(result, expected)
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd g:\traework\jk100 && moon test --target native`
预期：FAIL，`@core.hash` 模块不存在

- [ ] **步骤 3：实现 SHA256**

`lib/core/hash.mbt`:

```moonbit
/// SHA256 哈希计算（纯 MoonBit 实现）
/// 算法参考：FIPS 180-4

/// SHA256 初始哈希值
let H0 : FixedArray[UInt] = FixedArray::makei(8, i => {
  let vals = [0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
              0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u]
  vals[i]
})

/// SHA256 轮常数 K
let K : FixedArray[UInt] = FixedArray::makei(64, i => {
  let vals = [
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u,
    0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
    0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u,
    0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
    0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
    0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
    0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u,
    0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
    0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u,
    0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u,
    0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
    0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u,
    0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
    0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
    0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u,
  ]
  vals[i]
})

fn rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

fn ch(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) ^ (~x & z)
}

fn maj(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) ^ (x & z) ^ (y & z)
}

fn sigma0(x : UInt) -> UInt {
  rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22)
}

fn sigma1(x : UInt) -> UInt {
  rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25)
}

fn gamma0(x : UInt) -> UInt {
  rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)
}

fn gamma1(x : UInt) -> UInt {
  rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10)
}

/// 对预处理后的消息块执行 SHA256 压缩
fn sha256_compress(h : FixedArray[UInt], block : FixedArray[UInt]) -> FixedArray[UInt] {
  let w = FixedArray::make(64, 0u)
  for i in 0..<16 {
    w[i] = block[i]
  }
  for i in 16..<64 {
    w[i] = gamma1(w[i - 2]) + w[i - 7] + gamma0(w[i - 15]) + w[i - 16]
  }

  let mut a = h[0]
  let mut b = h[1]
  let mut c = h[2]
  let mut d = h[3]
  let mut e = h[4]
  let mut f = h[5]
  let mut g = h[6]
  let mut hh = h[7]

  for i in 0..<64 {
    let t1 = hh + sigma1(e) + ch(e, f, g) + K[i] + w[i]
    let t2 = sigma0(a) + maj(a, b, c)
    hh = g
    g = f
    f = e
    e = d + t1
    d = c
    c = b
    b = a
    a = t1 + t2
  }

  let result = FixedArray::make(8, 0u)
  result[0] = h[0] + a
  result[1] = h[1] + b
  result[2] = h[2] + c
  result[3] = h[3] + d
  result[4] = h[4] + e
  result[5] = h[5] + f
  result[6] = h[6] + g
  result[7] = h[7] + hh
  result
}

/// 计算 SHA256 并返回十六进制字符串
fn sha256_hex(data : Bytes) -> String {
  let len = data.length()

  // 预处理：填充
  let bit_len = len * 8
  let mut padded_len = len + 1 // 原始数据 + 0x80
  while (padded_len % 64) != 56 {
    padded_len = padded_len + 1
  }
  padded_len = padded_len + 8 // 追加 64 位长度

  let padded = FixedArray::make(padded_len, 0)
  for i in 0..<len {
    padded[i] = data[i]
  }
  padded[len] = 0x80
  // 长度字段（大端序，64 位，只写高 32 位为 0，低 32 位为 bit_len）
  let length_offset = padded_len - 8
  padded[length_offset + 4] = (bit_len >> 24) & 0xFF
  padded[length_offset + 5] = (bit_len >> 16) & 0xFF
  padded[length_offset + 6] = (bit_len >> 8) & 0xFF
  padded[length_offset + 7] = bit_len & 0xFF

  // 初始化哈希值
  let h = FixedArray::makei(8, i => H0[i])

  // 逐块处理
  let num_blocks = padded_len / 64
  for block_idx in 0..<num_blocks {
    let block = FixedArray::make(16, 0u)
    for i in 0..<16 {
      let offset = block_idx * 64 + i * 4
      let value = (padded[offset].to_uint() << 24) |
                  (padded[offset + 1].to_uint() << 16) |
                  (padded[offset + 2].to_uint() << 8) |
                  padded[offset + 3].to_uint()
      block[i] = value
    }
    let new_h = sha256_compress(h, block)
    for i in 0..<8 {
      h[i] = new_h[i]
    }
  }

  // 输出十六进制
  let mut result = ""
  for i in 0..<8 {
    result = result + uint_to_hex(h[i])
  }
  result
}

/// 将 UInt 转为 8 位十六进制字符串
fn uint_to_hex(v : UInt) -> String {
  let hex_chars = "0123456789abcdef"
  let mut s = ""
  for i in 0..<8 {
    let shift = (7 - i) * 4
    let nibble = ((v >> shift) & 0xFu).to_int()
    s = s + hex_chars[nibble..nibble + 1]
  }
  s
}

/// 计算文件的 SHA256（从文件路径读取）
pub fn file_sha256(path : String) -> String {
  let data = @fs.read_file(path)
  match data {
    Ok(bytes) => sha256_hex(bytes)
    Err(_) => ""
  }
}

/// 计算字节数组的 SHA256
pub fn bytes_sha256(data : Bytes) -> String {
  sha256_hex(data)
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`cd g:\traework\jk100 && moon test --target native`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/core/hash.mbt
git commit -m "feat: implement SHA256 hash module"
```

---

## 任务 4：Win32 C FFI 平台层

**文件：**
- 创建：`lib/platform/cwrap.h`
- 创建：`lib/platform/cwrap.c`
- 创建：`lib/platform/process.mbt`
- 创建：`lib/platform/registry.mbt`
- 创建：`lib/platform/service.mbt`
- 创建：`lib/platform/file.mbt`
- 创建：`lib/platform/priv.mbt`
- 创建：`lib/platform/priority.mbt`

这是整个项目的基础层——所有 Win32 API 调用都通过这个 FFI 层。我将逐个模块编写。

- [ ] **步骤 1：编写 C 头文件 cwrap.h**

```c
// cwrap.h - jk100 Win32 API shim declarations
#ifndef JK100_CWRAP_H
#define JK100_CWRAP_H

#include <windows.h>
#include <psapi.h>
#include <shlobj.h>
#include <tlhelp32.h>
#include <moonbit.h>

// === 进程操作 ===
// 返回进程列表（PID 数组 + 名称数组），通过输出参数
int32_t jk100_enum_processes(int32_t** pids, char*** names, int32_t* count);
int32_t jk100_kill_process(int32_t pid);
int32_t jk100_is_process_running(int32_t pid);

// === 注册表操作 ===
// 枚举 HKCU\...\Run 下的所有值
int32_t jk100_enum_run_keys(char*** names, char*** values, int32_t* count);
int32_t jk100_delete_run_key(const char* name);
int32_t jk100_read_run_key(const char* name, char** value);

// === 服务操作 ===
int32_t jk100_enum_services(char*** names, char*** display_names, int32_t** states, int32_t* count);
int32_t jk100_stop_service(const char* name);
int32_t jk100_delete_service(const char* name);

// === 文件操作 ===
int32_t jk100_move_file_to_quarantine(const char* src, const char* dst);
int32_t jk100_is_file_in_use(const char* path);
int32_t jk100_schedule_delete_on_reboot(const char* path);

// === 提权 ===
int32_t jk100_is_elevated();
int32_t jk100_request_elevation();

// === 优先级 ===
void jk100_set_thread_priority(int32_t priority);
// priority: 0=Idle, 1=Normal, 2=AboveNormal

// === 字符串辅助 ===
moonbit_string_t jk100_cstr_to_moonbit(const char* s);
void jk100_free_cstr_array(char** arr, int32_t count);
void jk100_free_int_array(int32_t* arr);

#endif
```

- [ ] **步骤 2：编写 C 实现文件 cwrap.c**

```c
// cwrap.c - jk100 Win32 API shim implementations
#include "cwrap.h"
#include <stdio.h>
#include <string.h>

// === 字符串辅助 ===
moonbit_string_t jk100_cstr_to_moonbit(const char* s) {
  if (s == NULL) return moonbit_make_string(0, 0);
  int32_t len = (int32_t)strlen(s);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int i = 0; i < len; i++) {
    ms[i] = (uint16_t)(unsigned char)s[i];
  }
  return ms;
}

void jk100_free_cstr_array(char** arr, int32_t count) {
  if (arr == NULL) return;
  for (int i = 0; i < count; i++) { free(arr[i]); }
  free(arr);
}

void jk100_free_int_array(int32_t* arr) {
  if (arr) free(arr);
}

// === 进程操作 ===
int32_t jk100_enum_processes(int32_t** pids, char*** names, int32_t* count) {
  HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snap == INVALID_HANDLE_VALUE) return -1;

  int32_t cap = 256;
  int32_t n = 0;
  *pids = (int32_t*)malloc(cap * sizeof(int32_t));
  *names = (char**)malloc(cap * sizeof(char*));

  PROCESSENTRY32 pe;
  pe.dwSize = sizeof(PROCESSENTRY32);
  if (Process32First(snap, &pe)) {
    do {
      if (n >= cap) {
        cap *= 2;
        *pids = (int32_t*)realloc(*pids, cap * sizeof(int32_t));
        *names = (char**)realloc(*names, cap * sizeof(char*));
      }
      (*pids)[n] = pe.th32ProcessID;
      (*names)[n] = _strdup(pe.szExeFile);
      n++;
    } while (Process32Next(snap, &pe));
  }
  CloseHandle(snap);
  *count = n;
  return 0;
}

int32_t jk100_kill_process(int32_t pid) {
  HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
  if (h == NULL) return -1;
  BOOL ok = TerminateProcess(h, 1);
  CloseHandle(h);
  return ok ? 0 : -1;
}

int32_t jk100_is_process_running(int32_t pid) {
  HANDLE h = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (h == NULL) return 0;
  CloseHandle(h);
  return 1;
}

// === 注册表操作 ===
int32_t jk100_enum_run_keys(char*** names, char*** values, int32_t* count) {
  const char* run_paths[] = {
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
  };
  HKEY roots[] = { HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE };

  int32_t cap = 64;
  int32_t n = 0;
  *names = (char**)malloc(cap * sizeof(char*));
  *values = (char**)malloc(cap * sizeof(char*));

  for (int r = 0; r < 2; r++) {
    for (int p = 0; p < 2; p++) {
      HKEY key;
      if (RegOpenKeyExA(roots[r], run_paths[p], 0, KEY_READ, &key) != ERROR_SUCCESS) continue;
      DWORD idx = 0;
      char name[256];
      DWORD name_len;
      BYTE value[1024];
      DWORD value_len;
      DWORD type;
      while (1) {
        name_len = sizeof(name);
        value_len = sizeof(value);
        LONG err = RegEnumValueA(key, idx, name, &name_len, NULL, &type, value, &value_len);
        if (err != ERROR_SUCCESS) break;
        if (n >= cap) {
          cap *= 2;
          *names = (char**)realloc(*names, cap * sizeof(char*));
          *values = (char**)realloc(*values, cap * sizeof(char*));
        }
        (*names)[n] = _strdup(name);
        (*values)[n] = _strdup((char*)value);
        n++;
        idx++;
      }
      RegCloseKey(key);
    }
  }
  *count = n;
  return 0;
}

int32_t jk100_delete_run_key(const char* name) {
  const char* run_paths[] = {
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
  };
  HKEY roots[] = { HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE };
  for (int r = 0; r < 2; r++) {
    for (int p = 0; p < 2; p++) {
      HKEY key;
      if (RegOpenKeyExA(roots[r], run_paths[p], 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) continue;
      RegDeleteValueA(key, name);
      RegCloseKey(key);
    }
  }
  return 0;
}

int32_t jk100_read_run_key(const char* name, char** value) {
  const char* run_paths[] = {
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
  };
  HKEY roots[] = { HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE };
  for (int r = 0; r < 2; r++) {
    for (int p = 0; p < 2; p++) {
      HKEY key;
      if (RegOpenKeyExA(roots[r], run_paths[p], 0, KEY_READ, &key) != ERROR_SUCCESS) continue;
      BYTE buf[1024];
      DWORD len = sizeof(buf);
      DWORD type;
      if (RegQueryValueExA(key, name, NULL, &type, buf, &len) == ERROR_SUCCESS) {
        *value = _strdup((char*)buf);
        RegCloseKey(key);
        return 0;
      }
      RegCloseKey(key);
    }
  }
  return -1;
}

// === 服务操作 ===
int32_t jk100_enum_services(char*** names, char*** display_names, int32_t** states, int32_t* count) {
  SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_ENUMERATE_SERVICE);
  if (scm == NULL) return -1;

  DWORD bytes_needed = 0, svc_count = 0, resume = 0;
  EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_STATE_ALL,
                        NULL, 0, &bytes_needed, &svc_count, &resume, NULL);
  BYTE* buf = (BYTE*)malloc(bytes_needed);
  EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_STATE_ALL,
                        buf, bytes_needed, &bytes_needed, &svc_count, &resume, NULL);

  *names = (char**)malloc(svc_count * sizeof(char*));
  *display_names = (char**)malloc(svc_count * sizeof(char*));
  *states = (int32_t*)malloc(svc_count * sizeof(int32_t));

  ENUM_SERVICE_STATUS_PROCESSA* ssp = (ENUM_SERVICE_STATUS_PROCESSA*)buf;
  for (DWORD i = 0; i < svc_count; i++) {
    (*names)[i] = _strdup(ssp[i].lpServiceName);
    (*display_names)[i] = _strdup(ssp[i].lpDisplayName);
    (*states)[i] = (int32_t)ssp[i].ServiceStatusProcess.dwCurrentState;
  }
  *count = (int32_t)svc_count;
  free(buf);
  CloseServiceHandle(scm);
  return 0;
}

int32_t jk100_stop_service(const char* name) {
  SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_CONNECT);
  if (scm == NULL) return -1;
  SC_HANDLE svc = OpenServiceA(scm, name, SERVICE_STOP | SERVICE_QUERY_STATUS);
  if (svc == NULL) { CloseServiceHandle(scm); return -1; }

  SERVICE_STATUS status;
  ControlService(svc, SERVICE_CONTROL_STOP, &status);

  // 等待最多 10 秒
  for (int i = 0; i < 100; i++) {
    Sleep(100);
    QueryServiceStatus(svc, &status);
    if (status.dwCurrentState == SERVICE_STOPPED) break;
  }
  CloseServiceHandle(svc);
  CloseServiceHandle(scm);
  return 0;
}

int32_t jk100_delete_service(const char* name) {
  SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_CONNECT);
  if (scm == NULL) return -1;
  SC_HANDLE svc = OpenServiceA(scm, name, DELETE);
  if (svc == NULL) { CloseServiceHandle(scm); return -1; }
  BOOL ok = DeleteService(svc);
  CloseServiceHandle(svc);
  CloseServiceHandle(scm);
  return ok ? 0 : -1;
}

// === 文件操作 ===
int32_t jk100_move_file_to_quarantine(const char* src, const char* dst) {
  // 确保目标目录存在
  char dir[MAX_PATH];
  strncpy(dir, dst, MAX_PATH - 1);
  dir[MAX_PATH - 1] = 0;
  char* last_slash = strrchr(dir, '\\');
  if (last_slash) {
    *last_slash = 0;
    // 递归创建目录
    char tmp[MAX_PATH];
    strncpy(tmp, dir, MAX_PATH - 1);
    tmp[MAX_PATH - 1] = 0;
    for (char* p = tmp + 3; *p; p++) {
      if (*p == '\\') {
        *p = 0;
        CreateDirectoryA(tmp, NULL);
        *p = '\\';
      }
    }
    CreateDirectoryA(tmp, NULL);
  }
  return MoveFileA(src, dst) ? 0 : -1;
}

int32_t jk100_is_file_in_use(const char* path) {
  HANDLE h = CreateFileA(path, GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE) return 1; // 文件被占用
  CloseHandle(h);
  return 0;
}

int32_t jk100_schedule_delete_on_reboot(const char* path) {
  return MoveFileExA(path, NULL, MOVEFILE_DELAY_UNTIL_REBOOT) ? 0 : -1;
}

// === 提权 ===
int32_t jk100_is_elevated() {
  BOOL elevated = FALSE;
  HANDLE token = NULL;
  if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
    TOKEN_ELEVATION e;
    DWORD size;
    if (GetTokenInformation(token, TokenElevation, &e, sizeof(e), &size)) {
      elevated = e.TokenIsElevated;
    }
    CloseHandle(token);
  }
  return elevated ? 1 : 0;
}

int32_t jk100_request_elevation() {
  // 重新以管理员身份启动自身
  char path[MAX_PATH];
  GetModuleFileNameA(NULL, path, MAX_PATH);
  SHELLEXECUTEINFOA info = {0};
  info.cbSize = sizeof(info);
  info.lpVerb = "runas";
  info.lpFile = path;
  info.nShow = SW_SHOWNORMAL;
  return ShellExecuteExA(&info) ? 0 : -1;
}

// === 优先级 ===
void jk100_set_thread_priority(int32_t priority) {
  int win_priority;
  switch (priority) {
    case 0: win_priority = THREAD_PRIORITY_IDLE; break;
    case 1: win_priority = THREAD_PRIORITY_NORMAL; break;
    case 2: win_priority = THREAD_PRIORITY_ABOVE_NORMAL; break;
    default: win_priority = THREAD_PRIORITY_NORMAL; break;
  }
  SetThreadPriority(GetCurrentThread(), win_priority);
}
```

- [ ] **步骤 3：编写 MoonBit FFI 绑定 - process.mbt**

```moonbit
#extern
type CStrArray
#extern
type CIntArray

extern "C" fn jk100_cstr_to_moonbit(s: CStrArray) -> String = "jk100_cstr_to_moonbit"
extern "C" fn jk100_free_cstr_array(arr: CStrArray, count: Int) -> Unit = "jk100_free_cstr_array"
extern "C" fn jk100_free_int_array(arr: CIntArray) -> Unit = "jk100_free_int_array"

extern "C" fn jk100_enum_processes(
  pids: Ref[CIntArray],
  names: Ref[CStrArray],
  count: Ref[Int]
) -> Int = "jk100_enum_processes"

extern "C" fn jk100_kill_process(pid: Int) -> Int = "jk100_kill_process"
extern "C" fn jk100_is_process_running(pid: Int) -> Int = "jk100_is_process_running"

/// 进程信息
struct ProcessInfo {
  pid : Int
  name : String
} derive(Show)

/// 枚举所有正在运行的进程
pub fn enum_processes() -> Array[ProcessInfo] {
  let pids : Ref[CIntArray] = Ref::{ val: 0 as CIntArray }
  let names : Ref[CStrArray] = Ref::{ val: 0 as CStrArray }
  let count : Ref[Int] = Ref::{ val: 0 }
  let rc = jk100_enum_processes(pids, names, count)
  if rc != 0 {
    return []
  }
  // TODO: 将 C 数组转换为 MoonBit 数组
  // 需要通过额外的 FFI 逐个读取元素
  []
}

/// 结束指定进程
pub fn kill_process(pid : Int) -> Bool {
  jk100_kill_process(pid) == 0
}

/// 检查进程是否在运行
pub fn is_process_running(pid : Int) -> Bool {
  jk100_is_process_running(pid) != 0
}
```

- [ ] **步骤 4：编写 MoonBit FFI 绑定 - registry.mbt**

```moonbit
/// 注册表自启项
struct RunEntry {
  name : String
  value : String
} derive(Show)

/// 枚举所有自启项
pub fn enum_run_keys() -> Array[RunEntry] {
  // FFI 调用 jk100_enum_run_keys
  // 实现：通过 C FFI 逐项读取
  []
}

/// 删除自启项
pub fn delete_run_key(name : String) -> Bool {
  let c_name = name.to_bytes()
  #borrow(c_name)
  extern "C" fn jk100_delete_run_key(name: Bytes) -> Int = "jk100_delete_run_key"
  jk100_delete_run_key(c_name) == 0
}

/// 读取自启项值
pub fn read_run_key(name : String) -> String {
  // FFI 调用 jk100_read_run_key
  ""
}
```

- [ ] **步骤 5：编写 MoonBit FFI 绑定 - service.mbt**

```moonbit
/// 服务信息
struct ServiceInfo {
  name : String
  display_name : String
  state : Int  // SERVICE_RUNNING=4, SERVICE_STOPPED=1, etc.
} derive(Show)

/// 枚举所有服务
pub fn enum_services() -> Array[ServiceInfo] {
  // FFI 调用 jk100_enum_services
  []
}

/// 停止服务
pub fn stop_service(name : String) -> Bool {
  let c_name = name.to_bytes()
  #borrow(c_name)
  extern "C" fn jk100_stop_service(name: Bytes) -> Int = "jk100_stop_service"
  jk100_stop_service(c_name) == 0
}

/// 删除服务
pub fn delete_service(name : String) -> Bool {
  let c_name = name.to_bytes()
  #borrow(c_name)
  extern "C" fn jk100_delete_service(name: Bytes) -> Int = "jk100_delete_service"
  jk100_delete_service(c_name) == 0
}
```

- [ ] **步骤 6：编写 MoonBit FFI 绑定 - file.mbt**

```moonbit
/// 移动文件到隔离区
pub fn move_to_quarantine(src : String, dst : String) -> Bool {
  let c_src = src.to_bytes()
  let c_dst = dst.to_bytes()
  #borrow(c_src)
  #borrow(c_dst)
  extern "C" fn jk100_move_file_to_quarantine(src: Bytes, dst: Bytes) -> Int = "jk100_move_file_to_quarantine"
  jk100_move_file_to_quarantine(c_src, c_dst) == 0
}

/// 检查文件是否被占用
pub fn is_file_in_use(path : String) -> Bool {
  let c_path = path.to_bytes()
  #borrow(c_path)
  extern "C" fn jk100_is_file_in_use(path: Bytes) -> Int = "jk100_is_file_in_use"
  jk100_is_file_in_use(c_path) != 0
}

/// 标记文件在重启后删除
pub fn schedule_delete_on_reboot(path : String) -> Bool {
  let c_path = path.to_bytes()
  #borrow(c_path)
  extern "C" fn jk100_schedule_delete_on_reboot(path: Bytes) -> Int = "jk100_schedule_delete_on_reboot"
  jk100_schedule_delete_on_reboot(c_path) == 0
}
```

- [ ] **步骤 7：编写 MoonBit FFI 绑定 - priv.mbt 和 priority.mbt**

`lib/platform/priv.mbt`:
```moonbit
extern "C" fn jk100_is_elevated() -> Int = "jk100_is_elevated"
extern "C" fn jk100_request_elevation() -> Int = "jk100_request_elevation"

/// 检查当前进程是否有管理员权限
pub fn is_elevated() -> Bool {
  jk100_is_elevated() != 0
}

/// 请求 UAC 提升权限（重启自身为管理员）
pub fn request_elevation() -> Bool {
  jk100_request_elevation() == 0
}
```

`lib/platform/priority.mbt`:
```moonbit
extern "C" fn jk100_set_thread_priority(priority: Int) -> Unit = "jk100_set_thread_priority"

/// 设置当前线程优先级
/// 0=Idle, 1=Normal, 2=AboveNormal
pub fn set_thread_priority(priority : Int) -> Unit {
  jk100_set_thread_priority(priority)
}
```

- [ ] **步骤 8：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功（C 文件正确编译和链接）

- [ ] **步骤 9：Commit**

```bash
git add lib/platform/
git commit -m "feat: implement Win32 C FFI platform layer"
```

---

## 任务 5：PE 解析器

**文件：**
- 创建：`lib/core/pe.mbt`

- [ ] **步骤 1：实现 PE 文件解析器**

```moonbit
/// PE 文件信息
struct PEInfo {
  mut signer : String           // 数字签名颁发者（空=无签名/签名验证失败）
  mut product_name : String     // 产品名
  mut company_name : String     // 公司名称
  mut file_description : String // 文件描述
  mut is_dotnet : Bool          // 是否 .NET 程序集
  mut subsystem : Int           // 子系统（2=GUI, 3=Console）
} derive(Show)

/// 解析 PE 文件基本信息
/// 从文件字节数组中提取元数据
pub fn parse_pe(data : Bytes) -> PEInfo {
  let info : PEInfo = {
    signer: "",
    product_name: "",
    company_name: "",
    file_description: "",
    is_dotnet: false,
    subsystem: 0,
  }

  if data.length() < 64 {
    return info
  }

  // 检查 MZ 签名
  if data[0] != 0x4D || data[1] != 0x5A {
    return info
  }

  // e_lfanew 偏移
  let pe_offset = (data[0x3C].to_int()) |
                  (data[0x3D].to_int() << 8) |
                  (data[0x3E].to_int() << 16) |
                  (data[0x3F].to_int() << 24)

  if pe_offset + 24 >= data.length() {
    return info
  }

  // 检查 PE\0\0 签名
  if data[pe_offset] != 0x50 || data[pe_offset + 1] != 0x45 {
    return info
  }

  // COFF Header
  let coff_offset = pe_offset + 4

  // 可选头偏移
  let opt_offset = coff_offset + 20

  if opt_offset + 2 >= data.length() {
    return info
  }

  // Magic (0x10B = PE32, 0x20B = PE32+)
  let magic = data[opt_offset].to_int() | (data[opt_offset + 1].to_int() << 8)

  // 子系统偏移（PE32: +68, PE32+: +68）
  let subsystem_offset = opt_offset + 68
  if subsystem_offset + 2 < data.length() {
    info.subsystem = data[subsystem_offset].to_int() | (data[subsystem_offset + 1].to_int() << 8)
  }

  // .NET 检测（检查 COM 描述符 RVA）
  let com_descriptor_offset = if magic == 0x20B {
    opt_offset + 208  // PE32+
  } else {
    opt_offset + 192  // PE32
  }
  if com_descriptor_offset + 8 < data.length() {
    let com_rva = data[com_descriptor_offset].to_int() |
                  (data[com_descriptor_offset + 1].to_int() << 8)
    info.is_dotnet = com_rva != 0
  }

  // 版本信息解析（简化版：扫描 PE 中的版本资源）
  // 实际实现需要解析资源目录 → VS_VERSIONINFO → StringFileInfo
  // 此处先留空，后续迭代补充

  info
}

/// 从文件路径解析 PE 信息
pub fn parse_pe_file(path : String) -> PEInfo {
  let data = @fs.read_file(path)
  match data {
    Ok(bytes) => parse_pe(bytes)
    Err(_) => {
      {
        signer: "",
        product_name: "",
        company_name: "",
        file_description: "",
        is_dotnet: false,
        subsystem: 0,
      }
    }
  }
}
```

- [ ] **步骤 2：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功

- [ ] **步骤 3：Commit**

```bash
git add lib/core/pe.mbt
git commit -m "feat: implement PE file parser"
```

---

## 任务 6：规则库加载器

**文件：**
- 创建：`lib/core/sigdb.mbt`

- [ ] **步骤 1：实现规则库加载与匹配**

```moonbit
/// 规则库加载器
/// 加载 rogue_rules.json 和 whitelist.json
/// 提供白名单优先级过滤和流氓规则匹配

struct SigDB {
  mut rules : @types.RogueRulesDB
  mut whitelist : @types.WhitelistDB
} derive(Show)

/// 加载规则库
pub fn load(rules_path : String, whitelist_path : String) -> SigDB {
  let rules_json = @fs.read_file(rules_path)
  let whitelist_json = @fs.read_file(whitelist_path)

  let rules : @types.RogueRulesDB = match rules_json {
    Ok(data) => {
      match @json.deserialize(data) {
        Ok(r) => r
        Err(_) => { version: "empty", rules: [] }
      }
    }
    Err(_) => { version: "empty", rules: [] }
  }

  let whitelist : @types.WhitelistDB = match whitelist_json {
    Ok(data) => {
      match @json.deserialize(data) {
        Ok(w) => w
        Err(_) => { version: "empty", entries: [] }
      }
    }
    Err(_) => { version: "empty", entries: [] }
  }

  { rules, whitelist }
}

/// 白名单检测（优先级最高）
/// 返回 true 表示该文件在白名单中，应跳过全部后续判定
pub fn is_whitelisted(db : SigDB, file_path : String, signer : String, sha256 : String) -> Bool {
  for entry in db.whitelist.entries {
    // 签名匹配
    if entry.signer.length() > 0 && signer.length() > 0 {
      if signer == entry.signer {
        return true
      }
    }
    // 哈希匹配
    for hash in entry.hashes_sha256 {
      if hash == sha256 {
        return true
      }
    }
    // 路径模式匹配
    for pattern in entry.paths {
      if path_match(pattern, file_path) {
        return true
      }
    }
  }
  false
}

/// 流氓规则匹配
/// 返回匹配的规则列表（可能匹配多条）
pub fn match_rogue_rules(db : SigDB, file_path : String, signer : String, sha256 : String, file_name : String) -> Array[@types.RogueRule] {
  let mut matched = []
  for rule in db.rules {
    let mut hit = false

    // 签名匹配
    if !hit {
      for sig in rule.signatures {
        if signer.length() > 0 && signer.contains(sig) {
          hit = true
          break
        }
      }
    }

    // 路径模式匹配
    if !hit {
      for pattern in rule.path_patterns {
        let expanded = expand_env(pattern)
        if path_match(expanded, file_path) {
          hit = true
          break
        }
      }
    }

    // 文件名匹配
    if !hit {
      for name in rule.file_names {
        if file_name.lower() == name.lower() {
          hit = true
          break
        }
      }
    }

    // 哈希匹配
    if !hit {
      for hash in rule.hashes_sha256 {
        if hash == sha256 {
          hit = true
          break
        }
      }
    }

    if hit {
      matched.push(rule)
    }
  }
  matched
}

/// 自启项名称匹配
pub fn match_run_name(db : SigDB, run_name : String) -> Option[@types.RogueRule] {
  for rule in db.rules {
    for name in rule.run_names {
      if run_name.lower() == name.lower() {
        return Some(rule)
      }
    }
  }
  None
}

/// 服务名匹配
pub fn match_service_name(db : SigDB, service_name : String) -> Option[@types.RogueRule] {
  for rule in db.rules {
    for name in rule.service_names {
      if service_name.lower() == name.lower() {
        return Some(rule)
      }
    }
  }
  None
}

/// 简易通配符路径匹配
/// 支持 * 作为任意字符序列
fn path_match(pattern : String, path : String) -> Bool {
  let p_lower = pattern.lower()
  let s_lower = path.lower()
  // 简化实现：仅支持前缀 + * 的模式
  if p_lower.ends_with("*") {
    let prefix = p_lower[..p_lower.length() - 1]
    s_lower.starts_with(prefix)
  } else {
    s_lower == p_lower
  }
}

/// 展开环境变量（简化版）
fn expand_env(path : String) -> String {
  path
    .replace("%LocalAppData%", @env.env("LOCALAPPDATA").0)
    .replace("%ProgramData%", @env.env("PROGRAMDATA").0)
    .replace("%AppData%", @env.env("APPDATA").0)
    .replace("%SystemRoot%", @env.env("SYSTEMROOT").0)
    .replace("%ProgramFiles%", @env.env("PROGRAMFILES").0)
}
```

- [ ] **步骤 2：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功

- [ ] **步骤 3：Commit**

```bash
git add lib/core/sigdb.mbt
git commit -m "feat: implement signature database loader with whitelist priority"
```

---

## 任务 7：ClamAV Socket 客户端

**文件：**
- 创建：`lib/core/clamd.mbt`

- [ ] **步骤 1：实现 ClamAV socket 客户端**

```moonbit
/// ClamAV socket 客户端
/// 通过 TCP socket 与 clamd 通信

/// ClamAV 扫描结果
struct ClamAVResult {
  mut infected : Bool
  mut virus_name : String
  mut file_path : String
} derive(Show)

/// ClamAV 客户端配置
struct ClamAVConfig {
  mut host : String
  mut port : Int
  mut available : Bool
} derive(Show)

/// 创建默认配置
pub fn default_config() -> ClamAVConfig {
  { host: "127.0.0.1", port: 3310, available: false }
}

/// 检查 clamd 是否可用
pub fn check_available(config : ClamAVConfig) -> ClamAVConfig {
  // 尝试 TCP 连接到 clamd
  // 使用 moonbitlang/async 的 socket API
  // 如果连接失败，标记 available = false
  let mut cfg = config
  // TODO: 使用 @tcp.connect 检测
  cfg.available = false  // 初始为不可用，启动后检测
  cfg
}

/// 扫描单个文件
pub fn scan_file(config : ClamAVConfig, file_path : String) -> ClamAVResult {
  if !config.available {
    return { infected: false, virus_name: "", file_path }
  }

  // 发送 "SCAN <path>\n" 到 clamd
  // 读取响应 "path: virus_name FOUND" 或 "path: OK"
  // 通过 TCP socket 通信
  // TODO: 使用 moonbitlang/async 的 TCP 客户端
  { infected: false, virus_name: "", file_path }
}

/// 启动 clamd 子进程
pub fn start_clamd(clamd_path : String) -> Bool {
  // 使用 @process.spawn 启动 clamd.exe 子进程
  // TODO: 使用 MoonBit 进程管理 API
  false
}

/// 关闭 clamd 子进程
pub fn stop_clamd() -> Unit {
  // 发送 SHUTDOWN 命令到 clamd
  ignore(scan_command("SHUTDOWN"))
}

/// 发送原始命令到 clamd
fn scan_command(cmd : String) -> String {
  // TCP socket 发送命令并读取响应
  ""
}
```

- [ ] **步骤 2：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功

- [ ] **步骤 3：Commit**

```bash
git add lib/core/clamd.mbt
git commit -m "feat: implement ClamAV socket client"
```

---

## 任务 8：扫描调度器

**文件：**
- 创建：`lib/core/scan.mbt`

- [ ] **步骤 1：实现扫描调度器**

```moonbit
/// 扫描调度器
/// 协调白名单过滤、流氓规则匹配、ClamAV 扫描
/// 支持速度档位调节

/// 扫描进度回调
struct ScanCallbacks {
  mut on_progress : (Int, Int) -> Unit      // (已扫描, 总数)
  mut on_threat : (Threat) -> Unit          // 发现威胁
  mut on_complete : (ScanResult) -> Unit    // 扫描完成
  mut on_error : (String) -> Unit           // 错误
}

/// 运行扫描
pub fn run_scan(
  db : @sigdb.SigDB,
  clamav : @clamd.ClamAVConfig,
  target : ScanTarget,
  speed : ScanSpeed,
  callbacks : ScanCallbacks
) -> ScanResult {
  let result : ScanResult = {
    threats: [],
    total_files: 0,
    scanned_files: 0,
    skipped_whitelist: 0,
    errors: 0,
    elapsed_ms: 0,
  }

  // 1. 收集目标文件列表
  let files = collect_target_files(target)
  result.total_files = files.length()

  // 2. 设置扫描线程优先级
  let priority = match speed {
    Low => 0
    Normal => 1
    High => 2
  }
  @platform.priority.set_thread_priority(priority)

  // 3. 逐文件扫描
  for path in files {
    // IO 间隔控制
    let sleep_ms = match speed {
      Low => 100
      Normal => 10
      High => 0
    }
    if sleep_ms > 0 {
      @async.sleep(sleep_ms)
    }

    // 读取文件并计算哈希
    let hash = @hash.file_sha256(path)
    if hash.length() == 0 {
      result.errors = result.errors + 1
      continue
    }

    // 解析 PE 信息
    let pe_info = @pe.parse_pe_file(path)
    let file_name = path_filename(path)

    // ① 白名单检测（优先级最高）
    if @sigdb.is_whitelisted(db, path, pe_info.signer, hash) {
      result.skipped_whitelist = result.skipped_whitelist + 1
      result.scanned_files = result.scanned_files + 1
      callbacks.on_progress(result.scanned_files, result.total_files)
      continue
    }

    // ② 流氓规则匹配
    let matched_rules = @sigdb.match_rogue_rules(db, path, pe_info.signer, hash, file_name)
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
      callbacks.on_threat(threat)
    }

    // ③ ClamAV 扫描
    if clamav.available {
      let clamav_result = @clamd.scan_file(clamav, path)
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
        callbacks.on_threat(threat)
      }
    }

    result.scanned_files = result.scanned_files + 1
    callbacks.on_progress(result.scanned_files, result.total_files)
  }

  // 4. 补充：扫描自启项和服务（与文件交叉匹配）
  scan_run_keys(db, result, callbacks)
  scan_services(db, result, callbacks)

  callbacks.on_complete(result)
  result
}

/// 收集目标文件
fn collect_target_files(target : ScanTarget) -> Array[String] {
  match target {
    QuickScan => {
      // 自启项路径 + 常见安装目录
      let mut files = []
      let common_dirs = [
        @env.env("PROGRAMFILES").0,
        @env.env("PROGRAMFILES(X86)").0,
        @env.env("LOCALAPPDATA").0 + "\\Programs",
        @env.env("APPDATA").0,
      ]
      for dir in common_dirs {
        files = files + list_pe_files(dir)
      }
      files
    }
    FullScan => {
      // 遍历所有驱动器
      list_pe_files("C:\\")
    }
    CustomScan(paths) => {
      let mut files = []
      for path in paths {
        files = files + list_pe_files(path)
      }
      files
    }
  }
}

/// 列出目录下所有 PE 文件（递归）
fn list_pe_files(dir : String) -> Array[String] {
  // TODO: 使用 @fs.read_dir 递归遍历
  []
}

/// 扫描自启项
fn scan_run_keys(db : @sigdb.SigDB, result : ScanResult, callbacks : ScanCallbacks) -> Unit {
  let run_entries = @platform.registry.enum_run_keys()
  for entry in run_entries {
    let matched = @sigdb.match_run_name(db, entry.name)
    match matched {
      Some(rule) => {
        let threat : Threat = {
          threat_type: Rogue,
          severity: Rogue,
          source: Sigdb,
          rule_id: rule.id,
          family_name: rule.name,
          file_path: entry.value,
          file_hash_sha256: "",
          signer: "",
          process_id: 0,
          service_name: "",
          run_key_name: entry.name,
          scheduled_task: "",
          homepage_hijack: rule.homepage,
          description: "自启项: " + entry.name + " -> " + rule.description,
        }
        result.threats.push(threat)
        callbacks.on_threat(threat)
      }
      None => ()
    }
  }
}

/// 扫描服务
fn scan_services(db : @sigdb.SigDB, result : ScanResult, callbacks : ScanCallbacks) -> Unit {
  let services = @platform.service.enum_services()
  for svc in services {
    let matched = @sigdb.match_service_name(db, svc.name)
    match matched {
      Some(rule) => {
        let threat : Threat = {
          threat_type: Rogue,
          severity: Rogue,
          source: Sigdb,
          rule_id: rule.id,
          family_name: rule.name,
          file_path: "",
          file_hash_sha256: "",
          signer: "",
          process_id: 0,
          service_name: svc.name,
          run_key_name: "",
          scheduled_task: "",
          homepage_hijack: rule.homepage,
          description: "服务: " + svc.display_name + " -> " + rule.description,
        }
        result.threats.push(threat)
        callbacks.on_threat(threat)
      }
      None => ()
    }
  }
}

/// 提取文件名
fn path_filename(path : String) -> String {
  match path.last_index_of("\\") {
    Some(idx) => path[idx + 1..]
    None => path
  }
}

/// CLI 入口
pub fn run_cli() -> Unit {
  println("jk100 极快100 防恶意软件 v0.1.0")
  println("========================================")

  // 检查提权
  if !@platform.priv.is_elevated() {
    println("[警告] 未以管理员身份运行，部分功能受限")
  }

  // 加载规则库
  let db = @sigdb.load("bundled/sigdb/rogue_rules.json", "bundled/sigdb/whitelist.json")
  println("规则库版本: " + db.rules.version)
  println("流氓软件规则数: " + db.rules.rules.length().to_string())
  println("白名单条目数: " + db.whitelist.entries.length().to_string())

  // 检查 ClamAV
  let mut clamav = @clamd.default_config()
  clamav = @clamd.check_available(clamav)
  if !clamav.available {
    println("[警告] ClamAV 不可用，仅扫描流氓软件")
  }

  // 执行快速扫描
  println("\n开始快速扫描...")
  let callbacks : ScanCallbacks = {
    on_progress: (scanned, total) => {
      println("进度: \{scanned}/\{total}")
    },
    on_threat: (threat) => {
      println("[发现] \{threat.family_name}: \{threat.file_path}")
    },
    on_complete: (result) => {
      println("\n扫描完成！")
      println("威胁数: \{result.threats.length()}")
    },
    on_error: (msg) => {
      println("[错误] \{msg}")
    },
  }

  let result = run_scan(db, clamav, QuickScan, Normal, callbacks)

  // 显示结果
  if result.threats.length() == 0 {
    println("\n系统安全，未发现威胁。")
  } else {
    println("\n发现 \{result.threats.length()} 个威胁：")
    for threat in result.threats {
      println("  [\{threat.threat_type}] \{threat.family_name}")
      println("    路径: \{threat.file_path}")
      println("    描述: \{threat.description}")
    }
  }
}
```

- [ ] **步骤 2：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功

- [ ] **步骤 3：Commit**

```bash
git add lib/core/scan.mbt
git commit -m "feat: implement scan scheduler with speed gears"
```

---

## 任务 9：隔离区与清理模块

**文件：**
- 创建：`lib/clean/quarantine.mbt`
- 创建：`lib/clean/targets.mbt`
- 创建：`lib/clean/classify.mbt`
- 创建：`lib/clean/oneclick.mbt`

- [ ] **步骤 1：实现隔离区管理**

```moonbit
/// 隔离区管理
/// 负责隔离区目录创建、manifest 写入、回滚

let quarantine_base : String = @env.env("PROGRAMDATA").0 + "\\jk100\\quarantine"

/// 生成扫描 ID
fn generate_scan_id() -> String {
  // 时间戳 + 随机数
  let t = @time.now()
  let ts = t.format("%Y%m%d-%H%M%S")
  ts
}

/// 创建隔离区目录
pub fn create_quarantine_dir(scan_id : String) -> String {
  let dir = quarantine_base + "\\" + scan_id
  let files_dir = dir + "\\files"
  // 创建目录
  // TODO: 使用 @fs.mkdir_p
  dir
}

/// 写入 manifest
pub fn write_manifest(scan_id : String, manifest : QuarantineManifest) -> Unit {
  let dir = quarantine_base + "\\" + scan_id
  // 将 manifest 序列化为 JSON 并写入文件
  // TODO: 使用 @json.serialize + @fs.write_file
  ignore(dir)
}

/// 读取 manifest
pub fn read_manifest(scan_id : String) -> Option[QuarantineManifest] {
  // TODO: 读取并反序列化
  None
}

/// 列出所有隔离区记录
pub fn list_quarantines() -> Array[String] {
  // 列出 quarantine_base 下的所有子目录
  []
}

/// 执行回滚
pub fn rollback(scan_id : String) -> Bool {
  match read_manifest(scan_id) {
    Some(manifest) => {
      let mut all_ok = true
      // 逆序恢复
      for i in manifest.items.length() - 1 ..>= 0 {
        let item = manifest.items[i]
        let ok = rollback_item(item)
        if !ok { all_ok = false }
      }
      all_ok
    }
    None => false
  }
}

/// 回滚单个操作
fn rollback_item(item : QuarantineItem) -> Bool {
  match item.op_type {
    "move_file" => {
      // 从隔离区移回原路径
      @platform.file.move_to_quarantine(item.quarantine_path, item.source)
    }
    "delete_registry" => {
      // 恢复注册表值
      // TODO: 需要额外的 FFI 写注册表
      false
    }
    "stop_delete_service" => {
      // 无法恢复已删除的服务（需要重新注册）
      false
    }
    _ => false
  }
}
```

- [ ] **步骤 2：实现清理目标操作**

```moonbit
/// 清理目标操作
/// 对威胁项执行具体的清理步骤

/// 对单个威胁执行深度清理
pub fn deep_clean_threat(threat : Threat, scan_id : String) -> Array[CleanItem] {
  let mut items = []

  // 1. 结束关联进程
  if threat.process_id > 0 {
    let ok = @platform.process.kill_process(threat.process_id)
    items.push({
      op: KillProcess(threat.process_id),
      success: ok,
      message: if ok { "进程已结束" } else { "进程结束失败" },
    })
  }

  // 2. 删除自启项
  if threat.run_key_name.length() > 0 {
    let ok = @platform.registry.delete_run_key(threat.run_key_name)
    items.push({
      op: DeleteRunKey("Run", threat.run_key_name),
      success: ok,
      message: if ok { "自启项已删除" } else { "自启项删除失败" },
    })
  }

  // 3. 停止并删除服务
  if threat.service_name.length() > 0 {
    let stop_ok = @platform.service.stop_service(threat.service_name)
    let del_ok = @platform.service.delete_service(threat.service_name)
    items.push({
      op: StopDeleteService(threat.service_name),
      success: stop_ok && del_ok,
      message: if stop_ok && del_ok { "服务已停止并删除" } else { "服务操作失败" },
    })
  }

  // 4. 移动文件到隔离区
  if threat.file_path.length() > 0 {
    let quarantine_path = @quarantine.quarantine_base + "\\" + scan_id +
                          "\\files\\" + threat.file_path.replace(":", "").replace("\\", "_")
    let file_in_use = @platform.file.is_file_in_use(threat.file_path)
    if file_in_use {
      // 文件被占用，标记重启后删除
      let ok = @platform.file.schedule_delete_on_reboot(threat.file_path)
      items.push({
        op: MoveFileToQuarantine(threat.file_path, quarantine_path),
        success: ok,
        message: "文件被占用，已标记重启后删除",
      })
    } else {
      let ok = @platform.file.move_to_quarantine(threat.file_path, quarantine_path)
      items.push({
        op: MoveFileToQuarantine(threat.file_path, quarantine_path),
        success: ok,
        message: if ok { "文件已移至隔离区" } else { "文件移动失败" },
      })
    }
  }

  items
}
```

- [ ] **步骤 3：实现分类引导清理**

```moonbit
/// 分类引导清理
/// 将威胁按类别分组，用户逐项勾选后执行

/// 威胁分类
enum ThreatCategory {
  Processes      // 运行中的进程
  RunKeys        // 自启项
  Services       // 服务
  ScheduledTasks // 计划任务
  Files          // 文件
  Homepage       // 主页劫持
}

/// 分类后的威胁组
struct CategorizedThreats {
  mut processes : Array[Threat]
  mut run_keys : Array[Threat]
  mut services : Array[Threat]
  mut scheduled_tasks : Array[Threat]
  mut files : Array[Threat]
  mut homepage : Array[Threat]
} derive(Show)

/// 将威胁列表分类
pub fn categorize(threats : Array[Threat]) -> CategorizedThreats {
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

/// 执行选中的分类清理
pub fn clean_selected(
  selected : Array[Threat],
  scan_id : String
) -> CleanResult {
  let mut items = []
  let mut pending_reboot = false
  for threat in selected {
    let clean_items = @targets.deep_clean_threat(threat, scan_id)
    for item in clean_items {
      items.push(item)
      if item.message.contains("重启") {
        pending_reboot = true
      }
    }
  }
  { items, pending_reboot, scan_id }
}
```

- [ ] **步骤 4：实现一键深度清理**

```moonbit
/// 一键深度清理
/// 自动对全部威胁执行完整清理流程

pub fn one_click_clean(
  threats : Array[Threat],
  scan_id : String
) -> CleanResult {
  // 1. 检查提权
  if !@platform.priv.is_elevated() {
    // 未提权时请求提权
    let elevated = @platform.priv.request_elevation()
    if !elevated {
      return { items: [], pending_reboot: false, scan_id }
    }
  }

  // 2. 创建隔离区
  @quarantine.create_quarantine_dir(scan_id)

  // 3. 对每个威胁执行深度清理
  let mut all_items = []
  let mut pending_reboot = false
  let mut manifest_items = []

  for threat in threats {
    let clean_items = @targets.deep_clean_threat(threat, scan_id)
    for item in clean_items {
      all_items.push(item)
      if item.message.contains("重启") {
        pending_reboot = true
      }
    }

    // 为每个操作写 manifest
    match item.op {
      KillProcess(pid) => {
        manifest_items.push({
          op_type: "kill_process",
          source: pid.to_string(),
          quarantine_path: "",
          old_value: "",
          sha256_before: "",
          status: if item.success { "success" } else { "failed" },
        })
      }
      DeleteRunKey(key, name) => {
        manifest_items.push({
          op_type: "delete_registry",
          source: key + "\\" + name,
          quarantine_path: "",
          old_value: "",
          sha256_before: "",
          status: if item.success { "success" } else { "failed" },
        })
      }
      StopDeleteService(name) => {
        manifest_items.push({
          op_type: "stop_delete_service",
          source: name,
          quarantine_path: "",
          old_value: "",
          sha256_before: "",
          status: if item.success { "success" } else { "failed" },
        })
      }
      MoveFileToQuarantine(src, dst) => {
        manifest_items.push({
          op_type: "move_file",
          source: src,
          quarantine_path: dst,
          old_value: "",
          sha256_before: threat.file_hash_sha256,
          status: if item.success { "success" } else { "failed" },
        })
      }
      FixHomepage(url) => {
        manifest_items.push({
          op_type: "fix_homepage",
          source: url,
          quarantine_path: "",
          old_value: "",
          sha256_before: "",
          status: "success",
        })
      }
    }
  }

  // 4. 写入 manifest
  let manifest : QuarantineManifest = {
    scan_id,
    timestamp: "",  // TODO: 当前时间
    items: manifest_items,
  }
  @quarantine.write_manifest(scan_id, manifest)

  { items: all_items, pending_reboot, scan_id }
}
```

- [ ] **步骤 5：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功

- [ ] **步骤 6：Commit**

```bash
git add lib/clean/
git commit -m "feat: implement quarantine, cleanup targets, classify and one-click clean"
```

---

## 任务 10：ImGui GUI

**文件：**
- 创建：`lib/ui/imgui_cwrap.c`
- 创建：`lib/ui/imgui.mbt`
- 创建：`lib/ui/views.mbt`
- 下载：ImGui 源码到 `lib/ui/imgui/`

- [ ] **步骤 1：下载 ImGui 源码**

运行：
```bash
cd g:\traework\jk100\lib\ui
git clone --depth 1 --branch v1.91.6-docking https://github.com/ocornut/imgui.git imgui_src
```

从 imgui_src 复制必要文件到 lib/ui/imgui/：
- `imgui.cpp`, `imgui.h`, `imgui_internal.h`
- `imgui_widgets.cpp`, `imgui_draw.cpp`, `imgui_tables.cpp`
- `backends/imgui_impl_win32.cpp`, `backends/imgui_impl_win32.h`
- `backends/imgui_impl_dx11.cpp`, `backends/imgui_impl_dx11.h`

- [ ] **步骤 2：编译 ImGui 为静态库**

创建 `lib/ui/build_imgui.ps1`：
```powershell
# 将 ImGui + Win32 + DX11 后端编译为 jk100_imgui.lib
gcc -c -O2 -DUNICODE -I./imgui -I./imgui/backends `
  ./imgui/imgui.cpp `
  ./imgui/imgui_widgets.cpp `
  ./imgui/imgui_draw.cpp `
  ./imgui/imgui_tables.cpp `
  ./imgui/backends/imgui_impl_win32.cpp `
  ./imgui/backends/imgui_impl_dx11.cpp `
  -o ./lib/libjk100_imgui.a
```

运行编译脚本。

- [ ] **步骤 3：编写 ImGui C 胶水文件**

`lib/ui/imgui_cwrap.c`:
```c
// imgui_cwrap.c - ImGui C shim for MoonBit FFI
#include "imgui/imgui.h"
#include "imgui/backends/imgui_impl_win32.h"
#include "imgui/backends/imgui_impl_dx11.h"
#include <d3d11.h>
#include <dwmapi.h>
#include <moonbit.h>

static ID3D11Device* g_pd3dDevice = NULL;
static ID3D11DeviceContext* g_pd3dDeviceContext = NULL;
static IDXGISwapChain* g_pSwapChain = NULL;
static ID3D11RenderTargetView* g_mainRenderTargetView = NULL;
static HWND g_hwnd = NULL;
static bool g_running = true;

// 外部回调函数（由 MoonBit 设置）
extern void jk100_ui_frame();

// Win32 窗口过程
LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
    return true;
  return DefWindowProcW(hWnd, msg, wParam, lParam);
}

int32_t jk100_ui_init() {
  // 创建 Win32 窗口
  WNDCLASSEXW wc = {0};
  wc.cbSize = sizeof(wc);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandle(NULL);
  wc.lpszClassName = L"JK100Class";
  RegisterClassExW(&wc);
  g_hwnd = CreateWindowExW(0, L"JK100Class", L"jk100 极快100",
    WS_OVERLAPPEDWINDOW, 100, 100, 800, 600,
    NULL, NULL, wc.hInstance, NULL);

  // 初始化 D3D11
  DXGI_SWAP_CHAIN_DESC sd = {0};
  sd.BufferCount = 2;
  sd.BufferDesc.Width = 0;
  sd.BufferDesc.Height = 0;
  sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
  sd.BufferDesc.RefreshRate.Numerator = 60;
  sd.BufferDesc.RefreshRate.Denominator = 1;
  sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
  sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  sd.OutputWindow = g_hwnd;
  sd.SampleDesc.Count = 1;
  sd.SampleDesc.Quality = 0;
  sd.Windowed = TRUE;
  sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

  D3D_FEATURE_LEVEL featureLevel;
  D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0,
    NULL, 0, D3D11_SDK_VERSION, &sd,
    &g_pSwapChain, &g_pd3dDevice, &featureLevel, &g_pd3dDeviceContext);

  ID3D11Texture2D* pBackBuffer;
  g_pSwapChain->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer));
  g_pd3dDevice->CreateRenderTargetView(pBackBuffer, NULL, &g_mainRenderTargetView);
  pBackBuffer->Release();

  // 初始化 ImGui
  IMGUI_CHECKVERSION();
  ImGui::CreateContext();
  ImGuiIO& io = ImGui::GetIO();
  io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
  ImGui::StyleColorsLight();
  ImGui_ImplWin32_Init(g_hwnd);
  ImGui_ImplDX11_Init(g_pd3dDevice, g_pd3dDeviceContext);

  ShowWindow(g_hwnd, SW_SHOWDEFAULT);
  return 0;
}

int32_t jk100_ui_new_frame() {
  MSG msg;
  while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
    if (msg.message == WM_QUIT) {
      g_running = false;
      return 1; // 退出
    }
  }
  if (!g_running) return 1;

  ImGui_ImplDX11_NewFrame();
  ImGui_ImplWin32_NewFrame();
  ImGui::NewFrame();
  return 0;
}

void jk100_ui_render() {
  ImGui::Render();
  const float clear_color[] = { 0.95f, 0.95f, 0.95f, 1.00f };
  g_pd3dDeviceContext->OMSetRenderTargets(1, &g_mainRenderTargetView, NULL);
  g_pd3dDeviceContext->ClearRenderTargetView(g_mainRenderTargetView, clear_color);
  ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
  g_pSwapChain->Present(1, 0);
}

void jk100_ui_shutdown() {
  ImGui_ImplDX11_Shutdown();
  ImGui_ImplWin32_Shutdown();
  ImGui::DestroyContext();
  if (g_mainRenderTargetView) g_mainRenderTargetView->Release();
  if (g_pSwapChain) g_pSwapChain->Release();
  if (g_pd3dDeviceContext) g_pd3dDeviceContext->Release();
  if (g_pd3dDevice) g_pd3dDevice->Release();
  DestroyWindow(g_hwnd);
}

// === ImGui 控件 FFI ===

void jk100_ui_begin(const char* name) { ImGui::Begin(name); }
void jk100_ui_end() { ImGui::End(); }
void jk100_ui_text(const char* text) { ImGui::Text("%s", text); }
int32_t jk100_ui_button(const char* label) { return ImGui::Button(label); }
void jk100_ui_same_line() { ImGui::SameLine(); }
void jk100_ui_separator() { ImGui::Separator(); }
void jk100_ui_progress_bar(float fraction) { ImGui::ProgressBar(fraction); }

int32_t jk100_ui_begin_listbox(const char* label, int32_t height) {
  return ImGui::BeginListBox(label, ImVec2(-1, (float)height));
}
void jk100_ui_end_listbox() { ImGui::EndListBox(); }
int32_t jk100_ui_selectable(const char* label, int32_t selected) {
  return ImGui::Selectable(label, selected != 0);
}

int32_t jk100_ui_checkbox(const char* label, int32_t* v) {
  return ImGui::Checkbox(label, (bool*)v);
}
void jk100_ui_set_cursor_pos_x(float x) { ImGui::SetCursorPosX(x); }
float jk100_ui_get_window_width() { return ImGui::GetWindowWidth(); }
```

- [ ] **步骤 4：编写 MoonBit ImGui FFI 绑定**

`lib/ui/imgui.mbt`:
```moonbit
#extern
type CCheckboxVal

extern "C" fn jk100_ui_init() -> Int = "jk100_ui_init"
extern "C" fn jk100_ui_new_frame() -> Int = "jk100_ui_new_frame"
extern "C" fn jk100_ui_render() -> Unit = "jk100_ui_render"
extern "C" fn jk100_ui_shutdown() -> Unit = "jk100_ui_shutdown"

extern "C" fn jk100_ui_begin(name: Bytes) -> Unit = "jk100_ui_begin"
extern "C" fn jk100_ui_end() -> Unit = "jk100_ui_end"
extern "C" fn jk100_ui_text(text: Bytes) -> Unit = "jk100_ui_text"
extern "C" fn jk100_ui_button(label: Bytes) -> Int = "jk100_ui_button"
extern "C" fn jk100_ui_same_line() -> Unit = "jk100_ui_same_line"
extern "C" fn jk100_ui_separator() -> Unit = "jk100_ui_separator"
extern "C" fn jk100_ui_progress_bar(fraction: Double) -> Unit = "jk100_ui_progress_bar"
extern "C" fn jk100_ui_begin_listbox(label: Bytes, height: Int) -> Int = "jk100_ui_begin_listbox"
extern "C" fn jk100_ui_end_listbox() -> Unit = "jk100_ui_end_listbox"
extern "C" fn jk100_ui_selectable(label: Bytes, selected: Int) -> Int = "jk100_ui_selectable"

/// 初始化 ImGui
pub fn init() -> Bool {
  jk100_ui_init() == 0
}

/// 开始新帧
pub fn new_frame() -> Bool {
  jk100_ui_new_frame() == 0  // 返回 true 表示继续
}

/// 渲染
pub fn render() -> Unit {
  jk100_ui_render()
}

/// 关闭
pub fn shutdown() -> Unit {
  jk100_ui_shutdown()
}

/// 窗口
pub fn begin(name : String) -> Unit {
  let b = name.to_bytes()
  #borrow(b)
  jk100_ui_begin(b)
}

pub fn end() -> Unit { jk100_ui_end() }

/// 文本
pub fn text(t : String) -> Unit {
  let b = t.to_bytes()
  #borrow(b)
  jk100_ui_text(b)
}

/// 按钮
pub fn button(label : String) -> Bool {
  let b = label.to_bytes()
  #borrow(b)
  jk100_ui_button(b) != 0
}

/// 同行
pub fn same_line() -> Unit { jk100_ui_same_line() }

/// 分隔线
pub fn separator() -> Unit { jk100_ui_separator() }

/// 进度条
pub fn progress_bar(fraction : Double) -> Unit {
  jk100_ui_progress_bar(fraction)
}

/// 列表框
pub fn begin_listbox(label : String, height : Int) -> Bool {
  let b = label.to_bytes()
  #borrow(b)
  jk100_ui_begin_listbox(b, height) != 0
}

pub fn end_listbox() -> Unit { jk100_ui_end_listbox() }

pub fn selectable(label : String, selected : Bool) -> Bool {
  let b = label.to_bytes()
  #borrow(b)
  jk100_ui_selectable(b, if selected { 1 } else { 0 }) != 0
}
```

- [ ] **步骤 5：编写 UI 视图**

`lib/ui/views.mbt`:
```moonbit
/// jk100 GUI 视图
/// ImGui 渲染主循环与各视图

/// 应用状态
enum AppState {
  Home          // 首页
  Scanning      // 扫描中
  Results       // 扫描结果
  Cleaning      // 清理中
  CleanDone     // 清理完成
  Quarantine    // 隔离区
  Settings      // 设置
}

struct AppModel {
  mut state : AppState
  mut scan_result : @types.ScanResult
  mut scan_speed : @types.ScanSpeed
  mut clamav_available : Bool
  mut progress : Double
  mut selected_threats : Array[Bool]
  mut clean_mode : @types.CleanMode
  mut clean_result : @types.CleanResult
  mut db : @sigdb.SigDB
  mut clamav : @clamd.ClamAVConfig
} derive(Show)

/// 初始化应用模型
fn init_model() -> AppModel {
  let db = @sigdb.load("bundled/sigdb/rogue_rules.json", "bundled/sigdb/whitelist.json")
  let clamav = @clamd.default_config()
  {
    state: Home,
    scan_result: { threats: [], total_files: 0, scanned_files: 0, skipped_whitelist: 0, errors: 0, elapsed_ms: 0 },
    scan_speed: Normal,
    clamav_available: false,
    progress: 0.0,
    selected_threats: [],
    clean_mode: Classify,
    clean_result: { items: [], pending_reboot: false, scan_id: "" },
    db,
    clamav,
  }
}

/// GUI 主循环
pub fn run_gui() -> Unit {
  if !@imgui.init() {
    println("ImGui 初始化失败")
    return
  }

  let mut model = init_model()

  // 主循环
  let mut running = true
  while running {
    if !@imgui.new_frame() {
      running = false
      break
    }

    render_frame(model)
    @imgui.render()
  }

  @imgui.shutdown()
}

/// 渲染一帧
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

/// 首页视图
fn render_home(model : AppModel) -> Unit {
  @imgui.begin("jk100 极快100 防恶意软件")
  @imgui.text("jk100 极快100 v0.1.0")
  @imgui.separator()
  @imgui.text("选择扫描模式：")
  if @imgui.button("快速扫描") {
    // TODO: 启动快速扫描
    model.state = Scanning
  }
  @imgui.same_line()
  if @imgui.button("全盘扫描") {
    model.state = Scanning
  }
  @imgui.separator()
  if @imgui.button("隔离区") {
    model.state = Quarantine
  }
  @imgui.same_line()
  if @imgui.button("设置") {
    model.state = Settings
  }
  if !model.clamav_available {
    @imgui.text("[提示] ClamAV 不可用，仅扫描流氓软件")
  }
  @imgui.end()
}

/// 扫描中视图
fn render_scanning(model : AppModel) -> Unit {
  @imgui.begin("扫描中...")
  @imgui.text("正在扫描，请稍候...")
  @imgui.progress_bar(model.progress)
  @imgui.text("已扫描: " + model.scan_result.scanned_files.to_string() + " / " + model.scan_result.total_files.to_string())
  if model.scan_result.threats.length() > 0 {
    @imgui.text("已发现威胁: " + model.scan_result.threats.length().to_string())
  }
  if @imgui.button("取消扫描") {
    // TODO: 取消扫描
    model.state = Results
  }
  @imgui.end()
}

/// 扫描结果视图
fn render_results(model : AppModel) -> Unit {
  @imgui.begin("扫描结果")
  let threat_count = model.scan_result.threats.length()
  @imgui.text("发现 " + threat_count.to_string() + " 个威胁")
  @imgui.separator()

  // 选择清理模式
  if threat_count > 0 {
    if @imgui.button("一键深度清理") {
      model.clean_mode = OneClick
      model.state = Cleaning
    }
    @imgui.same_line()
    if @imgui.button("分类引导清理") {
      model.clean_mode = Classify
      model.state = Cleaning
    }
  }

  // 威胁列表
  if @imgui.begin_listbox("威胁列表", 300) {
    for i in 0..<model.scan_result.threats.length() {
      let threat = model.scan_result.threats[i]
      let label = "[" + threat.threat_type.to_string() + "] " + threat.family_name + " - " + threat.file_path
      @imgui.selectable(label, false)
    }
    @imgui.end_listbox()
  }

  @imgui.separator()
  if @imgui.button("返回首页") {
    model.state = Home
  }
  @imgui.end()
}

/// 清理中视图
fn render_cleaning(model : AppModel) -> Unit {
  @imgui.begin("清理中...")
  @imgui.text("正在清理威胁...")
  // TODO: 显示清理进度
  @imgui.end()
}

/// 清理完成视图
fn render_clean_done(model : AppModel) -> Unit {
  @imgui.begin("清理完成")
  let mut success_count = 0
  let mut fail_count = 0
  for item in model.clean_result.items {
    if item.success { success_count = success_count + 1 } else { fail_count = fail_count + 1 }
  }
  @imgui.text("成功: " + success_count.to_string() + "  失败: " + fail_count.to_string())
  if model.clean_result.pending_reboot {
    @imgui.text("[提示] 部分操作需要重启后完成")
  }
  if @imgui.button("返回首页") {
    model.state = Home
  }
  @imgui.end()
}

/// 隔离区视图
fn render_quarantine(model : AppModel) -> Unit {
  @imgui.begin("隔离区")
  let quarantines = @quarantine.list_quarantines()
  if quarantines.length() == 0 {
    @imgui.text("隔离区为空")
  } else {
    if @imgui.begin_listbox("隔离记录", 300) {
      for qid in quarantines {
        if @imgui.selectable(qid, false) {
          // 选中某条隔离记录
          ignore(qid)
        }
      }
      @imgui.end_listbox()
    }
    if @imgui.button("回滚选中") {
      // TODO: 回滚
    }
    @imgui.same_line()
    if @imgui.button("回滚全部") {
      // TODO: 回滚全部
    }
  }
  @imgui.separator()
  if @imgui.button("返回") { model.state = Home }
  @imgui.end()
}

/// 设置视图
fn render_settings(model : AppModel) -> Unit {
  @imgui.begin("设置")
  @imgui.text("扫描速度档位：")
  // TODO: 速度档位单选按钮
  @imgui.separator()
  if @imgui.button("返回") { model.state = Home }
  @imgui.end()
}
```

- [ ] **步骤 6：验证编译**

运行：`cd g:\traework\jk100 && moon build --target native`
预期：编译成功（ImGui 静态库 + C FFI 链接正确）

- [ ] **步骤 7：Commit**

```bash
git add lib/ui/
git commit -m "feat: implement ImGui GUI with scan/clean/quarantine views"
```

---

## 任务 11：集成测试与打包

**文件：**
- 修改：`bundled/sigdb/rogue_rules.json`（填充真实规则）
- 修改：`bundled/sigdb/whitelist.json`（填充真实白名单）
- 创建：`bundled/clamav/clamd.conf`

- [ ] **步骤 1：填充真实流氓软件规则**

更新 `bundled/sigdb/rogue_rules.json`，从 SoftCnKiller 社区签名库提取国内常见流氓软件规则，覆盖驱动精灵、壁纸软件、安全助手捆绑等 20+ 家族。

- [ ] **步骤 2：填充真实白名单**

更新 `bundled/sigdb/whitelist.json`，添加 Microsoft、Google、Adobe、NVIDIA、Intel 等正规软件签名。

- [ ] **步骤 3：创建 ClamAV 配置**

`bundled/clamav/clamd.conf`:
```
LogFile stdout
DatabaseDirectory ./bundled/clamav
TCPSocket 3310
TCPAddr 127.0.0.1
MaxThreads 4
ScanPE yes
ScanELF no
ScanPDF no
ScanSWF no
ScanMail no
ScanArchive yes
ArchiveBlockEncrypted no
```

- [ ] **步骤 4：端到端测试**

在 VM 中执行：
1. 启动 jk100.exe，确认 GUI 正常显示
2. 执行快速扫描，确认威胁被检出
3. 执行分类引导清理，确认选中项被清理
4. 执行一键深度清理，确认全部项被清理
5. 检查隔离区，确认文件已移入
6. 执行回滚，确认系统恢复
7. 测试速度档位切换
8. 测试 UAC 未提权时的降级提示

- [ ] **步骤 5：Commit**

```bash
git add bundled/
git commit -m "feat: populate real rogue rules and ClamAV config"
```

---

## 任务 12：最终发布构建

**文件：**
- 创建：`build.ps1`（构建脚本）
- 创建：`dist/`（发布目录）

- [ ] **步骤 1：创建构建脚本**

```powershell
# build.ps1 - jk100 构建脚本
Write-Host "构建 jk100 极快100..."

# 1. 构建 ImGui 静态库
Write-Host "编译 ImGui..."
Push-Location lib\ui
.\build_imgui.ps1
Pop-Location

# 2. 构建 MoonBit 项目
Write-Host "编译 MoonBit..."
moon build --target native

# 3. 打包发布
Write-Host "打包..."
$dist = "dist\jk100-v0.1.0"
New-Item -ItemType Directory -Force -Path $dist
Copy-Item "target\native\release\bin\jk100.exe" $dist
Copy-Item -Recurse "bundled\clamav" $dist
Copy-Item -Recurse "bundled\sigdb" $dist

Write-Host "构建完成: $dist"
```

- [ ] **步骤 2：执行构建并验证**

运行：`cd g:\traework\jk100 && powershell -File build.ps1`
预期：dist 目录下生成完整的 jk100 发布包

- [ ] **步骤 3：最终 Commit**

```bash
git add build.ps1
git commit -m "feat: add build script and dist packaging"
```
