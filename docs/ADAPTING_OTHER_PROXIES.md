# Adapting This Patch For Other Proxies

这个项目不是“所有 OpenAI 兼容接口通吃”的万能补丁。

如果你要适配别的中转站，请按这个顺序做，不要靠猜。

## 1. 先确认是不是 Responses 路径问题

先问自己两个问题：

- 你的网关是不是实际提供了 `/codex` 风格路由？
- 你的模型是不是 `gpt-5` / `codex` 家族，应该走 `codex_responses`？

如果答案都不是，那这个项目大概率不适合你。

## 2. 抓一份真实对照

理想做法是抓两类请求：

- 直接可命中的 Codex 请求
- Hermes 发给同一网关的请求

重点比较：

- `prompt_cache_key`
- `cached_tokens`
- 是否有 transport headers
- 请求前缀是否稳定

## 3. 看网关有没有重写 `prompt_cache_key`

如果上游会把 Hermes 发出的 `prompt_cache_key` 改掉，而且后续还能稳定工作，说明它可能在走自己的 session/cache 语义。

这时你要检查：

- Hermes 是否继续沿用服务端回写的 key
- Hermes 是否错误地过早停止发送 client key

## 4. 看 transport metadata 是否参与缓存判定

这个发布包当前假设某些自定义 `/codex` 网关会看：

- `session_id`
- `x-client-request-id`
- `x-codex-window-id`
- `x-codex-turn-metadata`
- `originator`
- `User-Agent`

如果你的代理不用这套，就不要硬套。

## 5. 你最可能需要改的地方

### `hermes_cli/runtime_provider.py`

改 route detection 逻辑：

- 哪些 URL 应该升级到 `codex_responses`
- 哪些 model name 应该触发这个升级

### `run_agent.py`

改这两个点：

- `_uses_codex_transport_compat_headers`
  - 控制哪些目标启用 transport headers
- `_codex_transport_headers`
  - 控制具体 header 名和值

### `hermes_state.py`

如果你的代理有自己的 session/cache 语义，也许还要调整：

- `prompt_cache_key`
- `prompt_cache_supported`

## 6. 推荐的验证顺序

1. 先跑无工具、稳定提示词的控制实验
2. 再跑真实 Hermes chat shape
3. 再看稳定线程中的 `cached_tokens`
4. 最后才下“值不值得打补丁”的结论

## 7. 不要做的事

- 不要对所有域名直接放开 Codex transport headers
- 不要看到 `/v1` 就假定它支持 Responses 语义
- 不要把个人样本当成通用 benchmark
