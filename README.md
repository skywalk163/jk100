# jk100 极快100

> 致敬江民公司 kv100 —— 一款无广告、无弹窗、干净利落的 Windows 防恶意软件工具。

## 项目简介

jk100（极快100）是一款面向 Windows 10/11 x64 的轻量级反恶意软件工具，核心思路融合了三方面技术：

- **kv100 广谱过滤技术**：一条规则匹配整个恶意软件家族，无需枚举每个变种哈希
- **360 安全卫士的易用性**：双击即用，一键深度清理，像 360 好用但没有广告
- **社会工程识别点**：恶意软件常在防护关闭时集中入住、使用随机目录等特征（P2 计划）

### 目标威胁

| 威胁类型 | 来源 | 特征 |
|---|---|---|
| 国内流氓/捆绑软件 | 安装正规软件时被捆绑静默植入 | 开机自启、随机目录、隐藏服务、主页锁定、弹窗广告 |
| 通用病毒木马 | 网络传播、PE 恶意代码 | PE 入口异常、加壳、已知恶意特征码 |

## 技术栈

| 层级 | 技术 | 说明 |
|---|---|---|
| 主体语言 | MoonBit (native x64) | 原生编译，单文件分发，性能接近 Rust |
| GUI | ImGui (C FFI) | 即时模式 UI，单依赖，适合工具类 |
| 通用病毒引擎 | ClamAV (clamd socket) | 独立子进程，GPL 安全，零链接 |
| Win32 API | C FFI 绑定层 | 自研 extern 声明和 shim 层 |
| 数据格式 | JSON | 规则库、隔离 manifest、配置 |

## 架构

```
jk100.exe (MoonBit native x64, 单进程)
|
+-- core/              扫描引擎
|   +-- scan           扫描调度（后台线程 + 速度档位）
|   +-- sigdb          特征库加载（含白名单优先级过滤）
|   +-- clamd          ClamAV socket 客户端
|   +-- pe             PE 解析（签名/版本/入口/区段）
|   +-- hash           SHA256（纯 MoonBit）
|
+-- clean/             清理模块
|   +-- classify       分类引导清理（按类别分组、勾选）
|   +-- oneclick       一键深度清理（自动全流程）
|   +-- quarantine     隔离区目录 + 回滚 manifest
|   +-- targets        清理目标操作（进程/自启/服务/计划任务/文件/主页）
|
+-- platform/          Win32 C FFI 绑定层
|   +-- process        枚举/结束进程
|   +-- registry       Run 键/服务键读写
|   +-- service        SCM 服务枚举/停止/删除
|   +-- file           文件移动/占用检测
|   +-- priv           UAC 提权检测与请求
|   +-- priority       进程优先级调整（用于速度档位）
|
+-- ui/                ImGui 前端（C FFI）
|   +-- views          主窗 / 扫描中 / 结果 / 清理 / 隔离区 / 设置
|
+-- bundled/
    +-- clamav/        便携 clamd.exe + clamd.conf
    +-- sigdb/         rogue_rules.json + whitelist.json
```

## 核心特性

### 双引擎检测

1. **流氓软件规则引擎**：基于签名/路径/自启名/哈希的组合规则，广谱匹配整个家族
2. **ClamAV 病毒引擎**：通过 socket 调用便携版 clamd，检测通用病毒木马

### 白名单优先级过滤

正规软件的签名/哈希命中白名单后，直接跳过后续全部判定，最大限度降低误报率。

### 两种清理模式

- **分类引导清理**：威胁按类别分组（进程/自启/服务/计划任务/文件/主页），用户逐项勾选
- **一键深度清理**：自动执行全流程，所有操作先写 manifest 再执行，支持完整回滚

### 隔离区与回滚

- 所有删除的文件移入隔离区，保留原目录结构
- 注册表/服务/计划任务操作记录原始快照
- 支持按项回滚和全部回滚
- 恢复后校验文件哈希一致性

### 扫描速度档位

| 档位 | CPU 优先级 | IO 间隔 | 适用场景 |
|---|---|---|---|
| 低速 | Idle | 100ms | 工作时后台扫描，完全不打扰 |
| 正常 | Normal | 10ms | 平衡，默认 |
| 高速 | Above Normal | 0ms | 空闲时快速完成全盘扫描 |

## 项目结构

