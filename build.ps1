# build.ps1 - jk100 构建脚本
param(
    [string]$Version = "0.1.0",
    [string]$TargetDir = "dist\jk100-v$Version"
)

Write-Host "构建 jk100 极快100..." -ForegroundColor Cyan

# 1. 编译 ImGui 静态库
Write-Host "`n[1/4] 编译 ImGui..." -ForegroundColor Yellow
if (Test-Path "lib\ui\build_imgui.ps1") {
    & "lib\ui\build_imgui.ps1"
} else {
    Write-Host "警告：未找到 ImGui 编译脚本" -ForegroundColor Yellow
}

# 2. 构建 MoonBit 项目
Write-Host "`n[2/4] 编译 MoonBit 项目..." -ForegroundColor Yellow
$env:MOON_HOME = "moonbit"
$env:PATH = "$env:MOON_HOME\bin;$env:PATH"
.\moonbit\bin\moon build --target native

# 3. 创建发布目录
Write-Host "`n[3/4] 创建发布目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# 4. 复制文件
Write-Host "`n[4/4] 复制文件..." -ForegroundColor Yellow
Copy-Item "target\native\release\bin\jk100.exe" $TargetDir -ErrorAction SilentlyContinue
Copy-Item -Recurse "bundled\clamav" $TargetDir -ErrorAction SilentlyContinue
Copy-Item -Recurse "bundled\sigdb" $TargetDir -ErrorAction SilentlyContinue

Write-Host "`n构建完成！输出目录: $TargetDir" -ForegroundColor Green
