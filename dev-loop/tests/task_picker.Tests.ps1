BeforeAll {
    . $PSScriptRoot/../scripts/lib/task_picker.ps1
    $script:FixtureDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Select-NextTask' {
    It '返回第一个 passes=false 且依赖已完成的任务' {
        $t = Select-NextTask -Path (Join-Path $script:FixtureDir 'valid_task.json')
        $t.id | Should -Be 'T-002'
    }

    It '依赖未 passed 的任务不会被选中' {
        $t = Select-NextTask -Path (Join-Path $script:FixtureDir 'valid_task.json')
        $t.id | Should -Not -Be 'T-003'
    }

    It '全部完成时返回 $null' {
        $tmpJson = Join-Path ([System.IO.Path]::GetTempPath()) 'allDone.json'
        @{ schemaVersion='1.0'; project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null}; tasks=@(
            @{id='T-001';title='';description='';steps=@();estimated_files=1;depends_on=@();category='c';scope='p';verify_cmds=@('true');passes=$true;attempts=1;blocked=$false;blockReason='';lastError='';notes='';startedAt=$null;completedAt=$null}
        ) } | ConvertTo-Json -Depth 10 | Set-Content $tmpJson
        Select-NextTask -Path $tmpJson | Should -BeNullOrEmpty
        Remove-Item $tmpJson
    }
}

Describe 'Assert-TaskJsonValid' {
    It '对 estimated_files 超限抛异常' {
        { Assert-TaskJsonValid -Path (Join-Path $script:FixtureDir 'oversize.json') -MaxFiles 5 } |
            Should -Throw '*estimated_files*'
    }

    It '对依赖环抛异常' {
        { Assert-TaskJsonValid -Path (Join-Path $script:FixtureDir 'cyclic_deps.json') -MaxFiles 5 } |
            Should -Throw '*cycle*'
    }

    It '合法 fixture 静默通过' {
        { Assert-TaskJsonValid -Path (Join-Path $script:FixtureDir 'valid_task.json') -MaxFiles 5 } |
            Should -Not -Throw
    }
}
