# dev-loop/scripts/browser_verify.ps1
# P1-5：最小 browser verifier。读 .devloop/config.json 的 verify.browserTests
# 字段，生成临时 Playwright .mjs 脚本，用 `npx playwright` 跑，返回 exit code
# 供 verify_runner 消费。
#
# 功能（对齐 Anthropic《effective harnesses》"像用户一样测试"原则）：
#   1. URL 打开（失败 → 非零）
#   2. Console error 检查（有 error → 非零）
#   3. requiredSelectors 存在性（缺 → 非零）
#   4. 截图落盘到 screenshotDir
#
# 依赖：用户项目根目录有可用的 `npx playwright`（通常 `npm i -D @playwright/test`）
# 若无 node/playwright → 明确报错，让用户装或关闭 browserTests.enabled

[CmdletBinding()]
param(
    [string]$ConfigPath = '.devloop/config.json'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# P5-3: 薄 helper。本脚本可被 verify_cmds 独立调用，与 run.ps1 / guard_commit.ps1
# 维护独立副本以避免对 lib 的隐式依赖。
function Exit-WithError {
    param([Parameter(Mandatory)][int]$Code, [Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
    exit $Code
}

if (-not (Test-Path $ConfigPath)) {
    Exit-WithError -Code 1 -Message "browser_verify: 缺 $ConfigPath"
}
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# 读 browserTests（StrictMode-safe）
$verifyProp = $cfg.PSObject.Properties['verify']
if ($null -eq $verifyProp -or $null -eq $verifyProp.Value) {
    Write-Host 'browser_verify: 无 verify 配置，跳过'
    exit 0
}
$btProp = $verifyProp.Value.PSObject.Properties['browserTests']
if ($null -eq $btProp -or $null -eq $btProp.Value) {
    Write-Host 'browser_verify: 无 browserTests 配置，跳过'
    exit 0
}
$bt = $btProp.Value

$enabledProp = $bt.PSObject.Properties['enabled']
$enabled = ($null -ne $enabledProp) -and ([bool]$enabledProp.Value)
if (-not $enabled) {
    Write-Host 'browser_verify: browserTests.enabled=false，跳过'
    exit 0
}

function Get-BTProp {
    param($Obj, [string]$Name, $Default)
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    return $p.Value
}
$url                = [string](Get-BTProp $bt 'url' 'http://localhost:3000')
$consoleErrorCheck  = [bool]  (Get-BTProp $bt 'consoleErrorCheck' $true)
$requiredSelectors  = @(      Get-BTProp $bt 'requiredSelectors' @())
$screenshotDir      = [string](Get-BTProp $bt 'screenshotDir' '.devloop/logs/screenshots')

if (-not (Test-Path $screenshotDir)) {
    New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null
}

# 预检：npx 可用？
$null = Get-Command npx -ErrorAction SilentlyContinue
if (-not $?) {
    Exit-WithError -Code 1 -Message 'browser_verify: 未找到 npx。请装 Node.js 和 @playwright/test，或关闭 verify.browserTests.enabled'
}

# 生成临时 Playwright 脚本
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "devloop-browser-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$scriptPath = Join-Path $tmpDir 'verify.mjs'

$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$screenshotAbs = (Resolve-Path $screenshotDir).Path
$shotPath = (Join-Path $screenshotAbs "verify-$ts.png") -replace '\\','/'
$selectorsJson = ($requiredSelectors | ConvertTo-Json -Compress)
if ([string]::IsNullOrWhiteSpace($selectorsJson) -or $selectorsJson -eq 'null') { $selectorsJson = '[]' }

$mjs = @"
import { chromium } from 'playwright';

const url = '$url';
const consoleErrorCheck = $(if ($consoleErrorCheck) { 'true' } else { 'false' });
const requiredSelectors = $selectorsJson;
const shotPath = '$shotPath';

const errors = [];
let exitCode = 0;

const browser = await chromium.launch();
const ctx = await browser.newContext();
const page = await ctx.newPage();

page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
});
page.on('pageerror', err => errors.push('PAGEERROR: ' + err.message));

try {
    const res = await page.goto(url, { waitUntil: 'load', timeout: 30000 });
    if (!res || !res.ok()) {
        console.error('LOAD_FAIL:', url, res ? res.status() : 'no response');
        exitCode = 2;
    }
} catch (e) {
    console.error('NAVIGATE_FAIL:', e.message);
    exitCode = 2;
}

// requiredSelectors 存在性
for (const sel of requiredSelectors) {
    const loc = page.locator(sel);
    const count = await loc.count().catch(() => 0);
    if (count === 0) {
        console.error('SELECTOR_MISSING:', sel);
        exitCode = 3;
    }
}

// screenshot 总要落盘（失败时也有证据）
try {
    await page.screenshot({ path: shotPath, fullPage: true });
    console.log('SCREENSHOT:', shotPath);
} catch (e) {
    console.error('SCREENSHOT_FAIL:', e.message);
}

if (consoleErrorCheck && errors.length > 0) {
    console.error('CONSOLE_ERRORS:', JSON.stringify(errors));
    exitCode = 4;
}

await browser.close();
process.exit(exitCode);
"@

Set-Content -Path $scriptPath -Value $mjs -Encoding utf8

Write-Host ">>> [browser_verify] $url (selectors: $($requiredSelectors.Count))"
& npx playwright install chromium 2>&1 | Out-Null  # 确保浏览器已装
& node $scriptPath
$code = $LASTEXITCODE

# 清理临时脚本（保留截图）
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

if ($code -ne 0) {
    # 注意：非 exit 1，保留 Playwright 原始退出码转发
    Exit-WithError -Code $code -Message "browser_verify: 失败 (exit=$code)"
}
exit 0
