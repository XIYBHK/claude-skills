# run.ps1 集成测试（P2-5 新增）
# 思路：不 mock claude_invoker，而是在 PATH 头部放一个假 claude.cmd shim，
# 让 run.ps1 的 Invoke-HeadlessClaude 真实走 Start-Job → `& claude ...`，
# 从而覆盖 P2-1（exitCode 短路）、P2-3（maxFilesPerTask 读 config）、
# 事务顺序（先 update task 再 git commit）等跨模块行为。

BeforeAll {
    # P2-8：中文 Windows 上 Console.OutputEncoding 默认 gb2312，会让子 pwsh
    # 的中文输出经 pipe 乱码（UTF-16 code point 变形近字），正则断言静默失败。
    $script:PrevOE = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $script:SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:TmpBase   = Join-Path ([System.IO.Path]::GetTempPath()) "run-integ-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpBase | Out-Null

    function script:New-IntegSandbox {
        $id = [guid]::NewGuid().ToString('N').Substring(0,8)
        $d   = Join-Path $script:TmpBase ("sb-$id")
        # bin/ 必须放 sandbox 外，否则 Assert-GitClean 会把 claude.cmd 判为未跟踪 → throw
        $bin = Join-Path $script:TmpBase ("bin-$id")
        New-Item -ItemType Directory -Force -Path (Join-Path $d '.devloop/scripts/lib') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $d '.devloop/logs') | Out-Null
        New-Item -ItemType Directory -Force -Path $bin | Out-Null

        Copy-Item (Join-Path $script:SkillRoot 'scripts/run.ps1') `
                  (Join-Path $d '.devloop/scripts/run.ps1') -Force
        Get-ChildItem (Join-Path $script:SkillRoot 'scripts/lib') -Filter '*.ps1' | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $d ('.devloop/scripts/lib/' + $_.Name)) -Force
        }

        $notes = 'CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无'
        $tj = @{
            schemaVersion = '1.0'
            project = @{ name='t'; mainBranch='main'; createdAt='2026-04-26T00:00:00Z'; lastRunAt=$null }
            tasks = @(
                @{
                    id='T-001'; title='run integ'; description=''; steps=@(); estimated_files=1
                    depends_on=@(); category='feat'; scope='p'; verify_cmds=@('exit 0')
                    passes=$false; attempts=0; blocked=$false; blockReason=''; lastError=''
                    notes=$notes; startedAt=$null; completedAt=$null
                }
            )
        } | ConvertTo-Json -Depth 20
        Set-Content -Path (Join-Path $d '.devloop/task.json') -Value $tj -Encoding utf8
        $cfg = @{
            verify = @{ globalCmds=@() }
            limits = @{ claudeTimeoutSec=60; maxAttemptsPerTask=1; maxFilesPerTask=5; maxConsecBlocked=3 }
            git    = @{ commitTemplate = '{category}({scope}): {title} [{id}]' }
        } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $d '.devloop/config.json') -Value $cfg -Encoding utf8
        # gate G6：需要 CR-5 查证记录
        Set-Content -Path (Join-Path $d '.devloop/logs/task_T-001_research.md') `
                    -Value '# research' -Encoding utf8

        Push-Location $d
        try {
            git init -q --initial-branch=main 2>&1 | Out-Null
            git config user.email 't@e.com'
            git config user.name 't'
            Set-Content 'README.md' -Value 'init' -Encoding utf8
            git add -A 2>&1 | Out-Null
            git commit -q -m 'baseline' 2>&1 | Out-Null
            git checkout -q -b feat-test
        } finally { Pop-Location }
        return @{ Root = $d; Bin = $bin }
    }

    function script:New-FakeClaude {
        param(
            [Parameter(Mandatory)][string]$BinDir,
            [Parameter(Mandatory)][int]$ExitCode,
            [string]$SideEffectScript = ''
        )
        # 用 -EncodedCommand 避 cmd/pwsh 双重 quoting
        $pwshScript = "[Console]::In.ReadToEnd() | Out-Null`n$SideEffectScript`nexit $ExitCode"
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($pwshScript))
        $cmd = "@echo off`r`npwsh -NoProfile -EncodedCommand $encoded`r`nexit /b %ERRORLEVEL%`r`n"
        Set-Content -Path (Join-Path $BinDir 'claude.cmd') -Value $cmd -Encoding ascii -NoNewline
    }

    function script:Invoke-RunPs1 {
        param([Parameter(Mandatory)][string]$Cwd, [Parameter(Mandatory)][string]$BinDir)
        Push-Location $Cwd
        $prevPath = $env:Path
        try {
            $env:Path = $BinDir + ';' + $env:Path
            $out = & pwsh -NoProfile -File '.devloop/scripts/run.ps1' `
                         -MaxTasks 1 -MaxAttemptsPerTask 1 2>&1
            return @{ ExitCode = $LASTEXITCODE; Output = ($out | Out-String) }
        } finally {
            $env:Path = $prevPath
            Pop-Location
        }
    }
}

AfterAll {
    Remove-Item $script:TmpBase -Recurse -Force -ErrorAction SilentlyContinue
    if ($null -ne $script:PrevOE) { [Console]::OutputEncoding = $script:PrevOE }
}

Describe 'run.ps1 integration — fake claude exit 99 (P2-1 短路 + P3-1 blocked exit 5)' {
    It 'exit 99 时不得 commit，task.attempts=1，lastError 含 exit=99，进程 exit=5' {
        $sb = New-IntegSandbox
        New-FakeClaude -BinDir $sb.Bin -ExitCode 99

        $before = (git -C $sb.Root rev-list --count HEAD).Trim()
        $r = Invoke-RunPs1 -Cwd $sb.Root -BinDir $sb.Bin
        $after = (git -C $sb.Root rev-list --count HEAD).Trim()

        $after | Should -Be $before

        $data = Get-Content (Join-Path $sb.Root '.devloop/task.json') -Raw | ConvertFrom-Json
        $t = $data.tasks | Where-Object { $_.id -eq 'T-001' } | Select-Object -First 1
        $t.passes    | Should -Be $false
        $t.attempts  | Should -Be 1
        $t.lastError | Should -Match 'exit=99'
        $t.blocked   | Should -Be $true

        # P3-1：唯一 task 变 blocked 后第二轮 Select-NextTask 返回 null，
        # 不应打印 "全部任务完成" + exit 0，而应 exit 5 + "no runnable tasks"
        $r.ExitCode | Should -Be 5
        $r.Output   | Should -Match 'no runnable tasks'
    }
}

Describe 'run.ps1 integration — init.cmds 失败退出 (P4-1 exit 3)' {
    It 'config.init.cmds 有 exit 1 时，run.ps1 应 exit 3' {
        $sb = New-IntegSandbox
        # 改 config 注入失败的 init.cmds，然后重新 commit 保持 working tree clean
        $cfgPath = Join-Path $sb.Root '.devloop/config.json'
        $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
        Add-Member -InputObject $cfg -NotePropertyName 'init' `
                   -NotePropertyValue ([PSCustomObject]@{ cmds = @('exit 1') }) -Force
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $cfgPath -Encoding utf8
        git -C $sb.Root add .devloop/config.json 2>&1 | Out-Null
        git -C $sb.Root commit -q -m 'inject failing init.cmds' 2>&1 | Out-Null

        New-FakeClaude -BinDir $sb.Bin -ExitCode 0
        $r = Invoke-RunPs1 -Cwd $sb.Root -BinDir $sb.Bin

        $r.ExitCode | Should -Be 3
        $r.Output   | Should -Match 'harness precondition failed'
    }
}

