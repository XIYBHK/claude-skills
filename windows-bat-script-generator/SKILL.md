---
name: windows-bat-script-generator Windows批处理脚本生成器
description: 生成规范的Windows批处理脚本(.bat)，确保中文正确显示、防止窗口闪退并提供用户友好的交互。当用户要求创建批处理脚本、特别是需要中文界面、菜单交互、管理员权限申请、进度显示或双击运行时使用此skill。提供UTF-8和ANSI两种编码方案、菜单系统模板、窗口设置和统一的错误处理模式。
---

# Windows批处理脚本生成器

生成规范的Windows批处理脚本，确保中文正确显示、窗口持久化并提供良好的用户体验。

## 何时使用此Skill

用于生成Windows批处理脚本(.bat)，特别是：
- 需要双击运行的脚本
- 需要显示中文界面
- 需要用户确认或交互
- 需要显示执行进度
- 需要在完成后保持窗口打开
- 需要管理员权限执行
- 需要交互式菜单

## 核心技术要点

### 中文显示编码方案（二选一）

#### 方案A：UTF-8编码（推荐，通用性强）
```bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
```

**说明：**
- 脚本文件必须以 **UTF-8 without BOM** 格式保存
- `chcp 65001` 设置UTF-8代码页
- 适合包含多种语言或需要在不同区域设置下运行

#### 方案B：系统默认编码（中文Windows最优）
```bat
@echo OFF&PUSHD %~DP0 &TITLE <脚本标题>
```

**说明：**
- 不使用 `chcp` 命令，直接使用系统默认ANSI编码（中文Windows为GBK）
- 脚本文件以 **ANSI (GB2312/GBK)** 格式保存
- 中文显示效果最佳，无乱码风险
- 适合仅在中文Windows环境下使用的脚本
- `PUSHD %~DP0` 切换到脚本所在目录
- `TITLE <脚本标题>` 设置窗口标题（将 `<脚本标题>` 替换为实际标题）

### 窗口设置

#### 设置窗口大小
```bat
mode <列数>,<行数>
```
**说明：**
- `mode <列数>,<行数>` 设置控制台窗口尺寸（如 `mode 80,25`）
- 使界面更美观，避免内容换行
- 根据内容长度调整数值

#### 设置窗口标题
```bat
title <脚本标题>
:: 或紧凑写法
@echo OFF&TITLE <脚本标题>
```

### 管理员权限检测与申请

```bat
reg query "HKU\S-1-5-19">NUL 2>&1||powershell -Command "Start-Process '%~sdpnx0' -Verb RunAs"&&EXIT
```

**说明：**
- 检测是否具有管理员权限（访问HKU\S-1-5-19注册表项）
- 无权限时自动使用PowerShell提升权限重新运行脚本
- 提升成功后退出当前非管理员实例

### 系统架构检测

```bat
reg query "HKLM\Hardware\Description\System\CentralProcessor\0" /v "Identifier" | find /i "x86" 1>nul && set arch=x86|| set arch=x64

if "%arch%"=="x86" (
    echo 32位系统
) else (
    echo 64位系统
)
```

### 统一的错误输出处理

```bat
set "nul=>nul 2>&1"

:: 使用方式
命令 %nul%
reg add "路径" /v "值" /d "数据" /f %nul%
```

**说明：**
- 定义变量统一隐藏标准输出和错误输出
- 比每次写 `>nul 2>nul` 更简洁

### 任务说明和确认提示

#### 基础确认
```bat
echo ========================================
echo 脚本名称
echo ========================================
echo.
echo 即将执行以下操作:
echo 1. 操作说明1
echo 2. 操作说明2
echo.
echo 按任意键开始，或关闭窗口取消...
pause >nul
```

#### 是/否选择（choice命令）
```bat
echo 是否继续操作？
choice /n /c YN /m "请选择 [Y=是,N=否]: "
if errorlevel 2 (
    echo 已取消操作
    exit /b
)
echo 继续执行...
```

**说明：**
- `choice` 命令提供标准化的选项提示
- `/n` 隐藏选项列表，只显示提示信息
- `/c YN` 定义可选字符
- `/m` 设置提示消息
- `errorlevel 2` 对应第二个选项（N）

### 交互式菜单系统

```bat
:Menu
@echo.
@echo.============    主 菜 单    ============
@echo.========================================
@echo. 
@echo.  [1] 功能一
@echo. 
@echo.  [2] 功能二
@echo.
@echo.  [3] 退出
@echo. 
set /p choice=请输入选项编号(1-3):
if /i "%choice%"=="1" goto Function1
if /i "%choice%"=="2" goto Function2
if /i "%choice%"=="3" exit /b
@echo.
@echo 无效选择，请重新输入！
timeout /t 2 >nul
cls
goto Menu

:Function1
echo 执行功能一...
pause
cls
goto Menu

:Function2
echo 执行功能二...
pause
cls
goto Menu
```

**说明：**
- `set /p` 获取用户输入
- `goto` 实现菜单跳转
- `timeout /t 2` 延迟2秒后清屏返回菜单
- `cls` 清屏保持界面整洁

### 进度提示

```bat
echo.
echo [开始执行...]
echo.
echo [1/4] 执行第一步...
:: 命令
echo   完成

echo.
echo [2/4] 执行第二步...
:: 命令
echo   完成
```

**说明：**
- 显示当前进度（如 [1/4]）
- 缩进显示执行结果
- 使用空行分隔不同步骤

