# jk100 查杀清理引擎（MVP）设计文档

日期：2026-07-03
版本：v1.0
状态：待审查

---

## 1. 概述与范围

本文档定义 jk100 项目 Phase 1（P1）——查杀清理引擎 MVP 的完整设计。

P1 的目标是在最短时间内交付一个单文件可运行、带最小 GUI 的扫描清理工具，能同时应对两类威胁：
- **国内流氓/捆绑软件**（开机自启、随机目录、隐藏服务、主页锁定）
- **通用病毒木马**（PE 文件恶意特征）

P1 不包含实时行为监控、社会工程启发式检测（集中入住时间窗口识别、随机目录聚类）——这些属于 Phase 2。

成功标准：用户能在全新安装的 Windows 10/11 x64 上下载单个 jk100.exe，双击运行即可扫描并清理系统上的已知威胁，且所有删除操作可回滚。

---

## 2. 目标威胁

### 2.1 国内流氓/捆绑软件
- **来源**：安装 360 等软件时被捆绑植入，静默安装
- **特征**：开机自启、随机目录名、随机进程名、伪装驱动/服务、锁定主页、弹窗广告
- **覆盖来源**：SoftCnKiller 社区签名库 + 自研规则扩展

### 2.2 通用病毒木马
- **来源**：theZoo 样本库、网络传播、PE 恶意代码
- **特征**：PE 入口异常、加壳、已知恶意特征码
- **覆盖来源**：内置便携 ClamAV（clamd）的病毒特征库

---

## 3. 技术栈

| 层级 | 技术 | 说明 |
|---|---|---|
| 主体语言 | MoonBit (native x64) | 原生编译，单文件分发，性能接近 Rust |
| GUI | ImGui (C FFI) | 即时模式 UI，单依赖，适合工具类 |
| 通用病毒引擎 | ClamAV (clamd socket) | 独立子进程，GPL 安全，零链接 |
| Win32 API | C FFI 绑定层 | 我来写全部 extern 声明和 shim 层 |
| 数据格式 | JSON | 规则库、隔离 manifest、配置 |

---

## 4. 架构方案

### 4.1 采用方案：单进程多模块 + clamd 子进程

jk100.exe 是单个 MoonBit 原生进程，内部按模块划分。ImGui 通过 C FFI 直接链接进同一进程；ClamAV 作为独立 clamd.exe 子进程被拉起，走本地 socket 通信。

**不选双进程方案的理由**：MVP 阶段双进程引入 IPC 协议设计成本，两份构建，属于过度设计。等 P2/P3 需要常驻服务和内核通信时，再演进拆分。

**扫描阻塞问题**：扫描在后台线程运行，UI 主线程独立渲染进度条和结果列表。

---

## 5. 模块结构

```
jk100.exe (MoonBit native x64, 单进程)
|
+-- core/              扫描引擎
|   +-- scan           扫描调度（后台线程 + 并发 + 速度档位）
|   +-- sigdb          特征库加载（含白名单优先级过滤）
|   +-- clamd          ClamAV socket 客户端（SCAN 模式）
|   +-- pe             PE 解析（纯 MoonBit：签名/版本/入口/区段）
|   +-- hash           SHA256/MD5（纯 MoonBit）
|
+-- clean/             清理模块
|   +-- classify       分类引导清理（按类别分组、勾选）
|   +-- oneclick       一键深度清理（自动全流程）
|   +-- quarantine     隔离区目录 + 回滚 manifest
|   +-- targets        清理目标操作（进程/自启/服务/计划任务/文件/主页）
|
+-- platform/          Win32 C FFI 绑定层
|   +-- process        枚举/结束进程（含进程树）
|   +-- registry       Run 键/服务键读写
|   +-- service        SCM 服务枚举/停止/删除
|   +-- sched          计划任务枚举/删除
|   +-- file           文件移动/占用检测/PendingFileRename
|   +-- priv           UAC 提权检测与请求
|   +-- priority       进程优先级调整（用于速度档位）
|
+-- ui/                ImGui 前端（C FFI）
|   +-- views          主窗 / 扫描中 / 结果 / 分类清理 / 一键清理 / 回滚 / 设置
|
+-- bundled/
    +-- clamav/        裁剪后便携 clamd.exe + .cvd 特征快照
    +-- sigdb/         rogue_rules.json + whitelist.json
```

