# VSCode UE 配置脚本实现参考

此文档详细说明 `setup_vscode_env.ps1` 和相关脚本的关键实现细节，供扩展和参考使用。

## 核心设计原则

### 1. 路径处理

#### 空格路径支持

所有路径处理均正确处理带空格的路径（如 "D:\Unreal Projects\My Game"）：

```powershell
# 正确的路径使用方式
$arg = "'$($UEEnginePath.Replace('\', '/'))/Engine/Build/BatchFiles/Build.bat'"

# 任务配置中的 args 数组
args = @(
    "'$($UEEnginePath.Replace('\', '/'))/Engine/Build/BatchFiles/Build.bat'",
    "BuildPlugin",
    ...
)
```

#### 多盘符检测

遍历所有实际存在的盘符，搜索 UE 引擎安装：

```powershell
$AvailableDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
    $_.Root -match '^[A-Z]:\\$' -and (Test-Path $_.Root -ErrorAction SilentlyContinue)
} | ForEach-Object { $_.Name + ":" }
```

### 2. 工作区类型识别

#### 插件工作区检测

```powershell
$upluginFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.uplugin" -ErrorAction SilentlyContinue
if ($upluginFiles.Count -gt 0) {
    $PluginFile = $upluginFiles[0].FullName
    $WorkspaceType = "Plugin"
    $IsPlugin = $true
}
```

#### 项目工作区检测

```powershell
$uprojectFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.uproject" -ErrorAction SilentlyContinue
if ($uprojectFiles.Count -gt 0) {
    $ProjectFile = $uprojectFiles[0].FullName
    $WorkspaceType = "Project"
    $IsProject = $true
}
```

#### 智能项目关联（插件工作区）

自动向上搜索父目录中的 UE 项目（最多3层）：

```powershell
$currentDir = Split-Path -Parent $WorkspaceRoot
$foundProjects = @()

for ($i = 0; $i -lt 3; $i++) {
    if ([string]::IsNullOrWhiteSpace($currentDir)) { break }

    $uprojectFiles = Get-ChildItem -Path $currentDir -Filter "*.uproject" -ErrorAction SilentlyContinue
    if ($uprojectFiles.Count -gt 0) {
        foreach ($proj in $uprojectFiles) {
            $foundProjects += $proj.FullName
        }
    }

    $currentDir = Split-Path -Parent $currentDir
}
```

### 3. UE 引擎路径检测

#### Epic Games Launcher 路径

支持两个 Epic Games 常见路径：

```powershell
$EpicGamesPaths = @(
    "Program Files\Epic Games",    # Windows 标准路径
    "Epic Games"                  # 其他盘符根路径
)

foreach ($drive in $AvailableDrives) {
    foreach ($epPath in $EpicGamesPaths) {
        $fullPath = Join-Path $drive $epPath
        # 检查 UE_XX 目录
        Get-ChildItem $fullPath -Directory | Where-Object { $_.Name -match "^UE_" }
    }
}
```

#### 自定义编译引擎路径

支持用户自定义编译的 UnrealEngine：

```powershell
foreach ($drive in $AvailableDrives) {
    $customPath = Join-Path $drive "UnrealEngine"
    if (Test-Path "$customPath\Engine" -ErrorAction SilentlyContinue) {
        $UEPaths += @{
            Version = "Custom ($drive)"
            Path = $customPath
            Type = "Source Build"
        }
    }
}
```

### 4. Visual Studio 检测

#### 版本和 Edition 检测

```powershell
$VSBasePaths = @()
$VSBasePaths += "C:\Program Files\Microsoft Visual Studio\2022"
$VSBasePaths += "C:\Program Files (x86)\Microsoft Visual Studio\2022"

# 遍历所有盘符
foreach ($drive in $AvailableDrives) {
    if (Test-Path $drive -ErrorAction SilentlyContinue) {
        $VSBasePaths += Join-Path $drive "VisualStudio\2022"
        $VSBasePaths += Join-Path $drive "Visual Studio\2022"
        $VSBasePaths += Join-Path $drive "VS2022"
    }
}
```

