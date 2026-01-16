# ========================================
# VSCode UE 
#  VSCode  UE 
# 
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

        VSCode UE                                 



  -  UE 
  -  Visual Studio  MSVC 
  - //
  -  UE 
  - /IntelliSense

:
    scripts\setup_vscode_env.ps1 []

:
    -UEProjectPath <>   UE  .uproject 
    -UEEnginePath <>    UE 
    -IsPlugin              
    -IsProject             
    -Help                  

:
    # 1. 
    scripts\setup_vscode_env.ps1

    # 2.  + 
    scripts\setup_vscode_env.ps1 -UEProjectPath "D:\UnrealProjects\MyProject\MyProject.uproject"

    # 3. 
    scripts\setup_vscode_env.ps1 -UEEnginePath "F:\Epic Games\UE_5.4"

:
    :  .uplugin 
    :  .uproject 
    : 

:
    - c_cpp_properties.json  (IntelliSense )
    - tasks.json             ()
    - launch.json            ()
    - settings.json          ()

"@
    exit
}

# ========================================
# 0. 
# ========================================
Write-Host "[  0/5 ] ..." -ForegroundColor Yellow

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$WorkspaceType = "Unknown"
$PluginFile = $null
$ProjectFile = $null

# 
$upluginFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.uplugin" -ErrorAction SilentlyContinue
if ($upluginFiles.Count -gt 0) {
    $PluginFile = $upluginFiles[0].FullName
    $WorkspaceType = "Plugin"
    if (-not $IsProject) { $IsPlugin = $true }
}

# 
$uprojectFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.uproject" -ErrorAction SilentlyContinue
if ($uprojectFiles.Count -gt 0) {
    $ProjectFile = $uprojectFiles[0].FullName
    $WorkspaceType = "Project"
    if (-not $IsPlugin) { $IsProject = $true }
}

# 
Write-Host "   : " -NoNewline
Write-Host "$WorkspaceRoot" -ForegroundColor Gray
Write-Host "   : " -NoNewline
switch ($WorkspaceType) {
    "Plugin" {
        Write-Host " " -ForegroundColor Green
        Write-Host "   :   " -NoNewline
        Write-Host "$PluginFile" -ForegroundColor Gray
    }
    "Project" {
        Write-Host " " -ForegroundColor Green
        Write-Host "   :   " -NoNewline
        Write-Host "$ProjectFile" -ForegroundColor Gray
        $UEProjectPath = $ProjectFile
    }
    default {
        Write-Host " " -ForegroundColor Cyan
        Write-Host "   ( .uplugin  .uproject )" -ForegroundColor Gray
    }
}
Write-Host ""

# ========================================
# 1.  UE 
# ========================================
Write-Host "[  1/5 ]  Unreal Engine ..." -ForegroundColor Yellow

$UEPaths = @()
$selectedUE = $null

# 
if (-not [string]::IsNullOrWhiteSpace($UEEnginePath)) {
    if (Test-Path "$UEEnginePath/Engine" -ErrorAction SilentlyContinue) {
        $selectedUE = @{
            Version = "User Specified"
            Path = $UEEnginePath
            Type = "Manual"
        }
        Write-Host "    : $UEEnginePath" -ForegroundColor Green
    } else {
        Write-Host "    : $UEEnginePath" -ForegroundColor Red
        exit 1
    }
} else {
    #  UE 
    # 
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
                # 
            }
        }
    }

    if ($UEPaths.Count -eq 0) {
        Write-Host "     UE " -ForegroundColor Red
        Write-Host "    Unreal Engine  -UEEnginePath " -ForegroundColor Red
        exit 1
    }

    Write-Host "     $($UEPaths.Count)  UE " -ForegroundColor Green
    $UEPaths | ForEach-Object {
        Write-Host "     - $($_.Version) ($($_.Type)): $($_.Path)" -ForegroundColor Gray
    }

    # 
    $selectedUE = $UEPaths[0]
    if ($UEPaths.Count -gt 1) {
        Write-Host ""
        Write-Host "   :" -ForegroundColor Yellow
        for ($i = 0; $i -lt $UEPaths.Count; $i++) {
            Write-Host "   [$i] $($UEPaths[$i].Version) - $($UEPaths[$i].Path)"
        }
        $choice = Read-Host "    (: 0)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 0 }
        $selectedUE = $UEPaths[[int]$choice]
    }
}

$UEEnginePath = $selectedUE.Path
Write-Host "   : $UEEnginePath" -ForegroundColor Green
Write-Host ""

