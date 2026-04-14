# Verification Notes

这个项目里的补丁不是凭感觉写的，验证时看的是实际缓存相关证据。

## 个人使用结果

在我自己的稳定线程使用习惯里，额度消耗大约下降了 50% 左右。

这句话的前提非常重要：

- 同一个线程
- 同一个 endpoint
- 同一个 model
- 有明显可复用的前缀
- 会重复调用

如果你每次都是新线程、新提示词、冷启动，那就不要期待这个数字。

## 本地技术验证思路

### Stage 1

控制变量测试：

- 固定 session
- 固定 prompt
- 固定 request shape

目标：

- `cached_tokens` 稳定非零

### Stage 2

更真实的 Hermes chat shape：

- 保留 Hermes 的 instructions / tools
- 保留真实聊天轮次

目标：

- 稳定线程里仍然出现非零 `cached_tokens`

## 建议你自己也做的验证

```bash
python3 -m pytest -q -o addopts='' tests/hermes_cli/test_runtime_provider_resolution.py
PYTHONPATH=/tmp/hermes_test_stubs python3 -m pytest -q -o addopts='' tests/run_agent/test_run_agent_codex_responses.py
python3 -m pytest -q -o addopts='' tests/test_hermes_state.py
```

然后再做一轮真实线程测试：

- 先热身
- 在同一个线程里发送两次高度相似的输入
- 看 `cached_tokens` / `cache_read_tokens`

## 结论口径

合理的说法是：

- “在我的使用方式里，这个补丁显著改善了 Hermes 在自定义 `/codex` 网关上的缓存复用”

不合理的说法是：

- “这个补丁对所有中转站都能稳定省 50%”
