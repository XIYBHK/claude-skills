# ========================================
# VSCode UE 环境配置脚本
# 功能:自动检测并配置 VSCode 的 UE 开发环境
# 支持:插件工作区,项目工作区,独立源码工作区
# ========================================

param(
    [string]$UEProjectPath = "",
    [string]$UEEnginePath = "",
    [switch]$IsPlugin,
    [switch]$IsProject,
    [switch]$Help
    )

if ($Help) {
    Write-Host @"
╔══════════════════════════════════════════════════════════╗
║        VSCode UE 环境配置工具                                ║
╚══════════════════════════════════════════════════════════╝

功能:
  - 自动检测 UE 引擎安装(支持多版本,多盘符)
  - 自动检测 Visual Studio 和 MSVC 编译器
  - 智能识别工作区类型(插件/项目/源码)
  - 智能查找并关联 UE 项目(插件工作区)
  - 自动创建/更新配置文件(IntelliSense,编译,调试)

用法:
    scripts\setup_vscode_env.ps1 [选项]

参数:
    -UEProjectPath <路径>  指定 UE 项目的 .uproject 文件路径
    -UEEnginePath <路径>   强制指定 UE 引擎路径(跳过自动检测)
    -IsPlugin              明确指定当前工作区为插件目录
    -IsProject             明确指定当前工作区为项目目录
    -Help                  显示此帮助信息

示例:
    # 1. 自动检测并配置(最常用)
    scripts\setup_vscode_env.ps1

    # 2. 插件工作区 + 指定项目路径
    scripts\setup_vscode_env.ps1 -UEProjectPath "D:\UnrealProjects\MyProject\MyProject.uproject"

    # 3. 强制指定引擎路径
    scripts\setup_vscode_env.ps1 -UEEnginePath "F:\Epic Games\UE_5.4"

工作区类型说明:
    插件工作区: 工作区根目录有 .uplugin 文件
    项目工作区: 工作区根目录有 .uproject 文件
    源码工作区: 其他自定义源码目录

配置文件:
    - c_cpp_properties.json  (IntelliSense 配置)
    - tasks.json             (编译任务配置)
    - launch.json            (调试配置)
    - settings.json          (编辑器设置)

"@
    exit
}

# ========================================
# 0. 检测工作区类型
# ========================================
Write-Host "[ 步骤 0/5 ] 分析工作区类型..." -ForegroundColor Yellow

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$WorkspaceType = "Unknown"
$PluginFile = $null
$ProjectFile = $null

# 检测插件工作区
$upluginFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.uplugin" -ErrorAction SilentlyContinue
if ($upluginFiles.Count -gt 0) {
    $PluginFile = $upluginFiles[0].FullName
    $WorkspaceType = "Plugin"
    if (-not $IsProject) { $IsPlugin = $true }
}

# 检测项目工作区
$uprojectFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.uproject" -ErrorAction SilentlyContinue
if ($uprojectFiles.Count -gt 0) {
    $ProjectFile = $uprojectFiles[0].FullName
    $WorkspaceType = "Project"
    if (-not $IsPlugin) { $IsProject = $true }
}

# 显示检测结果
Write-Host "   工作区路径: " -NoNewline
Write-Host "$WorkspaceRoot" -ForegroundColor Gray
Write-Host "   工作区类型: " -NoNewline
switch ($WorkspaceType) {
    "Plugin" {
        Write-Host "插件工作区 [P]" -ForegroundColor Green
        Write-Host "   插件文件:   " -NoNewline
        Write-Host "$PluginFile" -ForegroundColor Gray
    }
    "Project" {
        Write-Host "项目工作区 [PJ]" -ForegroundColor Green
        Write-Host "   项目文件:   " -NoNewline
        Write-Host "$ProjectFile" -ForegroundColor Gray
        $UEProjectPath = $ProjectFile
    }
    default {
        Write-Host "源码工作区 [SRC]" -ForegroundColor Cyan
        Write-Host "   (未检测到 .uplugin 或 .uproject 文件)" -ForegroundColor Gray
    }
}
Write-Host ""