#### MSVC 编译器路径定位

```powershell
$VSEditions = @("Enterprise", "Professional", "Community", "BuildTools")

# 优先检查直接安装（无 Edition 子文件夹）
$directMsvcPath = Join-Path $basePath "VC\Tools\MSVC"
if (Test-Path $directMsvcPath -ErrorAction SilentlyContinue) {
    $msvcVersions = Get-ChildItem $directMsvcPath -Directory | Sort-Object Name -Descending
    if ($msvcVersions.Count -gt 0) {
        $foundVS = "Direct Install ($basePath)"
        $foundMSVC = Join-Path $msvcVersions[0].FullName "bin\Hostx64\x64\cl.exe"
    }
}

# 然后检查标准 Edition 子文件夹
foreach ($edition in $VSEditions) {
    $editionPath = Join-Path $basePath $edition
    $msvcPath = Join-Path $editionPath "VC\Tools\MSVC"
    if (Test-Path $msvcPath -ErrorAction SilentlyContinue) {
        # 获取最新版本
    }
}
```

### 5. 配置文件处理

#### c_cpp_properties.json 生成

**includePath 策略：**

- 插件工作区：`${workspaceFolder}/**` + 项目源码 + 引擎 + 引擎插件
- 项目工作区：`${workspaceFolder}/**` + 引擎 + 项目插件 + 引擎

