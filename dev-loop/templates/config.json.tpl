{
  "schemaVersion": "1.0",
  "projectType": "<由 init 段 1 Q2 填写，自由文本>",
  "init": {
    "cmds": [],
    "markerFile": ".devloop/.initialized"
  },
  "verify": {
    "globalCmds": [],
    "browserTests": {
      "enabled": false,
      "url": "http://localhost:3000",
      "consoleErrorCheck": true,
      "requiredSelectors": [],
      "screenshotDir": ".devloop/logs/screenshots"
    },
    "manualChecklist": []
  },
  "limits": {
    "maxAttemptsPerTask": 3,
    "maxConsecBlocked": 3,
    "maxFilesPerTask": 5,
    "claudeTimeoutSec": 1800,
    "totalBudgetMinutes": 0
  },
  "git": {
    "mainBranch": "main",
    "autoPush": false,
    "autoPR": false,
    "commitTemplate": "{category}({scope}): {title}\n\nTask-ID: {id}\nAttempts: {attempts}\nVerified: {verifyCmds}"
  },
  "claude": {
    "model": null,
    "dangerouslySkipPermissions": true,
    "outputFormat": "json",
    "mcp": {
      "context7Available": false
    }
  }
}
