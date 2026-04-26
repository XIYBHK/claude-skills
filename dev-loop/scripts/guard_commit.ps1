# dev-loop/scripts/guard_commit.ps1
# Claude Code PreToolUse hook: 拦截未通过 CR Gates 的 git commit
# stdin: JSON { tool_input: { command: "<shell cmd>" } }
# exit 0 = 放行 / exit != 0 = 拒绝

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# P2-8: 固定 UTF-8 输出。非中文英文 Windows 默认 Console.OutputEncoding 为
# gb2312 等 OEM codepage，中文 Write-Error 消息穿过 stderr pipe 到调用方
# （Claude Code hook / Pester）时 UTF-16 字符被错码映射成形近字，正则断言
# 静默失败。强制 UTF-8 让所有调用方看到真实消息。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# P5-2: 薄 helper。本脚本作为 PreToolUse hook 被独立 pwsh 进程调起，
# 为避免 lib 加载失败多一个失败点，helper 内联；run.ps1 / browser_verify.ps1
# 各自也维护相同形态的本地副本。
function Exit-WithError {
    param([Parameter(Mandatory)][int]$Code, [Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
    exit $Code
}

# === 1. 读 stdin hook 协议 ===
$stdin = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
try { $req = $stdin | ConvertFrom-Json } catch { exit 0 }

$cmd = ''
if ($req.tool_input -and $req.tool_input.PSObject.Properties['command']) {
    $cmd = [string]$req.tool_input.command
}

# === 2. 只管 git commit ===
if ($cmd -notmatch '\bgit\s+commit\b') { exit 0 }

# === 3. 非 dev-loop 项目放行 ===
if (-not (Test-Path '.devloop')) { exit 0 }

# === 4. [skip-devloop] 豁免 ===
if ($cmd -match '\[skip-devloop\]') {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $reason = '(no reason)'
    if ($cmd -match '\[skip-devloop\]\s*([^"'']*)') {
        $reason = $Matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($reason)) { $reason = '(no reason)' }
    }
    $progressPath = '.devloop/progress.md'
    if (-not (Test-Path $progressPath)) {
        Set-Content -Path $progressPath -Value "# Progress`n" -Encoding utf8
    }
    $content = Get-Content $progressPath -Raw
    if ($content -notmatch '## Overrides') {
        Add-Content -Path $progressPath -Value "`n## Overrides`n" -Encoding utf8
    }
    Add-Content -Path $progressPath -Value "- $ts - skip-devloop - $reason" -Encoding utf8
    exit 0
}

# === 5-9. 统一 gate 检查（P1-1 抽出到 lib/gate_runner.ps1） ===
# 两条路径共享同一套 gate：
#   - Claude Code 手动路径：此 hook 调
#   - run.ps1 自动路径：主循环 commit 前调
$gateRunnerPath = Join-Path $PSScriptRoot 'lib/gate_runner.ps1'
if (-not (Test-Path $gateRunnerPath)) {
    Exit-WithError -Code 1 -Message "guard_commit: 缺 gate_runner.ps1 （预期路径：$gateRunnerPath）"
}
. $gateRunnerPath
if (-not (Test-DevLoopGates -Cwd '.')) {
    exit 1
}

# === 10. verify_cmds 复验 ===
$taskIdPath = '.devloop/.current_task_id'
$taskId = (Get-Content $taskIdPath -Raw).Trim()
$data = Get-Content '.devloop/task.json' -Raw | ConvertFrom-Json
$currentTask = $data.tasks | Where-Object { $_.id -eq $taskId } | Select-Object -First 1

$libPath = Join-Path $PSScriptRoot 'lib/verify_runner.ps1'
if (-not (Test-Path $libPath)) {
    Exit-WithError -Code 1 -Message "guard_commit: 缺 verify_runner.ps1 （预期路径：$libPath）"
}
. $libPath
$configPath = '.devloop/config.json'
if (-not (Test-Path $configPath)) {
    Exit-WithError -Code 1 -Message 'guard_commit: 缺 .devloop/config.json'
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not (Invoke-VerifyRunner -Task $currentTask -Config $config)) {
    Exit-WithError -Code 1 -Message 'guard_commit: verify_cmds 复验失败，拒绝提交'
}

exit 0
