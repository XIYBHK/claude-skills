BeforeAll {
    . $PSScriptRoot/../scripts/lib/claude_invoker.ps1
}

Describe 'Build-Prompt' {
    It '包含 task id' {
        $p = Build-Prompt -TaskId 'T-042' -Attempt 1
        $p | Should -Match 'T-042'
    }

    It '包含 attempt 数' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 2
        $p | Should -Match 'Attempt:\s*2\s*/\s*3'
    }

    It 'attempt=1 时不含上次错误日志引用' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 1
        $p | Should -Not -Match 'Previous error log'
    }

    It 'attempt>1 时包含上次错误日志路径' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 2 -PrevLogPath '.devloop/logs/task_T-001_attempt_1.log'
        $p | Should -Match 'Previous error log'
        $p | Should -Match 'task_T-001_attempt_1\.log'
    }

    It '明确禁止 git commit' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 1
        $p | Should -Match 'Do not run git commit'
    }

    It '引用 RUN.md 路径' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 1
        $p | Should -Match 'RUN\.md'
    }
}
