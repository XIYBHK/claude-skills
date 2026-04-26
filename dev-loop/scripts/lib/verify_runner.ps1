# dev-loop/scripts/lib/verify_runner.ps1
# 函数：Invoke-VerifyRunner
# 单元测试：tests/verify_runner.Tests.ps1

Set-StrictMode -Version 3.0

# StrictMode 3.0 下直接访问 PSCustomObject 缺省属性会 throw。
# 此 helper 返回属性值或 $null，缺字段不崩。
function Get-OptProp {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Invoke-VerifyRunner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Task,
        [Parameter(Mandatory)][object]$Config
    )

    $cmds = @()

    # StrictMode-safe: Config 缺 verify / verify 缺 globalCmds → 跳过
    $verify = Get-OptProp $Config 'verify'
    if ($null -ne $verify) {
        $globalCmds = Get-OptProp $verify 'globalCmds'
        if ($null -ne $globalCmds) { $cmds += @($globalCmds) }
    }

    # StrictMode-safe: Task 缺 verify_cmds → 跳过
    $taskCmds = Get-OptProp $Task 'verify_cmds'
    if ($null -ne $taskCmds) { $cmds += @($taskCmds) }

    foreach ($cmd in $cmds) {
        if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
        Write-Host ">>> [verify] $cmd"
        & pwsh -NoProfile -Command $cmd
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host "    ^ FAILED (exit=$code)"
            return $false
        }
    }
    return $true
}