```json
{
  "configurations": [
    {
      "name": "Win64",
      "includePath": [
        "`${workspaceFolder}/**",
        "引擎/Engine/Source/**",
        "引擎/Engine/Plugins/**",
        "项目/Source/**",
        "项目/Plugins/**"
      ],
      "defines": [
        "WITH_EDITOR=1",
        "UE_BUILD_DEVELOPMENT=1",
        "UE_EDITOR=1",
        "PLATFORM_WINDOWS=1",
        "PLATFORM_MICROSOFT=1",
        "WIN64=1",
        "UBT_COMPILED_PLATFORM=Win64",
        "UNICODE=1"
      ]
    }
  ]
}
```

#### tasks.json PowerShell Shell 配置

确保 PowerShell 任务使用正确的 shell 配置：

```json
{
  "type": "shell",
  "command": "&",
  "args": [
      "Engine/Build/BatchFiles/Build.bat"
  ],
  "options": {
      "shell": {
          "executable": "powershell.exe",
          "args": ["-ExecutionPolicy", "Bypass", "-Command"]
      }
  }
}
```

### 6. compile_commands.json 支持

使用 UE 引擎根目录的 compile_commands.json 获取最准确的编译参数：

```json
{
  "configurations": [
    {
      "compileCommands": "引擎/compile_commands.json",
      "includePath": [
        "引擎/Engine/Source/**",
        "引擎/Engine/Plugins/**",
        "项目/Source/**",
        "项目/Plugins/**"
      ]
    }
  ]
}
```

## OpenCode LSP 配置

### opencode.json 结构

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
      "clangd": {
          "command": ["clangd", "--compile-commands-dir=<引擎路径>"],
          "extensions": [".c", ".cpp", ".cc", ".cxx", ".c++", ".h", ".hpp", ".hh", ".hxx", ".h++"],
          "disabled": false
      }
  }
}
```

### clangd 自动安装

使用 winget 自动安装 LLVM.LLVM：

```powershell
winget install LLVM.LLVM --accept-package-agreements --accept-source-agreements

# 验证安装
$verifyVersion = & clangd --version
if ($LASTEXITCODE -eq 0) {
    Write-Host "   [OK] clangd 已安装" -ForegroundColor Green
}
```

### PATH 更新

```powershell
# 添加 LLVM 到用户 PATH
$newPath = "$userPath;C:\Program Files\LLVM\bin"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# 验证
$verifyPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
```

## 关键实现细节

### 1. 错误处理

所有操作使用 try-catch 捕获错误，确保流程稳定：

```powershell
try {
    # 检测或操作
}
catch {
    Write-Host "   ❌ 操作失败" -ForegroundColor Red
    Write-Host "   错误: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

### 2. 用户交互

#### 引擎版本选择

```powershell
if ($UEPaths.Count -gt 1) {
    Write-Host "   选择要使用的引擎版本:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $UEPaths.Count; $i++) {
        Write-Host "   [$i] $($UEPaths[$i].Version) - $($UEPaths[$i].Path)"
    }
    $choice = Read-Host "   请输入序号 (默认: 0)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 0 }
    $selectedUE = $UEPaths[[int]$choice]
}
```

#### 项目路径选择

```powershell
if ($foundProjects.Count -gt 0) {
    Write-Host "   选择要关联的项目（用于调试）:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $foundProjects.Count; $i++) {
        Write-Host "   [$i] $(Split-Path -Leaf $foundProjects[$i])"
    }
    $choice = Read-Host "   请输入序号 (默认: N)"
}
```

### 3. 配置保留策略

所有配置操作均保留用户自定义：

```powershell
# 检查现有配置文件
if (Test-Path $configFile) {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json

    # 保留现有 includePath
    $existingPaths = $config.configurations[0].includePath

    # 添加新的路径
    $newIncludePath = $existingPaths + $engineIncludes
}

# 仅更新必要的字段
$config.configurations[0].compileCommands = $compileCommandsPath
```

### 4. 文本替换作为备用

当 JSON 解析失败时，使用正则表达式文本替换：

```powershell
catch {
    Write-Host "   [WARN] JSON 解析失败，使用文本替换模式" -ForegroundColor Yellow

    # 替换引擎路径（正则表达式）
    $content = $content -replace "'[A-Z]:/[^']*?/Epic Games/UE_[\d\.]+", "'$UEEnginePath'"
    $content = $content -replace "'[A-Z]:/[^']*?/UnrealEngine", "'$UEEnginePath'"

    # 替换项目路径
    $content = $content -replace "'[A-Z]:/[^']*?\.uproject'", "'$UEProjectPath'"
}
```

## 扩展指南

### 添加新的配置模板

要扩展脚本以支持新的配置需求：

1. **新的编译器** - 在 MSVC 检测部分添加新的编译器路径检测
2. **新的 IDE** - 添加对其他 IDE（如 CLion、Rider）的配置支持
3. **新的配置文件** - 添加对其他配置文件类型的支持

### 修改现有功能

1. **工作区类型** - 添加新的工作区类型识别逻辑
2. **路径检测** - 改进路径检测算法，支持更多路径模式
3. **配置生成** - 增强配置文件模板，添加新的设置项

## 测试建议

1. **测试多盘符环境** - 确保脚本在不同盘符配置下正常工作
2. **测试空格路径** - 验证所有带空格的路径正确处理
3. **测试工作区类型** - 分别测试插件工作区、项目工作区、源码工作区
4. **测试自动检测** - 验证自动检测的准确性
5. **测试手动指定** - 确保手动指定路径优先级正确

## 常见问题

### Q: 如何切换到不同的 UE 版本？

**A:** 重新运行脚本并选择不同的版本，或使用 `-UEEnginePath` 参数强制指定。

### Q: 如何为多个项目配置？

**A:** 运行 `scripts\setup_vscode_env.ps1` 并选择其中一个项目。可以在 `launch.json` 中手动添加其他项目配置。

### Q: 配置后 IntelliSense 仍然无法识别引擎头文件？

**A:**
1. 重新加载 VSCode 窗口（F1 → Reload Window）
2. 运行 "Generate Project Files" 任务
3. 检查 `c_cpp_properties.json` 中的路径是否正确
4. 运行 "Rebuild IntelliSense Database" 任务

### Q: OpenCode LSP 如何验证是否工作？

**A:**
1. 重启 opencode
2. 打开任意 C/C++ 文件
3. 检查 opencode 日志确认 clangd 已启动
4. 使用 `lsp` 工具测试功能（如跳转到定义）
