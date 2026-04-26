# dev-loop/scripts/lib/task_picker.ps1
# 函数：Select-NextTask、Assert-TaskJsonValid
# 单元测试：tests/task_picker.Tests.ps1

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# StrictMode 3.0 禁止访问不存在的属性, @() 也无法兜底 —— 因为内部表达式先求值才会被包装。
# 这里走 PSObject.Properties 索引器，缺失时返回 $null，从而安全降级为 @()。
function Get-TaskDependsOn {
    param($Task)
    $prop = $Task.PSObject.Properties['depends_on']
    if ($null -eq $prop -or $null -eq $prop.Value) { return @() }
    return @($prop.Value)
}

function Select-NextTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    $data = Get-Content $Path -Raw | ConvertFrom-Json
    $byId = @{}
    foreach ($t in $data.tasks) { $byId[$t.id] = $t }

    foreach ($t in $data.tasks) {
        if ($t.passes)   { continue }
        if ($t.blocked)  { continue }
        $ok = $true
        foreach ($dep in (Get-TaskDependsOn $t)) {
            if (-not $byId.ContainsKey($dep) -or -not $byId[$dep].passes) {
                $ok = $false
                break
            }
        }
        if ($ok) { return $t }
    }
    return $null
}

function Assert-TaskJsonValid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MaxFiles = 5
    )
    $data = Get-Content $Path -Raw | ConvertFrom-Json

    $seen = @{}
    foreach ($t in $data.tasks) {
        if ($seen.ContainsKey($t.id)) {
            throw "Duplicate task id: $($t.id)"
        }
        $seen[$t.id] = $true
    }

    foreach ($t in $data.tasks) {
        if ($t.estimated_files -gt $MaxFiles) {
            throw "Task $($t.id) estimated_files=$($t.estimated_files) > $MaxFiles"
        }
        if (-not $t.verify_cmds -or @($t.verify_cmds).Count -eq 0) {
            throw "Task $($t.id) verify_cmds is empty"
        }
    }

    $state = @{}
    foreach ($t in $data.tasks) { $state[$t.id] = 0 }
    $byId = @{}
    foreach ($t in $data.tasks) { $byId[$t.id] = $t }

    $visit = {
        param($id)
        if ($state[$id] -eq 1) { throw "dependency cycle detected at $id" }
        if ($state[$id] -eq 2) { return }
        $state[$id] = 1
        foreach ($dep in (Get-TaskDependsOn $byId[$id])) {
            if ($byId.ContainsKey($dep)) { & $visit $dep }
        }
        $state[$id] = 2
    }
    foreach ($t in $data.tasks) { & $visit $t.id }
}
