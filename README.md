# Hermes Codex Proxy Cache Compat

面向 Hermes 的一个公开补丁包，用来修复它在部分自定义 `/codex` 风格 Responses 中转站上的缓存命中问题。

这个项目的目标很直接：

- 让 Hermes 在自定义 `/codex` 网关上更稳定地走 `codex_responses`
- 让 Hermes 发出一组更接近 Codex 传输层语义的请求
- 让 `prompt_cache_key` 和会话缓存状态在 Hermes 内部可以持续工作
- 给你一个可以复用的 skill 和一套可自己魔改的适配方法

## 为什么会有这个项目

我在个人实际使用 Hermes + 自定义 `/codex` 中转站时，发现同样的 key、同样的 model，Codex 的缓存命中明显高于 Hermes。

在我自己的稳定线程使用场景里，打完这组补丁之后，额度消耗大约下降了 50% 左右。

这不是一个“所有人、所有模型、所有中转站都会稳定降低 50%”的承诺。它只是我个人在稳定线程、重复前缀、高缓存复用的真实使用习惯下得到的经验结果。

真正的技术结论是：

- 某些自定义 `/codex` 风格网关不只看 JSON body
- 它们还会看 transport metadata
- Hermes 默认请求形态在这些网关上可能拿不到理想的 prompt cache 行为
- Codex 风格的 transport headers + 更稳定的 Responses 路径选择，能显著改善这类网关上的缓存命中

## 适用范围

这个补丁包只针对下面这类目标：

- 自定义 `/codex` 风格 Responses 网关
- 例子：`https://right.codes/codex/v1`
- 其他行为接近 Codex Responses 的中转代理

明确不在适用范围内的目标：

- `api.openai.com`
- `chatgpt.com/backend-api/codex`
- `api.githubcopilot.com`
- `models.github.ai`

如果你的网关只是“长得像 OpenAI”，但没有 `/codex` 风格 transport 语义，这个补丁不一定有帮助。

## 仓库内容

- `patches/0001-custom-codex-runtime-detection.patch`
  - 让 Hermes 更稳地把自定义 `/codex` 路由识别成 `codex_responses`
- `patches/0002-codex-proxy-cache-compat.patch`
  - 核心缓存兼容补丁
  - 包括 transport headers、prompt cache state、对应测试
- `patches/0003-external-skills-permission-guard.patch`
  - 可选
  - 修复外部 skill 目录扫描时的 `PermissionError`
- `skills/codex-proxy-cache-compat/`
  - 可直接安装到 Hermes 的维护 skill
- `scripts/apply_patches.sh`
  - 一键给本地 Hermes checkout 打补丁
- `scripts/install_skill.sh`
  - 一键安装共享 skill 并把 `skills.external_dirs` 写进指定 profile
- `examples/`
  - 示例配置
- `docs/ADAPTING_OTHER_PROXIES.md`
  - 教你怎么针对别的中转站自己改
- `docs/VERIFICATION.md`
  - 补丁效果和验证方法说明

## 快速开始

### 1. 准备 Hermes 仓库

```bash
git clone https://github.com/NousResearch/hermes-agent.git
cd hermes-agent
```

### 2. 应用补丁

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/apply_patches.sh /path/to/hermes-agent
```

如果你还想把外部 skill 目录的健壮性修复一起打上：

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/apply_patches.sh \
  /path/to/hermes-agent \
  --with-skill-loader-fix
```

### 3. 跑聚焦验证

```bash
cd /path/to/hermes-agent

python3 -m pytest -q -o addopts='' tests/hermes_cli/test_runtime_provider_resolution.py
PYTHONPATH=/tmp/hermes_test_stubs python3 -m pytest -q -o addopts='' tests/run_agent/test_run_agent_codex_responses.py
python3 -m pytest -q -o addopts='' tests/test_hermes_state.py
```

### 4. 安装维护 skill

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/install_skill.sh ~/.hermes
```

如果你有多个 profile，就分别跑一次：

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/install_skill.sh ~/.hermes
bash /path/to/hermes-codex-proxy-cache-compat/scripts/install_skill.sh ~/.hermes/profiles/feishu2
```

