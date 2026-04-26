BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/guard_commit.ps1')).Path
    $script:TmpBase    = Join-Path ([System.IO.Path]::GetTempPath()) "guard-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpBase | Out-Null

    function script:New-SandboxDir {
        $d = Join-Path $script:TmpBase ("sb-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        return $d
    }

    function script:Invoke-Guard {
        param([string]$StdinJson, [string]$Cwd)
        Push-Location $Cwd
        try {
            $out = $StdinJson | & pwsh -NoProfile -File $script:ScriptPath 2>&1
            return @{ ExitCode = $LASTEXITCODE; Output = ($out | Out-String) }
        } finally { Pop-Location }
    }
}

AfterAll {
    Remove-Item $script:TmpBase -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'guard_commit.ps1 - routing' {
    It '放行非 git commit 命令' {
        $sb = New-SandboxDir
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"ls -la"}}' -Cwd $sb
        $r.ExitCode | Should -Be 0
    }

    It '在没有 .devloop 的目录里放行 git commit（视作非管理项目）' {
        $sb = New-SandboxDir
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m \"x\""}}' -Cwd $sb
        $r.ExitCode | Should -Be 0
    }
}

Describe 'guard_commit.ps1 - skip-devloop override' {
    It '[skip-devloop] 命令被放行并登记 Overrides' {
        $sb = New-SandboxDir
        New-Item -ItemType Directory -Force -Path (Join-Path $sb '.devloop') | Out-Null
        Set-Content -Path (Join-Path $sb '.devloop/progress.md') -Value "# Progress`n" -Encoding utf8
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m \"[skip-devloop] emergency\""}}' -Cwd $sb
        $r.ExitCode | Should -Be 0
        (Get-Content (Join-Path $sb '.devloop/progress.md') -Raw) | Should -Match '## Overrides'
    }
}

Describe 'guard_commit.ps1 - enforcement gates' {
    BeforeEach {
        $script:SB = New-SandboxDir
        New-Item -ItemType Directory -Force -Path (Join-Path $script:SB '.devloop/logs') | Out-Null
    }

    It '缺 .current_task_id 时拒绝' {
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m x"}}' -Cwd $script:SB
        $r.ExitCode | Should -Not -Be 0
        $r.Output   | Should -Match 'current_task_id'
    }

    It '缺 research.md 时拒绝' {
        Set-Content -Path (Join-Path $script:SB '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m x"}}' -Cwd $script:SB
        $r.ExitCode | Should -Not -Be 0
        $r.Output   | Should -Match 'research\.md'
    }

    It '缺 CR-6 notes 时拒绝' {
        Set-Content -Path (Join-Path $script:SB '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content -Path (Join-Path $script:SB '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        $taskJson = @{ schemaVersion='1.0'; project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null}; tasks=@(
            @{id='T-001';title='x';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$false;attempts=1;blocked=$false;blockReason='';lastError='';notes='';startedAt=$null;completedAt=$null}
        ) } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $script:SB '.devloop/task.json') -Value $taskJson -Encoding utf8
        Set-Content -Path (Join-Path $script:SB '.devloop/config.json') -Value '{"verify":{"globalCmds":[]}}' -Encoding utf8
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m x"}}' -Cwd $script:SB
        $r.ExitCode | Should -Not -Be 0
        $r.Output   | Should -Match 'CR-6'
    }

    It '完整 gate 通过时放行' {
        Set-Content -Path (Join-Path $script:SB '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content -Path (Join-Path $script:SB '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        $taskJson = @{ schemaVersion='1.0'; project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null}; tasks=@(
            @{id='T-001';title='x';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$true;attempts=1;blocked=$false;blockReason='';lastError='';notes='CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无';startedAt=$null;completedAt=$null}
        ) } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $script:SB '.devloop/task.json') -Value $taskJson -Encoding utf8
        Set-Content -Path (Join-Path $script:SB '.devloop/config.json') -Value '{"verify":{"globalCmds":["exit 0"]}}' -Encoding utf8
        # 需要 verify_runner.ps1 可被 guard_commit 加载；复制到 sandbox
        $libDst = Join-Path $script:SB '.devloop/scripts/lib'
        New-Item -ItemType Directory -Force -Path $libDst | Out-Null
        Copy-Item (Join-Path (Split-Path $script:ScriptPath) 'lib/verify_runner.ps1') $libDst
        Copy-Item (Join-Path (Split-Path $script:ScriptPath) 'lib/gate_runner.ps1') $libDst
        # guard_commit 自身也复制到 sandbox 以便相对路径 dot-source lib
        Copy-Item $script:ScriptPath (Join-Path $script:SB '.devloop/scripts/guard_commit.ps1')
        # 用 sandbox 内的 guard 跑
        Push-Location $script:SB
        try {
            $out = '{"tool_input":{"command":"git commit -m x"}}' | & pwsh -NoProfile -File '.devloop/scripts/guard_commit.ps1' 2>&1
            $LASTEXITCODE | Should -Be 0
        } finally { Pop-Location }
    }
}