```
jk100/
├── main/main.mbt              # 程序入口（CLI / GUI 模式切换）
├── lib/
│   ├── core/                  # 扫描引擎核心
│   │   ├── types.mbt          # 核心数据类型
│   │   ├── hash.mbt           # SHA256 哈希计算
│   │   ├── pe.mbt             # PE 文件解析
│   │   ├── sigdb.mbt          # 规则库加载与匹配
│   │   ├── clamd.mbt          # ClamAV socket 客户端
│   │   └── scan.mbt           # 扫描调度器
│   ├── clean/                 # 清理模块
│   │   ├── types.mbt          # 清理类型定义
│   │   ├── quarantine.mbt     # 隔离区管理
│   │   ├── targets.mbt        # 清理目标操作
│   │   ├── classify.mbt       # 分类引导清理
│   │   └── oneclick.mbt       # 一键深度清理
│   ├── platform/              # Win32 C FFI 平台层
│   │   ├── cwrap.c/h          # C 胶水层
│   │   ├── process.mbt        # 进程操作
│   │   ├── registry.mbt       # 注册表操作
│   │   ├── service.mbt        # 服务操作
│   │   ├── file.mbt           # 文件操作
│   │   ├── priv.mbt           # 提权操作
│   │   └── priority.mbt       # 优先级操作
│   └── ui/                    # ImGui GUI
│       ├── imgui_cwrap.c      # ImGui C 胶水
│       ├── imgui.mbt          # ImGui FFI 绑定
│       ├── views.mbt          # UI 视图
│       └── build_imgui.ps1    # ImGui 编译脚本
├── bundled/
│   ├── clamav/clamd.conf      # ClamAV 配置
│   └── sigdb/
│       ├── rogue_rules.json   # 流氓软件规则库
│       └── whitelist.json     # 白名单
├── docs/                      # 设计文档
├── build.ps1                  # 构建脚本
└── moon.mod                   # MoonBit 模块定义
```

## 构建与运行

### 环境要求

- Windows 10/11 x64
- [MoonBit](https://moonbitlang.com) 工具链
- GCC（用于编译 ImGui 和 C FFI 层）
- ClamAV 便携版（放入 `bundled/clamav/`）

### 构建

```powershell
# 安装 MoonBit 工具链（如未安装）
irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex

# 构建项目
.\moonbit\bin\moon build --target native

# 或使用构建脚本（包含 ImGui 编译和打包）
.\build.ps1
```

### 运行

```powershell
# GUI 模式（默认）
.\target\native\release\bin\jk100.exe

# CLI 模式
.\target\native\release\bin\jk100.exe --cli --scan "C:\Users"
```

## 规则库格式

### 流氓软件规则（rogue_rules.json）

```json
{
  "version": "2026-07-03",
  "rules": [
    {
      "id": "rogue_001",
      "name": "XX助手家族",
      "severity": "rogue",
      "signatures": ["某某有限公司"],
      "path_patterns": ["%LocalAppData%\\XXDriver*"],
      "run_names": ["XXService"],
      "file_names": ["xxhelper.exe"],
      "hashes_sha256": ["abc123..."],
      "service_names": ["XXAssist"],
      "description": "静默安装，弹窗广告，主页锁定"
    }
  ]
}
```

### 白名单（whitelist.json）

```json
{
  "version": "2026-07-03",
  "entries": [
    {
      "signer": "Microsoft Corporation",
      "paths": ["%SystemRoot%\\System32\\*"],
      "reason": "系统核心组件"
    }
  ]
}
```

## 开发路线图

| 阶段 | 内容 | 状态 |
|---|---|---|
| P1 | 查杀清理引擎 MVP | ✅ 已完成 |
| P2 | 实时行为监控 + 社会工程启发式检测 | 计划中 |
| P3 | 自我保护（内核 Hook） | 计划中 |
| P4 | 网络侧防护（恶意 DNS/流量拦截） | 计划中 |
| P5 | 轻量 AI 检测（本地 ML 推理） | 计划中 |
| P6 | 完整 GUI（系统修复、垃圾清理、开机加速） | 计划中 |
| P7 | 特征库在线更新通道 | 计划中 |

## 设计理念

- **零广告零弹窗**：除了安全告警，绝不打扰用户
- **开箱即用**：单文件分发，双击即用，无需安装
- **安全可回滚**：所有清理操作可回滚，隔离区保留原始文件
- **广谱高效**：学习 kv100 广谱过滤，一条规则覆盖整个家族
- **白名单优先**：正规软件优先放行，降低误报

## 致谢

- [江民公司 kv100](http://www.jiangmin.com/) —— 广谱过滤技术的先驱
- [ClamAV](https://www.clamav.net/) —— 开源反病毒引擎
- [MoonBit](https://moonbitlang.com) —— 高性能原生编程语言
- [ImGui](https://github.com/ocornut/imgui) —— 即时模式 GUI 库

## 许可证

本项目代码采用 MIT 许可证。ClamAV 组件遵循其原始 GPL 许可证。

## 仓库

- GitCode: https://gitcode.com/skywalk163/jk100
- GitHub: https://github.com/skywalk163/jk100