# ========================================
# 1. 检测或指定 UE 引擎路径
# ========================================
Write-Host "[ 步骤 1/5 ] 检测 Unreal Engine 安装..." -ForegroundColor Yellow

$UEPaths = @()
$selectedUE = $null

# 如果用户强制指定了引擎路径,跳过检测
if (-not [string]::IsNullOrWhiteSpace($UEEnginePath)) {
    if (Test-Path "$UEEnginePath/Engine" -ErrorAction SilentlyContinue) {
        $selectedUE = @{
            Version = "User Specified"
            Path = $UEEnginePath
            Type = "Manual"
        }
        Write-Host "   ✓ 使用指定的引擎路径: $UEEnginePath" -ForegroundColor Green
    } else {
        Write-Host "   [X] 指定的路径无效: $UEEnginePath" -ForegroundColor Red
        exit 1
    }
} else {
    # 自动检测 UE 引擎
    # 首先获取系统中实际存在且可访问的盘符
    $AvailableDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.Root -match '^[A-Z]:\\$' -and (Test-Path $_.Root -ErrorAction SilentlyContinue)
    } | ForEach-Object { $_.Name + ":" }

    $EpicGamesPaths = @(
        "Program Files\Epic Games",
        "Epic Games"
    )

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
                # 忽略错误,继续检查下一个路径
            }
        }
    }

    if ($UEPaths.Count -eq 0) {
        Write-Host "   [X] 未找到 UE 引擎安装!" -ForegroundColor Red
        Write-Host "   请确保已安装 Unreal Engine 或使用 -UEEnginePath 指定路径" -ForegroundColor Red
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
}

$UEEnginePath = $selectedUE.Path
Write-Host "   最终使用: $UEEnginePath" -ForegroundColor Green
Write-Host ""

# ========================================
# 2. 检测 Visual Studio 和 MSVC
# ========================================
Write-Host "[ 步骤 2/5 ] 检测 Visual Studio..." -ForegroundColor Yellow

$VSBasePaths = @()
$VSBasePaths += "C:\Program Files\Microsoft Visual Studio\2022"
$VSBasePaths += "C:\Program Files (x86)\Microsoft Visual Studio\2022"

# 检测所有盘符下的自定义路径
foreach ($drive in $AvailableDrives) {
    try {
        # 只有当盘符实际存在时才添加路径
        if (Test-Path $drive -ErrorAction SilentlyContinue) {
            $VSBasePaths += Join-Path $drive "VisualStudio\2022"
            $VSBasePaths += Join-Path $drive "Visual Studio\2022"
            $VSBasePaths += Join-Path $drive "VS2022"
        }
    }
    catch {
        # 忽略错误,继续检查下一个盘符
    }
}

$VSEditions = @("Enterprise", "Professional", "Community", "BuildTools")
$foundVS = $null
$foundMSVC = $null

foreach ($basePath in $VSBasePaths) {
    if ($null -ne $foundMSVC) { break }

    # 跳过空路径或无效路径
    if ([string]::IsNullOrWhiteSpace($basePath)) { continue }

    try {
        # 首先检查是否是直接安装(无 Edition 子文件夹)
        $directMsvcPath = Join-Path $basePath "VC\Tools\MSVC"
        if (Test-Path $directMsvcPath -ErrorAction SilentlyContinue) {
            $msvcVersions = Get-ChildItem $directMsvcPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            if ($msvcVersions.Count -gt 0) {
                $foundVS = "Direct Install ($basePath)"
                $foundMSVC = Join-Path $msvcVersions[0].FullName "bin\Hostx64\x64\cl.exe"
                break
            }
        }

        # 然后检查标准的 Edition 子文件夹
        foreach ($edition in $VSEditions) {
            $editionPath = Join-Path $basePath $edition
            if (Test-Path $editionPath -ErrorAction SilentlyContinue) {
                $msvcPath = Join-Path $editionPath "VC\Tools\MSVC"
                if (Test-Path $msvcPath -ErrorAction SilentlyContinue) {
                    $msvcVersions = Get-ChildItem $msvcPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
                    if ($msvcVersions.Count -gt 0) {
                        $foundVS = "$edition ($basePath)"
                        $foundMSVC = Join-Path $msvcVersions[0].FullName "bin\Hostx64\x64\cl.exe"
                        break
                    }
                }
            }
        }
    }
    catch {
        # 忽略错误,继续
    }
}

