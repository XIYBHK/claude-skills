# headless-gotchas.md — Windows + headless Claude 已知坑

## PowerShell 编码

默认 PowerShell 7 输出 UTF-8 无 BOM。但某些命令（特别是 `Out-File` / `Set-Content` 不带 `-Encoding`）可能写入 UTF-16 LE。

**规则**：所有写文件操作必须显式 `-Encoding utf8`。

## claude -p 的 stdin 传入

长 prompt 或含特殊字符时，不要用 `claude -p "<prompt>"`（argv 易被 shell 解析错误）。改用管道：

```powershell
$prompt | & claude -p --dangerously-skip-permissions --output-format json
```

## --dangerously-skip-permissions 行为

该标志必须存在，否则每个 Edit/Write/Bash 都会被 prompt 拦住，headless 循环失效。
使用该标志即等于"授权所有 Claude 操作" — 只在沙箱或可控项目使用。

## Start-Job 超时

`Invoke-HeadlessClaude` 用 Start-Job + Wait-Job -Timeout 实现。**坑**：Wait-Job 返回 `$null` 表示超时，之后 `Stop-Job` + `Remove-Job -Force`，否则 job 残留。

## Tee-Object 在 pipe 最后

想同时落盘 + 继续 pipe 时，`Tee-Object -FilePath` 放 pipe 末尾即可；放中间会把后续命令的输入改成 Tee 的输出对象。

## git 中文路径

Windows + git 遇中文路径可能出现 octal escape。设：

```powershell
git config --global core.quotepath false
```

## Pester 5.x 断言

Pester 5 的 `Should -Throw` 匹配**异常消息**用 `*...*` glob 模式，不是 regex。要 regex 用 `Should -Match`（对输出字符串）。

## PSScriptRoot 在 dot-sourcing 后

dot-source 脚本时 `$PSScriptRoot` 指向**被 source 的脚本**的目录。在 `guard_commit.ps1` 中用 `Join-Path $PSScriptRoot 'lib/...'` 才能稳定定位 lib。

## `$ErrorActionPreference='Stop'` 与退出码

在脚本顶层设置 `$ErrorActionPreference='Stop'` 后，`Write-Error; exit N`
里的 `exit N` 不会执行，进程通常变成 exit 1。v0.1.6 的顶层脚本用
`Exit-WithError` 直写 stderr 后显式 `exit N`，保持 exit 2/3/4/5 语义。

例外：`scripts/lib/gate_runner.ps1` 在函数内部使用
`$ErrorActionPreference='Continue'`，`Write-Error` 后返回 `$false` 是有意设计。