### 延迟等待

```bat
:: 延迟2秒（不显示倒计时）
timeout /t 2 >nul

:: 延迟并显示倒计时
timeout /t 2
```

### 进程检测与结束

```bat
:: 检测进程是否存在
tasklist /fi "imagename eq notepad.exe" | find /i "notepad.exe" >nul && (
    echo 进程正在运行，准备结束...
    taskkill /F /IM notepad.exe /T >nul 2>&1
) || (
    echo 进程未运行
)
```

### 完成提示和窗口保持

```bat
echo.
echo ========================================
echo 执行完成！
echo ========================================
echo.
pause
```

**说明：**
- `pause` 保持窗口打开，防止闪退
- 用户可以查看执行结果

### 条件判断和循环示例

**文件/文件夹存在性检查：**
```bat
if exist "<路径>" (
    echo <存在提示>
    <命令>
) else (
    echo <不存在提示>
)
```

**遍历文件：**
```bat
for %%f in (*.<扩展名>) do (
    echo 处理: %%f
    <命令> "%%f"
)
```

**遍历文件夹：**
```bat
for /d %%d in (<路径>\*) do (
    echo 处理文件夹: %%d
    <命令>
)
```

**删除文件夹内容但保留文件夹：**
```bat
if exist "<文件夹路径>" (
    for /d %%d in (<文件夹路径>\*) do rmdir /s /q "%%d"
    del /f /q "<文件夹路径>\*" 2>nul
    echo   <完成提示>
)
```

**从注册表读取值：**
```bat
FOR /F "tokens=2,*" %%I IN ('REG QUERY "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v Desktop 2^>NUL^|FIND /I "Desktop"') DO SET "DesktopPath=%%~J"
echo 桌面路径: %DesktopPath%
```

### PowerShell 集成

**创建快捷方式：**
```bat
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut($([Environment]::GetFolderPath('Desktop')) + '\<快捷方式名称>.lnk'); $s.TargetPath = '%~dp0<目标程序>'; $s.WorkingDirectory = '%~dp0'; $s.Save()"
```

## 生成脚本的标准流程

按照以下顺序生成脚本：

1. **脚本头部**：选择编码方案（UTF-8或ANSI），添加环境设置
2. **窗口设置**：设置标题、大小（可选）
3. **权限检查**：如需管理员权限则添加检测代码
4. **标题和说明**：清晰说明脚本功能
5. **确认提示**：给用户确认机会（可选但推荐）
6. **主要逻辑**：带进度提示的执行步骤
7. **完成提示**：告知完成并保持窗口

## 最佳实践

1. **编码选择**
   - 纯中文Windows环境：使用ANSI编码，不添加chcp命令
   - 多语言或通用环境：使用UTF-8编码（chcp 65001）
   - 确保文件保存编码与脚本声明一致

2. **路径处理**
   - 使用双引号包裹路径，防止空格问题
   - 示例：`del /f /q "路径\文件.txt"`

3. **变量定义**
   - 使用双引号定义变量：`set "变量=值"`
   - 避免额外空格影响

4. **输出格式**
   - 使用`echo.`输出空行
   - 使用分隔线提升可读性
   - 步骤编号清晰（如[1/4]）

5. **错误处理**
   - 关键操作检查返回值
   - 非关键错误可以抑制输出
   - 给出明确的错误提示

6. **用户体验**
   - 提供操作前确认
   - 显示清晰的进度
   - 完成后保持窗口
   - 使用中文界面
   - 添加适当的延迟让信息可读

## 占位符说明

所有代码示例中使用 `< >` 包裹的内容为**占位符**，需要根据实际需求替换：

| 占位符 | 说明 | 示例 |
|--------|------|------|
| `<脚本标题>` | 窗口标题文字 | `文件清理工具` |
| `<列数>,<行数>` | 窗口尺寸数值 | `80,25` |
| `<路径>` | 文件或文件夹路径 | `C:\Data` 或 `./files` |
| `<扩展名>` | 文件扩展名 | `txt`, `bat`, `log` |
| `<功能一描述>` | 菜单项描述文字 | `清理临时文件` |
| `<操作一步骤描述>` | 操作步骤说明 | `扫描临时文件夹` |
| `<命令>` | 实际执行的命令 | `del`, `copy`, `move` |
| `<提示文本>` | 显示给用户的消息 | `正在处理...` |
| `<快捷方式名称>` | 快捷方式文件名 | `我的工具` |
| `<目标程序>` | 快捷方式指向的程序 | `myapp.exe` |

**使用示例：**
```bat
:: 占位符写法（模板）
mode <列数>,<行数>
if exist "<路径>" (
    echo <提示文本>
)

:: 实际使用（替换后）
mode 80,30
if exist "C:\Temp" (
    echo 文件夹已存在
)
```

## 注意事项

- **编码一致性**：文件保存编码必须与脚本中的编码声明一致
- **UTF-8方案**：必须使用UTF-8 without BOM格式保存
- **ANSI方案**：中文Windows默认使用GBK编码
- **必须防止闪退**：在结尾使用`pause`或在菜单循环中保持运行
- **危险操作**：删除、覆盖等操作必须有确认提示
- **复杂逻辑**：考虑添加注释说明
- **管理员权限**：需要修改系统设置时自动申请提升权限

## 示例模板

参考`references/template.bat`获取完整的脚本模板。
