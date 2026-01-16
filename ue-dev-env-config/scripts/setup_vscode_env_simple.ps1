# ========================================
# VSCode UE 环境配置脚本 (简化版)
# ========================================

param(
    [string]$UEProjectPath = "",
    [string]$UEEnginePath = "",
    [switch]$Help
)

if ($Help) {
    Write-Host "VSCode UE Environment Setup Script (Simplified)"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  scripts\setup_vscode_env_simple.ps1 [-UEProjectPath <path>] [-UEEnginePath <path>]"
    Write-Host ""
    exit
}

# 检测工作区类型
$WorkspaceRoot = $PWD.Path
$WorkspaceType = "Unknown"
$RequiredEngineVersion = $null

Write-Host "[Step 1/4] Detecting workspace type..." -ForegroundColor Yellow

# 检测项目工作区
$uprojectFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.uproject" -ErrorAction SilentlyContinue
if ($uprojectFiles.Count -gt 0) {
    $ProjectFile = $uprojectFiles[0].FullName
    $WorkspaceType = "Project"
    if ([string]::IsNullOrWhiteSpace($UEProjectPath)) {
        $UEProjectPath = $ProjectFile
    }

    # 读取 .uproject 文件获取引擎版本
    try {
        $projectJson = Get-Content $ProjectFile -Raw | ConvertFrom-Json
        if ($projectJson.EngineAssociation) {
            $RequiredEngineVersion = $projectJson.EngineAssociation
            Write-Host "   Detected: Project Workspace (UE $RequiredEngineVersion)" -ForegroundColor Green
        }
    } catch {
        Write-Host "   Detected: Project Workspace" -ForegroundColor Green
    }
}

Write-Host ""

# 检测 UE 引擎
Write-Host "[Step 2/4] Detecting Unreal Engine..." -ForegroundColor Yellow

if ([string]::IsNullOrWhiteSpace($UEEnginePath)) {
    # 自动搜索 UE 引擎
    $AvailableDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.Root -match '^[A-Z]:\\$' -and (Test-Path $_.Root -ErrorAction SilentlyContinue)
    } | ForEach-Object { $_.Name + ":" }

    $EpicGamesPaths = @("Program Files\Epic Games", "Epic Games")
    $UEPaths = @()

    foreach ($drive in $AvailableDrives) {
        foreach ($epPath in $EpicGamesPaths) {
            $fullPath = Join-Path $drive $epPath
            if (Test-Path $fullPath -ErrorAction SilentlyContinue) {
                Get-ChildItem $fullPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^UE_" } | ForEach-Object {
                    $enginePath = Join-Path $_.FullName "Engine"
                    if (Test-Path $enginePath -ErrorAction SilentlyContinue) {
                        $version = $_.Name -replace "UE_", ""
                        $UEPaths += @{Version = $version; Path = $_.FullName; OriginalName = $_.Name}
                    }
                }
            }
        }
    }

    # 如果项目指定了引擎版本，优先匹配
    if ($RequiredEngineVersion) {
        $matchingEngines = $UEPaths | Where-Object { $_.Version -eq $RequiredEngineVersion }
        if ($matchingEngines) {
            $UEEnginePath = $matchingEngines[0].Path
            Write-Host "   Found UE ${RequiredEngineVersion}: $UEEnginePath" -ForegroundColor Green
        } else {
            Write-Host "   WARNING: UE ${RequiredEngineVersion} not found!" -ForegroundColor Yellow
            Write-Host "   Available engines:" -ForegroundColor Gray
            $UEPaths | ForEach-Object { Write-Host "     - UE $($_.Version) at $($_.Path)" -ForegroundColor Gray }
            Write-Host ""
            Write-Host "   Using first available engine..." -ForegroundColor Yellow
            if ($UEPaths.Count -gt 0) {
                $UEEnginePath = $UEPaths[0].Path
                Write-Host "   Using UE $($UEPaths[0].Version): $UEEnginePath" -ForegroundColor Yellow
            } else {
                Write-Host "   ERROR: No UE Engine found!" -ForegroundColor Red
                Write-Host "   Please specify with -UEEnginePath parameter" -ForegroundColor Yellow
                exit 1
            }
        }
    } else {
        if ($UEPaths.Count -gt 0) {
            $UEEnginePath = $UEPaths[0].Path
            Write-Host "   Found UE Engine: $UEEnginePath" -ForegroundColor Green
        } else {
            Write-Host "   ERROR: UE Engine not found!" -ForegroundColor Red
            Write-Host "   Please specify with -UEEnginePath parameter" -ForegroundColor Yellow
            exit 1
        }
    }
} else {
    Write-Host "   Using specified engine: $UEEnginePath" -ForegroundColor Green
}

Write-Host ""

# 创建配置文件
Write-Host "[Step 3/4] Creating VSCode configuration..." -ForegroundColor Yellow

$vscodeDir = Join-Path $WorkspaceRoot ".vscode"
if (-not (Test-Path $vscodeDir)) {
    New-Item -ItemType Directory -Path $vscodeDir | Out-Null
}

# 创建 c_cpp_properties.json
$includePaths = @(
    "`${workspaceFolder}/**",
    "$($UEEnginePath.Replace('\', '/'))/Engine/Source/**",
    "$($UEEnginePath.Replace('\', '/'))/Engine/Plugins/**"
)

if ($WorkspaceType -eq "Project") {
    $includePaths += "`${workspaceFolder}/Source/**"
    $includePaths += "`${workspaceFolder}/Plugins/**"
}

$c_cpp_properties = @{
    configurations = @(
        @{
            name = "Win64"
            includePath = $includePaths
            defines = @(
                "WITH_EDITOR=1",
                "UE_BUILD_DEVELOPMENT=1",
                "UE_EDITOR=1",
                "PLATFORM_WINDOWS=1",
                "WIN64=1",
                "UNICODE=1"
            )
            compilerPath = ""
            cppStandard = "c++20"
            cStandard = "c17"
            intelliSenseMode = "windows-msvc-x64"
        }
    )
    version = 4
}

$c_cpp_properties | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $vscodeDir "c_cpp_properties.json") -Encoding UTF8
Write-Host "   Created c_cpp_properties.json" -ForegroundColor Green

Write-Host ""
Write-Host "[Step 4/4] Configuration Summary" -ForegroundColor Yellow
Write-Host ""
Write-Host "Workspace Type: $WorkspaceType" -ForegroundColor White
if ($RequiredEngineVersion) {
    Write-Host "Project Requires: UE $RequiredEngineVersion" -ForegroundColor White
}
Write-Host "Engine Path: $UEEnginePath" -ForegroundColor White
Write-Host "Config File: $vscodeDir\c_cpp_properties.json" -ForegroundColor White
Write-Host ""

if ($RequiredEngineVersion -and $UEEnginePath -notmatch $RequiredEngineVersion.Replace('.', '\.')) {
    Write-Host "WARNING: Using UE $($UEPaths[0].Version) for a UE $RequiredEngineVersion project!" -ForegroundColor Yellow
    Write-Host "This may cause compatibility issues." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "[DONE] VSCode Environment Configuration Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Reload VSCode window (F1 -> Reload Window)"
Write-Host "  2. Wait for IntelliSense indexing to complete"
Write-Host ""
