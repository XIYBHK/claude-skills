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