# ========================================
# 2.  Visual Studio  MSVC
# ========================================
Write-Host "[  2/5 ]  Visual Studio..." -ForegroundColor Yellow

$VSBasePaths = @()
$VSBasePaths += "C:\Program Files\Microsoft Visual Studio\2022"
$VSBasePaths += "C:\Program Files (x86)\Microsoft Visual Studio\2022"

# 
foreach ($drive in $AvailableDrives) {
    try {
        # 
        if (Test-Path $drive -ErrorAction SilentlyContinue) {
            $VSBasePaths += Join-Path $drive "VisualStudio\2022"
            $VSBasePaths += Join-Path $drive "Visual Studio\2022"
            $VSBasePaths += Join-Path $drive "VS2022"
        }
    }
    catch {
        # 
    }
}

$VSEditions = @("Enterprise", "Professional", "Community", "BuildTools")
$foundVS = $null
$foundMSVC = $null

foreach ($basePath in $VSBasePaths) {
    if ($null -ne $foundMSVC) { break }

    # 
    if ([string]::IsNullOrWhiteSpace($basePath)) { continue }

    try {
        #  Edition 
        $directMsvcPath = Join-Path $basePath "VC\Tools\MSVC"
        if (Test-Path $directMsvcPath -ErrorAction SilentlyContinue) {
            $msvcVersions = Get-ChildItem $directMsvcPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            if ($msvcVersions.Count -gt 0) {
                $foundVS = "Direct Install ($basePath)"
                $foundMSVC = Join-Path $msvcVersions[0].FullName "bin\Hostx64\x64\cl.exe"
                break
            }
        }

        #  Edition 
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
        # 
    }
}

if ($null -eq $foundMSVC) {
    Write-Host "      Visual Studio 2022" -ForegroundColor Yellow
    Write-Host "    Visual Studio 2022  C++ " -ForegroundColor Yellow
} else {
    Write-Host "     Visual Studio 2022 $foundVS" -ForegroundColor Green
    Write-Host "    MSVC : $foundMSVC" -ForegroundColor Green
}
Write-Host ""

# ========================================
# 3.  UE 
# ========================================
Write-Host "[  3/5 ]  UE ..." -ForegroundColor Yellow

