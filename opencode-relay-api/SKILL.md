---
name: opencode-relay-api
description: Use when configuring OpenCode (anomalyco/opencode v1.3+) to use a relay/proxy API endpoint instead of official provider APIs. Triggers - setting up OpenCode on new machine, 404 Not Found from relay, baseURL not working, OAuth overriding relay config, Gemini v1beta path mismatch.
---

# OpenCode Relay API Configuration

## Overview

OpenCode (anomalyco/opencode) supports custom relay API endpoints via `provider.<name>.options.baseURL`. Each provider SDK has different URL path conventions, requiring provider-specific baseURL formats. OAuth tokens in `auth.json` override relay config and must be cleared.

## Key Pitfalls

| Problem | Root Cause | Fix |
|---------|-----------|-----|
| Anthropic 404 | SDK appends `messages` to baseURL, expects baseURL to include `/v1` | baseURL must end with `/v1` |
| OpenAI 404 | SDK appends path after baseURL | baseURL must end with `/v1/` |
| Gemini 404 | Relay only supports `/v1/` but SDK defaults to `/v1beta/`; overriding built-in `google` provider has known bug (#5674) | Register custom provider with `@ai-sdk/google` npm package |
| "max" label in UI / ignores relay config | `auth.json` contains OAuth token from `/connect` login, overrides provider config | Delete OAuth entries from `auth.json` |
| baseURL trailing slash | Go SDK `url.Parse` treats no-trailing-slash path segment as filename, replaces it during join | Anthropic: no trailing slash after `/v1`; OpenAI: trailing slash after `/v1/` |

## Configuration Template

### opencode.json

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "YOUR_RELAY_KEY",
        "baseURL": "https://YOUR_RELAY/claude/v1"
      }
    },
    "openai": {
      "options": {
        "apiKey": "YOUR_RELAY_KEY",
        "baseURL": "https://YOUR_RELAY/openai/v1/"
      }
    },
    "my-gemini": {
      "npm": "@ai-sdk/google",
      "name": "My Gemini",
      "options": {
        "apiKey": "YOUR_RELAY_KEY",
        "baseURL": "https://YOUR_RELAY/gemini/v1"
      },
      "models": {
        "gemini-3.1-pro-preview": {
          "name": "Gemini 3.1 Pro Preview",
          "limit": { "context": 1048576, "output": 65536 }
        },
        "gemini-2.5-pro": {
          "name": "Gemini 2.5 Pro",
          "limit": { "context": 1048576, "output": 65536 }
        }
      }
    }
  }
}
```

### Gemini Model References

When using oh-my-openagent or other plugins that reference Gemini models, change the provider prefix from `google/` to the custom provider name:

```
google/gemini-3.1-pro-preview  ->  my-gemini/gemini-3.1-pro-preview
```

## Setup Checklist

1. **Write `opencode.json`** with provider configs per template above
2. **Clear OAuth tokens**: Edit `~/.local/share/opencode/auth.json`, remove any `openai`/`anthropic` OAuth entries (keep API-key-only entries like zhipuai)
3. **Verify relay connectivity** before launching OpenCode:
   ```bash
   # Anthropic
   curl -s -w "%{http_code}" "$RELAY/claude/v1/messages" \
     -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" \
     -H "content-type: application/json" \
     -d '{"model":"claude-sonnet-4-20250514","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}'

   # OpenAI
   curl -s -w "%{http_code}" "$RELAY/openai/v1/models" \
     -H "Authorization: Bearer $KEY"

   # Gemini
   curl -s -w "%{http_code}" "$RELAY/gemini/v1/models/gemini-2.5-pro:generateContent" \
     -H "x-goog-api-key: $KEY" -H "content-type: application/json" \
     -d '{"contents":[{"role":"user","parts":[{"text":"hi"}]}],"generationConfig":{"maxOutputTokens":10}}'
   ```
4. **Update plugin configs** (oh-my-opencode.json etc.) to use custom provider prefix for Gemini models
5. **Restart OpenCode** (new terminal if env vars changed)

## Troubleshooting

**Still getting 404?** Check the actual URL being requested:
- Anthropic SDK: `{baseURL}/messages` (baseURL should include `/v1`)
- OpenAI SDK: `{baseURL}/chat/completions` (baseURL should include `/v1/`)
- Google SDK (`@ai-sdk/google`): `{baseURL}/models/{model}:generateContent` (baseURL should include `/v1`)

**Relay requires different auth header?** Test with curl first. Common patterns:
- Anthropic relay: `x-api-key` header
- OpenAI relay: `Authorization: Bearer` header
- Gemini relay: `x-goog-api-key` header or `Authorization: Bearer` header

**Claude Code Gemini same issue?** Set env var `GOOGLE_GENAI_API_VERSION=v1` to switch SDK from `/v1beta/` to `/v1/`.

## References

- [anomalyco/opencode#5777](https://github.com/anomalyco/opencode/issues/5777) - Custom Gemini baseURL solution
- [anomalyco/opencode#5674](https://github.com/anomalyco/opencode/issues/5674) - Custom provider options not passed bug
- [anomalyco/opencode#5163](https://github.com/anomalyco/opencode/issues/5163) - Anthropic baseURL needs `/v1`
- [OpenCode Providers Docs](https://opencode.ai/docs/providers/)
