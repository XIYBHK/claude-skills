BeforeAll {
    $script:RunPath = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/run.ps1')).Path
    # 只加载函数定义，不跑主循环
    . $script:RunPath -LoadFunctionsOnly
    $script:TmpBase = Join-Path ([System.IO.Path]::GetTempPath()) "runps1-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpBase | Out-Null

    function script:New-GitRepo {
        param([string]$Branch = 'dev', [switch]$Dirty, [switch]$NoDevLoop)
        $d = Join-Path $script:TmpBase ("r-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        Push-Location $d
        try {
            git init -q --initial-branch=main
            git config user.email 'test@example.com'
            git config user.name 'test'
            'init' | Out-File README.md -Encoding utf8
            git add README.md
            git commit -q -m 'init'
            if ($Branch -ne 'main') { git checkout -q -b $Branch }
            if (-not $NoDevLoop) {
                New-Item -ItemType Directory -Force -Path '.devloop/scripts/lib' | Out-Null
                '{"schemaVersion":"1.0","project":{"name":"t","mainBranch":"main","createdAt":"2026-04-26T00:00:00Z","lastRunAt":null},"tasks":[]}' |
                    Out-File '.devloop/task.json' -Encoding utf8
                '{"verify":{"globalCmds":[]},"limits":{"maxFilesPerTask":5}}' |
                    Out-File '.devloop/config.json' -Encoding utf8
                git add .devloop
                git commit -q -m 'add devloop'
            }
            if ($Dirty) { 'dirty' | Out-File 'dirty.txt' -Encoding utf8 }
        } finally { Pop-Location }
        return $d
    }
}

AfterAll {
    Remove-Item $script:TmpBase -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Assert-GitClean' {
    It '干净 repo 通过' {
        $d = New-GitRepo
        Push-Location $d
        try { { Assert-GitClean } | Should -Not -Throw } finally { Pop-Location }
    }
    It '脏 repo 抛异常' {
        $d = New-GitRepo -Dirty
        Push-Location $d
        try { { Assert-GitClean } | Should -Throw '*not clean*' } finally { Pop-Location }
    }
}

Describe 'Assert-BranchNotMain' {
    It '非 main 分支通过' {
        $d = New-GitRepo -Branch dev
        Push-Location $d
        try { { Assert-BranchNotMain } | Should -Not -Throw } finally { Pop-Location }
    }
    It 'main 抛异常' {
        $d = New-GitRepo -Branch main
        Push-Location $d
        try { { Assert-BranchNotMain } | Should -Throw '*main*' } finally { Pop-Location }
    }
}

Describe 'Assert-DevLoopInitialized' {
    It '缺 .devloop 抛异常' {
        $d = New-GitRepo -NoDevLoop
        Push-Location $d
        try { { Assert-DevLoopInitialized } | Should -Throw '*not initialized*' } finally { Pop-Location }
    }
    It '有 .devloop/task.json 通过' {
        $d = New-GitRepo
        Push-Location $d
        try { { Assert-DevLoopInitialized } | Should -Not -Throw } finally { Pop-Location }
    }
}

Describe 'Get-CfgLimit (P1-4)' {
    It '缺 limits 返回默认' {
        $cfg = '{"verify":{"globalCmds":[]}}' | ConvertFrom-Json
        Get-CfgLimit $cfg 'maxAttemptsPerTask' 3 | Should -Be 3
    }
    It '有 limits 但缺对应字段返回默认' {
        $cfg = '{"limits":{"other":42}}' | ConvertFrom-Json
        Get-CfgLimit $cfg 'maxAttemptsPerTask' 3 | Should -Be 3
    }
    It '字段存在返回 config 值' {
        $cfg = '{"limits":{"maxAttemptsPerTask":7}}' | ConvertFrom-Json
        Get-CfgLimit $cfg 'maxAttemptsPerTask' 3 | Should -Be 7
    }
}

Describe 'Invoke-InitCmds (P0-1)' {
    It '缺 init 字段直接返回不抛异常' {
        $cfg = '{"verify":{"globalCmds":[]},"limits":{"maxFilesPerTask":5}}' | ConvertFrom-Json
        { Invoke-InitCmds -Config $cfg } | Should -Not -Throw
    }
    It '空 cmds 数组直接返回不抛异常' {
        $cfg = '{"init":{"cmds":[]},"verify":{"globalCmds":[]}}' | ConvertFrom-Json
        { Invoke-InitCmds -Config $cfg } | Should -Not -Throw
    }
    It '所有 cmd 成功则不抛' {
        $cfg = '{"init":{"cmds":["exit 0","exit 0"]}}' | ConvertFrom-Json
        { Invoke-InitCmds -Config $cfg } | Should -Not -Throw
    }
    It '任一 cmd 失败则抛异常包含 init check failed' {
        $cfg = '{"init":{"cmds":["exit 1"]}}' | ConvertFrom-Json
        { Invoke-InitCmds -Config $cfg } | Should -Throw '*init check failed*'
    }
}
