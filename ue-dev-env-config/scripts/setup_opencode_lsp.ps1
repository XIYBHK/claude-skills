# ========================================
# OpenCode LSP 配置脚本
# 功能：安装和配置 clangd 用于 opencode LSP 支持
# ========================================

param(
    [switch]$Help
    )

if ($Help) {
    Write-Host @"
╔════════════════════════════════════════════════════════════╗
║        OpenCode Clangd LSP 配置工具                        ║
╚════════════════════════════════════════════════════════════╝

功能：
  - 检测 clangd 是否已安装
  - 自动安装 LLVM.LLVM（包含 clangd）
  - 验证 clangd 版本和平台
  - 添加 LLVM 到系统 PATH
  - 提供配置指南

用法:
    scripts\setup_opencode_lsp.ps1

参数:
    -Help                  显示此帮助信息

配置文件:
    - opencode.json  (LSP 配置，由 configure_opencode_json.ps1 生成)

"@
    exit
}

# ========================================
# 1. 检测 clangd 安装状态
# ========================================
Write-Host "[ 步骤 0/4 ] 检测 clangd 安装状态..." -ForegroundColor Yellow

# 尝试使用 clangd 命令
try {
    $clangdVersionOutput = & clangd --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ clangd 已安装！" -ForegroundColor Green
        Write-Host "   版本信息: $clangdVersionOutput" -ForegroundColor White
    }
} catch {
    Write-Host "   ❌ clangd 未安装或不在 PATH 中" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
}

# 检查 LLVM 安装路径
$llvmPaths = @(
    "C:\Program Files\LLVM\bin",
    "C:\Program Files (x86)\LLVM\bin"
)

$foundLLVM = $null
foreach ($path in $llvmPaths) {
    if (Test-Path "$path\clangd.exe" -ErrorAction SilentlyContinue) {
        $foundLLVM = $path
        Write-Host "   ✓ 找到 LLVM: $path" -ForegroundColor Green
        break
    }
}

if ($null -eq $foundLLVM) {
    Write-Host "   ⚠️  未找到 LLVM 安装路径" -ForegroundColor Yellow
    Write-Host "   将尝试自动安装..." -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
}

Write-Host ""

# ========================================
# 2. 自动安装 clangd
# ========================================
if ($null -eq $foundLLVM) {
    Write-Host "[ 步骤 1/4 ] 安装 LLVM.LLVM (包含 clangd)..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   使用 winget 安装 LLVM.LLVM..." -ForegroundColor Cyan
    Write-Host "   这将下载约 356 MB 的安装包，请耐心等待..." -ForegroundColor Gray
    Write-Host ""

    try {
        $installResult = winget install LLVM.LLVM --accept-package-agreements --accept-source-agreements 2>&1
        $installOutput = $installResult -join "`n"

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "   ✓ LLVM.LLVM 安装成功！" -ForegroundColor Green
            Write-Host "   clangd 已自动安装到系统中" -ForegroundColor Green
            Write-Host ""

            # 验证安装
            Write-Host "[ 步骤 2/4 ] 验证安装..." -ForegroundColor Yellow

            # 刷新环境变量
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User")

            # 检查是否可以运行 clangd
            Start-Sleep -Seconds 2
            $verifyVersion = & clangd --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✓ clangd 验证成功！" -ForegroundColor Green
                Write-Host "   版本: $verifyVersion" -ForegroundColor White
            } else {
                Write-Host "   ⚠️  clangd 验证失败，可能需要重启终端" -ForegroundColor Yellow
                Write-Host "   版本: $verifyVersion" -ForegroundColor White
            }
        } else {
            Write-Host ""
            Write-Host "   ❌ LLVM.LLVM 安装失败" -ForegroundColor Red
            Write-Host "   错误信息:" -ForegroundColor Red
            Write-Host $installOutput -ForegroundColor Red
            Write-Host ""
            Write-Host "   请尝试手动安装：" -ForegroundColor Yellow
            Write-Host "   1. 从官网下载: https://github.com/clangd/clangd/releases" -ForegroundColor Gray
            Write-Host "   2. 或使用其他包管理器安装" -ForegroundColor Gray
            exit 1
        }
    }
    catch {
        Write-Host ""
        Write-Host "   ❌ 安装过程中发生错误" -ForegroundColor Red
        Write-Host "   错误: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "   请确保：" -ForegroundColor Yellow
        Write-Host "   - 网络连接正常" -ForegroundColor Gray
        Write-Host "   - winget 已安装并更新" -ForegroundColor Gray
        Write-Host "   - 有管理员权限" -ForegroundColor Gray
        exit 1
    }

    Write-Host ""
    Write-Host "[ 步骤 3/4 ] 添加 LLVM 到 PATH..." -ForegroundColor Yellow
} else {
    Write-Host "[ 步骤 1/4 ] clangd 已安装，添加到 PATH..." -ForegroundColor Yellow
}

