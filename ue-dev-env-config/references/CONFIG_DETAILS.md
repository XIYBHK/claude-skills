# VSCode 配置文件详解

本文档详细说明生成的各配置文件的内容和用途。

## c_cpp_properties.json

### IntelliSense 配置

```json
{
  "configurations": [
    {
      "name": "Win64",
      "compileCommands": "F:/Epic Games/UE_5.4/compile_commands.json",
      "includePath": [
        "${workspaceFolder}/**",
        "F:/Epic Games/UE_5.4/Engine/Source/**",
        "F:/Epic Games/UE_5.4/Engine/Plugins/**",
        "F:/Epic Games/UE_5.4/Engine/Intermediate/Build/Win64/UnrealEditor/Inc/**",
        "F:/Unreal Projects/MyProject/Source/**",
        "F:/Unreal Projects/MyProject/Plugins/**",
        "F:/Unreal Projects/MyProject/Intermediate/Build/Win64/UnrealEditor/Inc/**"
      ],
      "defines": [
        "WITH_EDITOR=1",
        "UE_BUILD_DEVELOPMENT=1",
        "UE_EDITOR=1",
        "PLATFORM_WINDOWS=1",
        "PLATFORM_MICROSOFT=1",
        "WIN64=1",
        "UBT_COMPILED_PLATFORM=Win64",
        "UNICODE=1",
        "_UNICODE=1"
      ],
      "compilerPath": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.xx/bin/Hostx64/x64/cl.exe",
      "cppStandard": "c++20",
      "cStandard": "c17",
      "intelliSenseMode": "windows-msvc-x64",
      "browse": {
        "path": [
          "${workspaceFolder}/Source",
          "F:/Epic Games/UE_5.4/Engine/Source",
          "F:/Unreal Projects/MyProject/Source"
        ],
        "limitSymbolsToIncludedHeaders": true
      }
    }
  ],
  "version": 4
}
```

### 关键配置项

| 项 | 说明 |
|-----|------|
| `compileCommands` | 最准确的编译参数来源（UE 引擎生成） |
| `includePath` | 头文件搜索路径（引擎、项目、插件、Intermediate） |
| `defines` | UE 必需宏定义（PLATFORM_MICROSOFT、UBT_COMPILED_PLATFORM 等） |
| `compilerPath` | MSVC 编译器路径（自动检测 VS2022） |
| `browse.path` | "转到定义" 功能的搜索路径 |

## tasks.json

### 编译任务配置

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build Plugin - Development Editor",
      "type": "shell",
      "command": "&",
      "args": [
        "'F:/Epic Games/UE_5.4/Engine/Build/BatchFiles/RunUAT.bat'",
        "BuildPlugin",
        "-Plugin='${workspaceFolder}/YourPlugin.uplugin'",
        "-Package='${workspaceFolder}/Packaged'",
        "-TargetPlatforms=Win64"
      ],
      "group": { "kind": "build", "isDefault": true }
    },
    {
      "label": "Compile Plugin in Project (快速编译)",
      "type": "shell",
      "command": "&",
      "args": [
        "'F:/Epic Games/UE_5.4/Engine/Build/BatchFiles/Build.bat'",
        "MyProjectEditor",
        "Win64",
        "Development",
        "'F:/Unreal Projects/MyProject/MyProject.uproject'",
        "-WaitMutex"
      ],
      "problemMatcher": "$msCompile"
    },
    {
      "label": "Generate Project Files",
      "type": "shell",
      "command": "&",
      "args": [
        "'F:/Epic Games/UE_5.4/Engine/Build/BatchFiles/GenerateProjectFiles.bat'",
        "'F:/Unreal Projects/MyProject/MyProject.uproject'"
      ]
    },
    {
      "label": "Rebuild IntelliSense Database",
      "type": "shell",
      "command": "&",
      "args": [
        "'F:/Epic Games/UE_5.4/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.exe'",
        "-Mode=GenerateClangDatabase",
        "-Project='F:/Unreal Projects/MyProject/MyProject.uproject'",
        "MyProjectEditor",
        "Win64",
        "Development"
      ]
    }
  ]
}
```

### 任务说明

| 任务 | 用途 |
|------|------|
| Build Plugin | 打包插件为 .uplugin 文件 |
| Compile Plugin in Project | 在项目上下文中快速编译插件 |
| Generate Project Files | 重新生成 VS 项目文件 |
| Rebuild IntelliSense Database | 重建 clangd 数据库（修复 IntelliSense 问题） |

## launch.json

### 调试配置

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug UE Editor",
      "type": "cppvsdbg",
      "request": "launch",
      "program": "F:/Epic Games/UE_5.4/Engine/Binaries/Win64/UnrealEditor.exe",
      "args": ["\"F:/Unreal Projects/MyProject/MyProject.uproject\"", "-debug"],
      "stopAtEntry": false,
      "cwd": "F:/Epic Games/UE_5.4/Engine/Binaries/Win64",
      "console": "externalTerminal",
      "preLaunchTask": "Compile Plugin in Project (快速编译)"
    },
    {
      "name": "Attach to UE Editor",
      "type": "cppvsdbg",
      "request": "attach",
      "processId": "${command:pickProcess}"
    }
  ]
}
```

### 调试模式

| 配置 | 用途 |
|------|------|
| Debug UE Editor | 启动并调试 UE 编辑器 |
| Attach to UE Editor | 附加到运行中的 UE 编辑器进程 |

## settings.json

### 编辑器设置

```json
{
  "files.associations": {
    "*.cpp": "cpp",
    "*.h": "cpp",
    "*.hpp": "cpp"
  },
  "editor.formatOnSave": false,
  "editor.tabSize": 4,
  "editor.insertSpaces": true,
  "C_Cpp.default.cppStandard": "c++20",
  "C_Cpp.default.cStandard": "c17",
  "C_Cpp.intelliSenseEngine": "default",
  "C_Cpp.errorSquiggles": "enabled",
  "files.exclude": {
    "**/Binaries": true,
    "**/Build": true,
    "**/Intermediate": true,
    "**/Saved": true,
    "**/DerivedDataCache": true
  },
  "files.watcherExclude": {
    "**/Binaries/**": true,
    "**/Build/**": true,
    "**/Intermediate/**": true,
    "**/Saved/**": true
  }
}
```

### 关键设置

| 设置 | 说明 |
|------|------|
| `files.associations` | .h 文件映射到 cpp（而非 C） |
| `editor.tabSize` | UE 编码标准使用 4 空格缩进 |
| `files.exclude` | 隐藏生成目录（Binaries、Intermediate 等） |

## extensions.json

### 推荐扩展

```json
{
  "recommendations": [
    "ms-vscode.cpptools",
    "ms-vscode.cpptools-extension-pack",
    "xaver.clang-format",
    "eamodio.gitlens",
    "yzhang.markdown-all-in-one",
    "ms-python.python",
    "zomfg.ue-resource-viewer",
    "gruntfuggly.todo-tree",
    "aaron-bond.better-comments",
    "oderwat.indent-rainbow",
    "coenraads.bracket-pair-colorizer-2"
  ]
}
```

### 必需扩展

| 扩展 | 用途 |
|------|------|
| ms-vscode.cpptools | C/C++ IntelliSense |
| xaver.clang-format | 代码格式化 |
| eamodio.gitlens | Git 增强 |
| zomfg.ue-resource-viewer | UE 资源查看器 |