Describe 'run.ps1 integration — 连续 blocked 达阈值 (P4-1 exit 2)' {
    It 'MaxConsecBlocked=1 + fake claude exit 99 → 第一条 blocked 后立即 exit 2' {
        $sb = New-IntegSandbox
        # 把 maxConsecBlocked 降到 1 并重新 commit
        $cfgPath = Join-Path $sb.Root '.devloop/config.json'
        $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
        $cfg.limits.maxConsecBlocked = 1
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $cfgPath -Encoding utf8
        git -C $sb.Root add .devloop/config.json 2>&1 | Out-Null
        git -C $sb.Root commit -q -m 'lower maxConsecBlocked to 1' 2>&1 | Out-Null

        New-FakeClaude -BinDir $sb.Bin -ExitCode 99
        # MaxTasks=0 让 run.ps1 能跑第二轮来触发 exit 2（第一轮仅 blocked++）
        Push-Location $sb.Root
        $prevPath = $env:Path
        try {
            $env:Path = $sb.Bin + ';' + $env:Path
            $out = & pwsh -NoProfile -File '.devloop/scripts/run.ps1' `
                         -MaxAttemptsPerTask 1 2>&1
            $exitCode = $LASTEXITCODE
            $outStr   = ($out | Out-String)
        } finally {
            $env:Path = $prevPath
            Pop-Location
        }
        # 唯一 task 被标 blocked 后 $consecBlocked=1，if ($consecBlocked -ge 1) 立即触发
        $exitCode | Should -Be 2
        $outStr   | Should -Match '连续 1 个任务 blocked'
    }
}

Describe 'run.ps1 integration — fake claude exit 0 + 有效产物 (happy path)' {
    It 'exit 0 且 task 更新合法时，run.ps1 生成新 commit 且 exit=0' {
        $sb = New-IntegSandbox
        $side = @'
$j = Get-Content '.devloop/task.json' -Raw | ConvertFrom-Json
$j.tasks[0].passes = $true
$j | ConvertTo-Json -Depth 20 | Set-Content '.devloop/task.json' -Encoding utf8
'@
        New-FakeClaude -BinDir $sb.Bin -ExitCode 0 -SideEffectScript $side

        $before = [int](git -C $sb.Root rev-list --count HEAD).Trim()
        $r = Invoke-RunPs1 -Cwd $sb.Root -BinDir $sb.Bin
        $after = [int](git -C $sb.Root rev-list --count HEAD).Trim()

        $after | Should -Be ($before + 1)
        $r.ExitCode | Should -Be 0

        $data = Get-Content (Join-Path $sb.Root '.devloop/task.json') -Raw | ConvertFrom-Json
        $t = $data.tasks | Where-Object { $_.id -eq 'T-001' } | Select-Object -First 1
        $t.passes  | Should -Be $true
        $t.blocked | Should -Be $false
    }
}