Describe 'guard_commit.ps1 - task.json diff protection (P0-2)' {
    BeforeEach {
        $script:SB = New-SandboxDir
        New-Item -ItemType Directory -Force -Path (Join-Path $script:SB '.devloop/logs') | Out-Null
        $libDst = Join-Path $script:SB '.devloop/scripts/lib'
        New-Item -ItemType Directory -Force -Path $libDst | Out-Null
        Copy-Item (Join-Path (Split-Path $script:ScriptPath) 'lib/verify_runner.ps1') $libDst
        Copy-Item (Join-Path (Split-Path $script:ScriptPath) 'lib/gate_runner.ps1') $libDst
        Copy-Item $script:ScriptPath (Join-Path $script:SB '.devloop/scripts/guard_commit.ps1')
        Set-Content -Path (Join-Path $script:SB '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content -Path (Join-Path $script:SB '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        Set-Content -Path (Join-Path $script:SB '.devloop/config.json') -Value '{"verify":{"globalCmds":["exit 0"]}}' -Encoding utf8
        $notes = 'CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无'
        $script:BaselineJson = @{ schemaVersion='1.0'; project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null}; tasks=@(
            @{id='T-001';title='x';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$true;attempts=1;blocked=$false;blockReason='';lastError='';notes=$notes;startedAt=$null;completedAt=$null},
            @{id='T-002';title='y';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$false;attempts=0;blocked=$false;blockReason='';lastError='';notes='';startedAt=$null;completedAt=$null}
        ) } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $script:SB '.devloop/task.json') -Value $script:BaselineJson -Encoding utf8
        Push-Location $script:SB
        try {
            git init -q --initial-branch=main 2>&1 | Out-Null
            git config user.email 'test@example.com'
            git config user.name 'test'
            git add .devloop 2>&1 | Out-Null
            git commit -q -m 'baseline' 2>&1 | Out-Null
        } finally { Pop-Location }
    }

    It 'baseline 未改动时通过' {
        Push-Location $script:SB
        try {
            $out = '{"tool_input":{"command":"git commit -m x"}}' | & pwsh -NoProfile -File '.devloop/scripts/guard_commit.ps1' 2>&1
            $LASTEXITCODE | Should -Be 0
        } finally { Pop-Location }
    }

    It '删除 task 被拒' {
        $shortened = $script:BaselineJson | ConvertFrom-Json
        $shortened.tasks = @($shortened.tasks[0])
        $shortened | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:SB '.devloop/task.json') -Encoding utf8
        Push-Location $script:SB
        try {
            $out = '{"tool_input":{"command":"git commit -m x"}}' | & pwsh -NoProfile -File '.devloop/scripts/guard_commit.ps1' 2>&1
            $LASTEXITCODE | Should -Not -Be 0
            ($out | Out-String) | Should -Match '缩短|丢失'
        } finally { Pop-Location }
    }

    It '清空 verify_cmds 被拒' {
        $tampered = $script:BaselineJson | ConvertFrom-Json
        $tampered.tasks[0].verify_cmds = @()
        $tampered | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:SB '.devloop/task.json') -Encoding utf8
        Push-Location $script:SB
        try {
            $out = '{"tool_input":{"command":"git commit -m x"}}' | & pwsh -NoProfile -File '.devloop/scripts/guard_commit.ps1' 2>&1
            $LASTEXITCODE | Should -Not -Be 0
            ($out | Out-String) | Should -Match 'verify_cmds'
        } finally { Pop-Location }
    }
}
