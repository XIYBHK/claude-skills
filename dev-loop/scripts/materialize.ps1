# dev-loop/scripts/materialize.ps1
# P1-6：INIT 段 4 确定性落盘器。把 INIT §1-3 产物（一份 init.json）
# + skill templates → 项目目录的具体文件。Claude 只负责填 init.json，
# 文件拷贝/追加/占位符替换由本脚本确定性完成。
#
# 用法：
#   pwsh -File materialize.ps1 -InitPayload .devloop/init/payload.json [-ProjectRoot .]
#
# init.json schema（Claude 段 1-3 产出）：
#   {
#     "project":        { "name":"X", "mainBranch":"main", "projectType":"web",
#                         "createdAt":"2026-04-26T..." },
#     "q3":             { "lintCmd":"...", "typecheckCmd":"...", "unitTestCmd":"...",
#                         "buildCmd":"...", "isUiProject":true,
#                         "browserTests": { "url":"...", "requiredSelectors":[] } },
#     "commitCategories":["feat","fix","refactor","docs","test","chore"],
#     "context7Available": true,
#     "architectureMd":  "<完整 architecture.md 正文>",
#     "tasks":           [ { task-schema... }, ... ]
#   }

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InitPayload,
    [string]$ProjectRoot = '.'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InitPayload)) { throw "缺 init payload: $InitPayload" }
if (-not (Test-Path $ProjectRoot)) { throw "ProjectRoot 不存在: $ProjectRoot" }

$payload = Get-Content $InitPayload -Raw | ConvertFrom-Json
$skillRoot = Split-Path $PSScriptRoot -Parent  # .../dev-loop/
$tpl = Join-Path $skillRoot 'templates'

# === 1. 建目录骨架 ===
$devloop = Join-Path $ProjectRoot '.devloop'
@(
    $devloop,
    (Join-Path $devloop 'logs'),
    (Join-Path $devloop 'scripts'),
    (Join-Path $devloop 'scripts/lib'),
    (Join-Path $devloop 'init'),
    (Join-Path $ProjectRoot '.claude')
) | ForEach-Object { if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null } }

# === 2. 拷贝 scripts/ 到 .devloop/scripts ===
Copy-Item (Join-Path $skillRoot 'scripts/run.ps1')            (Join-Path $devloop 'scripts/run.ps1')            -Force
Copy-Item (Join-Path $skillRoot 'scripts/guard_commit.ps1')   (Join-Path $devloop 'scripts/guard_commit.ps1')   -Force
Copy-Item (Join-Path $skillRoot 'scripts/browser_verify.ps1') (Join-Path $devloop 'scripts/browser_verify.ps1') -Force
Get-ChildItem (Join-Path $skillRoot 'scripts/lib') -Filter '*.ps1' | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $devloop "scripts/lib/$($_.Name)") -Force
}

# === 3. 渲染 config.json（含 browserTests 映射） ===
$cfgTpl = Get-Content (Join-Path $tpl 'config.json.tpl') -Raw | ConvertFrom-Json
$cfgTpl.projectType = [string]$payload.project.projectType
$cfgTpl.git.mainBranch = [string]$payload.project.mainBranch

# Q3 → verify.globalCmds
$globalCmds = @()
if ($payload.q3.PSObject.Properties['lintCmd']       -and $payload.q3.lintCmd)       { $globalCmds += $payload.q3.lintCmd }
if ($payload.q3.PSObject.Properties['typecheckCmd']  -and $payload.q3.typecheckCmd)  { $globalCmds += $payload.q3.typecheckCmd }
if ($payload.q3.PSObject.Properties['unitTestCmd']   -and $payload.q3.unitTestCmd)   { $globalCmds += $payload.q3.unitTestCmd }
if ($payload.q3.PSObject.Properties['buildCmd']      -and $payload.q3.buildCmd)      { $globalCmds += $payload.q3.buildCmd }