---

## 6. 核心数据流

### 6.1 扫描阶段

```
[用户选目标区域]
    -> scan 启动后台扫描线程
    -> 遍历目标 PE 文件
    -> 对每个文件，按优先级顺序判定：
       ① whitelist.json 查签名/哈希/路径 -> 命中白名单则直接跳过该文件全部后续判定
       ② rogue_rules.json 查签名/路径/自启名/哈希 -> 命中则报流氓软件
       ③ clamd SCAN <path> -> 命中则报通用病毒
    -> 汇总 Threat 列表（含：类型、路径、进程ID、服务名、注册表项、来源引擎）
    -> UI 进度条更新，结果列表填充
```

### 6.2 清理阶段

```
[结果视图]
    -> 用户选择清理模式：
       分类引导模式：按类别（进程/自启/服务/计划任务/文件/主页）分组，逐项勾选
       一键深度模式：自动全选，直接执行全流程
    -> 执行前检查 UAC 提权
    -> 清理执行（后台线程）：
       每项操作前先写 quarantine manifest
       步骤：结束进程树 -> 清自启项 -> 停止并删除服务 -> 清计划任务 -> 移文件到隔离区 -> 修主页
    -> 生成报告：成功/失败/待重启项
```

### 6.3 回滚阶段

```
[隔离区列表]
    -> 用户选择回滚范围（全部回滚 / 单项回滚）
    -> 读对应 manifest 逆序恢复
    -> 验证恢复后文件哈希一致性
```

---

## 7. 规则库格式

### 7.1 流氓软件规则库 rogue_rules.json

```json
{
  "version": "2026-07-03",
  "rules": [
    {
      "id": "rogue_family_001",
      "name": "XX助手家族",
      "severity": "rogue",
      "signatures": ["某某有限公司", "XX科技"],
      "path_patterns": ["%LocalAppData%\\XXDriver*", "%ProgramData%\\XXHelper*"],
      "run_names": ["XXService", "XXHelper", "XXDriver"],
      "file_names": ["xxhelper.exe", "xxservice.dll"],
      "hashes_sha256": ["abc123..."],
      "service_names": ["XXAssist"],
      "homepage": "http://www.xxhijack.com",
      "description": "静默安装，弹窗广告，主页锁定"
    }
  ]
}
```

- `signatures`：PE 数字签名颁发者名称（匹配则属于该家族）
- `path_patterns`：安装路径通配符，支持 `%` 环境变量
- `run_names`：注册表 Run 键中可疑名称
- `file_names`：文件名黑名单
- `hashes_sha256`：精确文件哈希
- `service_names`：Windows 服务名
- `homepage`：已知主页劫持目标
- `severity`：`rogue`（流氓软件）

### 7.2 白名单 whitelist.json

```json
{
  "version": "2026-07-03",
  "entries": [
    {
      "signer": "Microsoft Corporation",
      "hashes_sha256": ["def456..."],
      "paths": ["%SystemRoot%\\System32\\*"],
      "reason": "系统核心组件"
    },
    {
      "signer": "NVIDIA Corporation",
      "reason": "显卡驱动"
    }
  ]
}
```

**优先级规则**：白名单判定在流氓规则之前执行。任何白名单命中（签名/哈希/路径 任一匹配）的文件，直接跳过 clamd 和 rogue 全部后续判定。防止正规软件（如 Adobe、Steam）因路径相似或签名在第三方被误报。

### 7.3 广谱规则思路

KV100 的广谱过滤核心是"一条规则匹配一族样本"。在我们的规则格式中，通过 `signatures` + `path_patterns` + `run_names` 的组合实现：例如同时满足"签名=XX科技"和"路径含XXHelper"即匹配整个家族，而不需要枚举该家族每一个变种的哈希。

---

## 8. 扫描速度档位

用户可在设置中调节速度档位，扫描调度器据此控制后台线程的 CPU 优先级和 IO 间隔：