# ========================================
# 3. 添加 LLVM 到系统 PATH
# ========================================
Write-Host ""

# 获取当前用户 PATH
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

# 检查 LLVM 是否已在 PATH 中
if ($userPath -match [regex]::Escape($foundLLVM)) {
    Write-Host "   ✓ LLVM 已在 PATH 中" -ForegroundColor Green
} else {
    Write-Host "   → LLVM 不在 PATH 中，正在添加..." -ForegroundColor Cyan

    # 添加 LLVM 到用户 PATH
    $newPath = "$userPath;$foundLLVM"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")

    Write-Host "   ✓ 已添加 LLVM 到用户 PATH" -ForegroundColor Green
    Write-Host "   路径: $foundLLVM" -ForegroundColor White
    Write-Host ""
    Write-Host "   ⚠️  注意：新 PATH 在新终端会话中生效" -ForegroundColor Yellow
    Write-Host "   → 请重新启动终端或 opencode" -ForegroundColor Gray
}

Write-Host ""

# ========================================
# 4. 生成配置指南
# ========================================
Write-Host "[ 步骤 4/4 ] 生成配置指南..." -ForegroundColor Yellow

Write-Host ""
Write-Host "═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                下一步操作                              ║" -ForegroundColor Cyan
Write-Host "╚═════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. 配置 opencode.json" -ForegroundColor White
Write-Host "   运行: scripts\configure_opencode_json.ps1" -ForegroundColor Gray
Write-Host "   此脚本会：" -ForegroundColor Gray
Write-Host "   - 检测或提示输入 UE 引擎路径" -ForegroundColor Gray
Write-Host "   - 生成 opencode.json LSP 配置" -ForegroundColor Gray
Write-Host "   - 配置 clangd 命令和参数" -ForegroundColor Gray
Write-Host ""

Write-Host "2. 重启 opencode" -ForegroundColor White
Write-Host "   关闭当前 opencode 会话" -ForegroundColor Gray
Write-Host "   重新打开 opencode" -ForegroundColor Gray
Write-Host ""

Write-Host "3. 打开任意 C/C++ 文件" -ForegroundColor White
Write-Host "   opencode 会自动启动 clangd LSP" -ForegroundColor Gray
Write-Host "   LSP 诊断和代码智能功能将可用" -ForegroundColor Gray
Write-Host ""

Write-Host "═════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Clangd LSP 配置完成！                    ║" -ForegroundColor Green
Write-Host "╚═════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📋 配置摘要:" -ForegroundColor Cyan
Write-Host "   Clangd 路径: $foundLLVM" -ForegroundColor White
if ($null -ne $foundLLVM) {
    $verifyInfo = & clangd --version 2>&1
    Write-Host "   Clangd 版本: $verifyInfo" -ForegroundColor White
}
Write-Host ""
Write-Host "✨ Clangd LSP 配置完成！" -ForegroundColor Green
Write-Host ""