# UI 项目：追加 browser_verify 命令 + 覆盖 browserTests 字段
$isUi = $false
if ($payload.q3.PSObject.Properties['isUiProject']) { $isUi = [bool]$payload.q3.isUiProject }
if ($isUi) {
    $globalCmds += 'pwsh -NoProfile -File .devloop/scripts/browser_verify.ps1'
    $cfgTpl.verify.browserTests.enabled = $true
    if ($payload.q3.PSObject.Properties['browserTests']) {
        $bt = $payload.q3.browserTests
        if ($bt.PSObject.Properties['url']               -and $bt.url)               { $cfgTpl.verify.browserTests.url = [string]$bt.url }
        if ($bt.PSObject.Properties['requiredSelectors'] -and $bt.requiredSelectors) { $cfgTpl.verify.browserTests.requiredSelectors = @($bt.requiredSelectors) }
    }
}
$cfgTpl.verify.globalCmds = $globalCmds

# context7 可用性
if ($payload.PSObject.Properties['context7Available']) {
    $cfgTpl.claude.mcp.context7Available = [bool]$payload.context7Available
}

$cfgTpl | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $devloop 'config.json') -Encoding utf8

# === 4. 渲染 task.json（插入真实 tasks 数组） ===
$taskTpl = Get-Content (Join-Path $tpl 'task.json.tpl') -Raw | ConvertFrom-Json
$taskTpl.project.name       = [string]$payload.project.name
$taskTpl.project.mainBranch = [string]$payload.project.mainBranch
$taskTpl.project.createdAt  = [string]$payload.project.createdAt
$taskTpl.tasks              = @($payload.tasks)
$taskTpl | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $devloop 'task.json') -Encoding utf8

# === 5. 写 architecture.md（正文由 Claude 段 2 产出，原样落盘） ===
Set-Content -Path (Join-Path $ProjectRoot 'architecture.md') -Value ([string]$payload.architectureMd) -Encoding utf8

# === 6. 渲染 CLAUDE.md ===
$claudeMd = Get-Content (Join-Path $tpl 'CLAUDE.md.tpl') -Raw
$claudeMd = $claudeMd.Replace('<PROJECT_NAME>', [string]$payload.project.name)
Set-Content -Path (Join-Path $ProjectRoot 'CLAUDE.md') -Value $claudeMd -Encoding utf8

# === 7. 拷贝 claude-settings.json 与空白 progress/lessons ===
Copy-Item (Join-Path $tpl 'claude-settings.json.tpl') (Join-Path $ProjectRoot '.claude/settings.json') -Force
Copy-Item (Join-Path $tpl 'progress.md.tpl')          (Join-Path $devloop 'progress.md')                -Force
Copy-Item (Join-Path $tpl 'lessons.md.tpl')           (Join-Path $devloop 'lessons.md')                 -Force

# === 8. 追加 .gitignore（若已有则跳过重复行） ===
$gitIgnore = Join-Path $ProjectRoot '.gitignore'
$snippet = Get-Content (Join-Path $tpl 'gitignore.tpl') -Raw
if (Test-Path $gitIgnore) {
    $existing = Get-Content $gitIgnore -Raw
    if ($existing -notmatch '\.devloop/logs/') {
        Add-Content -Path $gitIgnore -Value "`n$snippet" -Encoding utf8
    }
} else {
    Set-Content -Path $gitIgnore -Value $snippet -Encoding utf8
}

# === 9. 留痕 init payload 到 .devloop/init/ 供审计 ===
Copy-Item $InitPayload (Join-Path $devloop 'init/payload.json') -Force

Write-Host "✓ materialize 完成"
Write-Host "  项目根:        $ProjectRoot"
Write-Host "  tasks:         $(@($payload.tasks).Count) 条"
Write-Host "  globalCmds:    $(@($globalCmds).Count) 条"
Write-Host "  UI 项目:       $isUi"