### 5. 重启 Hermes gateway

如果你是 systemd user service：

```bash
hermes gateway restart
hermes --profile feishu2 gateway restart
```

或者按你自己的部署方式重启。

## 推荐配置

参考：

- `examples/model-config.right-codes.yaml`
- `examples/shared-skills.config.yaml`

一个典型的模型配置长这样：

```yaml
model:
  provider: custom
  default: gpt-5.4-xhigh
  base_url: https://right.codes/codex/v1
  api_mode: chat_completions
```

为什么这里还写 `chat_completions`？

因为这个发布包里的 `0001` 补丁会把“`gpt-5`/`codex` 家族模型 + `/codex` 路径”的组合自动升级到 `codex_responses`。如果你不想依赖自动识别，也可以直接手工配成：

```yaml
api_mode: codex_responses
```

## 这个补丁到底改了什么

### 1. 让 runtime provider 识别 custom `/codex` 路由

如果你的 base URL 是：

```text
https://something.example.com/codex/v1
```

并且模型是 `gpt-5` / `codex` 家族，Hermes 应该优先走 `codex_responses`。

### 2. 给特定自定义网关发送 Codex 风格 transport headers

有些代理不只看 body 里的 `prompt_cache_key`，还会看：

- `session_id`
- `x-client-request-id`
- `x-codex-window-id`
- `x-codex-turn-metadata`
- `originator`
- `User-Agent`

### 3. 在 Hermes 内部持久化 prompt cache state

补丁会在 session DB 里保存：

- `prompt_cache_key`
- `prompt_cache_supported`

这样 Hermes 不会每轮都像“第一次见这个会话”一样乱来。

### 4. 附带一个维护 skill

这个 skill 不会自动改代码，它的作用是：

- 在 Hermes 更新后提醒你检查哪些锚点
- 提供聚焦验证命令
- 提供 Feishu / 稳定线程场景下的验证协议

## 我是怎么验证的

验证原则不是“只看客户端感觉”，而是看真实缓存指标：

- 保持同一个稳定线程
- 保持同一个 endpoint
- 保持同一个 model
- 保持提示词前缀基本稳定
- 观察 `cached_tokens` 或 Hermes 的 `cache_read_tokens`

具体见：

- `docs/VERIFICATION.md`

## 不同中转站怎么自己魔改

看这里：

- `docs/ADAPTING_OTHER_PROXIES.md`

核心思路是 4 步：

1. 先确认这个中转站是不是应该走 `codex_responses`
2. 看上游是否会重写 `prompt_cache_key`
3. 看它是不是依赖 transport metadata
4. 再去改 domain/path guard 和 header 生成逻辑

不要一上来就把所有 OpenAI 兼容接口都当成 Codex 风格代理。

## 常见误区

- 误区 1：只要是 OpenAI 兼容接口，都适合打这个补丁
  - 不对
- 误区 2：只测冷启动 one-shot CLI，就能判断缓存效果
  - 不对
- 误区 3：看到 `prompt_cache_key` 就说明缓存一定命中
  - 不对
- 误区 4：把官方 `api.openai.com` 也纳入同一套 transport header 策略
  - 不对

## 回滚

如果你要回滚：

```bash
cd /path/to/hermes-agent
git apply -R /path/to/hermes-codex-proxy-cache-compat/patches/0002-codex-proxy-cache-compat.patch
git apply -R /path/to/hermes-codex-proxy-cache-compat/patches/0001-custom-codex-runtime-detection.patch
```

如果你还打了可选补丁：

```bash
git apply -R /path/to/hermes-codex-proxy-cache-compat/patches/0003-external-skills-permission-guard.patch
```

## 致谢

- 上游项目：`NousResearch/hermes-agent`
- 这个仓库不是官方 Hermes 仓库
- 这是一个面向自定义 `/codex` cache compatibility 的独立发布包

## License

MIT
