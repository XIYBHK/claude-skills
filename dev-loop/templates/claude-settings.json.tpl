{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -File .devloop/scripts/guard_commit.ps1"
          }
        ]
      }
    ]
  }
}
