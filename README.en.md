# Hermes Codex Proxy Cache Compat

Language / 语言: [简体中文](./README.md) | English

A standalone public patch bundle for Hermes that improves cache hit behavior on some custom `/codex`-style Responses gateways.

The project has a narrow goal:

- keep Hermes on `codex_responses` more reliably for custom `/codex` gateways
- make Hermes send requests that are closer to Codex transport semantics
- persist `prompt_cache_key` and cache support state across Hermes sessions
- provide a reusable maintenance skill and a practical adaptation guide for other proxies

## Why this exists

In my own Hermes usage with a custom `/codex` proxy, I found that Codex achieved materially better cache reuse than Hermes with the same key and the same model.

In my personal stable-thread workflow, this patch set reduced spend by roughly 50%.

That is not a universal promise for every user, every model, or every gateway. It is a measured result from my own usage pattern: stable threads, repeated prefixes, and high cache reuse opportunities.

The real technical takeaway is:

- some custom `/codex` gateways do not rely on JSON body fields alone
- they also appear to consider transport metadata
- Hermes' default request shape can be suboptimal for prompt cache behavior on those gateways
- Codex-style transport headers plus more reliable Responses-path selection can improve cache reuse significantly

## Scope

This patch bundle is intended only for:

- custom `/codex`-style Responses gateways
- example: `https://right.codes/codex/v1`
- other proxies that behave like Codex Responses endpoints

Explicitly out of scope:

- `api.openai.com`
- `chatgpt.com/backend-api/codex`
- `api.githubcopilot.com`
- `models.github.ai`

If your endpoint is merely "OpenAI-compatible" but does not implement `/codex`-style transport semantics, this patch may not help.

## Repository contents

- `patches/0001-custom-codex-runtime-detection.patch`
  - improves detection so Hermes upgrades custom `/codex` routes to `codex_responses`
- `patches/0002-codex-proxy-cache-compat.patch`
  - the core cache-compat patch
  - includes transport headers, prompt cache state persistence, and focused tests
- `patches/0003-external-skills-permission-guard.patch`
  - optional
  - hardens external skill directory scanning against `PermissionError`
- `skills/codex-proxy-cache-compat/`
  - a reusable maintenance skill for Hermes
- `scripts/apply_patches.sh`
  - one-shot patch application for a local Hermes checkout
- `scripts/install_skill.sh`
  - installs the shared skill and updates `skills.external_dirs` in a target profile
- `examples/`
  - example config snippets
- `docs/ADAPTING_OTHER_PROXIES.md`
  - how to adapt the patch for other proxy behaviors
- `docs/VERIFICATION.md`
  - how to validate whether the patch is actually helping

## Quick start

### 1. Clone Hermes

```bash
git clone https://github.com/NousResearch/hermes-agent.git
cd hermes-agent
```

### 2. Apply the patch set

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/apply_patches.sh /path/to/hermes-agent
```

If you also want the external skill loader guard:

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/apply_patches.sh \
  /path/to/hermes-agent \
  --with-skill-loader-fix
```

### 3. Run focused verification

```bash
cd /path/to/hermes-agent

python3 -m pytest -q -o addopts='' tests/hermes_cli/test_runtime_provider_resolution.py
PYTHONPATH=/tmp/hermes_test_stubs python3 -m pytest -q -o addopts='' tests/run_agent/test_run_agent_codex_responses.py
python3 -m pytest -q -o addopts='' tests/test_hermes_state.py
```