if ($null -eq $foundMSVC) {
    Write-Host "   [!]️  未找到 Visual Studio 2022" -ForegroundColor Yellow
    Write-Host "   请确保已安装 Visual Studio 2022 和 C++ 工作负载" -ForegroundColor Yellow
} else {
    Write-Host "   ✓ 找到 Visual Studio 2022 $foundVS" -ForegroundColor Green
    Write-Host "   ✓ MSVC 编译器: $foundMSVC" -ForegroundColor Green
}
Write-Host ""

# ========================================
# 3. 智能检测 UE 项目路径
# ========================================
Write-Host "[ 步骤 3/5 ] 检测 UE 项目路径..." -ForegroundColor Yellow

if ([string]::IsNullOrWhiteSpace($UEProjectPath) -and $IsPlugin) {
    # 自动查找可能的项目路径
    Write-Host "   → 正在搜索使用此插件的 UE 项目..." -ForegroundColor Cyan

    # 向上查找父目录中的项目
    $currentDir = Split-Path -Parent $WorkspaceRoot
    $foundProjects = @()

    # 检查父目录层级(最多向上3层)
    for ($i = 0; $i -lt 3; $i++) {
        if ([string]::IsNullOrWhiteSpace($currentDir)) { break }

        $uprojectFiles = Get-ChildItem -Path $currentDir -Filter "*.uproject" -ErrorAction SilentlyContinue
        if ($uprojectFiles.Count -gt 0) {
            foreach ($proj in $uprojectFiles) {
                $foundProjects += $proj.FullName
                Write-Host "      找到项目: $($proj.FullName)" -ForegroundColor Gray
            }
        }

        $currentDir = Split-Path -Parent $currentDir
    }

    # 也检查常见的项目目录位置
    $possiblePaths = @(
        "F:\Unreal Projects\CPP",
        "D:\Unreal Projects",
        "C:\Unreal Projects"
    )

    foreach ($basePath in $possiblePaths) {
        if (Test-Path $basePath -ErrorAction SilentlyContinue) {
            Get-ChildItem -Path $basePath -Filter "*.uproject" -Recurse -Depth 1 -ErrorAction SilentlyContinue | ForEach-Object {
                if ($foundProjects -notcontains $_.FullName) {
                    $foundProjects += $_.FullName
                    Write-Host "      找到项目: $($_.FullName)" -ForegroundColor Gray
                }
            }
        }
    }

    if ($foundProjects.Count -gt 0) {
        Write-Host ""
        Write-Host "   ✓ 找到 $($foundProjects.Count) 个 UE 项目" -ForegroundColor Green

        if ($foundProjects.Count -eq 1) {
            $UEProjectPath = $foundProjects[0]
            Write-Host "   → 自动选择: $UEProjectPath" -ForegroundColor Cyan
        } else {
            Write-Host "   选择要关联的项目(用于调试):" -ForegroundColor Yellow
            for ($i = 0; $i -lt $foundProjects.Count; $i++) {
                Write-Host "   [$i] $(Split-Path -Leaf $foundProjects[$i]) - $($foundProjects[$i])"
            }
            Write-Host "   [N] 暂不配置(只配置 IntelliSense)" -ForegroundColor Gray

            $choice = Read-Host "   请输入序号 (默认: N)"
            if (-not [string]::IsNullOrWhiteSpace($choice) -and $choice -ne "N" -and $choice -ne "n") {
                $UEProjectPath = $foundProjects[[int]$choice]
                Write-Host "   → 已选择: $UEProjectPath" -ForegroundColor Cyan
            } else {
                Write-Host "   → 跳过项目关联,仅配置 IntelliSense" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   ⊘ 未找到 UE 项目" -ForegroundColor Gray
        Write-Host '      可在运行时指定: scripts\setup_vscode_env.ps1 -UEProjectPath "路径"' -ForegroundColor Gray
    }
} elseif (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host "   ✓ 使用指定的项目: $UEProjectPath" -ForegroundColor Green
}
Write-Host ""

# ========================================
# 4. 更新/创建 c_cpp_properties.json
# ========================================
Write-Host "[ 步骤 4/5 ] 配置 IntelliSense..." -ForegroundColor Yellow

$configFile = Join-Path $PSScriptRoot "c_cpp_properties.json"
if (Test-Path $configFile) {
    # 更新现有配置
    $config = Get-Content $configFile -Raw | ConvertFrom-Json

    # 添加 compile_commands.json 支持(最准确的方式)
    $compileCommandsPath = "$($UEEnginePath.Replace('\', '/'))/compile_commands.json"
    if (-not ($config.configurations[0].PSObject.Properties.Name -contains "compileCommands")) {
        $config.configurations[0] | Add-Member -NotePropertyName "compileCommands" -NotePropertyValue $compileCommandsPath -Force
        Write-Host "   → 添加 compile_commands.json 支持" -ForegroundColor Cyan
    } else {
        $config.configurations[0].compileCommands = $compileCommandsPath
    }

    # 构建引擎包含路径(作为备用)
    $engineIncludes = @(
        "$($UEEnginePath.Replace('\', '/'))/Engine/Source/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Plugins/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Intermediate/Build/Win64/UnrealEditor/Inc/**"
    )

    # 如果是插件工作区,添加项目的 includePath
    if ($IsPlugin -and -not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
        $projectDir = Split-Path -Parent $UEProjectPath
        $engineIncludes += "$($projectDir.Replace('\', '/'))/Source/**"
        $engineIncludes += "$($projectDir.Replace('\', '/'))/Plugins/**"
        $engineIncludes += "$($projectDir.Replace('\', '/'))/Intermediate/Build/Win64/UnrealEditor/Inc/**"
        Write-Host "   → 添加项目源码路径: $projectDir/Source" -ForegroundColor Cyan
    }

    # 确保 includePath 是数组
    if ($config.configurations[0].includePath -is [string]) {
        $config.configurations[0].includePath = @($config.configurations[0].includePath)
    }

    # 保留工作区路径,移除旧的引擎路径
    $existingPaths = $config.configurations[0].includePath | Where-Object {
        $_ -notmatch "Epic Games|UnrealEngine|/Engine/|/Intermediate/Build"
    }
    $newIncludePath = @()
    $newIncludePath += $existingPaths
    $newIncludePath += $engineIncludes
    $config.configurations[0].includePath = $newIncludePath

    # 添加/更新 UE 必需的宏定义
    $requiredDefines = @(
        "WITH_EDITOR=1",
        "UE_BUILD_DEVELOPMENT=1",
        "UE_EDITOR=1",
        "PLATFORM_WINDOWS=1",
        "PLATFORM_MICROSOFT=1",
        "WIN64=1",
        "UBT_COMPILED_PLATFORM=Win64",
        "UNICODE=1",
        "_UNICODE=1"
    )

    if (-not $config.configurations[0].defines) {
        $config.configurations[0] | Add-Member -NotePropertyName "defines" -NotePropertyValue $requiredDefines -Force
    } else {
        # 合并现有的和必需的定义
        $existingDefines = $config.configurations[0].defines | Where-Object {
            $_ -notin $requiredDefines
        }
        $config.configurations[0].defines = $existingDefines + $requiredDefines
    }

    # 更新编译器路径
    if ($null -ne $foundMSVC) {
        $config.configurations[0].compilerPath = $foundMSVC.Replace('\', '/')
    }

    # 更新 browse 路径
    $browsePaths = @("`${workspaceFolder}/Source")
    $browsePaths += "$($UEEnginePath.Replace('\', '/'))/Engine/Source"
    if ($IsPlugin -and -not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
        $projectDir = Split-Path -Parent $UEProjectPath
        $browsePaths += "$($projectDir.Replace('\', '/'))/Source"
    }
    $config.configurations[0].browse.path = $browsePaths

    # 保存配置
    $jsonOutput = $config | ConvertTo-Json -Depth 100
    $jsonOutput = $jsonOutput -replace '\\\$\{workspaceFolder\}', '${workspaceFolder}'
    $jsonOutput | Set-Content $configFile -Encoding UTF8
    Write-Host "   ✓ 已更新 c_cpp_properties.json" -ForegroundColor Green

} else {
    # 自动创建新配置
    Write-Host "   → 创建默认 c_cpp_properties.json..." -ForegroundColor Cyan

    $engineIncludesNew = @(
        "`${workspaceFolder}/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Source/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Plugins/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Intermediate/Build/Win64/UnrealEditor/Inc/**"
    )

    # 如果是插件工作区且有项目路径,添加项目源码
    if ($IsPlugin -and -not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
        $projectDir = Split-Path -Parent $UEProjectPath
        $engineIncludesNew += "$($projectDir.Replace('\', '/'))/Source/**"
        $engineIncludesNew += "$($projectDir.Replace('\', '/'))/Plugins/**"
        $engineIncludesNew += "$($projectDir.Replace('\', '/'))/Intermediate/Build/Win64/UnrealEditor/Inc/**"
    }

    $newConfig = @{
        configurations = @(
            @{
                name = "Win64"
                compileCommands = "$($UEEnginePath.Replace('\', '/'))/compile_commands.json"
                includePath = $engineIncludesNew
                defines = @(
                    "WITH_EDITOR=1",
                    "UE_BUILD_DEVELOPMENT=1",
                    "UE_EDITOR=1",
                    "PLATFORM_WINDOWS=1",
                    "PLATFORM_MICROSOFT=1",
                    "WIN64=1",
                    "UBT_COMPILED_PLATFORM=Win64",
                    "UNICODE=1",
                    "_UNICODE=1"
                )
                compilerPath = if ($null -ne $foundMSVC) { $foundMSVC.Replace('\', '/') } else { "" }
                cppStandard = "c++20"
                cStandard = "c17"
                intelliSenseMode = "windows-msvc-x64"
                browse = @{
                    path = @(
                        "`${workspaceFolder}/Source",
                        "$($UEEnginePath.Replace('\', '/'))/Engine/Source"
                    )
                    limitSymbolsToIncludedHeaders = $true
                }
            }
        )
        version = 4
    }

    $jsonOutput = $newConfig | ConvertTo-Json -Depth 100
    $jsonOutput = $jsonOutput -replace '\\\$\{workspaceFolder\}', '${workspaceFolder}'
    $jsonOutput | Set-Content $configFile -Encoding UTF8
    Write-Host "   ✓ 已创建 c_cpp_properties.json" -ForegroundColor Green
}

# ========================================
# 5. 更新/创建 launch.json 和 tasks.json
# ========================================
Write-Host "[ 步骤 5/5 ] 配置编译和调试..." -ForegroundColor Yellow

# 更新或创建 launch.json
$launchFile = Join-Path $PSScriptRoot "launch.json"
if (Test-Path $launchFile) {
    $content = Get-Content $launchFile -Raw

    # 替换引擎路径(支持多种格式)
    $content = $content -replace '[A-Z]:/[^"]*?/Epic Games/UE_[\d\.]+', $UEEnginePath.Replace('\', '/')
    $content = $content -replace '[A-Z]:/[^"]*?/UnrealEngine', $UEEnginePath.Replace('\', '/')

    # 替换项目路径
    if (-not [string]::IsNullOrWhiteSpace($UEProjectPath) -and (Test-Path $UEProjectPath)) {
        $escapedPath = $UEProjectPath.Replace('\', '/')
        $quotedPath = '"' + $escapedPath + '"'
        $content = $content -replace '// ".*?\.uproject"', $quotedPath
        $content = $content -replace '"// .*?\.uproject"', $quotedPath
        Write-Host "   → 配置调试项目: $(Split-Path -Leaf $UEProjectPath)" -ForegroundColor Cyan
    }

    $content | Set-Content $launchFile -Encoding UTF8
    Write-Host "   ✓ 已更新 launch.json" -ForegroundColor Green
} else {
    Write-Host "   → launch.json 不存在,跳过创建" -ForegroundColor Gray
}

# 更新或创建 tasks.json
$tasksFile = Join-Path $PSScriptRoot "tasks.json"
if (Test-Path $tasksFile) {
    # 读取并解析现有的 tasks.json
    try {
        $tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
        $updated = $false

        # 提取项目名称(如果有项目路径)
        $projectName = ""
        if (-not [string]::IsNullOrWhiteSpace($UEProjectPath) -and (Test-Path $UEProjectPath)) {
            $projectName = (Get-Item $UEProjectPath).BaseName
        }

        foreach ($task in $tasks.tasks) {
            # 更新所有任务中的引擎路径和项目路径
            if ($task.args) {
                for ($i = 0; $i -lt $task.args.Count; $i++) {
                    $arg = $task.args[$i]

                    # 替换引擎批处理文件路径(带引号)
                    if ($arg -match "Engine/Build/BatchFiles|Engine/Binaries/DotNET") {
                        # 提取原始路径中的文件名部分
                        $fileName = ""
                        if ($arg -match "(Build\.bat|RunUAT\.bat|GenerateProjectFiles\.bat|UnrealBuildTool\.exe)") {
                            $fileName = $matches[1]
                        }

                        if ($fileName -eq "Build.bat") {
                            $task.args[$i] = "'$($UEEnginePath.Replace('\', '/'))/Engine/Build/BatchFiles/Build.bat'"
                        } elseif ($fileName -eq "RunUAT.bat") {
                            $task.args[$i] = "'$($UEEnginePath.Replace('\', '/'))/Engine/Build/BatchFiles/RunUAT.bat'"
                        } elseif ($fileName -eq "GenerateProjectFiles.bat") {
                            $task.args[$i] = "'$($UEEnginePath.Replace('\', '/'))/Engine/Build/BatchFiles/GenerateProjectFiles.bat'"
                        } elseif ($fileName -eq "UnrealBuildTool.exe") {
                            $task.args[$i] = "'$($UEEnginePath.Replace('\', '/'))/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.exe'"
                        }
                        $updated = $true
                    }

                    # 替换项目文件路径(带引号)
                    if ($arg -match "\.uproject" -and -not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
                        $task.args[$i] = "'$($UEProjectPath.Replace('\', '/'))'"
                        $updated = $true
                    }

                    # 替换项目名称(如 CPPEditor)
                    if (-not [string]::IsNullOrWhiteSpace($projectName) -and $arg -match "^\w+Editor$" -and $arg -notmatch "UnrealEditor") {
                        $task.args[$i] = "${projectName}Editor"
                        $updated = $true
                    }
                }
            }

            # 确保 PowerShell 任务有正确的 options 配置
            if ($task.type -eq "shell" -and $task.command -eq "&") {
                if (-not $task.options) {
                    $task | Add-Member -NotePropertyName "options" -NotePropertyValue @{
                        shell = @{
                            executable = "powershell.exe"
                            args = @("-ExecutionPolicy", "Bypass", "-Command")
                        }
                    } -Force
                    $updated = $true
                } elseif (-not $task.options.shell) {
                    $task.options | Add-Member -NotePropertyName "shell" -NotePropertyValue @{
                        executable = "powershell.exe"
                        args = @("-ExecutionPolicy", "Bypass", "-Command")
                    } -Force
                    $updated = $true
                }
            }
        }

        if ($updated) {
            $jsonOutput = $tasks | ConvertTo-Json -Depth 100
            $jsonOutput = $jsonOutput -replace '\\\$\{workspaceFolder\}', '${workspaceFolder}'
            $jsonOutput = $jsonOutput -replace '"\$msCompile"', '$msCompile'
            $jsonOutput | Set-Content $tasksFile -Encoding UTF8
            Write-Host "   ✓ 已更新 tasks.json" -ForegroundColor Green
        } else {
            Write-Host "   → tasks.json 无需更新" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "   [!]️  JSON 解析失败,使用文本替换模式" -ForegroundColor Yellow
        $content = Get-Content $tasksFile -Raw

        # 替换引擎路径(处理带引号的路径)
        $content = $content -replace "'[A-Z]:/[^']*?/Epic Games/UE_[\d\.]+", "'$($UEEnginePath.Replace('\', '/'))"
        $content = $content -replace "'[A-Z]:/[^']*?/UnrealEngine", "'$($UEEnginePath.Replace('\', '/'))"

        # 替换项目路径
        if (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
            $content = $content -replace "'[A-Z]:/[^']*?\.uproject'", "'$($UEProjectPath.Replace('\', '/'))'"
        }

        $content | Set-Content $tasksFile -Encoding UTF8
        Write-Host "   ✓ 已更新 tasks.json (文本模式)" -ForegroundColor Green
    }
} elseif (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host "   → tasks.json 不存在,未提供项目路径,跳过创建" -ForegroundColor Gray
}
Write-Host ""

# ========================================
# 6. 生成配置摘要
# ========================================
Write-Host "配置摘要" -ForegroundColor Yellow
Write-Host ""

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                     VSCode 配置完成!                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "[I] 配置信息:" -ForegroundColor Cyan
Write-Host "   工作区类型:  $WorkspaceType" -ForegroundColor White
Write-Host "   UE 引擎:     $UEEnginePath" -ForegroundColor White
if (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host "   UE 项目:     $UEProjectPath" -ForegroundColor White
}
if ($null -ne $foundMSVC) {
    Write-Host "   MSVC:        $foundVS" -ForegroundColor White
}
Write-Host ""

Write-Host "[SRC] 下一步操作:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1. 重新加载 VSCode 窗口" -ForegroundColor White
Write-Host "      → 按 F1 或 Ctrl+Shift+P" -ForegroundColor Gray
Write-Host "      → 输入 'Reload Window' 并回车" -ForegroundColor Gray
Write-Host ""
Write-Host "   2. 等待 IntelliSense 索引完成" -ForegroundColor White
Write-Host "      → 右下角会显示 'Indexing...' 进度" -ForegroundColor Gray
Write-Host "      → 首次索引可能需要几分钟时间" -ForegroundColor Gray
Write-Host ""

if ($IsPlugin -and [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host "[TIP] 提示:" -ForegroundColor Cyan
    Write-Host "   当前仅配置了 IntelliSense,未关联调试项目" -ForegroundColor Cyan
    Write-Host "   如需配置调试功能,可重新运行并指定项目:" -ForegroundColor Gray
    Write-Host '   scripts\setup_vscode_env.ps1 -UEProjectPath "路径\项目.uproject"' -ForegroundColor Gray
    Write-Host ""
}

Write-Host "[DONE] VSCode 环境配置完成!" -ForegroundColor Green
Write-Host ""
