BeforeAll {
    $script:LibPath = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/lib/gate_runner.ps1')).Path
    . $script:LibPath
    $script:TmpBase = Join-Path ([System.IO.Path]::GetTempPath()) "gaterunner-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpBase | Out-Null

    function script:New-GateSandbox {
        $d = Join-Path $script:TmpBase ("sb-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path (Join-Path $d '.devloop/logs') | Out-Null
        return $d
    }

    function script:Write-MinTaskJson {
        param($Cwd, [string]$Notes = 'CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无')
        $json = @{
            schemaVersion='1.0';
            project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null};
            tasks=@(
                @{id='T-001';title='x';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$false;attempts=1;blocked=$false;blockReason='';lastError='';notes=$Notes;startedAt=$null;completedAt=$null}
            )
        } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $Cwd '.devloop/task.json') -Value $json -Encoding utf8
    }
}

AfterAll {
    Remove-Item $script:TmpBase -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Test-DevLoopGates (P1-1)' {
    It '缺 .current_task_id 返回 false' {
        $sb = New-GateSandbox
        (Test-DevLoopGates -Cwd $sb) 2>$null | Should -Be $false
    }

    It '缺 research.md 返回 false' {
        $sb = New-GateSandbox
        Set-Content (Join-Path $sb '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        (Test-DevLoopGates -Cwd $sb) 2>$null | Should -Be $false
    }

    It 'notes 缺 CR-6 返回 false' {
        $sb = New-GateSandbox
        Set-Content (Join-Path $sb '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content (Join-Path $sb '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        Write-MinTaskJson -Cwd $sb -Notes ''
        (Test-DevLoopGates -Cwd $sb) 2>$null | Should -Be $false
    }

    It 'CR-6 声明"有"时 lessons 当日无条目返回 false' {
        $sb = New-GateSandbox
        Set-Content (Join-Path $sb '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content (Join-Path $sb '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        Write-MinTaskJson -Cwd $sb -Notes 'CR-6: 超出描述=有 某块多删了 / 过度抽象=无 / 更简替代=无'
        Set-Content (Join-Path $sb '.devloop/lessons.md') -Value "# Lessons`n`n## 1999-01-01`n`n- old" -Encoding utf8
        (Test-DevLoopGates -Cwd $sb) 2>$null | Should -Be $false
    }

    It '完整 gate 通过时（无 HEAD git）返回 true' {
        $sb = New-GateSandbox
        Set-Content (Join-Path $sb '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content (Join-Path $sb '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        Write-MinTaskJson -Cwd $sb
        Test-DevLoopGates -Cwd $sb | Should -Be $true
    }

    It 'HEAD 存在时 task 被删返回 false' {
        $sb = New-GateSandbox
        Set-Content (Join-Path $sb '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content (Join-Path $sb '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        # baseline 含 2 task
        $baseline = @{
            schemaVersion='1.0';
            project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null};
            tasks=@(
                @{id='T-001';title='x';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$false;attempts=0;blocked=$false;blockReason='';lastError='';notes='CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无';startedAt=$null;completedAt=$null},
                @{id='T-002';title='y';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$false;attempts=0;blocked=$false;blockReason='';lastError='';notes='';startedAt=$null;completedAt=$null}
            )
        } | ConvertTo-Json -Depth 10
        Set-Content (Join-Path $sb '.devloop/task.json') -Value $baseline -Encoding utf8
        Push-Location $sb
        try {
            git init -q --initial-branch=main 2>&1 | Out-Null
            git config user.email 't@e.com'
            git config user.name 't'
            git add .devloop 2>&1 | Out-Null
            git commit -q -m 'baseline' 2>&1 | Out-Null
        } finally { Pop-Location }
        # 当前版本把 T-002 删掉
        Write-MinTaskJson -Cwd $sb
        (Test-DevLoopGates -Cwd $sb) 2>$null | Should -Be $false
    }
}
