# Flask gateway in front of vLLM: auth, streaming, security

Compiled 2026-11-13 from primary sources only: vLLM docs and source (tags `v0.32.0` and `v0.33.0`), the vLLM GitHub security advisories, Flask/Werkzeug/Gunicorn/nginx/httpx/requests docs, the OpenAI OpenAPI spec and `openai-python` README, PEP 3333, Python stdlib docs, NIST SP 800-63B-4, OWASP, the OpenSSH and Linux man pages, and GitHub's engineering blog for token format. Every page was accessed on **2026-11-13**. Claims are cited inline. "(my arithmetic)" marks derived numbers. `[INFERENCE]` marks conclusions I drew that no source states. **Uncertain**, **Conflict**, **Stale** and **Not found** mark doubtful points.

VACC context comes from the earlier notes ([../vacc/README.md](../vacc/README.md), [../vacc/access.md](../vacc/access.md)). Whether the VACC allows long-running services and inbound ports is outside this file. See [Open questions](#open-questions).

**Versions this file applies to.** vLLM **0.33.0** is the newest version on PyPI (uploaded 2026-11-02) ([PyPI](https://pypi.org/project/vllm/0.33.0/)). The `v0.33.0` git tag points at the same commit as `v0.33.0rc3`. GitHub's Releases page lists only `v0.33.0rc3`, and **v0.32.0** (2026-10-18) is the newest non-rc release object there ([releases](https://github.com/vllm-project/vllm/releases)). **Conflict** (minor): PyPI shows 0.33.0 as final, while GitHub Releases has no 0.33.0 entry. I read the source at both tags. The auth middleware is byte-identical between them. Other versions: Flask 3.1.3, Werkzeug 3.1.9, Gunicorn 27.0.1 (released 2026-11-12), httpx 0.28.1, requests 2.34.2, openai-python 3.50.0, Flask-Limiter 4.1.1 (all from PyPI JSON, 2026-11-13).

## Contents

1. [vLLM's `--api-key`: what it covers](#1-vllms---api-key-what-it-covers)
2. [vLLM's guidance for untrusted networks](#2-vllms-guidance-for-untrusted-networks)
3. [Security advisories relevant to an OpenAI-compatible server](#3-security-advisories-relevant-to-an-openai-compatible-server)
4. [Gateway architecture: keys, hashing, limits, logging](#4-gateway-architecture-keys-hashing-limits-logging)
5. [Streaming SSE through Flask](#5-streaming-sse-through-flask)
6. [Production layout and VACC placement](#6-production-layout-and-vacc-placement)
7. [`openai` SDK vs `httpx`/`requests`](#7-openai-sdk-vs-httpxrequests)
8. [Reference sketch: auth + streaming proxy](#8-reference-sketch-auth--streaming-proxy)
9. [Security controls checklist](#9-security-controls-checklist)
10. [Open questions](#open-questions)

---

## 1. vLLM's `--api-key`: what it covers

**Mechanism (code, v0.33.0).** If `--api-key` (or the `VLLM_API_KEY` env var) is set, vLLM adds `AuthenticationMiddleware`. The CLI value takes precedence over the env var, and several keys may be given ([register.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/middleware/register.py)). The middleware:
- guards only paths that start with `GUARDED_PREFIX = ("/v1", "/v2", "/inference", "/cohere")`. It skips `OPTIONS` requests and every other path ([authenticate.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/middleware/authenticate.py));
- expects `Authorization: Bearer <key>`, hashes the presented key and every configured key with SHA-256, and compares them with `secrets.compare_digest`. On failure it returns `401 {"error": "Unauthorized"}` ([authenticate.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/middleware/authenticate.py));
- reads the path from `scope["path"]` (minus `root_path`). Older versions rebuilt the URL from the `Host` header, and that was the bug behind GHSA-94f4 (see §3) ([authenticate.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/middleware/authenticate.py); [GHSA-94f4-hr76-p5j6](https://github.com/vllm-project/vllm/security/advisories/GHSA-94f4-hr76-p5j6)).

**Docs say the same.** "`--api-key` ... provides authentication for vLLM's HTTP server, but **only for endpoints under the `/v1`, `/v2`, `/inference`, and `/cohere` path prefixes** ... Do not rely exclusively on `--api-key`" ([security.md @ v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/usage/security.md); rendered: [docs.vllm.ai security](https://docs.vllm.ai/en/stable/usage/security/)).

**Conflict (minor):** the `--api-key` help text and the OpenAI-server doc page list only `/v1`, `/v2` and `/inference`. The middleware code and security.md also include `/cohere` ([cli_args.py @ v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py); [openai_compatible_server.md](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/serving/online_serving/openai_compatible_server.md)). The code is authoritative.

### Protected (key required), relevant subset

`/v1/models`, `/v1/chat/completions`, `/v1/chat/completions/batch`, `/v1/completions`, `/v1/responses` (+ `/{id}`, `/{id}/cancel`), `/v1/messages`, `/v1/embeddings`, `/v1/score`, `/v1/rerank`, `/v1/load_lora_adapter`, `/v1/unload_lora_adapter`, and `/inference/v1/generate` (only with `--enable-scale-out` or `--tokens-only`) ([security.md @ v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/usage/security.md)).

### NOT protected, even with `--api-key`

From [security.md @ v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/usage/security.md) unless noted:

| Group | Endpoints | Why it matters |
| --- | --- | --- |
| Inference outside `/v1` | **`/invocations`** (SageMaker; "routes to the same inference functions as `/v1` endpoints"), `/generative_scoring`, `/pooling`, `/classify`, `/score`, `/rerank` | Free inference without a key. The docs call `/invocations` "particularly concerning" |
| Operational control (when the "generate" task is supported) | `/pause`, `/resume`, `/is_paused`, `/abort_requests`, `/scale_elastic_ep`, `/is_scaling_elastic_ep`, `/init_weight_transfer_engine`, **`/update_weights`**, `/get_world_size`. With `--enable-sleep-mode`: `/checkpoint/prepare`, `/checkpoint/restore`, `/checkpoint/status`. With fault tolerance: `/fault_tolerance/*` | DoS (`/pause`, `/abort_requests`). `/update_weights` "can alter model behavior" |
| Utility | **`/metrics`**, `/kv_event_sources`, **`/tokenize`**, **`/detokenize`**, **`/health`**, `/ping`, **`/version`**, `/load` | Information disclosure. `/tokenize` also runs the chat template |
| FastAPI docs | `/docs`, `/redoc`, `/openapi.json` | Not in security.md's list. vLLM builds `FastAPI()` with default doc URLs unless `--disable-fastapi-docs` is set ([app.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/launchers/app.py)). FastAPI serves Swagger UI at `/docs` and ReDoc at `/redoc` by default ([FastAPI metadata docs](https://fastapi.tiangolo.com/tutorial/metadata/)). These paths are outside the guarded prefixes, so they are unauthenticated (my reading of [authenticate.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/middleware/authenticate.py)) |
| Opt-in, off by default | `/tokenizer_info` (`--enable-tokenizer-info-endpoint`). Dev endpoints including **`/collective_rpc`** ("extremely dangerous"), `/sleep`, `/server_info`, `/reset_*_cache` (`VLLM_SERVER_DEV_MODE=1`). `/start_profile`, `/stop_profile` (`--profiler-config`) | Never enable in production |
| Endpoint plugins | Any plugin route outside the four prefixes | "Unauthenticated unless the plugin implements its own authentication". Plugins load only if named in `VLLM_PLUGINS` |
| gRPC (`--grpc-port`) | `Generate`, `GenerateStream`, `Control.*` incl. `Shutdown` | "Insecure by default — it does not implement authentication, authorization, or encryption". Off unless `--grpc-port` is set |

**Bind address default.** `--host` defaults to `None`. The launcher binds `(args.host or "", args.port)` ([cli_args.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py); [launcher.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/launchers/launcher.py)). For IPv4, `''` "represents `INADDR_ANY`, which is used to bind to all interfaces" ([Python socket docs](https://docs.python.org/3/library/socket.html)). So **an unconfigured `vllm serve` listens on every interface on port 8000**. vLLM can also listen on a Unix socket via `--uds` ("If set, host and port arguments are ignored") ([cli_args.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py)).

**CORS default changed in 0.32.0.** `allowed_origins` used to default to `["*"]` (GHSA-vvpg-rrww-wpmh). In v0.32.0/v0.33.0 it defaults to `[]`, "Cross-origin browser access is disabled by default" ([advisory](https://github.com/vllm-project/vllm/security/advisories/GHSA-vvpg-rrww-wpmh); [cli_args.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py)).

**Bottom line for this design.** `--api-key` should be a shared secret between the gateway and vLLM, not the user-facing control. Anyone who can open a TCP connection to vLLM's port can use `/invocations` and `/pause` without it. The real control is making vLLM's port unreachable to anyone but the gateway (§6). `[INFERENCE]`, following the docs' own "Do not rely exclusively on `--api-key`".

## 2. vLLM's guidance for untrusted networks

All from [security.md @ v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/usage/security.md):

- **Reverse proxy with an allowlist:** "The most effective approach is to deploy vLLM behind a reverse proxy ... that: Explicitly allowlists only the endpoints you want to expose to end users; Blocks all other endpoints ...; Implements additional authentication, rate limiting, and logging at the proxy layer." The Flask gateway is that proxy.
- **Firewall:** "Block all incoming connections except to the TCP port the API server is listening on." `torch.distributed` creates a `TCPStore` that "by default, listens on all network interfaces", even on a single host, and "any use of `torch.distributed` should be considered insecure by default."
- **Inter-node traffic** (TP/PP/DP, KV transfer) is "insecure by default" and must sit on an isolated network. Set `VLLM_HOST_IP` explicitly.
- **Multi-tenancy:** "vLLM does not provide isolation between tenants that share the same server process." Per-tenant isolation means one vLLM instance per tenant, or "a gateway in front of vLLM that authenticates callers and scopes client-supplied cache identifiers, such as `cache_salt` ... per tenant."
- **Prefix-cache timing side channel** (CVE-2025-46570): another tenant can infer cached prefixes from TTFT. The mitigation is a per-request `cache_salt`, which should be "random values ... (e.g. 43 base64 characters, 256 bits)". "Multi-tenant deployments: Set `cache_salt` on every request."
- **`n` parameter:** `VLLM_MAX_N_SEQUENCES` defaults to **16384**. For public deployments the docs suggest e.g. 64 or 128, plus "request body validation and rate limiting at your reverse proxy."
- **Per-request multimodal kwargs** are rejected by default. Keep `--trust-request-mm-kwargs` off for untrusted clients.
- **Dynamic LoRA loading** (`--enable-lora` + `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True`) "is not a secure operation and should not be enabled in deployments exposed to untrusted clients."
- **gpt-oss built-in tools:** `--tool-server demo` enables a Python code interpreter that runs model-generated code in Docker "not configured with network isolation by default". If `VLLM_GPT_OSS_SYSTEM_TOOL_MCP_LABELS` is unset, no built-in tools requested via MCP are enabled. (The VACC has no Docker; Apptainer only, per [../vacc/README.md](../vacc/README.md).)

Related, from code:
- **Server-wide output-token cap.** "If `max_new_tokens` is specified in generation config, then it sets a server-wide limit on the number of output tokens for all requests" ([config/model.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/model.py)). With `--generation-config auto` (the default) or `vllm`, the chat server reads `override_generation_config["max_new_tokens"]` as `override_max_tokens` ([chat_completion/serving.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/chat_completion/serving.py)). `get_max_tokens()` returns the minimum of the model's remaining context, the request's value and that override ([api_utils.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/utils/api_utils.py)). So `--override-generation-config '{"max_new_tokens": N}'` is a hard cap enforced in vLLM, independent of the gateway (my reading of the code; **untested**).
- **Prompt logging is off by default.** `enable_log_requests` defaults to `False`. When on, INFO logs request ID and parameters, and DEBUG logs "Prompt inputs (e.g: text, token IDs)" ([arg_utils.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/engine/arg_utils.py)). `--enable-log-outputs` logs generated text and requires `--enable-log-requests`. `--max-log-len` defaults to unlimited ([cli_args.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py)). `VLLM_DEBUG_LOG_API_SERVER_RESPONSE` triggers the warning "This can include sensitive information and should be avoided in production" ([register.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/middleware/register.py)).
- **Responses API store** (`VLLM_ENABLE_RESPONSES_API_STORE=1`) keeps inputs and outputs in memory and "will cause a memory leak, as stored messages are never removed". It defaults to off ([envs.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/envs.py)). With it on, `/v1/responses/{id}` could serve one user's stored response to another key holder unless the gateway checks ownership (OWASP API1, object-level authorization) `[INFERENCE]`.
- **Prompt embeddings** are off by default (`enable_prompt_embeds: bool = False`, "Only enable this flag for trusted users!") ([config/model.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/model.py)).

## 3. Security advisories relevant to an OpenAI-compatible server

Source: the GitHub advisory API for `vllm-project/vllm` (125 published advisories on 2026-11-13). Each row links to its advisory page under `https://github.com/vllm-project/vllm/security/advisories/`. "Affected" and "Fixed in" are copied as each advisory states them. Some ranges are internally inconsistent, and I flag those. **44 of the 125** have summaries mentioning multimodal/media/image/audio/video paths (my count by keyword). gpt-oss-120b's `config.json` declares `GptOssForCausalLM` ([HF config](https://huggingface.co/openai/gpt-oss-120b/raw/main/config.json)), a text model, so those mostly don't apply and are left out. `[INFERENCE]`

| ID (CVE) | Severity | Issue | Affected | Fixed in | Relevance here |
| --- | --- | --- | --- | --- | --- |
| [GHSA-94f4-hr76-p5j6](https://github.com/vllm-project/vllm/security/advisories/GHSA-94f4-hr76-p5j6) (CVE-2026-48746) | Critical, CVSS 9.1 | **API-key auth bypass**: a crafted `Host:` header changes the reconstructed URL path, so `/v1/*` is reached without the key. "Instances behind an RFC-conforming web server (such as nginx) are **not** affected" | ≥0.3.0 | ≥0.22.0 | Direct hit on `--api-key` |
| [GHSA-wr9h-g72x-mwhm](https://github.com/vllm-project/vllm/security/advisories/GHSA-wr9h-g72x-mwhm) (CVE-2025-59425) | High | API-key comparison was vulnerable to a **timing attack** | "≤0.11.0" as listed | 0.11.0 | **Conflict**: the listed range includes the fixed version |
| [GHSA-vvpg-rrww-wpmh](https://github.com/vllm-project/vllm/security/advisories/GHSA-vvpg-rrww-wpmh) (CVE-2026-115917) | Low | Default CORS `*`: a web page could drive a vLLM server reachable from the victim's browser | all (default config) | 0.32.0 | Matters if vLLM is reachable from user laptops (e.g. over VPN) |
| [GHSA-rxc4-3w6r-4v47](https://github.com/vllm-project/vllm/security/advisories/GHSA-rxc4-3w6r-4v47) (CVE-2025-48956) | High | Unauthenticated DoS from huge HTTP headers | ≥0.1.0 | 0.10.1.1 | Pre-auth |
| [GHSA-3mwp-wvh9-7528](https://github.com/vllm-project/vllm/security/advisories/GHSA-3mwp-wvh9-7528) (CVE-2026-34756) | Medium, 6.5 | Unbounded **`n`** → event-loop block and OOM | ≥0.1.0 | 0.19.0 | Gateway should drop `n` |
| [GHSA-87x5-vmc3-756j](https://github.com/vllm-project/vllm/security/advisories/GHSA-87x5-vmc3-756j) (CVE-2026-73559) | Medium | `/v1/completions` prompt lists fan out into unbounded engine requests | ≥0.19.0, ≤0.26.0 | 0.26.0 | Don't expose `/v1/completions` |
| [GHSA-6fvq-23cw-5628](https://github.com/vllm-project/vllm/security/advisories/GHSA-6fvq-23cw-5628) (CVE-2025-61620) | Medium | DoS via request-supplied `chat_template` / `chat_template_kwargs` (Jinja) | ≥0.5.1, <0.11.0 | 0.11.0 | Gateway should drop both fields |
| [GHSA-69j4-grxj-j64p](https://github.com/vllm-project/vllm/security/advisories/GHSA-69j4-grxj-j64p) (CVE-2025-62426) | Medium | DoS via crafted `chat_template_kwargs` on chat and tokenize | ≥0.5.5 | 0.11.1 | Same |
| [GHSA-x567-49g5-p4cf](https://github.com/vllm-project/vllm/security/advisories/GHSA-x567-49g5-p4cf) (CVE-2026-115918) | Medium | `/v1/responses` ignored the `--trust-request-chat-template` gate | ≥0.16.0, ≤0.23.0 | 0.32.0 | Range and fix version disagree as listed |
| [GHSA-542m-9234-8gvf](https://github.com/vllm-project/vllm/security/advisories/GHSA-542m-9234-8gvf) (CVE-2026-115911) | Medium | Unbounded Jinja render wedges the single renderer thread and blocks **all** chat endpoints | ≥0.19.0 | 0.32.0 | Authenticated client is enough |
| [GHSA-4xqp-c3mv-qff7](https://github.com/vllm-project/vllm/security/advisories/GHSA-4xqp-c3mv-qff7) | Medium | Huge `min_tokens` on `/inference/v1/generate` hangs the engine "while /health stays green" | <0.31.0 | 0.31.0 | Health checks can miss it. Drop `min_tokens` |
| [GHSA-q97c-p368-75c4](https://github.com/vllm-project/vllm/security/advisories/GHSA-q97c-p368-75c4) (CVE-2026-115916) | Medium | Out-of-vocabulary **prompt token id** crashes the engine (CUDA assert) when vocab size is an exact multiple of 64 and TP=1 | ≤0.31.0 | 0.32.0 | gpt-oss-120b `vocab_size` = 201,088 = 64 × 3,142 (my arithmetic from [HF config](https://huggingface.co/openai/gpt-oss-120b/raw/main/config.json)). The condition matches. **Uncertain** whether gpt-oss's embedding path is affected. Block token-id prompts |
| [GHSA-q9v9-qpjp-fc24](https://github.com/vllm-project/vllm/security/advisories/GHSA-q9v9-qpjp-fc24) | High, 7.5 | Same class of crash under `skip_tokenizer_init` (incomplete fix of GHSA-25q3) | ≥0.28.0, <0.33.0 | 0.33.0 | Only with `skip_tokenizer_init` |
| [GHSA-85xf-c7hm-whqw](https://github.com/vllm-project/vllm/security/advisories/GHSA-85xf-c7hm-whqw) (CVE-2026-105757) | Medium, 6.5 | **Structured-output** request errors escape into EngineCore and kill it (3 sites) | <0.30.0 | 0.30.0 | Affects `response_format` / `structured_outputs` |
| [GHSA-rwxx-mrjm-wc2m](https://github.com/vllm-project/vllm/security/advisories/GHSA-rwxx-mrjm-wc2m) (CVE-2026-55574) / [GHSA-48jh-3gj7-fg8v](https://github.com/vllm-project/vllm/security/advisories/GHSA-48jh-3gj7-fg8v) (CVE-2026-73556) | Medium | ReDoS via `structured_outputs.regex` (xgrammar/outlines; lm-format-enforcer) | <0.24.0; ≤0.24.0 | 0.24.0; 0.26.0 | Drop `structured_outputs` |
| [GHSA-7h4p-rffg-7823](https://github.com/vllm-project/vllm/security/advisories/GHSA-7h4p-rffg-7823) (CVE-2026-54235) | Medium | `temperature=NaN/Infinity` bypasses validation and reaches GPU kernels | ≤0.8.5 as listed | ≥0.24.0 | Range looks wrong as listed. Validate floats in the gateway |
| [GHSA-v5gm-qgmv-gc6c](https://github.com/vllm-project/vllm/security/advisories/GHSA-v5gm-qgmv-gc6c) / [GHSA-w9r6-29q4-pvpr](https://github.com/vllm-project/vllm/security/advisories/GHSA-w9r6-29q4-pvpr) | Medium | Out-of-range `stop_token_ids` (+`min_tokens`) kills EngineCore, or causes an out-of-bounds GPU write | <0.29.0; ≥0.20.1, <0.29.0 | 0.29.0 | Drop `stop_token_ids` |
| [GHSA-wpww-v874-ph2p](https://github.com/vllm-project/vllm/security/advisories/GHSA-wpww-v874-ph2p) (CVE-2026-100647) | Medium, 5.3 | Multi-hundred-MB `cache_salt` stalls the scheduler thread | <0.29.0 | 0.29.0 | Gateway sets the salt itself |
| [GHSA-935w-9g4m-p28p](https://github.com/vllm-project/vllm/security/advisories/GHSA-935w-9g4m-p28p) (CVE-2026-105752) | Low, 3.1 | **gpt-oss Harmony** tool continuations on `/v1/responses` drop `cache_salt`, which reopens the cross-tenant prefix-cache oracle | <0.30.0 | 0.30.0 | gpt-oss specific |
| [GHSA-fpch-3xrf-7q96](https://github.com/vllm-project/vllm/security/advisories/GHSA-fpch-3xrf-7q96) | Medium | `thinking_token_budget` state aliases onto a co-batched request (wrong-session data) | 0.21.0–0.27.1 | 0.28.0 | Reasoning models. Drop the field |
| [GHSA-7m6h-x95x-82q5](https://github.com/vllm-project/vllm/security/advisories/GHSA-7m6h-x95x-82q5) (CVE-2026-73558) | Medium | **Cross-user output leak** from an integer overflow in `act_and_mul_kernel` | "<0.21.0" as listed (text says ≤0.21.0 and later) | ≥0.27.0 | **Uncertain** whether gpt-oss's MoE path uses this kernel. Use ≥0.27.0 regardless |
| [GHSA-v97p-wpxp-px84](https://github.com/vllm-project/vllm/security/advisories/GHSA-v97p-wpxp-px84) | Medium | Cross-user token leak with async scheduling + pipeline parallelism | 0.16.0–0.20.x | 0.21.0 | Only with PP > 1 |
| [GHSA-mwgq-9582-w2vf](https://github.com/vllm-project/vllm/security/advisories/GHSA-mwgq-9582-w2vf) | Medium | Validation-error handler amplifies the response (echoes input many times) | ≥0.3.0, <0.30.0 | 0.30.0 | Pre-auth path to CPU/memory use |
| [GHSA-hwrm-c4cx-rf4j](https://github.com/vllm-project/vllm/security/advisories/GHSA-hwrm-c4cx-rf4j) (CVE-2026-73555) | Low | Validation errors disclose internal paths and usernames, unauthenticated | ≤0.20.1 | ≥0.26.0 | Gateway can replace upstream error bodies |
| [GHSA-mrw7-hf4f-83pf](https://github.com/vllm-project/vllm/security/advisories/GHSA-mrw7-hf4f-83pf) (CVE-2025-62164) | High | **Deserialization**: `prompt_embeds` loaded with `torch.load()` → memory corruption, "potentially ... RCE" | ≥0.10.2 | 0.11.1 | Prompt embeds are off by default in 0.33.0 |
| [GHSA-hjq4-87xh-g4fv](https://github.com/vllm-project/vllm/security/advisories/GHSA-hjq4-87xh-g4fv) (CVE-2025-47277) | Critical | **RCE** via the PyNcclPipe KV-transfer service (pickle) | ≥0.6.5, <0.8.5 | 0.8.5 | Only with disaggregated KV transfer |
| [GHSA-9pcc-gvx5-r5wm](https://github.com/vllm-project/vllm/security/advisories/GHSA-9pcc-gvx5-r5wm) (CVE-2025-30165) | High | **RCE** via ZeroMQ (pickle) in multi-node V0 TP | ≥0.5.2 | Listed "0.10.0", but the text says **won't fix**: "V1 engine is not affected" | Only V0 multi-host TP |

**Minimum version.** For a text-only gpt-oss server behind this gateway, nothing older than **0.32.0** clears every row above except the two 0.33.0 rows (`skip_tokenizer_init`; and GHSA-5r3c, a media budget bug not listed because it is multimodal). Use **0.33.0** if the build used for gpt-oss allows it (my synthesis of the table; which vLLM build runs on the VACC GPUs is outside this file). The project publishes many advisories each month (39 published 2026-10-01 to 2026-11-12, by my count from the API), so check the advisory list again before deploying.

## 4. Gateway architecture: keys, hashing, limits, logging

```
user (openai SDK, curl) --HTTPS--> nginx (TLS, body cap, IP rate limit)
      --> gunicorn+Flask gateway (per-user key auth, field allowlist, quotas, metering)
      --> [SSH tunnel or private network] --> vLLM on a compute node (bound to loopback/UDS, --api-key = shared internal secret)
```

This matches vLLM's recommended "reverse proxy that ... allowlists ... implements additional authentication, rate limiting, and logging" ([security.md](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/usage/security.md)). The OWASP API Security Top 10 2023 items that map onto it are API2 Broken Authentication, API3 Broken Object Property Level Authorization (which absorbed Mass Assignment), API4 Unrestricted Resource Consumption, API8 Security Misconfiguration and API9 Improper Inventory Management ([OWASP API Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)).

### Key format and issuance

- Generate the secret with `secrets`. "As of 2015, it is believed that 32 bytes (256 bits) of randomness is sufficient for the typical use-case" ([Python secrets](https://docs.python.org/3/library/secrets.html)). `token_urlsafe(32)` gives Base64url text, about 1.3 characters per byte ([Python secrets](https://docs.python.org/3/library/secrets.html)), so about 43 characters (my arithmetic).
- **Prefix scheme.** GitHub's token format uses a company signifier plus a type letter (`ghp`, `gho`, …), an `_` separator ("not a Base64 character"), and a 32-bit CRC32 checksum in the last 6 characters (Base62). The checksum lets secret scanners reject fake tokens "without having to hit our database" ([GitHub blog, 2021-04-05](https://github.blog/engineering/platform-security/behind-githubs-new-authentication-token-formats/)). A gateway can use `<prefix>_<key_id>_<secret>`. A public `key_id` lets the gateway look up a single row, and the prefix makes leaked keys greppable `[INFERENCE]`. Note that `token_urlsafe` output can itself contain `_`, so split at most twice.
- Show the full key once. Store `key_id`, the digest, owner, creation and expiry dates, a revoked flag, and the limits.

### Which hash to store

- **NIST SP 800-63B-4 (look-up secrets):** "All look-up secrets SHALL be stored in a hashed form using an approved hashing function." Only secrets "shorter than the minimum security strength ... (i.e., 112 bits ...)" must use "a suitable password hashing scheme" with a ≥32-bit salt ([SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)). For passwords, it says verifiers "SHOULD perform an additional iteration of a keyed hashing or encryption operation using a secret key known only to the verifier", and that key "SHALL be stored separately from the hashed passwords" ([SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)).
- **Applied to 256-bit API keys** `[INFERENCE]`: NIST does not classify API keys as an authenticator type, so this is an analogy. A 256-bit random key is far above the 112-bit threshold, so a fast approved hash meets the bar. **HMAC-SHA256 with a server-side pepper** stored outside the database (an env var or secret file on the gateway host) adds the keyed step NIST describes, so a stolen key table cannot be checked offline. bcrypt/argon2 exist to slow guessing of *low-entropy* secrets. At 256 bits they add per-request CPU cost (every API call verifies a key) without a security gain. vLLM itself stores only SHA-256 hashes of its keys and compares those ([authenticate.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/middleware/authenticate.py)).
- Python: `hmac.digest(key, msg, digest)` "uses an optimized C or inline implementation" ([hmac docs](https://docs.python.org/3/library/hmac.html)).

### Constant-time compare

- Compare with `hmac.compare_digest(a, b)`. It "uses an approach designed to prevent timing analysis by avoiding content-based short circuiting behaviour". If lengths differ, "a timing attack could theoretically reveal information about the types and lengths ... but not their values" ([hmac docs](https://docs.python.org/3/library/hmac.html)). Comparing two fixed-length digests sidesteps the length case. vLLM's own key check was once vulnerable to exactly this ([GHSA-wr9h](https://github.com/vllm-project/vllm/security/advisories/GHSA-wr9h-g72x-mwhm)).
- Looking up by `key_id` first leaks whether that `key_id` exists through timing. The `key_id` is not secret, so that is acceptable `[INFERENCE]`.

### Revocation and expiry

- Check the `revoked` flag and `expires_at` in the same DB lookup, on every request. If a cache is added, its TTL is the revocation delay `[INFERENCE]`. A long-running stream that started before revocation continues to completion unless the gateway also checks revocation mid-stream (design choice, no source).
- NIST: a verifier "SHALL limit consecutive failed authentication attempts ... to no more than 100" for authenticators that require throttling ([SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)). For random 256-bit keys, per-IP throttling of 401s at nginx serves the same purpose `[INFERENCE]`.

### Rate limits and token quotas

- OWASP API4 says to define "maximum size of data on all incoming parameters and payloads, such as maximum length for strings, maximum number of elements in arrays". It also says to implement "a limit on how often a client can interact with the API within a defined timeframe", and that per-client per-operation throttles are needed ([OWASP API4:2023](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/)).
- **Layers** `[INFERENCE]` (design synthesis):
  1. nginx `limit_req` by client IP, which uses the "leaky bucket" method ([ngx_http_limit_req_module](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html)). It stops floods before Python runs.
  2. Gateway, per key: requests per minute, **max concurrent streams**, and a **token quota** (per day or month). Reserve `max_completion_tokens` before forwarding, then settle with the real `usage` afterwards.
  3. vLLM: `VLLM_MAX_N_SEQUENCES` small, `--max-model-len`, and `--override-generation-config '{"max_new_tokens": N}'` as a backstop (§2).
- The counters must be shared across Gunicorn workers. Flask-Limiter's `memory://` storage "is only meant for testing/development and should be replaced with an appropriate storage ... before mov[ing to production]" ([Flask-Limiter docs](https://flask-limiter.readthedocs.io/en/stable/)). Redis or the key database work.
- **Metering streamed tokens.** With `stream_options: {"include_usage": true}`, "an additional chunk will be streamed before the `data: [DONE]` message" carrying usage for the whole request. "If the stream is interrupted, you may not receive the final usage chunk" ([OpenAI OpenAPI spec, commit e6f6d80](https://github.com/openai/openai-openapi/blob/e6f6d8050b584033b3cdce6803c5813b682884d0/openapi.yaml)). The gateway should force `include_usage` and charge the reserved amount when no usage arrives `[INFERENCE]`. vLLM also has `--enable-force-include-usage` ("including usage on every request") ([cli_args.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py)).
- `max_completion_tokens` is "an upper bound for the number of tokens that can be generated for a completion, including visible output tokens and reasoning tokens". `max_tokens` is "deprecated in favor of `max_completion_tokens`" ([OpenAI OpenAPI spec](https://github.com/openai/openai-openapi/blob/e6f6d8050b584033b3cdce6803c5813b682884d0/openapi.yaml)). vLLM accepts both, and `max_completion_tokens` wins when set ([chat_completion/protocol.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/chat_completion/protocol.py)). gpt-oss emits its reasoning as generated tokens, so the cap bounds reasoning plus answer together `[INFERENCE]`.

### Request size and field allowlist

- **Body size:** nginx `client_max_body_size` (default **1m**; over the limit returns 413) ([ngx_http_core_module](https://nginx.org/en/docs/http/ngx_http_core_module.html)) and Flask `MAX_CONTENT_LENGTH` ("If this limit is exceeded, a 413 RequestEntityTooLarge error is raised", default `None`) ([Flask config](https://flask.palletsprojects.com/en/stable/config/)).
- **Field allowlist, not denylist.** The vLLM chat request accepts many non-OpenAI fields that appear in advisories: `n`, `min_tokens`, `prompt_logprobs`, `chat_template`, `chat_template_kwargs`, `mm_processor_kwargs`, `structured_outputs`, `priority`, `request_id`, `cache_salt`, `kv_transfer_params`, `vllm_xargs`, `thinking_token_budget`, `truncate_prompt_tokens` ([chat_completion/protocol.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/chat_completion/protocol.py); §3). Forward only the OpenAI fields the service supports. Overwrite `model`, the token cap and `cache_salt` server-side. Validate numeric ranges (`temperature` NaN, GHSA-7h4p). This is OWASP API3 (mass assignment) applied to an upstream `[INFERENCE]`.
- **Expose only `/v1/chat/completions`** (plus `/v1/models` if clients need it). `/v1/completions` accepts token-id and list prompts (GHSA-87x5, GHSA-q97c). `/v1/responses` has had its own gpt-oss gaps (GHSA-x567, GHSA-935w). If the Responses API is needed for gpt-oss tool use, add it as a separate, reviewed route `[INFERENCE]`.
- **`cache_salt` per user:** derive it with HMAC from a second server secret and the user ID. The result is secret, 256-bit, and stable per user, which matches vLLM's "per-user isolation" guidance ([security.md](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/usage/security.md)) `[INFERENCE]`.

### Logging without secrets or prompts

- OWASP lists "Access tokens", "Authentication passwords", "Encryption keys and other primary secrets" and "Sensitive personal data" among things that "should usually not be recorded directly in the logs, but instead should be removed, masked, sanitized, hashed, or encrypted" ([OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)).
- Log `key_id`, user ID, route, status, `prompt_tokens`, `completion_tokens`, latency and time-to-first-byte. Never log the `Authorization` header or request/response bodies.
- The default access logs don't include `Authorization`. nginx's predefined `combined` format is `$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"` ([ngx_http_log_module](https://nginx.org/en/docs/http/ngx_http_log_module.html)). Gunicorn's default is `%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"` ([Gunicorn settings](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/reference/settings.md)). Both log the request line, **including the query string**, so never accept keys as a query parameter `[INFERENCE]`.
- vLLM side: leave `--enable-log-requests`, `--enable-log-outputs` and `VLLM_DEBUG_LOG_API_SERVER_RESPONSE` off, and don't run at DEBUG (§2).

## 5. Streaming SSE through Flask

**Wire format.** With `stream: true`, "tokens will be sent as data-only server-sent events ... with the stream terminated by a `data: [DONE]` message" ([OpenAI OpenAPI spec](https://github.com/openai/openai-openapi/blob/e6f6d8050b584033b3cdce6803c5813b682884d0/openapi.yaml)). SSE lines starting with `:` are comments that clients ignore ([WHATWG HTML, SSE](https://html.spec.whatwg.org/multipage/server-sent-events.html)).

**Flask.**
- Return a generator in a `Response`. "Each `yield` expression is directly sent to the browser". "Headers cannot be changed after the streaming response starts", so set them all before streaming ([Flask streaming](https://flask.palletsprojects.com/en/stable/patterns/streaming/)).
- `request` "will not be active while the generator is running". Use `stream_with_context()` if the generator needs it ([Flask streaming](https://flask.palletsprojects.com/en/stable/patterns/streaming/)). The sketch in §8 copies everything it needs into locals before returning, so it doesn't need `stream_with_context`.
- "Some WSGI middlewares might break streaming" ([Flask streaming](https://flask.palletsprojects.com/en/stable/patterns/streaming/)).

**Client disconnect.**
- PEP 3333: if the returned iterable has `close()`, the server "must call that method upon completion of the current request, whether the request was completed normally, or terminated early due to an application error during iteration or an early disconnect of the browser" ([PEP 3333](https://peps.python.org/pep-3333/)). Calling `close()` on a Python generator raises `GeneratorExit` at the paused `yield`, so a `try/finally` in the generator runs. Put `upstream.close()` and usage settlement there.
- **Uncertain:** a WSGI server usually notices a disconnect only when its next write fails. Gunicorn's deploy doc mentions "Ignoring EPIPE" in debug logs when nginx sees a client abort ([Gunicorn deploy](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/deploy.md)). Gunicorn's exact behaviour per worker class was **not found** in the docs.
- vLLM cancels on disconnect: `with_cancellation` waits on the handler and on an HTTP disconnect message together, cancelling the handler when the client goes away. The chat route uses it ([api_utils.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/serve/utils/api_utils.py); [chat_completion/api_router.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/chat_completion/api_router.py)). So closing the upstream connection from the gateway should free the GPU slot `[INFERENCE]`.
- nginx `proxy_ignore_client_abort` (default `off`) "determines whether the connection with a proxied server should be closed when a client closes the connection" ([nginx proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)). Leave it off so disconnects propagate. Gunicorn's docs suggest turning it on only for things like health checks ([Gunicorn deploy](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/deploy.md)).

**nginx buffering and timeouts.**
- With `proxy_buffering on` (the default) nginx reads the upstream response into buffers. With it off, "the response is passed to a client synchronously, immediately as it is received". Buffering "can also be enabled or disabled by passing 'yes' or 'no' in the 'X-Accel-Buffering' response header field" ([nginx proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)). Sending `X-Accel-Buffering: no` from the Flask streaming route turns buffering off for that response only.
- `proxy_read_timeout` (default **60s**) applies "only between two successive read operations, not for the transmission of the whole response" ([nginx proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)). A long queue wait or prefill with no bytes sent can trip it. Raise it, or enable vLLM's `--sse-keep-alive-interval N`, which sends "an SSE keep-alive comment line every this many seconds when a `/v1/chat/completions` or `/v1/completions` streaming response is idle (queued, prefill, or between tokens), to prevent reverse proxies/tunnels with read timeouts from closing the connection". It defaults to 0 (off) ([cli_args.py @ v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py)). WHATWG suggests a comment "every 15 seconds or so" for legacy proxies ([WHATWG SSE](https://html.spec.whatwg.org/multipage/server-sent-events.html)).
- `proxy_http_version` defaults to 1.1 since nginx 1.29.7 (1.0 before) ([nginx proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)). Set it explicitly on older nginx builds.

**Gunicorn worker class.**
- **sync** (default): one request at a time per worker, "Requires a buffering proxy". Gunicorn warns that with sync workers "you must ensure the proxy buffers slow clients; otherwise Gunicorn becomes vulnerable to denial-of-service attacks" ([Gunicorn design](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/design.md); [Gunicorn deploy](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/deploy.md)). Its `timeout` (default **30 s**) kills workers that are silent that long ([settings](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/reference/settings.md)). **Not suitable for SSE.**
- For streaming, Gunicorn says: "disable proxy buffering and run Gunicorn with an async worker class". Its quick guide maps "WebSockets, streaming, long-polling?" to "`gevent` or ASGI worker" ([deploy](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/deploy.md); [design](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/design.md)).
- **gthread:** a thread pool per worker, with keep-alive support ([design](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/design.md)). For non-sync workers, `timeout` "just means that the worker process is still communicating and is not tied to the length of time required to handle a single request" ([settings](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/reference/settings.md)). Each open stream holds one thread, so concurrent streams ≤ workers × `--threads` `[INFERENCE]`. That is predictable and needs no monkey-patching. It is enough when concurrency is bounded by one GPU's batch size anyway `[INFERENCE]`.
- **gevent:** "Handles thousands of concurrent connections" ([design](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/design.md)). Requires gevent ≥ 24.10.1 ([settings](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/reference/settings.md)). Flask says to call `gevent.monkey.patch_all()` "as early as possible", and warns that gevent "does not interact well with Flask's built-in asyncio support" ([Flask gevent](https://flask.palletsprojects.com/en/stable/gevent/)). Use it if many slow clients must be held open.
- `--graceful-timeout` (default 30 s) force-kills workers still serving after a restart signal, which cuts active streams on reload ([settings](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/reference/settings.md)).

## 6. Production layout and VACC placement

**Don't use the Flask dev server.** "Do not use the development server when deploying to production. It is intended for use only during local development. It is not designed to be particularly secure, stable, or efficient" ([Flask deploying](https://flask.palletsprojects.com/en/stable/deploying/)). Werkzeug: "The development server is not intended to be used on production systems" ([Werkzeug serving](https://werkzeug.palletsprojects.com/en/stable/serving/)).

**gunicorn + nginx.**
- Gunicorn "should not be run as root ... a reverse proxy such as nginx ... should be used in front". Binding `0.0.0.0` behind a proxy is wrong: "Don't do this when using a reverse proxy setup, otherwise it will be possible to bypass the proxy" ([Flask gunicorn](https://flask.palletsprojects.com/en/stable/deploying/gunicorn/)). Gunicorn "strongly recommend[s] running Gunicorn behind a proxy server" ([Gunicorn deploy](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/deploy.md)).
- nginx terminates TLS and forwards `X-Forwarded-For`/`X-Forwarded-Proto` ([Gunicorn deploy](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/deploy.md)). Wrap the app in Werkzeug `ProxyFix` only when it really sits behind a proxy, "configured with the number of proxies that are chained in front of it", because "incoming headers can be faked" ([Flask proxy_fix](https://flask.palletsprojects.com/en/stable/deploying/proxy_fix/)). Gunicorn's `forwarded_allow_ips` defaults to `127.0.0.1,::1`. Setting `*` "is **dangerous** if untrusted clients can reach Gunicorn directly" ([Gunicorn deploy](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/deploy.md); [settings](https://github.com/benoitc/gunicorn/blob/27.0.1/docs/content/reference/settings.md)). Rate limiting by IP depends on getting the real client IP right `[INFERENCE]`.
- Being behind nginx also defeats the Host-header trick in GHSA-94f4 ([advisory](https://github.com/vllm-project/vllm/security/advisories/GHSA-94f4-hr76-p5j6)). The gateway sends its own requests to vLLM, so client `Host` headers never reach vLLM at all `[INFERENCE]`.

Minimal nginx shape (sketch, untested):
```nginx
limit_req_zone $binary_remote_addr zone=perip:10m rate=5r/s;
server {
    listen 443 ssl;                      # cert/key: see Open questions
    client_max_body_size 512k;
    location = /v1/chat/completions { limit_req zone=perip burst=20; proxy_pass http://127.0.0.1:8080; include proxy_common.conf; }
    location = /v1/models           { limit_req zone=perip burst=20; proxy_pass http://127.0.0.1:8080; include proxy_common.conf; }
    location / { return 404; }           # allowlist: nothing else reaches the gateway
}
# proxy_common.conf
proxy_http_version 1.1;
proxy_read_timeout 600s;                 # gap between reads, not total duration
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
# buffering: Flask sends X-Accel-Buffering: no on streaming responses
```

**Where the gateway sits relative to the vLLM node** `[INFERENCE]` unless cited:

| Option | How | Notes |
| --- | --- | --- |
| A. Gateway outside VACC, **SSH tunnel** to the compute node | `ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -J <netid>@login.vacc.uvm.edu -L 127.0.0.1:18000:127.0.0.1:8000 <netid>@<compute-node>`. `-L` can forward to a host:port **or a Unix socket** on the remote side. A `bind_address` of `localhost` keeps the local end private ([ssh(1)](https://man.openbsd.org/ssh.1)). `ExitOnForwardFailure` makes ssh exit if the forward can't be set up, and `ServerAliveInterval` sends keepalives (default 0 = off) ([ssh_config(5)](https://man.openbsd.org/ssh_config.5)) | Needs SSH from the gateway host to compute nodes and an unattended credential. The earlier notes found no documentation on SSH keys or Duo for VACC ([../vacc/README.md](../vacc/README.md#open-questions--not-found)). The node name changes every job, so the tunnel has to be rebuilt after each restart (jobs end at the partition's limit: 48 h on `nvgpu`, per prior notes) |
| B. Gateway on a host inside the cluster network, **direct** to `node:port` | vLLM binds to the node's private interface | Depends on VACC firewalling between hosts and compute nodes. **Not found.** vLLM must not be reachable from other users (§1) |
| C. Gateway on a login node | — | Ruled out. Login nodes are for tests "under 5 minutes" using under 5 GB and ≤2 CPUs ([../vacc/access.md](../vacc/access.md)) |

**Shared-node caution** `[INFERENCE]`: on a compute node shared with other users' jobs, `127.0.0.1:8000` is reachable by **every local user**, not just you. Loopback binding stops remote hosts, not co-tenants. Those users could call `/invocations`, `/pause` or `/update_weights` without the key (§1). Mitigations:
1. Run vLLM with `--uds /path/dir/vllm.sock` inside a directory only you can access. On Linux, "pathname sockets honor the permissions of the directory they are in", and connecting "requires write permission on that socket" ([unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html)). vLLM's `create_server_unix_socket` just calls `bind()` and sets no mode itself ([launcher.py](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/launchers/launcher.py)), so the directory permissions and umask do the work. Then forward with `ssh -L 127.0.0.1:18000:/path/dir/vllm.sock`. **Uncertain:** per-job private `/tmp` on VACC ([../vacc/README.md](../vacc/README.md)) may hide a socket in `/tmp` from an SSH session that is not inside the job. Whether Unix sockets work on GPFS paths was also not checked.
2. Or request the whole node (`--exclusive`) so there are no co-tenants. Note `--exclusive` alone does not give all memory ([../slurm/cheatsheet.md](../slurm/cheatsheet.md)). On H200 nodes this costs every GPU's compute units.
3. Either way, set vLLM's `--api-key` (via `VLLM_API_KEY` in the job environment, not on the command line) and treat it as an internal secret the gateway injects. Command-line arguments are visible to other users via `ps` on Linux `[INFERENCE]`.

## 7. `openai` SDK vs `httpx`/`requests`

**For end users** (clients of the gateway): the official SDK works unchanged because the gateway speaks the OpenAI wire format (Bearer auth, SSE ending in `data: [DONE]`). vLLM's own docs use `OpenAI(base_url="http://localhost:8000/v1", api_key="token-abc123")`, and vLLM-specific parameters go in `extra_body` ([openai_compatible_server.md](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/serving/online_serving/openai_compatible_server.md)). Users point `base_url` at `https://<gateway>/v1` with their issued key. The chat API's `user` parameter "is ignored" by vLLM ([same](https://github.com/vllm-project/vllm/blob/v0.33.0/docs/serving/online_serving/openai_compatible_server.md)), so identity has to come from the gateway's key.

**Inside the gateway**, as the upstream client:

| | `openai` SDK 3.50.0 | `httpx` 0.28.1 | `requests` 2.34.2 |
| --- | --- | --- | --- |
| Streaming | `stream=True` returns an iterator of parsed events. `.with_streaming_response` exposes raw `iter_lines()`, and "The context manager is required so that the response will reliably be closed" ([README @ v3.50.0](https://github.com/openai/openai-python/blob/v3.50.0/README.md)) | `client.send(req, stream=True)` / `httpx.stream()` with `iter_bytes()`/`iter_lines()` ([httpx quickstart](https://www.python-httpx.org/quickstart/)) | `stream=True`. Requests "cannot release the connection back to the pool unless you consume all the data or call `Response.close`", so use `with` ([requests advanced](https://requests.readthedocs.io/en/latest/user/advanced/)) |
| Retries | **2 automatic retries** on connection errors, 408, 409, 429 and ≥500. Stream consumption is not retried ([README](https://github.com/openai/openai-python/blob/v3.50.0/README.md)) | none by default | none by default |
| Default timeout | 10 minutes ([README](https://github.com/openai/openai-python/blob/v3.50.0/README.md)) | **5 s of network inactivity** ([httpx timeouts](https://www.python-httpx.org/advanced/timeouts/)). Too short for queued or long-prefill streams; set `read=` | **none** ("requests do not time out unless a timeout value is set explicitly") ([requests advanced](https://requests.readthedocs.io/en/latest/user/advanced/)) |
| HTTP stack | **HTTPX2** is the default client in 3.x ([README](https://github.com/openai/openai-python/blob/v3.50.0/README.md)) | httpx | urllib3 |

Choice `[INFERENCE]`: use **raw `httpx` streaming** in the gateway. It forwards upstream bytes verbatim, so there's no parse/re-serialize step that could change vLLM-specific fields and nothing to keep in sync with SDK models. It also has no hidden retries: SDK retries would multiply GPU load and token charges on 5xx/429. If the SDK is used anyway, set `max_retries=0` and an explicit timeout. **Not found:** httpx's docs (pages read) don't say whether one sync `httpx.Client` may be shared across gthread threads. Verify that, or keep one client per thread.

## 8. Reference sketch: auth + streaming proxy

> **SKETCH, not a complete or tested application.** It shows the auth and streaming path using only documented APIs: Flask 3.1 (`Response`, `abort`, `request.get_json`, `MAX_CONTENT_LENGTH`), httpx 0.28 (`Client.build_request`, `Client.send(stream=True)`, `iter_bytes`, `read`, `close`), and stdlib `secrets`/`hmac`. `lookup_key`, `reserve_quota` (aborts 429) and `settle_quota` are placeholders for your DB/Redis code. Run under gunicorn `-k gthread` (or gevent) behind nginx, never `flask run`.

```python
import hashlib, hmac, json, os, secrets
import httpx
from flask import Flask, Response, abort, request

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 512 * 1024                  # Flask answers 413 above this
PEPPER = bytes.fromhex(os.environ["GATEWAY_PEPPER_HEX"])        # 32 random bytes, never stored in the DB
SALT_KEY = bytes.fromhex(os.environ["CACHE_SALT_KEY_HEX"])      # separate secret for per-user cache_salt
MODEL, MAX_OUT = os.environ["SERVED_MODEL_NAME"], 4096
ALLOWED = {"messages", "temperature", "top_p", "stop", "stream", "tools", "tool_choice",
           "reasoning_effort", "seed", "max_tokens", "max_completion_tokens"}
VLLM = httpx.Client(base_url=os.environ["VLLM_URL"],             # e.g. http://127.0.0.1:18000 (SSH tunnel)
                    headers={"Authorization": "Bearer " + os.environ["VLLM_API_KEY"]},
                    timeout=httpx.Timeout(10.0, read=600.0))

def issue_key():
    """Return (full key, shown once; key_id; digest to store)."""
    key_id = secrets.token_hex(6)
    key = f"cat_{key_id}_{secrets.token_urlsafe(32)}"
    return key, key_id, hmac.digest(PEPPER, key.encode(), "sha256")

def authenticate():
    scheme, _, key = request.headers.get("Authorization", "").partition(" ")
    parts = key.split("_", 2)                                   # the secret part may contain "_"
    if scheme.lower() != "bearer" or len(parts) != 3 or parts[0] != "cat":
        abort(401)
    row = lookup_key(parts[1])                                  # {"digest", "revoked", "user_id"} or None
    if row is None or row["revoked"]:
        abort(401)
    if not hmac.compare_digest(hmac.digest(PEPPER, key.encode(), "sha256"), row["digest"]):
        abort(401)
    return parts[1], row

@app.post("/v1/chat/completions")
def chat_completions():
    key_id, row = authenticate()
    body = request.get_json(silent=True)
    if not isinstance(body, dict) or not isinstance(body.get("messages"), list):
        abort(400)
    body = {k: v for k, v in body.items() if k in ALLOWED}       # drops n, chat_template*, cache_salt, ...
    mct, mt = body.pop("max_completion_tokens", None), body.pop("max_tokens", None)
    asked = mct or mt or MAX_OUT
    if not isinstance(asked, int) or asked < 1:
        abort(400)
    stream = body.get("stream") is True
    body.update(model=MODEL, max_completion_tokens=min(asked, MAX_OUT),
                cache_salt=hmac.new(SALT_KEY, row["user_id"].encode(), hashlib.sha256).hexdigest())
    if stream:
        body["stream_options"] = {"include_usage": True}
    reserve_quota(key_id, body["max_completion_tokens"])         # abort(429) when over rate or token quota
    try:
        upstream = VLLM.send(VLLM.build_request("POST", "/v1/chat/completions", json=body), stream=True)
    except httpx.TransportError:
        abort(502)
    if upstream.status_code != 200 or not stream:
        data = upstream.read()
        upstream.close()
        settle_quota(key_id, json.loads(data).get("usage") if upstream.status_code == 200 else None)
        return Response(data, status=upstream.status_code, mimetype="application/json")

    def relay():
        buf, usage = b"", None
        try:
            for chunk in upstream.iter_bytes():
                yield chunk                                     # pass SSE bytes through unchanged
                buf += chunk
                *events, buf = buf.split(b"\n\n")
                for ev in events:
                    if ev.startswith(b"data: {"):
                        usage = json.loads(ev[6:]).get("usage") or usage
        finally:                                                # runs on normal end AND client disconnect (PEP 3333 close())
            upstream.close()                                    # vLLM sees the disconnect and cancels the request
            settle_quota(key_id, usage)                         # usage None -> charge the reservation

    return Response(relay(), mimetype="text/event-stream",
                    headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})
```

Notes on the sketch:
- `hmac.digest`, `hmac.new` and `hmac.compare_digest` are documented in [hmac](https://docs.python.org/3/library/hmac.html), and `token_hex`/`token_urlsafe` in [secrets](https://docs.python.org/3/library/secrets.html).
- All headers are set before the generator runs, as Flask requires ([Flask streaming](https://flask.palletsprojects.com/en/stable/patterns/streaming/)). The generator touches no `request` state, so `stream_with_context` is not needed.
- Upstream error bodies are passed through as-is. To avoid leaking vLLM internals (cf. GHSA-hwrm), replace them with a generic error plus a request ID.
- Missing on purpose: `/v1/models`, admin key issuance and revocation endpoints, a concurrent-stream cap, structured-output fields (`response_format`) pending review against GHSA-85xf/-rwxx, and audit logging (§4).

## 9. Security controls checklist

**vLLM process (on the GPU node)**
- [ ] vLLM ≥ **0.32.0**, preferably **0.33.0** (§3). Re-check the [advisory list](https://github.com/vllm-project/vllm/security/advisories) before each deploy.
- [ ] Not reachable by anyone but the gateway: `--uds` in a 0700 directory, or `--host 127.0.0.1` on an exclusive node. Never the default all-interfaces bind (§1, §6).
- [ ] `--api-key` set via `VLLM_API_KEY` env as an internal shared secret. Users never see it.
- [ ] `--disable-fastapi-docs`. No `VLLM_SERVER_DEV_MODE`, no `--profiler-config`, no `--enable-tokenizer-info-endpoint`, no `--grpc-port`, no endpoint plugins.
- [ ] No `--tool-server demo`. `VLLM_GPT_OSS_SYSTEM_TOOL_MCP_LABELS` unset unless tools have been reviewed.
- [ ] No runtime LoRA updating. No `--enable-prompt-embeds`. No `--trust-request-chat-template` / `--trust-request-mm-kwargs`. `VLLM_ENABLE_RESPONSES_API_STORE` off.
- [ ] `VLLM_MAX_N_SEQUENCES` small (the gateway strips `n` anyway). `--max-model-len` set. `--override-generation-config '{"max_new_tokens": N}'` as a hard output cap.
- [ ] `--enable-log-requests` / `--enable-log-outputs` off. Log level not DEBUG. `VLLM_DEBUG_LOG_API_SERVER_RESPONSE` off.
- [ ] `--sse-keep-alive-interval` set (e.g. 15) if any hop has a read timeout.
- [ ] `torch.distributed`/KV/DP ports unreachable from other hosts (only matters for multi-node or multi-process setups).

**Gateway (Flask + gunicorn)**
- [ ] gunicorn `-k gthread --threads N` (or gevent). Not sync, not `flask run`. Bound to `127.0.0.1` behind nginx. Not root.
- [ ] Per-user keys: ≥32 random bytes from `secrets`, a prefixed format, shown once.
- [ ] Only `HMAC-SHA256(pepper, key)` stored. Pepper kept outside the DB. `hmac.compare_digest` on fixed-length digests.
- [ ] Revocation and expiry checked on every request. Repeated 401s per IP throttled.
- [ ] Routes allowlisted: only `/v1/chat/completions` (+ `/v1/models`). No `/v1/completions`, `/tokenize`, `/metrics` or `/invocations` passthrough.
- [ ] Body fields allowlisted. `model`, `max_completion_tokens` and `cache_salt` overwritten server-side. Numeric fields validated.
- [ ] Per-user secret `cache_salt` (HMAC-derived).
- [ ] `MAX_CONTENT_LENGTH` set. Message count and length bounded.
- [ ] Per-key request rate, concurrent-stream cap and token quota in a store shared across workers. `include_usage` forced. Reserve then settle.
- [ ] Upstream client has explicit timeouts and no automatic retries. Upstream closed in `finally`.
- [ ] Logs hold key_id/user/status/tokens/latency only. No `Authorization`, no prompts or outputs. Keys never accepted in query strings.
- [ ] `ProxyFix` / `forwarded_allow_ips` match the real proxy chain.

**Edge (nginx)**
- [ ] TLS on 443. Gunicorn and vLLM never exposed directly.
- [ ] `client_max_body_size` ≤ the Flask limit. `limit_req` per IP.
- [ ] Exact-match `location` allowlist, everything else 404.
- [ ] Buffering off for SSE (`X-Accel-Buffering: no` or `proxy_buffering off`). `proxy_read_timeout` above the longest expected silent gap. `proxy_ignore_client_abort off`.

## Open questions

1. **Is a persistent public-facing service allowed on VACC at all?** That means a multi-day GPU job serving outside users, a tunnel from an outside host, and any inbound port. Covered by the VACC serving-policy research, not here. Ask **vacchelp@uvm.edu**.
2. **SSH to compute nodes:** can a user SSH into the node running their job (is `pam_slurm_adopt` in use?), and does such a session see the job's private `/tmp`? This decides whether the Unix-socket tunnel in §6 works. **Not found.** Ask vacchelp@uvm.edu.
3. **Unattended SSH credential** for the tunnel: are SSH keys allowed, and is Duo required? Already open in [../vacc/README.md](../vacc/README.md#open-questions--not-found). Ask vacchelp@uvm.edu.
4. **Network reachability** between a UVM-hosted VM (where the gateway would run) and IceCore compute nodes, and whether compute nodes are firewalled from each other. **Not found.** Ask vacchelp@uvm.edu / UVM ETS.
5. **GPU node sharing:** does `nvgpu` place other users' jobs on the same node, and what does `--exclusive` cost in CUs on an 8-GPU node? Ask vacchelp@uvm.edu.
6. **TLS certificate and hostname** for the gateway (UVM-issued cert, DNS name, whether UVM security review is needed for an externally reachable service). Ask UVM ETS.
7. **Data policy:** whether prompts from end users may be processed on VACC, and whether any regulated data (HIPAA/FERPA) is expected. The earlier notes found no VACC compliance statement ([../vacc/README.md](../vacc/README.md#open-questions--not-found)).
8. **Advisory ranges with errors as published:** GHSA-wr9h, GHSA-7h4p, GHSA-7m6h and GHSA-x567 list affected/fixed ranges that contradict themselves or their text. The fixed-in versions were taken at face value. Ask via the vLLM [security policy](https://github.com/vllm-project/vllm/blob/main/SECURITY.md) if a precise boundary matters.
9. **GHSA-q97c and GHSA-7m6h on gpt-oss specifically** (embedding padding at TP=1; whether the MoE path uses `act_and_mul_kernel`). Not verified. Running ≥0.32.0 makes the question moot.
10. **Gunicorn disconnect detection per worker class**, and **httpx `Client` thread-safety** under gthread: neither documented in the pages read. Verify with a test before relying on prompt cancellation.
11. **0.33.0 release status:** on PyPI, but no GitHub Release object (only rc3). Confirm it is a supported release before pinning.
