# dev-loop/scripts/run.ps1
# 主循环驱动器：选任务 -> 调 headless Claude -> 脚本复验 -> commit/rollback -> 循环

[CmdletBinding()]
param(
    [int]$MaxTasks = 0,
    [int]$MaxConsecBlocked = 3,
    [int]$MaxAttemptsPerTask = 3,
    [switch]$DryRun,
    [switch]$LoadFunctionsOnly     # 测试钩子：只 dot-source 函数定义
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# === 加载 lib ===
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'task_picker.ps1')
. (Join-Path $libDir 'verify_runner.ps1')
. (Join-Path $libDir 'claude_invoker.ps1')
. (Join-Path $libDir 'gate_runner.ps1')

# === 前置 guards ===
function Assert-GitClean {
    $status = git status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'not a git repo' }
    if ($status) { throw "working tree is not clean:`n$status" }
}

function Assert-BranchNotMain {
    $branch = (git branch --show-current).Trim()
    if ($branch -in @('main', 'master')) {
        throw "refuse to run on protected branch: $branch"
    }
}

function Assert-DevLoopInitialized {
    if (-not (Test-Path '.devloop/task.json') -or -not (Test-Path '.devloop/config.json')) {
        throw '.devloop is not initialized — run `/dev-loop init` first'
    }
}

# === 工具函数 ===
function Update-TaskField {
    param(
        [Parameter(Mandatory)][string]$Id,
        [hashtable]$Fields
    )
    $path = '.devloop/task.json'
    $data = Get-Content $path -Raw | ConvertFrom-Json
    $task = $data.tasks | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $task) { throw "task $Id not found" }
    foreach ($k in $Fields.Keys) {
        if ($task.PSObject.Properties[$k]) {
            $task.$k = $Fields[$k]
        } else {
            Add-Member -InputObject $task -NotePropertyName $k -NotePropertyValue $Fields[$k] -Force
        }
    }
    $data | ConvertTo-Json -Depth 20 | Set-Content -Path $path -Encoding utf8
}

function Append-Progress {
    param([string]$Line)
    $path = '.devloop/progress.md'
    if (-not (Test-Path $path)) {
        Set-Content -Path $path -Value "# Progress`n" -Encoding utf8
    }
    $today = Get-Date -Format 'yyyy-MM-dd'
    $content = Get-Content $path -Raw
    if ($content -notmatch "## $today") {
        Add-Content -Path $path -Value "`n## $today`n`n| Time  | Task  | Title | Status | Attempts | Notes |`n|-------|-------|-------|--------|----------|-------|" -Encoding utf8
    }
    Add-Content -Path $path -Value $Line -Encoding utf8
}

function Build-CommitMessage {
    param([object]$Task, [object]$Config)
    $tpl = $Config.git.commitTemplate
    $verifyCmds = ($Task.verify_cmds -join ', ')
    $tpl = $tpl.Replace('{category}', [string]$Task.category)
    $tpl = $tpl.Replace('{scope}',    [string]$Task.scope)
    $tpl = $tpl.Replace('{title}',    [string]$Task.title)
    $tpl = $tpl.Replace('{id}',       [string]$Task.id)
    $tpl = $tpl.Replace('{attempts}', [string]$Task.attempts)
    $tpl = $tpl.Replace('{verifyCmds}', $verifyCmds)
    return $tpl
}

function Get-LastError {
    param([string]$LogPath)
    if (-not (Test-Path $LogPath)) { return '(no log)' }
    $lines = Get-Content $LogPath -Tail 30
    return ($lines -join "`n")
}

# P0-1: session-start smoke。对齐前作 init.sh 语义：
# 每任务进入 attempt loop 前跑 config.init.cmds 做项目健康度检查，
# 任一失败 → throw，主循环捕获后 exit 3 (harness precondition failed)。
# init 或 cmds 缺字段/为空 → 跳过，向后兼容。
function Invoke-InitCmds {
    param([Parameter(Mandatory)][object]$Config)
    $initProp = $Config.PSObject.Properties['init']
    if ($null -eq $initProp -or $null -eq $initProp.Value) { return }
    $cmdsProp = $initProp.Value.PSObject.Properties['cmds']
    if ($null -eq $cmdsProp -or $null -eq $cmdsProp.Value) { return }
    $cmds = @($cmdsProp.Value)
    foreach ($cmd in $cmds) {
        if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
        Write-Host ">>> [init] $cmd"
        & pwsh -NoProfile -Command $cmd
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            throw "init check failed: $cmd (exit=$code)"
        }
    }
}

# 测试钩子：不启动主循环
if ($LoadFunctionsOnly) { return }

# === 主循环 ===
Assert-GitClean
Assert-BranchNotMain
Assert-DevLoopInitialized
Assert-TaskJsonValid -Path '.devloop/task.json' -MaxFiles 5

