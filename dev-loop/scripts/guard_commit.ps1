# dev-loop/scripts/guard_commit.ps1
# Claude Code PreToolUse hook: 拦截未通过 CR Gates 的 git commit
# stdin: JSON { tool_input: { command: "<shell cmd>" } }
# exit 0 = 放行 / exit != 0 = 拒绝

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

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

# === 5. 读当前 task id ===
$taskIdPath = '.devloop/.current_task_id'
if (-not (Test-Path $taskIdPath)) {
    Write-Error 'guard_commit: 未找到 .devloop/.current_task_id，无法判定当前任务。请通过 run.ps1 驱动或手动写入该文件。'
    exit 1
}
$taskId = (Get-Content $taskIdPath -Raw).Trim()

# === 6. research.md 必须存在 ===
$researchPath = ".devloop/logs/task_${taskId}_research.md"
if (-not (Test-Path $researchPath)) {
    Write-Error "guard_commit: 缺 CR-5 查证记录：$researchPath"
    exit 1
}

# === 7. task.json 中 notes 必须含 CR-6 ===
$taskJsonPath = '.devloop/task.json'
if (-not (Test-Path $taskJsonPath)) {
    Write-Error 'guard_commit: 缺 .devloop/task.json'
    exit 1
}
$data = Get-Content $taskJsonPath -Raw | ConvertFrom-Json
$currentTask = $data.tasks | Where-Object { $_.id -eq $taskId } | Select-Object -First 1
if (-not $currentTask) {
    Write-Error "guard_commit: task.json 中未找到 id=$taskId"
    exit 1
}
if ([string]::IsNullOrEmpty([string]$currentTask.notes) -or [string]$currentTask.notes -notmatch 'CR-6:') {
    Write-Error "guard_commit: 任务 $taskId 的 notes 缺少 CR-6 自省结论（需形如 'CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无'）"
    exit 1
}

# === 8. CR-6 声明"有"时，lessons.md 当日必须有新追加 ===
if ([string]$currentTask.notes -match 'CR-6:[^\r\n]*有') {
    $today = Get-Date -Format 'yyyy-MM-dd'
    $lessonsPath = '.devloop/lessons.md'
    $hasToday = (Test-Path $lessonsPath) -and ((Get-Content $lessonsPath -Raw) -match "## $today")
    if (-not $hasToday) {
        Write-Error "guard_commit: CR-6 声明有问题，但 .devloop/lessons.md 当日（$today）无新条目"
        exit 1
    }
}

# === 9. task.json 结构防篡改 (P0-2) ===
# 对比当前 task.json 与 HEAD:.devloop/task.json：
#   a) tasks 数组长度未缩短（禁止删 task）
#   b) 任一 task 的 id 没丢失（禁止改 id）
#   c) 任一 task 的 verify_cmds 没变空（禁止空验证）
# 首次 commit (HEAD 无 task.json) → 跳过（repo 初始化场景）
$headTaskJson = git show "HEAD:.devloop/task.json" 2>$null
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($headTaskJson)) {
    $headData = $headTaskJson | ConvertFrom-Json
    $headById = @{}
    foreach ($t in $headData.tasks) { $headById[$t.id] = $t }
    $currById = @{}
    foreach ($t in $data.tasks) { $currById[$t.id] = $t }

    if ($data.tasks.Count -lt $headData.tasks.Count) {
        Write-Error "guard_commit: task.json 任务数被缩短（$($headData.tasks.Count) → $($data.tasks.Count)），禁止删除 task"
        exit 1
    }
    foreach ($headId in $headById.Keys) {
        if (-not $currById.ContainsKey($headId)) {
            Write-Error "guard_commit: task id '$headId' 在当前版本中丢失，禁止删除或改 id"
            exit 1
        }
        $headTask = $headById[$headId]
        $currTask = $currById[$headId]
        $headCmdsProp = $headTask.PSObject.Properties['verify_cmds']
        $currCmdsProp = $currTask.PSObject.Properties['verify_cmds']
        $headHadCmds = ($null -ne $headCmdsProp) -and ($null -ne $headCmdsProp.Value) -and (@($headCmdsProp.Value).Count -gt 0)
        $currHasCmds = ($null -ne $currCmdsProp) -and ($null -ne $currCmdsProp.Value) -and (@($currCmdsProp.Value).Count -gt 0)
        if ($headHadCmds -and -not $currHasCmds) {
            Write-Error "guard_commit: task '$headId' 的 verify_cmds 被清空，禁止"
            exit 1
        }
    }
}

# === 10. verify_cmds 复验 ===
$libPath = Join-Path $PSScriptRoot 'lib/verify_runner.ps1'
if (-not (Test-Path $libPath)) {
    Write-Error "guard_commit: 缺 verify_runner.ps1 （预期路径：$libPath）"
    exit 1
}
. $libPath
$configPath = '.devloop/config.json'
if (-not (Test-Path $configPath)) {
    Write-Error 'guard_commit: 缺 .devloop/config.json'
    exit 1
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not (Invoke-VerifyRunner -Task $currentTask -Config $config)) {
    Write-Error 'guard_commit: verify_cmds 复验失败，拒绝提交'
    exit 1
}

exit 0