| 档位 | CPU 优先级 | IO 间隔 | 适用场景 |
|---|---|---|---|
| 低速 | Idle | 100ms | 完全不打扰用户，适合工作时后台扫描 |
| 正常 | Normal | 10ms | 平衡，默认 |
| 高速 | Above Normal | 0ms | 快速完成全盘扫描，适合空闲时 |

实现：通过 Win32 API `SetThreadPriority` 调整扫描线程优先级；IO 间隔通过扫描线程内 sleep 控制。UI 可实时切换档位，扫描线程读取共享变量即时响应。

---

## 9. 隔离区与回滚

### 9.1 隔离区结构

```
%ProgramData%\jk100\quarantine\
  <scan-id>\                    # 单次扫描唯一标识（时间戳+UUID前8位）
    manifest.json                # 本次所有操作的原子快照
    files\                       # 隔离文件（保留原目录结构）
      C_\Users\Admin\AppData\Local\XXDriver\xx.exe
    registry_snapshots\          # 注册表原始值快照（JSON）
    service_snapshots\           # 服务原始状态快照（JSON）
    task_snapshots\              # 计划任务原始状态快照（JSON）
```

### 9.2 manifest.json 格式

```json
{
  "scan_id": "20260703-143022-a1b2c3d4",
  "timestamp": "2026-07-03T14:30:22+08:00",
  "items": [
    {
      "op": "move_file",
      "source": "C:\\Users\\Admin\\AppData\\Local\\XXDriver\\xx.exe",
      "quarantine_path": "files/C_/Users/Admin/AppData/Local/XXDriver/xx.exe",
      "sha256_before": "abc123...",
      "status": "success"
    },
    {
      "op": "delete_registry",
      "key": "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run",
      "value_name": "XXService",
      "old_value": "C:\\...",
      "status": "success"
    },
    {
      "op": "stop_delete_service",
      "service_name": "XXAssist",
      "old_config": { ... },
      "status": "success"
    }
  ]
}
```

### 9.3 回滚实现

- **按项回滚**：用户从隔离列表中选一条记录，读 manifest 中对应 `items` 反向执行
- **全部回滚**：遍历 manifest `items` 逆序恢复（先恢复文件，再恢复注册表/服务，避免进程重启后再次写入）
- **哈希校验**：恢复后计算文件 SHA256，与 manifest 中 `sha256_before` 比对，不一致则标红警告

### 9.4 清理模式选择

两种模式并存，由用户在结果视图自主选择：
- **分类引导清理**：结果按类别分组（进程/自启/服务/计划任务/文件/主页），用户逐项勾选后点击"执行选中"
- **一键深度清理**：按钮直接执行全部检测到的威胁的完整清理流程，每项操作先写 manifest 再执行，所有文件先入隔离区

---

## 10. ClamAV 接入（含裁剪）

### 10.1 接入方式

- **内置便携版**：打包裁剪后的 `clamd.exe` + 精简版 `.cvd` 特征文件到 `bundled/clamav/`
- **通信协议**：jk100 启动时拉起 clamd 作为子进程，走本地 TCP socket（默认端口 3310），发送 `SCAN <path>` 指令
- **GPL 安全**：不静态/动态链接 libclamav，通过 socket 调用是完全独立的进程间通信，避免 GPL 传染 jk100 主体代码

### 10.2 ClamAV 裁剪

为压缩打包体积，对 ClamAV 进行裁剪：
- **删除**：`clamscan` CLI 工具、`clamdscan` 前端、`freshclam` 独立更新（P7 实现自定义更新通道）、`sigtool` 签名工具、邮件扫描模块（Milter/LibClamAV 的 mail 解码器）
- **保留**：`clamd` daemon 进程、核心 PE 解析、特征码匹配引擎、启发式引擎、脱壳引擎
- **特征库**：仅保留病毒/木马 `.cvd`，删除钓鱼/垃圾邮件/PUA 分类以减体积
- **预期体积**：从完整版约 200MB 压缩到约 80-100MB

### 10.3 降级策略

clamd 启动失败时（特征库损坏、端口被占、防病毒冲突），UI 顶部显示黄色提示条："通用病毒引擎不可用，仅扫描流氓软件"。不影响流氓规则扫描功能。

---

## 11. 错误处理策略

