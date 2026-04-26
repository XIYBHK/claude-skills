# materialize.ps1 测试（P2-6 新增）
# 覆盖 P2-2：-InitPayload 指向最终目标 .devloop/init/payload.json 时
# 不应因 Copy-Item 自拷贝而报错退出。

BeforeAll {
    $script:PrevOE = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/materialize.ps1')).Path
    $script:TmpBase    = Join-Path ([System.IO.Path]::GetTempPath()) "materialize-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpBase | Out-Null

    function script:New-MinimalPayload {
        @{
            project = @{
                name         = 't'
                mainBranch   = 'main'
                projectType  = 'generic'
                createdAt    = '2026-04-26T00:00:00Z'
            }
            q3 = @{
                lintCmd      = 'exit 0'
                typecheckCmd = ''
                unitTestCmd  = 'exit 0'
                buildCmd     = ''
                isUiProject  = $false
            }
            commitCategories   = @('feat','fix')
            context7Available  = $false
            architectureMd     = "# arch`n"
            tasks = @(
                @{
                    id='T-001'; title='x'; description=''; steps=@()
                    estimated_files=1; depends_on=@(); category='feat'; scope='p'
                    verify_cmds=@('exit 0'); passes=$false; attempts=0
                    blocked=$false; blockReason=''; lastError=''; notes=''
                    startedAt=$null; completedAt=$null
                }
            )
        } | ConvertTo-Json -Depth 20
    }
}

AfterAll {
    Remove-Item $script:TmpBase -Recurse -Force -ErrorAction SilentlyContinue
    if ($null -ne $script:PrevOE) { [Console]::OutputEncoding = $script:PrevOE }
}

Describe 'materialize.ps1 - src==dst self-copy (P2-2)' {
    It 'InitPayload 指向默认 dst 路径时不应报 "overwrite with itself"' {
        $sb = Join-Path $script:TmpBase ("sb-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path (Join-Path $sb '.devloop/init') | Out-Null
        $payload = Join-Path $sb '.devloop/init/payload.json'
        Set-Content -Path $payload -Value (New-MinimalPayload) -Encoding utf8
        $bytesBefore = (Get-Item $payload).Length

        $out = & pwsh -NoProfile -File $script:ScriptPath -InitPayload $payload -ProjectRoot $sb 2>&1
        $LASTEXITCODE | Should -Be 0
        Test-Path $payload | Should -Be $true
        (Get-Item $payload).Length | Should -Be $bytesBefore
    }

    It '外部 payload 复制到 .devloop/init/payload.json 正常' {
        $sb = Join-Path $script:TmpBase ("sb-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $sb | Out-Null
        $external = Join-Path $script:TmpBase ("extern-" + [guid]::NewGuid().ToString('N').Substring(0,8) + '.json')
        Set-Content -Path $external -Value (New-MinimalPayload) -Encoding utf8

        $out = & pwsh -NoProfile -File $script:ScriptPath -InitPayload $external -ProjectRoot $sb 2>&1
        $LASTEXITCODE | Should -Be 0
        Test-Path (Join-Path $sb '.devloop/init/payload.json') | Should -Be $true
    }
}
