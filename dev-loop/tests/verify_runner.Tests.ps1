BeforeAll {
    . $PSScriptRoot/../scripts/lib/verify_runner.ps1
    $script:TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "dev-loop-verify-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpDir | Out-Null
}

AfterAll {
    Remove-Item $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-VerifyRunner' {
    It '全部命令成功时返回 $true' {
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @('exit 0') }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @('exit 0') } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeTrue
    }

    It 'globalCmd 失败时返回 $false（且 task.verify_cmds 不再执行）' {
        $marker = Join-Path $script:TmpDir 'task_did_run.txt'
        if (Test-Path $marker) { Remove-Item $marker }
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @("'x' | Out-File -Encoding utf8 '$marker'") }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @('exit 1') } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeFalse
        Test-Path $marker | Should -BeFalse
    }

    It 'task.verify_cmd 失败时返回 $false' {
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @('exit 3') }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @('exit 0') } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeFalse
    }

    It 'globalCmds 先于 task.verify_cmds 执行' {
        $marker = Join-Path $script:TmpDir 'order.txt'
        if (Test-Path $marker) { Remove-Item $marker }
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @("'task' | Out-File -Append -Encoding utf8 '$marker'") }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @("'global' | Out-File -Append -Encoding utf8 '$marker'") } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeTrue
        ((Get-Content $marker) -join ',') | Should -Match 'global.*task'
    }

    It '空 globalCmds 也能运行' {
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @('exit 0') }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @() } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeTrue
    }

    It 'Config 缺 verify 属性时不崩（StrictMode 兼容）' {
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @('exit 0') }
        $cfg  = [pscustomobject]@{ other = 'x' }
        { Invoke-VerifyRunner -Task $task -Config $cfg } | Should -Not -Throw
    }

    It 'Task 缺 verify_cmds 属性时不崩（StrictMode 兼容）' {
        $task = [pscustomobject]@{ id = 'T-001' }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @('exit 0') } }
        { Invoke-VerifyRunner -Task $task -Config $cfg } | Should -Not -Throw
    }
}
