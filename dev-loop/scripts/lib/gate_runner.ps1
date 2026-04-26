# dev-loop/scripts/lib/gate_runner.ps1
# 函数：Test-DevLoopGates
# P1-1：抽自原 guard_commit.ps1 第 5-9 道 gate，供 guard_commit（Claude Code
# 手动路径）和 run.ps1（自动循环路径）共用。
# 单元测试：tests/gate_runner.Tests.ps1
#
# 本 lib 不包含 verify_cmds 复验（见 verify_runner.ps1）。调用者分别调。

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Test-DevLoopGates {
    [CmdletBinding()]
    param([string]$Cwd = '.')
    # 函数内 Write-Error 不应中断 return $false；脚本顶层的 Stop 策略保留给
    # 调用者自行决定。
    $ErrorActionPreference = 'Continue'

    # G5: .current_task_id 存在非空
    $taskIdPath = Join-Path $Cwd '.devloop/.current_task_id'
    if (-not (Test-Path $taskIdPath)) {
        Write-Error "gate: 未找到 .devloop/.current_task_id，无法判定当前任务"
        return $false
    }
    $taskId = (Get-Content $taskIdPath -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($taskId)) {
        Write-Error "gate: .current_task_id 为空"
        return $false
    }

    # G6: research.md 存在（CR-5 查证工件）
    $researchPath = Join-Path $Cwd ".devloop/logs/task_${taskId}_research.md"
    if (-not (Test-Path $researchPath)) {
        Write-Error "gate: 缺 CR-5 查证记录：$researchPath"
        return $false
    }

    # G7: task.json 中对应 task.notes 含 CR-6 字段
    $taskJsonPath = Join-Path $Cwd '.devloop/task.json'
    if (-not (Test-Path $taskJsonPath)) {
        Write-Error 'gate: 缺 .devloop/task.json'
        return $false
    }
    $data = Get-Content $taskJsonPath -Raw | ConvertFrom-Json
    $currentTask = $data.tasks | Where-Object { $_.id -eq $taskId } | Select-Object -First 1
    if (-not $currentTask) {
        Write-Error "gate: task.json 中未找到 id=$taskId"
        return $false
    }
    $notesProp = $currentTask.PSObject.Properties['notes']
    $notesVal = if ($null -ne $notesProp) { [string]$notesProp.Value } else { '' }
    if ([string]::IsNullOrEmpty($notesVal) -or $notesVal -notmatch 'CR-6:') {
        Write-Error "gate: 任务 $taskId 的 notes 缺少 CR-6 自省结论"
        return $false
    }

    # G8: CR-6 声明"有"时 lessons.md 当日必须有新条目
    if ($notesVal -match 'CR-6:[^\r\n]*有') {
        $today = Get-Date -Format 'yyyy-MM-dd'
        $lessonsPath = Join-Path $Cwd '.devloop/lessons.md'
        $hasToday = (Test-Path $lessonsPath) -and ((Get-Content $lessonsPath -Raw) -match "## $today")
        if (-not $hasToday) {
            Write-Error "gate: CR-6 声明有问题，但 lessons.md 当日（$today）无新条目"
            return $false
        }
    }

    # G9: task.json 结构防篡改（与 HEAD 比较）
    Push-Location $Cwd
    try {
        $headTaskJson = git show "HEAD:.devloop/task.json" 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($headTaskJson)) {
            $headData = $headTaskJson | ConvertFrom-Json
            $headById = @{}; foreach ($t in $headData.tasks) { $headById[$t.id] = $t }
            $currById = @{}; foreach ($t in $data.tasks) { $currById[$t.id] = $t }

            if ($data.tasks.Count -lt $headData.tasks.Count) {
                Write-Error "gate: task.json 任务数被缩短（$($headData.tasks.Count) → $($data.tasks.Count)），禁止删除 task"
                return $false
            }
            foreach ($headId in $headById.Keys) {
                if (-not $currById.ContainsKey($headId)) {
                    Write-Error "gate: task id '$headId' 在当前版本中丢失，禁止删除或改 id"
                    return $false
                }
                $headCmdsProp = $headById[$headId].PSObject.Properties['verify_cmds']
                $currCmdsProp = $currById[$headId].PSObject.Properties['verify_cmds']
                $headHad = ($null -ne $headCmdsProp) -and ($null -ne $headCmdsProp.Value) -and (@($headCmdsProp.Value).Count -gt 0)
                $currHas = ($null -ne $currCmdsProp) -and ($null -ne $currCmdsProp.Value) -and (@($currCmdsProp.Value).Count -gt 0)
                if ($headHad -and -not $currHas) {
                    Write-Error "gate: task '$headId' 的 verify_cmds 被清空，禁止"
                    return $false
                }
            }
        }
    } finally { Pop-Location }

    return $true
}
