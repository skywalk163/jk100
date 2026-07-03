# build.ps1 - jk100 构建脚本
param(
    [string]$Version = "0.1.0",
    [string]$TargetDir = "dist\jk100-v$Version",
    [switch]$Release = $false
)

$BuildType = if ($Release) { "release" } else { "debug" }
$MoonTargetDir = if ($Release) { "target" } else { "_build" }
$ExeSource = "$MoonTargetDir\native\$BuildType\build\jk100\jk100\main\main.exe"
$ExeDestDir = "target\native\$BuildType\bin"
$ExeDest = "$ExeDestDir\jk100.exe"

Write-Host "构建 jk100 极快100 v$Version ($BuildType)..." -ForegroundColor Cyan

# 1. 编译 ImGui 静态库（可选）
Write-Host "`n[1/5] 编译 ImGui..." -ForegroundColor Yellow
$imguiBuilt = $false
if (Test-Path "lib\ui\build_imgui.ps1") {
    try {
        & "lib\ui\build_imgui.ps1"
        if ($LASTEXITCODE -eq 0) {
            $imguiBuilt = $true
        }
    } catch {
        Write-Host "ImGui 编译失败，跳过: $_" -ForegroundColor Yellow
    }
    if (-not $imguiBuilt) {
        Write-Host "警告：ImGui 编译失败，当前版本不包含 GUI 功能" -ForegroundColor Yellow
    }
} else {
    Write-Host "警告：未找到 ImGui 编译脚本，跳过" -ForegroundColor Yellow
}

# 2. 构建 MoonBit 项目
Write-Host "`n[2/5] 编译 MoonBit 项目..." -ForegroundColor Yellow
$BuildArgs = @("build", "--target", "native")
if ($Release) {
    $BuildArgs += "--release"
    $BuildArgs += "--target-dir"
    $BuildArgs += "target"
}
$MoonBin = ".\moonbit\bin\moon.exe"
& $MoonBin @BuildArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "构建失败！" -ForegroundColor Red
    exit 1
}

# 3. 复制并重命名 exe 到 target/native/<type>/bin/jk100.exe
Write-Host "`n[3/5] 生成输出文件..." -ForegroundColor Yellow
if (-not (Test-Path $ExeSource)) {
    Write-Host "错误：找不到构建产物 $ExeSource" -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Force -Path $ExeDestDir | Out-Null
Copy-Item $ExeSource $ExeDest -Force
Write-Host "输出: $ExeDest" -ForegroundColor Green

# 4. 创建发布目录
Write-Host "`n[4/5] 创建发布目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# 5. 复制发布文件
Write-Host "`n[5/5] 复制发布文件..." -ForegroundColor Yellow
Copy-Item $ExeDest $TargetDir -Force
Copy-Item -Recurse "bundled\clamav" $TargetDir -ErrorAction SilentlyContinue
Copy-Item -Recurse "bundled\sigdb" $TargetDir -ErrorAction SilentlyContinue
Copy-Item "README.md" $TargetDir -ErrorAction SilentlyContinue

Write-Host "`n构建完成！" -ForegroundColor Green
Write-Host "  可执行文件: $ExeDest"
Write-Host "  发布目录:   $TargetDir"