### 4. Install the maintenance skill

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/install_skill.sh ~/.hermes
```

If you maintain multiple profiles, run it once per profile:

```bash
bash /path/to/hermes-codex-proxy-cache-compat/scripts/install_skill.sh ~/.hermes
bash /path/to/hermes-codex-proxy-cache-compat/scripts/install_skill.sh ~/.hermes/profiles/feishu2
```

### 5. Restart Hermes gateway

If you use systemd user services:

```bash
hermes gateway restart
hermes --profile feishu2 gateway restart
```

Otherwise restart Hermes in whatever deployment mode you use.

## Recommended config

See:

- `examples/model-config.right-codes.yaml`
- `examples/shared-skills.config.yaml`

A typical model block looks like this:

```yaml
model:
  provider: custom
  default: gpt-5.4-xhigh
  base_url: https://right.codes/codex/v1
  api_mode: chat_completions
```

Why is `chat_completions` still shown there?

Because patch `0001` upgrades the combination of a `gpt-5` or `codex` family model plus a `/codex` route to `codex_responses` automatically. If you do not want to rely on auto-detection, you can set:

```yaml
api_mode: codex_responses
```

## What the patch actually changes

### 1. Runtime provider detection for custom `/codex` routes

If your base URL looks like:

```text
https://something.example.com/codex/v1
```

and your model belongs to the `gpt-5` or `codex` family, Hermes should prefer `codex_responses`.

### 2. Codex-style transport headers for selected custom gateways

Some proxies appear to consider more than the body-level `prompt_cache_key`. They may also look at:

- `session_id`
- `x-client-request-id`
- `x-codex-window-id`
- `x-codex-turn-metadata`
- `originator`
- `User-Agent`

### 3. Persistent prompt cache state inside Hermes

The patch stores:

- `prompt_cache_key`
- `prompt_cache_supported`

in Hermes' session database so the agent does not behave like every turn is a brand-new cache context.

### 4. A reusable maintenance skill

The skill does not patch code automatically. It exists to:

- remind you which anchors to inspect after Hermes updates
- give you focused verification commands
- preserve a stable validation routine for Feishu and long-thread usage

## How I validated it

The validation standard is not "it feels cheaper". The relevant signals are actual cache metrics:

- same stable thread
- same endpoint
- same model
- mostly stable prompt prefix
- observe `cached_tokens` or Hermes' `cache_read_tokens`

See:

- `docs/VERIFICATION.md`

## Community

If you are using this patch, or adapting it for your own Hermes or `/codex` proxy setup, you are welcome to discuss it on Linux.do:

- Community homepage: `https://linux.do/`

If you plan to post about your results, the most useful details usually include:

- your endpoint and model combination
- whether the test used a stable-thread workflow
- how `cached_tokens` or `cache_read_tokens` changed
- what you had to modify for other proxies

## How to adapt this for other proxies

See:

- `docs/ADAPTING_OTHER_PROXIES.md`

The basic method is:

1. confirm whether the endpoint should really use `codex_responses`
2. check whether the upstream rewrites `prompt_cache_key`
3. check whether transport metadata participates in cache decisions
4. then adjust the domain/path guards and header generation logic accordingly

Do not assume every OpenAI-compatible API should be treated like a Codex-style proxy.

## Common mistakes

- Mistake 1: every OpenAI-compatible API should use this patch
  - false
- Mistake 2: a cold-start one-shot CLI test is enough to judge cache behavior
  - false
- Mistake 3: the presence of `prompt_cache_key` means cache hits are working
  - false
- Mistake 4: first-party `api.openai.com` should use the same transport header strategy
  - false

## Rollback

If you want to roll back:

```bash
cd /path/to/hermes-agent
git apply -R /path/to/hermes-codex-proxy-cache-compat/patches/0002-codex-proxy-cache-compat.patch
git apply -R /path/to/hermes-codex-proxy-cache-compat/patches/0001-custom-codex-runtime-detection.patch
```

If you also applied the optional patch:

```bash
git apply -R /path/to/hermes-codex-proxy-cache-compat/patches/0003-external-skills-permission-guard.patch
```

## Credits

- Upstream project: `NousResearch/hermes-agent`
- This repository is not the official Hermes repository
- This is a standalone patch bundle focused on custom `/codex` cache compatibility

## License

MIT
