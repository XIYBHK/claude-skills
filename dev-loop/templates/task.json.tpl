{
  "schemaVersion": "1.0",
  "project": {
    "name": "<PROJECT_NAME>",
    "mainBranch": "main",
    "createdAt": "<ISO_8601_TIMESTAMP>",
    "lastRunAt": null
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "<任务标题>",
      "description": "<任务的完整描述，包含上下文和约束>",
      "steps": [
        "<步骤 1>",
        "<步骤 2>"
      ],
      "estimated_files": 3,
      "depends_on": [],
      "category": "chore",
      "scope": "project",
      "verify_cmds": [
        "npm run lint",
        "npm run build"
      ],
      "passes": false,
      "attempts": 0,
      "blocked": false,
      "blockReason": "",
      "lastError": "",
      "notes": "",
      "startedAt": null,
      "completedAt": null
    }
  ]
}
