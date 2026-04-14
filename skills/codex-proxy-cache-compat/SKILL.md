---
name: codex-proxy-cache-compat
description: Use when Hermes talks to a custom /codex Responses gateway and cache hits regress after an update, especially for stable-thread chats behind right.codes/codex/v1 or similar Codex-style proxies.
---

# Codex Proxy Cache Compat

这个技能用于维护 Hermes 在自定义 `/codex` Responses 网关上的缓存兼容补丁。

## Scope

- 适用:
  - `api_mode` 最终应为 `codex_responses`
  - `base_url` 是自定义 `/codex` 风格网关
- 已验证目标:
  - `https://right.codes/codex/v1`
- 明确不适用:
  - `api.openai.com`
  - `chatgpt.com/backend-api/codex`
  - `api.githubcopilot.com`
  - `models.github.ai`

## What To Inspect

- `hermes_cli/runtime_provider.py`
  - custom `/codex` 路由是否被识别成 `codex_responses`
- `run_agent.py`
  - `_codex_transport_headers`
  - `_uses_codex_transport_compat_headers`
  - `codex_responses` 请求里是否注入 `extra_headers`
- `hermes_state.py`
  - `prompt_cache_key`
  - `prompt_cache_supported`

## Verification

```bash
python3 -m pytest -q -o addopts='' tests/hermes_cli/test_runtime_provider_resolution.py
PYTHONPATH=/tmp/hermes_test_stubs python3 -m pytest -q -o addopts='' tests/run_agent/test_run_agent_codex_responses.py
python3 -m pytest -q -o addopts='' tests/test_hermes_state.py
```

## Stable Thread Validation

- 用同一个聊天线程
- 用同一个机器人
- 用同一个 endpoint
- 用同一个 model
- 看 `cached_tokens` / `cache_read_tokens`
- 不要只用冷启动 one-shot CLI 下结论

## Common Mistakes

- 把所有 OpenAI 兼容接口都当成 `/codex` 代理
- 给官方 OpenAI 端点也加 Codex transport headers
- 忽略上游是否重写 `prompt_cache_key`
- 只测一次冷启动
