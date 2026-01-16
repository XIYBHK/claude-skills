# ========================================
# OpenCode JSON 配置生成脚本
# 功能：生成交互式配置 opencode.json 的 LSP 设置
# ========================================

param(
    [string]$UEEnginePath = "",
    [switch]$Help
    )

if ($Help) {
    Write-Host @"
╔══════════════════════════════════════════════════════════╗
║        OpenCode JSON 配置生成工具                        ║
╚════════════════════════════════════════════════════════╝

功能：
  - 生成交互式配置 opencode.json
  - 配置 clangd LSP 支持
  - 自动检测或提示 UE 引擎路径
  - 配置 compile_commands.json 路径

用法:
    scripts\configure_opencode_json.ps1 [选项]

参数:
    -UEEnginePath <路径>   指定 UE 引擎路径
    -Help                  显示此帮助信息

配置文件:
    - opencode.json  (OpenCode 配置文件)

"@
    exit
}

# ========================================
# 0. 获取工作区根目录
# ========================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║            OpenCode LSP 配置向导                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot

# ========================================
# 1. 检测或获取 UE 引擎路径
# ========================================
Write-Host "[ 步骤 1/3 ] 检测 Unreal Engine 安装..." -ForegroundColor Yellow

if ([string]::IsNullOrWhiteSpace($UEEnginePath)) {
    # 自动检测 UE 引擎
    $AvailableDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.Root -match '^[A-Z]:\\$' -and (Test-Path $_.Root -ErrorAction SilentlyContinue)
    } | ForEach-Object { $_.Name + ":" }

    $EpicGamesPaths = @(
        "Program Files\Epic Games",
        "Epic Games"
    )

    $UEPaths = @()

    foreach ($drive in $AvailableDrives) {
        foreach ($epPath in $EpicGamesPaths) {
            try {
                $fullPath = Join-Path $drive $epPath
                if (Test-Path $fullPath -ErrorAction SilentlyContinue) {
                    Get-ChildItem $fullPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^UE_" } | ForEach-Object {
                        $enginePath = Join-Path $_.FullName "Engine"
                        if (Test-Path $enginePath -ErrorAction SilentlyContinue) {
                            $UEPaths += @{
                                Version = $_.Name
                                Path = $_.FullName
                                Type = "Epic Games Launcher"
                            }
                        }
                    }
                }
            }
            catch {
                # 忽略错误
            }
        }
    }

    if ($UEPaths.Count -eq 0) {
        Write-Host "   ❌ 未找到 UE 引擎安装！" -ForegroundColor Red
        Write-Host "" -ForegroundColor Red
        exit 1
    }

    Write-Host "   ✓ 找到 $($UEPaths.Count) 个 UE 引擎安装" -ForegroundColor Green
    $UEPaths | ForEach-Object {
        Write-Host "     - $($_.Version) ($($_.Type)): $($_.Path)" -ForegroundColor Gray
    }

    # 选择引擎版本
    $selectedUE = $UEPaths[0]
    if ($UEPaths.Count -gt 1) {
        Write-Host ""
        Write-Host "   选择要使用的引擎版本:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $UEPaths.Count; $i++) {
            Write-Host "   [$i] $($UEPaths[$i].Version) - $($UEPaths[$i].Path)"
        }
        $choice = Read-Host "   请输入序号 (默认: 0)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 0 }
        $selectedUE = $UEPaths[[int]$choice]
    }

    $UEEnginePath = $selectedUE.Path
    Write-Host "   → 已选择: $UEEnginePath" -ForegroundColor Green
} else {
    Write-Host "   ✓ 使用指定的引擎路径: $UEEnginePath" -ForegroundColor Green
}

Write-Host ""

# ========================================
# 2. 验证引擎路径
# ========================================
Write-Host "[ 步骤 2/3 ] 验证引擎路径..." -ForegroundColor Yellow

if (-not (Test-Path "$UEEnginePath/Engine")) {
    Write-Host "   ❌ 无效的引擎路径: $UEEnginePath" -ForegroundColor Red
    Write-Host "   未找到 Engine 目录" -ForegroundColor Red
    exit 1
}

Write-Host "   ✓ 引擎路径验证通过" -ForegroundColor Green
Write-Host ""

# ========================================
# 3. 生成 opencode.json 配置
# ========================================
Write-Host "[ 步骤 3/3 ] 生成 opencode.json..." -ForegroundColor Yellow

$configFilePath = Join-Path $WorkspaceRoot ".vscode\opencode.json"
$configDir = Split-Path -Parent $configFilePath

if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$compileCommandsPath = "$($UEEnginePath.Replace('\', '/'))/compile_commands.json"

# 验证 compile_commands.json 是否存在
if (-not (Test-Path $compileCommandsPath)) {
    Write-Host "   ⚠️  警告: compile_commands.json 不存在" -ForegroundColor Yellow
    Write-Host "   路径: $compileCommandsPath" -ForegroundColor Yellow
    Write-Host "   IntelliSense 可能不准确" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   建议先运行 UE 项目生成或使用 VSCode 编译任务生成" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "   ✓ 找到 compile_commands.json" -ForegroundColor Green
}

Write-Host ""

# 生成 opencode.json 配置
$opencodeConfig = @{
    `$schema` = "https://opencode.ai/config.json"
    lsp = @{
        clangd = @{
            command = @("clangd", "--compile-commands-dir=$($UEEnginePath.Replace('\', '/'))")
            extensions = @(".c", ".cpp", ".cc", ".cxx", ".c++", ".h", ".hpp", ".hh", ".hxx", ".h++")
            disabled = $false
        }
    }
}

$configJson = $opencodeConfig | ConvertTo-Json -Depth 100

# 保存配置文件
$configJson | Set-Content $configFilePath -Encoding UTF8

Write-Host "   ✓ 已生成 opencode.json" -ForegroundColor Green
Write-Host "   位置: $configFilePath" -ForegroundColor Gray
Write-Host ""

# ========================================
# 4. 配置摘要
# ========================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              配置完成！                              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📋 配置摘要:" -ForegroundColor Cyan
Write-Host "   UE 引擎路径: $UEEnginePath" -ForegroundColor White
Write-Host "   opencode.json: $configFilePath" -ForegroundColor White
Write-Host "   compile_commands.json: $compileCommandsPath" -ForegroundColor White
Write-Host ""

Write-Host "📝 下一步操作:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1. 验证 opencode.json 配置" -ForegroundColor White
Write-Host "      → 打开: $configFilePath" -ForegroundColor Gray
Write-Host ""
Write-Host "   2. 重启 opencode" -ForegroundColor White
Write-Host "      → 关闭当前 opencode 会话" -ForegroundColor Gray
Write-Host "      → 重新打开 opencode" -ForegroundColor Gray
Write-Host "      → LSP 配置将自动生效" -ForegroundColor Gray
Write-Host ""
Write-Host "   3. 打开任意 C/C++ 文件" -ForegroundColor White
Write-Host "      → opencode 会自动启动 clangd LSP" -ForegroundColor Gray
Write-Host "      → 验证 LSP 状态（查看 opencode 日志）" -ForegroundColor Gray
Write-Host ""

Write-Host "✨ OpenCode LSP 配置完成！" -ForegroundColor Green
Write-Host ""