if ([string]::IsNullOrWhiteSpace($UEProjectPath) -and $IsPlugin) {
    # 
    Write-Host "   →  UE ..." -ForegroundColor Cyan

    # 
    $currentDir = Split-Path -Parent $WorkspaceRoot
    $foundProjects = @()

    # 3
    for ($i = 0; $i -lt 3; $i++) {
        if ([string]::IsNullOrWhiteSpace($currentDir)) { break }

        $uprojectFiles = Get-ChildItem -Path $currentDir -Filter "*.uproject" -ErrorAction SilentlyContinue
        if ($uprojectFiles.Count -gt 0) {
            foreach ($proj in $uprojectFiles) {
                $foundProjects += $proj.FullName
                Write-Host "      : $($proj.FullName)" -ForegroundColor Gray
            }
        }

        $currentDir = Split-Path -Parent $currentDir
    }

    # 
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
                    Write-Host "      : $($_.FullName)" -ForegroundColor Gray
                }
            }
        }
    }

    if ($foundProjects.Count -gt 0) {
        Write-Host ""
        Write-Host "     $($foundProjects.Count)  UE " -ForegroundColor Green

        if ($foundProjects.Count -eq 1) {
            $UEProjectPath = $foundProjects[0]
            Write-Host "   → : $UEProjectPath" -ForegroundColor Cyan
        } else {
            Write-Host "   :" -ForegroundColor Yellow
            for ($i = 0; $i -lt $foundProjects.Count; $i++) {
                Write-Host "   [$i] $(Split-Path -Leaf $foundProjects[$i]) - $($foundProjects[$i])"
            }
            Write-Host "   [N]  IntelliSense" -ForegroundColor Gray

            $choice = Read-Host "    (: N)"
            if (-not [string]::IsNullOrWhiteSpace($choice) -and $choice -ne "N" -and $choice -ne "n") {
                $UEProjectPath = $foundProjects[[int]$choice]
                Write-Host "   → : $UEProjectPath" -ForegroundColor Cyan
            } else {
                Write-Host "   →  IntelliSense" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   ⊘  UE " -ForegroundColor Gray
        Write-Host "      : scripts\setup_vscode_env.ps1 -UEProjectPath `"`"" -ForegroundColor Gray
    }
} elseif (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host "    : $UEProjectPath" -ForegroundColor Green
}
Write-Host ""

# ========================================
# 4. / c_cpp_properties.json
# ========================================
Write-Host "[  4/5 ]  IntelliSense..." -ForegroundColor Yellow

$configFile = Join-Path $PSScriptRoot "c_cpp_properties.json"
if (Test-Path $configFile) {
    # 
    $config = Get-Content $configFile -Raw | ConvertFrom-Json

    #  compile_commands.json 
    $compileCommandsPath = "$($UEEnginePath.Replace('\', '/'))/compile_commands.json"
    if (-not ($config.configurations[0].PSObject.Properties.Name -contains "compileCommands")) {
        $config.configurations[0] | Add-Member -NotePropertyName "compileCommands" -NotePropertyValue $compileCommandsPath -Force
        Write-Host "   →  compile_commands.json " -ForegroundColor Cyan
    } else {
        $config.configurations[0].compileCommands = $compileCommandsPath
    }

    # 
    $engineIncludes = @(
        "$($UEEnginePath.Replace('\', '/'))/Engine/Source/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Plugins/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Intermediate/Build/Win64/UnrealEditor/Inc/**"
    )

    #  includePath
    if ($IsPlugin -and -not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
        $projectDir = Split-Path -Parent $UEProjectPath
        $engineIncludes += "$($projectDir.Replace('\', '/'))/Source/**"
        $engineIncludes += "$($projectDir.Replace('\', '/'))/Plugins/**"
        $engineIncludes += "$($projectDir.Replace('\', '/'))/Intermediate/Build/Win64/UnrealEditor/Inc/**"
        Write-Host "   → : $projectDir/Source" -ForegroundColor Cyan
    }

    #  includePath 
    if ($config.configurations[0].includePath -is [string]) {
        $config.configurations[0].includePath = @($config.configurations[0].includePath)
    }

    # 
    $existingPaths = $config.configurations[0].includePath | Where-Object {
        $_ -notmatch "Epic Games|UnrealEngine|/Engine/|/Intermediate/Build"
    }
    $newIncludePath = @()
    $newIncludePath += $existingPaths
    $newIncludePath += $engineIncludes
    $config.configurations[0].includePath = $newIncludePath

    # / UE 
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
        # 
        $existingDefines = $config.configurations[0].defines | Where-Object {
            $_ -notin $requiredDefines
        }
        $config.configurations[0].defines = $existingDefines + $requiredDefines
    }

    # 
    if ($null -ne $foundMSVC) {
        $config.configurations[0].compilerPath = $foundMSVC.Replace('\', '/')
    }

    #  browse 
    $browsePaths = @("`${workspaceFolder}/Source")
    $browsePaths += "$($UEEnginePath.Replace('\', '/'))/Engine/Source"
    if ($IsPlugin -and -not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
        $projectDir = Split-Path -Parent $UEProjectPath
        $browsePaths += "$($projectDir.Replace('\', '/'))/Source"
    }
    $config.configurations[0].browse.path = $browsePaths

    # 
    $jsonOutput = $config | ConvertTo-Json -Depth 100
    $jsonOutput = $jsonOutput -replace '\\\$\{workspaceFolder\}', '${workspaceFolder}'
    $jsonOutput | Set-Content $configFile -Encoding UTF8
    Write-Host "     c_cpp_properties.json" -ForegroundColor Green

} else {
    # 
    Write-Host "   →  c_cpp_properties.json..." -ForegroundColor Cyan

    $engineIncludesNew = @(
        "`${workspaceFolder}/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Source/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Plugins/**",
        "$($UEEnginePath.Replace('\', '/'))/Engine/Intermediate/Build/Win64/UnrealEditor/Inc/**"
    )

    # 
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
    Write-Host "     c_cpp_properties.json" -ForegroundColor Green
}

# ========================================
# 5. / launch.json  tasks.json
# ========================================
Write-Host "[  5/5 ] ..." -ForegroundColor Yellow

#  launch.json
$launchFile = Join-Path $PSScriptRoot "launch.json"
if (Test-Path $launchFile) {
    $content = Get-Content $launchFile -Raw

    # 
    $content = $content -replace '[A-Z]:/[^"]*?/Epic Games/UE_[\d\.]+', $UEEnginePath.Replace('\', '/')
    $content = $content -replace '[A-Z]:/[^"]*?/UnrealEngine', $UEEnginePath.Replace('\', '/')

    # 
    if (-not [string]::IsNullOrWhiteSpace($UEProjectPath) -and (Test-Path $UEProjectPath)) {
        $content = $content -replace '// ".*?\.uproject"', "`"$($UEProjectPath.Replace('\', '/'))`""
        $content = $content -replace '"// .*?\.uproject"', "`"$($UEProjectPath.Replace('\', '/'))`""
        Write-Host "   → : $(Split-Path -Leaf $UEProjectPath)" -ForegroundColor Cyan
    }

    $content | Set-Content $launchFile -Encoding UTF8
    Write-Host "     launch.json" -ForegroundColor Green
} else {
    Write-Host "   → launch.json " -ForegroundColor Gray
}

#  tasks.json
$tasksFile = Join-Path $PSScriptRoot "tasks.json"
if (Test-Path $tasksFile) {
    #  tasks.json
    try {
        $tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
        $updated = $false

        # 
        $projectName = ""
        if (-not [string]::IsNullOrWhiteSpace($UEProjectPath) -and (Test-Path $UEProjectPath)) {
            $projectName = (Get-Item $UEProjectPath).BaseName
        }

        foreach ($task in $tasks.tasks) {
            # 
            if ($task.args) {
                for ($i = 0; $i -lt $task.args.Count; $i++) {
                    $arg = $task.args[$i]

                    # 
                    if ($arg -match "Engine/Build/BatchFiles|Engine/Binaries/DotNET") {
                        # 
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

                    # 
                    if ($arg -match "\.uproject" -and -not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
                        $task.args[$i] = "'$($UEProjectPath.Replace('\', '/'))'"
                        $updated = $true
                    }

                    #  CPPEditor
                    if (-not [string]::IsNullOrWhiteSpace($projectName) -and $arg -match "^\w+Editor$" -and $arg -notmatch "UnrealEditor") {
                        $task.args[$i] = "${projectName}Editor"
                        $updated = $true
                    }
                }
            }

            #  PowerShell  options 
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
            Write-Host "     tasks.json" -ForegroundColor Green
        } else {
            Write-Host "   → tasks.json " -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "     JSON " -ForegroundColor Yellow
        $content = Get-Content $tasksFile -Raw

        # 
        $content = $content -replace "'[A-Z]:/[^']*?/Epic Games/UE_[\d\.]+", "'$($UEEnginePath.Replace('\', '/'))"
        $content = $content -replace "'[A-Z]:/[^']*?/UnrealEngine", "'$($UEEnginePath.Replace('\', '/'))"

        # 
        if (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
            $content = $content -replace "'[A-Z]:/[^']*?\.uproject'", "'$($UEProjectPath.Replace('\', '/'))'"
            #  - 
            $projectName = (Get-Item $UEProjectPath).BaseName
            $pattern = "`"\w+Editor`"(?=,?\s*`"Win64`")"
            $replacement = "`"`"${projectName}Editor`"`""
            $content = $content -replace $pattern, $replacement
        }

        $content | Set-Content $tasksFile -Encoding UTF8
        Write-Host "     tasks.json ()" -ForegroundColor Green
    }
} elseif (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host "   → tasks.json " -ForegroundColor Gray
}
Write-Host ""

# ========================================
# 6. 
# ========================================
Write-Host "" -ForegroundColor Yellow
Write-Host ""

Write-Host "" -ForegroundColor Green
Write-Host "                     VSCode                         " -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host ""

Write-Host " :" -ForegroundColor Cyan
Write-Host "   :  $WorkspaceType" -ForegroundColor White
Write-Host "   UE :     $UEEnginePath" -ForegroundColor White
if (-not [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host "   UE :     $UEProjectPath" -ForegroundColor White
}
if ($null -ne $foundMSVC) {
    Write-Host "   MSVC:        $foundVS" -ForegroundColor White
}
Write-Host ""

Write-Host " :" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1.  VSCode " -ForegroundColor White
Write-Host "      →  F1  Ctrl+Shift+P" -ForegroundColor Gray
Write-Host "      →  'Reload Window' " -ForegroundColor Gray
Write-Host ""
Write-Host "   2.  IntelliSense " -ForegroundColor White
Write-Host "      →  'Indexing...' " -ForegroundColor Gray
Write-Host "      → " -ForegroundColor Gray
Write-Host ""

if ($IsPlugin -and [string]::IsNullOrWhiteSpace($UEProjectPath)) {
    Write-Host " :" -ForegroundColor Cyan
    Write-Host "    IntelliSense" -ForegroundColor Cyan
    Write-Host "   :" -ForegroundColor Gray
    Write-Host "   scripts\setup_vscode_env.ps1 -UEProjectPath `"\.uproject`"" -ForegroundColor Gray
    Write-Host ""
}

Write-Host " VSCode " -ForegroundColor Green
Write-Host ""