$cfg = Get-Content '.devloop/config.json' -Raw | ConvertFrom-Json
$consecBlocked = 0
$done = 0

while ($true) {
    $task = Select-NextTask -Path '.devloop/task.json'
    if (-not $task) { Write-Host '✓ 全部任务完成'; break }

    Write-Host ""
    Write-Host ">>> 任务 $($task.id): $($task.title)"

    if ($DryRun) {
        Write-Host '[DryRun] 跳过 attempt 循环'
        $done++
        if ($MaxTasks -gt 0 -and $done -ge $MaxTasks) { break }
        continue
    }

    # P0-1: session-start smoke
    try {
        Invoke-InitCmds -Config $cfg
    } catch {
        Write-Error "harness precondition failed: $_"
        exit 3
    }

    $verified = $false
    for ($attempt = 1; $attempt -le $MaxAttemptsPerTask; $attempt++) {

        # 2a. 写当前 task id（供 guard_commit 读）
        Set-Content -Path '.devloop/.current_task_id' -Value $task.id -NoNewline -Encoding ascii

        # 2a-bis. 首次 attempt 记录 startedAt (T2 review 延期项)
        if ($attempt -eq 1 -and $null -eq $task.startedAt) {
            Update-TaskField -Id $task.id -Fields @{ startedAt = (Get-Date).ToString('o') }
            # 回读一次以保持 $task 与磁盘同步
            $data = Get-Content '.devloop/task.json' -Raw | ConvertFrom-Json
            $task = $data.tasks | Where-Object { $_.id -eq $task.id } | Select-Object -First 1
        }

        # 2b. 构造 prompt
        $prevLog = ".devloop/logs/task_$($task.id)_attempt_$($attempt - 1).log"
        $prompt  = Build-Prompt -TaskId $task.id -Attempt $attempt -PrevLogPath $prevLog -MaxAttempts $MaxAttemptsPerTask

        # 2c. 调 headless Claude
        $logPath = ".devloop/logs/task_$($task.id)_attempt_$attempt.log"
        $timeout = $cfg.limits.claudeTimeoutSec
        $exitCode = Invoke-HeadlessClaude -Prompt $prompt -LogPath $logPath -TimeoutSec $timeout

        # 2d. 重新载入 task（Claude 可能写过）
        $data = Get-Content '.devloop/task.json' -Raw | ConvertFrom-Json
        $task = $data.tasks | Where-Object { $_.id -eq $task.id } | Select-Object -First 1

        # 2e. 脚本独立复验
        $verified = Invoke-VerifyRunner -Task $task -Config $cfg
        if ($verified) { break }

        # 2f. 失败 -> 回滚工作区 + 记录 lastError
        git restore . *>&1 | Out-Null
        git clean -fd *>&1 | Out-Null
        Update-TaskField -Id $task.id -Fields @{
            attempts  = $attempt
            lastError = Get-LastError -LogPath $logPath
        }
    }

    # P1-1: commit 前走完整 CR gate（原先只靠 verify_cmds，其他 gate 全靠
    # guard_commit hook 拦 Claude 的 Bash，而 run.ps1 这条自动路径完全绕过）
    if ($verified) {
        if (-not (Test-DevLoopGates -Cwd '.')) {
            Write-Error "gate check failed for task $($task.id)"
            $verified = $false
        }
    }

    # 清理 current_task_id
    Remove-Item '.devloop/.current_task_id' -ErrorAction SilentlyContinue

    # === 结果判定 ===
    $ts = Get-Date -Format 'HH:mm'
    if ($verified) {
        git add -A
        $msg = Build-CommitMessage -Task $task -Config $cfg
        git commit -m $msg | Out-Null
        Update-TaskField -Id $task.id -Fields @{ passes = $true; completedAt = (Get-Date).ToString('o') }
        Append-Progress "| $ts | $($task.id) | $($task.title) | ✓ done | $($task.attempts) | — |"
        $consecBlocked = 0
        $done++
    }
    else {
        $reason = if ($task.blockReason) { [string]$task.blockReason } else { 'attempts exhausted' }
        Update-TaskField -Id $task.id -Fields @{ blocked = $true; blockReason = $reason }
        Append-Progress "| $ts | $($task.id) | $($task.title) | ✗ blocked | $MaxAttemptsPerTask | $reason |"
        $consecBlocked++
        if ($consecBlocked -ge $MaxConsecBlocked) {
            Write-Error "连续 $MaxConsecBlocked 个任务 blocked，整体停止"
            exit 2
        }
    }

    if ($MaxTasks -gt 0 -and $done -ge $MaxTasks) { break }
}

Write-Host ""
Write-Host "完成: $done 任务"
$blockedCount = @((Get-Content '.devloop/task.json' -Raw | ConvertFrom-Json).tasks | Where-Object { $_.blocked }).Count
Write-Host "Blocked: $blockedCount"
Write-Host "查看进度: .devloop/progress.md"