| 场景 | 行为 | UI 反馈 |
|---|---|---|
| clamd 不可用 | 降级为仅流氓规则扫描 | 黄条提示 |
| 文件被占用（正在运行） | 移动失败，写入 PendingFileRename，标记为"待重启清理" | 结果列表标黄，清理报告提示重启 |
| 进程结束失败 | 记录失败原因，不阻断其余清理 | 结果标红 |
| 未提权（UAC 拒绝） | 扫描可用，清理按钮禁用 | 按钮灰显 + 提示需管理员权限 |
| 扫描线程异常（单文件） | 跳过该文件，记录日志，继续扫描其余 | 进度条继续，最后报告"X 个文件扫描异常" |
| 隔离区写入失败 | 终止清理，回滚已执行操作，报告错误 | 弹窗提示 |
| manifest 损坏/缺失 | 回滚不可用，提示"该次隔离记录不完整" | 灰显回滚按钮 |

---

## 12. 测试策略

### 12.1 特征匹配测试
- **ClamAV 识别率**：用 theZoo 样本库（200+ 样本）验证，要求检出率 > 85%
- **流氓规则命中率**：收集 20+ 国内常见流氓软件（如某驱动精灵变体、某壁纸软件）验证家族规则覆盖
- **白名单测试**：验证 Microsoft/Adobe/Google 等正规软件不被误报

### 12.2 清理+回滚测试
- **VM 内模拟植入**：在干净 Win10 VM 中安装模拟流氓软件（假进程/假自启/假服务/假计划任务），执行分类引导和一键两种清理模式
- **回滚一致性**：清理后回滚，验证系统状态与清理前完全一致
- **异常场景**：测试文件占用（进程未结束时的文件移动）、UAC 拒绝、隔离区满等边界

### 12.3 FFI 层测试
- 每个 Win32 绑定函数独立单元测试（枚举进程、读写注册表、服务操作等）
- 在 32 位和 64 位进程上下文中分别验证（尽管只发 x64）

### 12.4 UI 验收
- 手动验收：扫描 -> 分类清理 -> 一键清理 -> 回滚 -> 速度档位切换 -> UAC 交互

---

## 13. 边界与范围排除（P1 不做）

以下功能**明确排除在 P1 之外**，归入后续阶段：

| 排除项 | 归入阶段 | 理由 |
|---|---|---|
| 实时行为监控（进程创建 Hook、文件系统过滤驱动） | P2 | 需内核驱动开发 |
| 社会工程启发式检测（关闭防护后集中入住时间窗口识别、随机目录聚类） | P2 | 需实时数据流支撑 |
| 网络侧防护（恶意 DNS/DGA/流量拦截） | P4 | 需网络过滤驱动 |
| 自我保护（防止恶意软件结束/篡改 jk100） | P3 | 需内核 Hook |
| 轻量 AI 检测（本地 ML 模型推理） | P5 | MVP 特征码够用 |
| 360 式完整 GUI（系统修复、垃圾清理、开机加速等） | P6 | MVP 聚焦查杀 |
| 特征库在线更新通道 | P7 | MVP 用静态快照 |
| 主动防御 / HIPS（行为规则拦截） | P2/P3 | MVP 纯被动扫描 |

---

## 14. 关键设计决策记录

| 决策 | 选择 | 原因 |
|---|---|---|
| 架构 | 单进程多模块 | MVP 最快，IPC 最少，等 P2/P3 再拆分 |
| 技术栈 | MoonBit native | 单文件分发、性能接近 Rust、贴合用户兴趣 |
| GUI 工具包 | ImGui via C FFI | 即时模式、单依赖、适合工具 |
| ClamAV 接入 | 内置裁剪便携版 + socket | GPL 安全、开箱即用、体积可控 |
| 清理模式 | 分类引导 + 一键深度并存 | 满足不同用户习惯 |
| 回滚机制 | 隔离区 + manifest 快照 | 一键深度清理的安全网 |
| 扫描档位 | 低/中/高三档 + 线程优先级 | 工作时不打扰 |
| 白名单 | 独立 JSON，优先级高于全部判定 | 降低正规软件误报 |
| 启发式检测 | 全放 P2 | MVP 聚焦特征码 |
| 目标系统 | Win10/11 x64 | WebView2/ImGui 兼容性好，覆盖主流 |
