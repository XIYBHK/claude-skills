# dev-loop/scripts/lib/claude_invoker.ps1
# 函数：Build-Prompt、Invoke-HeadlessClaude
# 单元测试：tests/claude_invoker.Tests.ps1（仅测 Build-Prompt）

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Build-Prompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskId,
        [Parameter(Mandatory)][int]$Attempt,
        [string]$PrevLogPath = '',
        [int]$MaxAttempts = 3
    )
    $cwd = (Get-Location).Path
    $parts = @(
        "You are executing task ``$TaskId`` for the dev-loop harness.",
        "",
        "Read ~/.claude/skills/dev-loop/RUN.md and strictly follow the 7-step protocol.",
        "",
        "Context:",
        "- Working directory: $cwd",
        "- Task ID: $TaskId",
        "- Attempt: $Attempt / $MaxAttempts"
    )
    if ($Attempt -gt 1 -and $PrevLogPath) {
        $parts += "- Previous error log: $PrevLogPath (read first to avoid repeating the error)"
    }
    $parts += @(
        "",
        "Execute the task now. Do not run git commit / git push — run.ps1 handles those.",
        "When finished, update .devloop/task.json (your task's passes/attempts/lastError/notes fields) and exit."
    )
    return ($parts -join "`n")
}

function Invoke-HeadlessClaude {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$LogPath,
        [int]$TimeoutSec = 1800
    )
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }

    $job = Start-Job -ScriptBlock {
        param($p, $log)
        $p | & claude -p --dangerously-skip-permissions --output-format json 2>&1 |
            Tee-Object -FilePath $log | Out-Null
        return $LASTEXITCODE
    } -ArgumentList $Prompt, $LogPath

    $completed = Wait-Job -Job $job -Timeout $TimeoutSec
    if (-not $completed) {
        # KNOWN (v0.1): Stop-Job terminates the PS job host but on Windows
        # the child claude process may be orphaned and continue running until
        # its own timeout. Tracked for v0.2 (use System.Diagnostics.Process).
        Stop-Job -Job $job
        Remove-Job -Job $job -Force
        Add-Content -Path $LogPath -Value "`n[TIMEOUT] killed after $TimeoutSec s"
        return -1
    }
    $exit = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    return [int]$exit
}
