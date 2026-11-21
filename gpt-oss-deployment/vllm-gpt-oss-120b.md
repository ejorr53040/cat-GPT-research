# Serving a fine-tuned gpt-oss-120b with vLLM on VACC

Claims are cited inline. "(my arithmetic)" marks derived numbers; "[INFERENCE]" marks conclusions drawn from code or docs that no source states outright. VACC facts are in [../vacc/](../vacc/README.md).

## Versions this note applies to

- **vLLM v0.33.0**, released 2026-11-02 (GitHub API tag string `v0.33.0rc3`; release name and git tag `v0.33.0`) ([release](https://github.com/vllm-project/vllm/releases/tag/v0.33.0)). Image: `vllm/vllm-openai:v0.33.0` ([Docker Hub](https://hub.docker.com/r/vllm/vllm-openai/tags)).
- **v0.33.0 wheels and images are CUDA 13.0 only**; the `-cu129` images are no longer published ([v0.33.0 notes](https://github.com/vllm-project/vllm/releases/tag/v0.33.0)). The last CUDA 12.9 image is `vllm/vllm-openai:v0.32.0-cu129` ([v0.32.0 notes](https://github.com/vllm-project/vllm/releases/tag/v0.32.0)).
- Recipes: the current recipe is [recipes.vllm.ai/openai/gpt-oss-120b](https://recipes.vllm.ai/openai/gpt-oss-120b) ([JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json), `min_vllm_version: 0.10.1`). The legacy Markdown recipe ([docs.vllm.ai … GPT-OSS](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html), cited below as "recipe") is marked historical but holds the Hopper config, known limitations and troubleshooting.

## 1. Model facts

| Item | Value | Source |
| --- | --- | --- |
| Total / active params | 116.83 B total, 5.13 B active per token. MLP 114.71 B, attention 0.96 B, embed+unembed 1.16 B | [Model card, Table 1](https://arxiv.org/abs/2508.10925) |
| Architecture | 36 layers, residual dim 2880, MoE with 128 experts and top-4 routing, SwiGLU with clamping. Attention alternates between a 128-token banded window and dense layers. 64 query heads of dim 64, GQA with 8 KV heads, learned attention sinks | [Model card §2.2](https://arxiv.org/abs/2508.10925); [config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json) |
| Context length | 131,072 tokens via YaRN (`max_position_embeddings: 131072`, `initial_context_length: 4096`, rope factor 32) | [Model card §2.2](https://arxiv.org/abs/2508.10925); [config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json) |
| Quantization | MoE weights are post-trained in **MXFP4** at 4.25 bits/param. Attention, router, embeddings and `lm_head` stay BF16 (`modules_to_not_convert`). All evals used MXFP4 | [Model card §2.1](https://arxiv.org/abs/2508.10925); [config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json); [HF card](https://huggingface.co/openai/gpt-oss-120b) |
| Checkpoint size | The 15 top-level `model-*.safetensors` files total **65,248,893,184 bytes ≈ 65.25 GB** (60.8 GiB). The whole repo is **195.8 GB** because it also holds `original/` (65.25 GB) and `metal/model.bin` (65.24 GB). vLLM needs only the top-level files | [Model card](https://arxiv.org/abs/2508.10925); [HF file list](https://huggingface.co/openai/gpt-oss-120b/tree/main) |
| Tokenizer | `o200k_harmony`, 201,088 tokens | [Model card §2.3](https://arxiv.org/abs/2508.10925) |
| License | Apache 2.0 plus the gpt-oss usage policy (comply with applicable law) | [Model card §1](https://arxiv.org/abs/2508.10925); [USAGE_POLICY](https://huggingface.co/openai/gpt-oss-120b/blob/main/USAGE_POLICY) |
| Response format | Requires the **harmony** format ("will not work correctly otherwise"). Channels: `analysis` (chain of thought), `commentary` (tool calls), `final` (answer). Role priority System > Developer > User > Assistant > Tool. Drop reasoning traces from past assistant turns in multi-turn use | [HF card](https://huggingface.co/openai/gpt-oss-120b); [Model card §2.5.1](https://arxiv.org/abs/2508.10925); [openai/harmony](https://github.com/openai/harmony) |
| Reasoning effort | low, medium or high, set in the system prompt (e.g. "Reasoning: high"). Harmony defaults to `ReasoningEffort.MEDIUM` | [Model card §2.5.2](https://arxiv.org/abs/2508.10925); [harmony `__init__.py`](https://github.com/openai/harmony/blob/main/python/openai_harmony/__init__.py) |
| Tool use | Trained with a browsing tool, a stateful Python (Jupyter) tool, and developer-defined functions declared in the Developer message. Supports Structured Outputs | [Model card §1, §2.5.3](https://arxiv.org/abs/2508.10925) |
| Chain of thought | Fully exposed, "not intended to be shown to end users" | [HF card](https://huggingface.co/openai/gpt-oss-120b) |
| Fine-tuning | "can be fine-tuned on a single H100 node" | [HF card](https://huggingface.co/openai/gpt-oss-120b) |

## 2. Memory sizing

### What the sources say

- gpt-oss-120b fits "into a single 80GB GPU" ([HF card](https://huggingface.co/openai/gpt-oss-120b)).
- **H100 TP1 limit:** default memory utilization and batched tokens cause CUDA OOM; use `--gpu-memory-utilization 0.95 --max-num-batched-tokens 1024`. On H100 TP2, keep utilization below 0.95 ([recipe, Known Limitations](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- Default `gpu_memory_utilization` is **0.92** in v0.33.0 ([`config/cache.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/cache.py)).
- vLLM's hybrid KV-cache manager handles the sliding-window + full-attention mix; sliding-window layers "reserve slots only for the most recent `sliding_window_size` tokens" ([hybrid KV cache manager, v0.33.0](https://docs.vllm.ai/en/v0.33.0/design/hybrid_kv_cache_manager/)).

### KV cache per token (my arithmetic from config.json)

- Each layer stores K+V: 2 × 8 KV heads × 64 dims × 2 bytes (BF16) = 2,048 B per token.
- Only the **18 full-attention layers** grow with context: 18 × 2,048 = **36,864 B/token (36 KiB)**. The 18 sliding-window layers hold at most about 128 tokens plus one block per sequence (~5 MB per sequence).
- A full 131,072-token sequence needs about **4.83 GB** of KV in BF16, about 2.42 GB with `--kv-cache-dtype fp8`.
- With TP=N, each GPU holds 1/N of the KV heads, so per-GPU cost per token falls by N while total capacity stays the same.

### Sizing table (my arithmetic)

Method: KV budget = utilisation × vendor capacity × GPUs − weights.

- **The budget is an upper bound.** Activation workspace and CUDA-graph memory also come out of it; no source quantifies them for gpt-oss. The usable memory vLLM reports at startup will differ.
- Vendor capacities (decimal GB): H200 141, H100 80, RTX Pro 6000 96, A100 40 ([../vacc/hardware.md](../vacc/hardware.md)).
- Weights: MXFP4 = 65.25 GB. Merged BF16 = 116.83 B × 2 B = **233.7 GB**, matching [`unsloth/gpt-oss-120b-BF16`](https://huggingface.co/unsloth/gpt-oss-120b-BF16) (233,658,385,752 bytes).
- "Full-ctx seqs" = simultaneous 131k-token sequences with a BF16 KV cache.

| Checkpoint | GPUs (TP) | Weights per GPU | KV budget @0.92 | Tokens of KV @0.92 | Full-ctx seqs | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| MXFP4 | 1× H200 | 65.2 GB | 64.5 GB | ~1.75 M | ~13 | **Fits.** Recipe default for H200 is TP1 |
| MXFP4 | 2× H200 (TP2) | 32.6 GB | 194.2 GB | ~5.27 M | ~40 | Lower latency, more KV |
| MXFP4 | 1× H100 80 GB | 65.2 GB | 8.4 GB (10.8 @0.95) | ~0.23 M (0.29 M) | ~1.7 (2.2) | **Marginal.** Recipe documents OOM at defaults |
| MXFP4 | 2× H100 (TP2) | 32.6 GB | 82.0 GB | ~2.22 M | ~17 | OK. Keep util < 0.95 (recipe) |
| MXFP4 | 1× RTX Pro 6000 96 GB | 65.2 GB | 23.1 GB | ~0.63 M | ~4.8 | Fits. Kernel caveats in §3 |
| MXFP4 | 2× RTX Pro 6000 (TP2) | 32.6 GB | 111.4 GB | ~3.02 M | ~23 | PCIe only. VACC: RTX 6000 multi-GPU "not recommended" ([../vacc/hardware.md](../vacc/hardware.md#gpu-inventory-as-vacc-documents-it)) |
| MXFP4 | 1× A100 40 GB | 65.2 GB | — | — | — | **Does not fit** |
| MXFP4 | 2× A100 40 GB (TP2) | 32.6 GB | 8.4 GB total | ~0.23 M | ~1.7 | Marginal. PCIe Gen4, not recommended by VACC for multi-GPU. Only 2 A100s per node |
| BF16 merged | 2× H200 (TP2) | 116.8 GB | 25.8 GB | ~0.70 M | ~5 | Tight |
| BF16 merged | **4× H200 (TP4)** | 58.4 GB | 285.2 GB | ~7.74 M | ~59 | **Minimum practical for BF16.** One full H200 NVL node, or half an SXM node |
| BF16 merged | 8× H200 SXM (TP8) | 29.2 GB | 804 GB | ~21.8 M | ~166 | Whole SXM node |
| BF16 merged | 4× H100 (TP4) | 58.4 GB | 60.7 GB | ~1.65 M | ~12.6 | Possible. H100 access restricted (§8) |
| BF16 merged | 4× RTX Pro 6000 (TP4) | 58.4 GB | 119.6 GB | ~3.24 M | ~25 | PCIe only, not recommended by VACC |

- Valid TP sizes are 1, 2, 4 or 8 (64 query heads, 8 KV heads; [config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json)) [INFERENCE: vLLM shards heads evenly].
- `GptOssForCausalLM` also supports pipeline parallelism ([supported models, v0.33.0](https://docs.vllm.ai/en/v0.33.0/models/supported_models/)).
- **LoRA adds GPU memory.** Each MoE layer allocates stacked expert LoRA buffers sized `max_loras × experts × max_lora_rank × (hidden + 2·intermediate + intermediate + hidden)` ([`lora/layers/fused_moe.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/lora/layers/fused_moe.py)). At TP1 that is about **132.7 MB per rank per adapter slot** (my arithmetic: 128 × 14,400 × 36 layers × 2 B):
  - rank 16: ≈2.1 GB
  - rank 32: ≈4.2 GB
  - rank 64: ≈8.5 GB

  This is per `--max-loras` slot, before attention-layer LoRA. On a single H100 it consumes the KV headroom.

## 3. Hardware and kernel support in vLLM

### Official statements

- The current recipe marks h100, h200, b200, mi300x, mi325x, mi355x, ironwood and arc_pro_b70 as "verified". **No RTX Pro 6000 / SM120 entry** ([recipe JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json)).
- Ampere works by default with `TRITON_ATTN` and Marlin MXFP4 MoE ([recipe, A100 section](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)), supported since v0.10.1 ([v0.10.1 notes](https://github.com/vllm-project/vllm/releases/tag/v0.10.1)). The recipe's "actively working on Ampere" line is stale.

### What vLLM v0.32.0/v0.33.0 actually selects (read from source)

**MoE kernel.** `_get_priority_backends_for_gpt_oss()` tries backends in this order ([`fused_moe/oracle/mxfp4.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/layers/fused_moe/oracle/mxfp4.py)):

1. FlashInfer TRT-LLM (SM100 family only)
2. AITER (ROCm)
3. OAI Triton (SM90 ≤ CC < SM130)
4. FlashInfer CUTLASS (the W4A16 MXFP4 scheme on SM90 only)
5. Marlin (CC ≥ 7.5)

On **SM120** the code moves Triton behind Marlin (Triton is capped at small tiles by the 99 KB shared-memory budget); Triton stays opt-in.

**Attention.** vLLM picks the first backend that supports sinks:

- On non-SM100 CUDA the priority is FLASH_ATTN, then FLASHINFER, then TRITON_ATTN ([`platforms/cuda.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/platforms/cuda.py)).
- FLASH_ATTN supports sinks only on FA3 (CC 9.x) or FA4 (CC 10.x); everything else falls back to FA2 ([`fa_utils.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/v1/attention/backends/fa_utils.py)).
- TRITON_ATTN always supports sinks ([`triton_attn.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/v1/attention/backends/triton_attn.py)).

| VACC GPU | CC | MoE kernel (default, no LoRA) | Attention | Status |
| --- | --- | --- | --- | --- |
| H200 NVL / SXM | 9.0 | OAI Triton `matmul_ogs` (MXFP4 W4A16) | FlashAttention 3 with sinks | **Verified** in the recipe. Use `GPT-OSS_Hopper.yaml`-style flags |
| H100 | 9.0 | Same as H200 | FA3 | **Verified**. Memory-tight at TP1 |
| RTX Pro 6000 Blackwell | **12.0** | **Marlin** (MXFP4 weight-only, BF16 activations). Triton opt-in via `--moe-backend triton`. FlashInfer TRT-LLM is SM100-only. The SM120 `b12x` MoE rejects expert biases ([`b12x.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/layers/fused_moe/b12x.py)), which gpt-oss has | TRITON_ATTN. FlashInfer sinks on SM120 depend on a TRT-LLM attention check ([`flashinfer.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/v1/attention/backends/flashinfer.py)) | **Runs; not on the verified list.** Lower throughput than SM100's native-FP4 path |
| A100 40 GB | 8.0 | Marlin | TRITON_ATTN | Supported, but **does not fit** one 40 GB card (§2) |

**RTX Pro 6000 (SM120) resources:**

- [Issue #30135](https://github.com/vllm-project/vllm/issues/30135) (open): MXFP4 models fall back to Marlin on RTX PRO 6000.
- [PR #31089](https://github.com/vllm-project/vllm/pull/31089) (SM120 Triton MXFP4) was closed as slower than Marlin on SM120. A maintainer there notes the "no native FP4" warning is harmless because gpt-oss is a weight-only MXFP4 W4A16 checkpoint.
- [Issue #23497](https://github.com/vllm-project/vllm/issues/23497) (open) collects configs that run gpt-oss-120b on RTX Pro 6000 with `--kv-cache-dtype fp8`.
- **Do not copy the B200 recipe flags** (`--moe-backend flashinfer_trtllm --quantization-config.moe.activation mxfp8`, [recipe JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json)) to the RTX Pro 6000: FlashInfer TRT-LLM MXFP4 is gated to `is_device_capability_family(100)` ([`trtllm_mxfp4_moe.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/model_executor/layers/fused_moe/experts/trtllm_mxfp4_moe.py)) [INFERENCE]. VACC has no SM100 GPUs.

**Driver requirement.** "CUDA 13 requires an R580 or newer driver". The image ships CUDA forward-compatibility libraries, enabled with `VLLM_ENABLE_CUDA_COMPATIBILITY=1`, that support R535/R570 hosts on "select professional and datacenter NVIDIA GPUs" ([GPU install docs, v0.33.0](https://docs.vllm.ai/en/v0.33.0/getting_started/installation/gpu/)). The v0.33.0 image is built `FROM nvidia/cuda:13.0.3-base-ubuntu24.04` ([Dockerfile @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docker/Dockerfile)). VACC's host driver version is **not documented**; VACC's `cuda/13.0.2` module ([../vacc/software.md](../vacc/software.md)) suggests R580+ [INFERENCE].

## 4. Fine-tunes: what they produce and how vLLM serves them

### What the official fine-tuning guides produce

- **OpenAI cookbook / Hugging Face TRL guide** ([cookbook: fine-tune-transfomers](https://developers.openai.com/cookbook/articles/gpt-oss/fine-tune-transfomers); written for gpt-oss-20b on one H100):
  - Load with `Mxfp4Config(dequantize=True)` and `torch_dtype=torch.bfloat16`, which **dequantizes the MXFP4 experts to BF16**.
  - Apply PEFT LoRA with `target_modules="all-linear"` plus `target_parameters=[...mlp.experts.gate_up_proj, ...mlp.experts.down_proj]` for selected layers (example `r=8`, `lora_alpha=16`).
  - Train with TRL `SFTTrainer` (`trl>=0.20.0`, `peft>=0.17.0`, `transformers>=4.55.0`).
  - Output is a **PEFT LoRA adapter**. `merge_and_unload()` yields a merged model in the loaded dtype (BF16); the guide never re-quantizes to MXFP4.
- **HF `gpt-oss-recipes`** `sft.py` supports full-parameter training (`accelerate` + ZeRO-3 on one 8-GPU node) and LoRA (one GPU) ([huggingface/gpt-oss-recipes](https://github.com/huggingface/gpt-oss-recipes)). A full fine-tune produces a **BF16 checkpoint** of about 233.7 GB (§2).
- **NVIDIA Model-Optimizer** ([examples/gpt-oss README](https://github.com/NVIDIA/Model-Optimizer/blob/main/examples/gpt-oss/README.md)):
  - BF16 training yields a model about 4× the original size; MXFP4 post-training quantization (PTQ) "degrades the finetuned model accuracy".
  - Its fix is **QAT** (`mtq.MXFP4_MLP_WEIGHT_ONLY_CFG` / recipe `general/ptq/mxfp4_mlp_weight_only`), then `convert_oai_mxfp4_weight_only.py`, which converts a BF16 checkpoint to the original GPT-OSS MXFP4 weight-only format. It can also merge a LoRA-QAT adapter (`--lora_path … --base_path openai/gpt-oss-120b`).
  - QAT with LoRA on gpt-oss-120b needs one node with 8 × 80 GB GPUs. Deployment is `vllm serve <model_path>`.

### (a) Serving LoRA adapters directly (`--enable-lora`)

- **Supported.** `GptOssForCausalLM` is marked LoRA ✅ ([supported models, v0.33.0](https://docs.vllm.ai/en/v0.33.0/models/supported_models/)). It implements `SupportsLoRA` with `is_3d_moe_weight = True` ([`gpt_oss.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/models/gpt_oss.py)), so it accepts PEFT `target_parameters`-style fused 3D expert adapters (`...experts.gate_up_proj.lora_A.weight`) ([LoRA docs, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/lora/)).
- **LoRA forces the Marlin MoE kernel** [INFERENCE from source]:
  - With LoRA enabled, kernels lacking `supports_lora()` are rejected ([`modular_kernel.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/model_executor/layers/fused_moe/modular_kernel.py)), and monolithic kernels are refused ([`lora/layers/fused_moe.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/lora/layers/fused_moe.py)).
  - Of the default-priority MXFP4 kernels, only `MarlinExperts` mixes in `LoRAExpertsMixin` ([`marlin_moe.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/layers/fused_moe/experts/marlin_moe.py)).
  - On H200, a LoRA deployment gives up the Hopper Triton MoE kernel. The throughput cost is **not published**.
- **Bug at TP 4/8.** [PR #65825](https://github.com/vllm-project/vllm/pull/65825), merged 2026-11-05 (not in v0.33.0), fixes mismatched intermediate-channel slices for expert LoRA at TP=4/8.
  - For gpt-oss (intermediate 2880 = 90 MXFP4 blocks), TP2 gives 1440 = 1440 (unaffected); TP4 gives 736 vs 720 and TP8 384 vs 360 (my arithmetic).
  - **Use TP1 or TP2 for LoRA on ≤ v0.33.0.**
- [Issue #60811](https://github.com/vllm-project/vllm/issues/60811) (closed 2026-10-10): silently wrong outputs with `--enable-mixed-moe-lora-format`; the default 3D path is unaffected. **Validate adapter outputs against the merged model before production.**
- **Defaults and flags.** `max_lora_rank` defaults to 16 and accepts {1, 8, 16, 32, 64, 128, 256, 320, 512}; `max_loras` defaults to 1 ([`config/lora.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/lora.py)). Adapters load at start with `--lora-modules name=path`, or at runtime via `/v1/load_lora_adapter` when `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True` ([LoRA docs](https://docs.vllm.ai/en/v0.33.0/features/lora/)). Requests address the adapter by `name` in the `model` field.
- **Base precision.** The adapter is trained against BF16-dequantized experts but served over the MXFP4 base. The accuracy cost is **not quantified** by any source. ModelOpt QAT is the documented way to avoid the mismatch.

### (b) Serving a merged BF16 checkpoint

- vLLM has a non-MXFP4 weight path for gpt-oss (`_load_weights_other`, mapping `.gate_up_proj` / `.down_proj` to unquantized `w13_weight` / `w2_weight`) ([`gpt_oss.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/models/gpt_oss.py)). No recipe or test serves gpt-oss-120b in BF16: **Uncertain until smoke-tested**.
- **Size and GPUs:** about 233.7 GB, so at least 2× H200, in practice 4× H200 at TP4 (§2).
- **Uncertain:** after `Mxfp4Config(dequantize=True)` + `merge_and_unload()` + `save_pretrained`, check that the saved `config.json` no longer declares `quantization_config.quant_method: mxfp4`; vLLM picks the loader from that field ([`gpt_oss.py` `load_weights`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/models/gpt_oss.py)).
- **Load-time shrink (Uncertain for gpt-oss):** vLLM online quantization can quantize MoE weights of a BF16 checkpoint to MXFP4 at load, e.g. `--quantization mxfp4 --quantization-config '{"linear":{"activation":null,"weight":null}}'` ([online quantization, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/quantization/online/)). Documented only for Llama/Qwen, untested for gpt-oss's biased, clamped SwiGLU experts, and it is PTQ (accuracy loss per ModelOpt).

### (c) Re-quantized MXFP4 checkpoint

- ModelOpt's `convert_oai_mxfp4_weight_only.py` output deploys like the original GPT-OSS MXFP4 models ([Model-Optimizer README](https://github.com/NVIDIA/Model-Optimizer/blob/main/examples/gpt-oss/README.md)).
- Keeps the 65 GB footprint, the 1× H200 TP1 layout, and the Hopper Triton MoE kernel.
- Costs: an extra QAT stage (recommended learning rate 1e-5, "a few million to billion tokens") and a dependency on NVIDIA tooling.

### Tradeoffs

| Path | Serving GPUs (H200) | MoE kernel on H200 | Accuracy risk | Ops notes |
| --- | --- | --- | --- | --- |
| (a) Base MXFP4 + LoRA adapter | 1 (TP1) or 2 (TP2) | Marlin (forced) | Adapter trained on BF16, served on MXFP4. Recently fixed code | Smallest artifact. Several adapters can share one base. TP4/8 LoRA broken ≤ v0.33.0 |
| (a′) Merge LoRA → BF16 | 4 (TP4) | Unquantized path | Lowest (matches training precision) | 234 GB on disk and in VRAM |
| (b) Full FT → BF16 | 4 (TP4), or 8 | Unquantized path | Lowest | 234 GB. No published vLLM recipe for BF16 |
| (c) LoRA/full FT → QAT → MXFP4 | 1 (TP1) | OAI Triton (default Hopper) | QAT recovers PTQ loss per NVIDIA. Must evaluate | Best serving efficiency. Extra training step |

## 5. Serving with `vllm serve`

### Commands from the recipes

- Current recipe for H200 ([recipe JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json)):
  ```bash
  vllm serve openai/gpt-oss-120b \
    --tensor-parallel-size 1 \
    --tool-call-parser openai \
    --enable-auto-tool-choice
  ```
- The H100 entry's `--tensor-parallel-size 8` reflects "TP size is set to the GPU count at deploy time" on an 8-GPU profile, not a minimum ([recipe JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json)).
- Hopper config `GPT-OSS_Hopper.yaml` ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)):
  ```yaml
  no-enable-prefix-caching: true   # for benchmarking with synthetic datasets
  max-cudagraph-capture-size: 2048
  max-num-batched-tokens: 8192
  stream-interval: 20
  ```
  `stream-interval 20` maximises throughput but streams in 20-token chunks ([recipe, Configs and Parameters](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). For interactive chat, leave the default of 1 ([`config/scheduler.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/scheduler.py)).
- **Throughput vs latency:** TP1 gives the best throughput per GPU; TP 2/4/8 give better per-user latency ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).

### Key flags (vLLM v0.33.0)

| Flag | Meaning / default | Source |
| --- | --- | --- |
| `--tensor-parallel-size N` | GPUs per replica. 1, 2, 4 or 8 for this model | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--max-model-len` | Defaults to 131,072. Lowering it "may improve the performance" | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--gpu-memory-utilization` | Default **0.92** | [`config/cache.py`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/cache.py) |
| `--async-scheduling` | **On by default** unless incompatible (`None` = auto-enable). `--no-async-scheduling` turns it off | [`config/vllm.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/vllm.py); [`config/scheduler.py`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/scheduler.py) |
| `--max-num-seqs`, `--max-num-batched-tokens` | Batch size and per-step token budget. Recipe uses 8192 | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--kv-cache-dtype fp8` | In the Blackwell config only, not Hopper | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--served-model-name` | Name clients put in `model`. LoRA adapters are addressed by their `--lora-modules` name | [LoRA docs](https://docs.vllm.ai/en/v0.33.0/features/lora/) |
| `--host` / `--port` | `host` defaults to `None`, and the launcher binds `(args.host or "", args.port)`, i.e. **all interfaces**. Default port **8000**. The legacy recipe's "127.0.0.1" default is wrong for v0.33.0. Always pass `--host` or `--uds` | [`entrypoints/common/cli_args.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py); [`launchers/launcher.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/launchers/launcher.py) |
| `--api-key` / `VLLM_API_KEY` | Bearer token; "only authenticates endpoints under the `/v1`, `/v2`, `/inference`, and `/cohere` path prefixes". `/invocations`, `/pause`, `/abort_requests`, `/update_weights`, `/metrics`, `/tokenize` and others stay open. Docs recommend a reverse proxy that allowlists endpoints | [security, v0.33.0](https://docs.vllm.ai/en/v0.33.0/usage/security/); [`cli_args.py`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py) |
| `--tool-call-parser openai --enable-auto-tool-choice` | Function calling for gpt-oss. Only `tool_choice="auto"` is supported | [tool calling, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/tool_calling/); [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--reasoning-parser openai_gptoss` | Reasoning parser name for gpt-oss (missing from the docs' parser table) | [`reasoning/__init__.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/reasoning/__init__.py) |
| `--tool-server demo` or `--tool-server host:port,...` | Built-in browser/python tools (Responses API only). `demo` needs `pip install gpt-oss` and either Docker or `PYTHON_EXECUTION_BACKEND=dangerously_use_uv` | [recipe, Tool Use](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--enable-lora --lora-modules n=path --max-lora-rank R --max-loras K` | LoRA serving | [LoRA docs](https://docs.vllm.ai/en/v0.33.0/features/lora/) |

**Parser selection:** `ParserManager` returns **no parser** when neither `--tool-call-parser` nor `--reasoning-parser` is set; when either is set for a `gpt_oss` model it returns `HarmonyParser` ([`parser/parser_manager.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/parser/parser_manager.py); [`chat_completion/serving.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/chat_completion/serving.py)). Pass at least `--tool-call-parser openai` so reasoning and final text come back as separate fields [INFERENCE].

### Endpoints and how reasoning is exposed

- `/v1/chat/completions` ([recipe, Usage](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)):
  - Returns reasoning and final text structurally; no built-in tools are invoked.
  - Function calling works; built-in browser and python tools do not.
  - Reasoning is in `message.reasoning` (formerly `reasoning_content`; clients reading the old name get an empty field) ([reasoning outputs, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/reasoning_outputs/)).
- `/v1/responses` supports built-in tools (browsing, python, MCP) via `openai-harmony` ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). Limits:
  - "Usage accounting is currently broken and only returns all zeros" (blocks per-user token metering)
  - streaming is "fairly barebone"
  - annotations are unsupported
  - function calling is not supported with streaming
- `/v1/completions` is raw text with no template; harmony formatting is the caller's job ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- **Reasoning effort:**
  - Chat Completions takes `reasoning_effort` (`high`, `medium` or `low`), written into the harmony system message ([`harmony_utils.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/parser/harmony_utils.py)).
  - The Responses API takes `reasoning.effort` ([reasoning outputs](https://docs.vllm.ai/en/v0.33.0/features/reasoning_outputs/)).
  - Unset defaults to medium ([harmony](https://github.com/openai/harmony/blob/main/python/openai_harmony/__init__.py)).
- **Hiding the chain of thought:** `include_reasoning: false` works on both APIs, streaming and non-streaming. Reasoning is still generated; vLLM also suppresses per-token logprobs and token IDs ([reasoning outputs](https://docs.vllm.ai/en/v0.33.0/features/reasoning_outputs/)). Since the CoT is not meant for end users ([HF card](https://huggingface.co/openai/gpt-oss-120b)), the Flask layer must strip `reasoning` or force `include_reasoning=false` [INFERENCE].

## 6. Running under Apptainer on Slurm (no Docker)

### Image

- Official image `vllm/vllm-openai`: `ENTRYPOINT ["vllm", "serve"]`, runs as root by default ([Dockerfile @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docker/Dockerfile); [Docker deployment, v0.33.0](https://docs.vllm.ai/en/v0.33.0/deployment/docker/)).
- Tags: `v0.33.0` (CUDA 13.0 only, about 10.9 GB) and `v0.32.0` / `v0.32.0-cu129` ([Docker Hub](https://hub.docker.com/r/vllm/vllm-openai/tags)).
- `apptainer pull docker://…` builds a SIF and caches the blobs ([Apptainer 1.3: Docker and OCI](https://apptainer.org/docs/user/1.3/docker_and_oci.html)).
- An ENTRYPOINT-only image's entrypoint becomes the runscript ([same page, "CMD / ENTRYPOINT Behaviour"](https://apptainer.org/docs/user/1.3/docker_and_oci.html)): `apptainer run img.sif <model> <flags>` = `vllm serve <model> <flags>`; `apptainer exec img.sif vllm serve …` is the explicit form.
- VACC sets `APPTAINER_CACHEDIR` to scratch and recommends `-e` (clean environment) ([../vacc/software.md](../vacc/software.md#containers)).

### GPU access

- `--nv` exposes `/dev/nvidiaX`, binds the host CUDA driver libraries, and sets `LD_LIBRARY_PATH`. The container must be built for a CUDA version and compute capability the host driver supports ([Apptainer 1.3: GPU](https://apptainer.org/docs/user/1.3/gpu.html)). For the CUDA 13 image: R580+ host driver, or the compat libraries (§3).
- Apptainer exposes all host devices by default; CUDA visibility is limited with `CUDA_VISIBLE_DEVICES` / `APPTAINERENV_CUDA_VISIBLE_DEVICES` ([Apptainer 1.3: GPU](https://apptainer.org/docs/user/1.3/gpu.html)). Slurm sets `CUDA_VISIBLE_DEVICES` for the job's GPUs ([../slurm/gpus.md](../slurm/gpus.md)), but `-e`/`--cleanenv` drops host environment ([Apptainer 1.3: environment](https://apptainer.org/docs/user/1.3/environment_and_metadata.html)). **With `-e`, pass it explicitly**: `--env CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES` [INFERENCE].

### Shared memory (`/dev/shm`)

- vLLM under Docker needs `--ipc=host` or `--shm-size` because PyTorch uses shared memory between processes, particularly for tensor parallelism ([GPU install / Docker, v0.33.0](https://docs.vllm.ai/en/v0.33.0/getting_started/installation/gpu/)).
- Apptainer has no such cap: by default `/dev` (including `/dev/shm`), `$HOME`, `/tmp` and `/var/tmp` are bind-mounted from the host ([Apptainer 1.3: bind paths](https://apptainer.org/docs/user/1.3/bind_paths_and_mounts.html)).
- On VACC the host `/dev/shm` is **per-job private**, deleted at job end, with an **undocumented** size limit ([../vacc/storage.md](../vacc/storage.md#filesystems)). TP1 makes little use of cross-process shared memory [INFERENCE]. Confirm the limit with VACC before TP4/TP8.

### Model weights, caches and offline mode

- `HF_HOME` sets the Hub cache and token location (default `~/.cache/huggingface`). `HF_HUB_OFFLINE=1` makes no Hub HTTP calls and reads only cached files ([HF Hub env vars](https://huggingface.co/docs/huggingface_hub/en/package_reference/environment_variables)).
- Pre-download on a login or data-transfer node. Then point `vllm serve` at a local directory, or set `HF_HOME` to the GPFS cache and run with `HF_HUB_OFFLINE=1`.
- **Exclude `original/*` and `metal/*`** to save about 130 GB (§1). The 65.25 GB safetensors fit Tier 1 gpfs1 (2 TB soft) ([../vacc/storage.md](../vacc/storage.md#quotas)).
- **Harmony vocab download.** `openai-harmony` loads the `o200k` vocab from `TIKTOKEN_ENCODINGS_BASE` (local dir) or downloads `https://openaipublic.blob.core.windows.net/encodings/` into `TIKTOKEN_RS_CACHE_DIR` (default `/tmp/tiktoken-rs-cache`) ([harmony `public_encodings.rs`](https://github.com/openai/harmony/blob/main/src/tiktoken_ext/public_encodings.rs)).
  - VACC `/tmp` is per-job and wiped, so every job re-downloads; without outbound internet, startup fails with `HarmonyError: error downloading or loading vocab file`.
  - Fix: pre-download `o200k_base.tiktoken` and `cl100k_base.tiktoken` and `export TIKTOKEN_ENCODINGS_BASE=<dir>` ([recipe, Troubleshooting](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- `VLLM_CACHE_ROOT` (default `~/.cache/vllm`) holds `torch.compile` artifacts; persisting it avoids recompiling on every start ([Docker deployment, v0.33.0](https://docs.vllm.ai/en/v0.33.0/deployment/docker/); [`envs.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/envs.py)). Put it on scratch, not `$HOME`.

### Ports and networking

- `--net` joins a new network namespace, and for non-privileged users only `none` is allowed, which isolates the container from the host network ([Apptainer 1.3: networking](https://apptainer.org/docs/user/1.3/networking.html)). Run **without** `--net`; `vllm serve --port P` then listens on the compute node's interfaces [INFERENCE].
- Two jobs on one node cannot share port 8000; pick a free port per job.
- Reachability from the Flask host and VACC service policy: see [../vacc/serving-an-llm.md](../vacc/serving-an-llm.md) and Open questions. If Flask runs elsewhere, bind vLLM to the node's internal interface, not `0.0.0.0`, and use `--api-key` only as a Flask↔vLLM shared secret ([security](https://docs.vllm.ai/en/v0.33.0/usage/security/)).

## 7. Throughput and latency

- **No official per-GPU numbers** for gpt-oss-120b in vLLM, OpenAI or recipe sources. Benchmark method: `vllm bench serve --dataset-name random --random-input-len 1024 --random-output-len 1024 --max-concurrency … --num-prompts ≥5×concurrency` ([recipe, Benchmarking](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- **Accuracy reproduced by vLLM** (120B, no tools), GPQA / AIME25: low 65.3 / 51.2, medium 72.4 / 79.6, high 79.4 / 93.0 ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). Use as a regression check for the fine-tune.
- Average CoT+answer length grows with reasoning effort, roughly 2k tokens at low to 16k+ at high for AIME ([model card Fig. 3](https://arxiv.org/abs/2508.10925)). This drives per-request latency more than hardware choice [INFERENCE].

## 8. Recommended configurations on VACC

GPU features and partitions from [../vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#node-constraints---constraint---c):

- Constraints: `GPU_SKU:H200` | `H200_NVL` | `H200_SXM` | `H100` | `RTX6000` | `A100`, `GPU_MEM:140GB`, `GPU_CC:9.0` | `12.0`, `GPU_GEN:HOPPER` | `BLACKWELL`.
- Partitions: `nvgpu` (48 h max) and `week` (GPU availability unknown).
- Cost (my arithmetic, 1 CU = 1 GPU-minute, [../vacc/access.md](../vacc/access.md#allocations-tiers-and-compute-units)): 1 GPU 24/7 for a year = 525,600 CU (above Tier 1's 250k). 4 GPUs = 2.10 M CU (Tier 2); 8 GPUs = 4.20 M CU (Tier 3).
- **H100 is not an option:** the 8 SOCKS-funded H100s (`hgnodes`) are owner-restricted ([../vacc/access.md](../vacc/access.md#allocations-tiers-and-compute-units)).

### (i) LoRA fine-tune → base MXFP4 + adapter

- **Hardware:** 1× H200, TP1. `--constraint=GPU_SKU:H200` (either form factor) or `GPU_MEM:140GB`. TP2 for lower latency or more KV. No TP4/TP8 with LoRA on ≤ v0.33.0 (§4a).
- **Fallback:** 1× RTX Pro 6000, `--constraint=GPU_SKU:RTX6000` (or `GPU_CC:12.0`). Marlin MoE + Triton attention, about 0.6 M tokens of KV at 0.92. Not on vLLM's verified list. Keep rank and `--max-loras` small (rank-64 slot ≈ 8.5 GB, §2).
- **Image:** `vllm/vllm-openai:v0.33.0`, or a release containing PR #65825 if TP>2 is needed.
- **Sketch** (not run; flags per §5–6). Pin the version and paths:
  ```bash
  #!/bin/bash
  #SBATCH --partition=nvgpu
  #SBATCH --gpus=1
  #SBATCH --constraint=GPU_SKU:H200
  #SBATCH --cpus-per-task=8
  #SBATCH --mem=128G
  #SBATCH --time=48:00:00
  export APPTAINER_CACHEDIR=$HOME/scratch/apptainer-cache
  SIF=/gpfs1/pi/<PI>/containers/vllm-openai_v0.33.0.sif   # apptainer pull docker://vllm/vllm-openai:v0.33.0
  PORT=$(( 20000 + SLURM_JOB_ID % 20000 ))                # avoid collisions; any free-port scheme works
  apptainer exec -e --nv \
    --env CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES \
    --env HF_HOME=/gpfs1/pi/<PI>/hf --env HF_HUB_OFFLINE=1 \
    --env TIKTOKEN_ENCODINGS_BASE=/gpfs1/pi/<PI>/tiktoken \
    --env VLLM_CACHE_ROOT=$HOME/scratch/vllm-cache \
    --env VLLM_API_KEY="$(cat ~/.vllm_key)" \
    $SIF vllm serve /gpfs1/pi/<PI>/models/gpt-oss-120b \
      --served-model-name gpt-oss-120b-base \
      --tensor-parallel-size 1 \
      --enable-lora --max-loras 1 --max-lora-rank <your r> \
      --lora-modules catgpt=/gpfs1/pi/<PI>/adapters/catgpt-lora \
      --tool-call-parser openai --enable-auto-tool-choice \
      --reasoning-parser openai_gptoss \
      --max-model-len 32768 \
      --host <node-internal-ip> --port $PORT
  ```
  - Clients (Flask) send `model: "catgpt"`.
  - `--max-model-len 32768` is a placeholder; set it to the real input+output limit (shorter is faster).
- **Before going live:**
  - Run the gpt-oss GPQA/AIME eval (`python -m gpt_oss.evals`) at low effort against the adapter and the merged-BF16 model to catch LoRA or kernel mismatches (§4a).
  - Path (c), QAT-merge to MXFP4, removes `--enable-lora` and restores the Triton MoE kernel.

### (ii) Full fine-tune → BF16 checkpoint (about 234 GB)

- **Preferred:** convert to MXFP4 with ModelOpt QAT + `convert_oai_mxfp4_weight_only.py` (§4c), then serve like the base model on **1× H200, TP1** (`GPU_SKU:H200`) without LoRA flags; the default Hopper Triton MoE kernel and FA3 apply.
- **If kept in BF16:**
  - Hardware: **4× H200, TP4**, one node. `--gpus=4 --constraint=GPU_SKU:H200_NVL` takes a whole NVL node; `--constraint=GPU_SKU:H200_SXM` takes half an SXM node with NVSwitch (~900 GB/s vs ~300 GB/s NVL bridge, [../vacc/hardware.md](../vacc/hardware.md#gpu-inventory-as-vacc-documents-it)). Prefer `H200_SXM` for TP4 all-reduce [INFERENCE].
  - KV headroom ≈ 285 GB at 0.92; 2× H200 TP2 leaves only ≈ 26 GB (§2).
  - Flags: `--tensor-parallel-size 4 --tool-call-parser openai --enable-auto-tool-choice --reasoning-parser openai_gptoss`, same Apptainer wrapper with `--gpus=4`.
  - Smoke-test first (§4b).
  - Costs 4× the CU of the MXFP4 option.
- **Not suitable for BF16:** RTX Pro 6000 ×4 (PCIe, not recommended by VACC), A100 (too small), H100 ×4 (restricted, ≈ 61 GB KV).

## Open questions

- **Host NVIDIA driver version** (CUDA 13 image needs R580+ or compat mode): vacchelp@uvm.edu, or `nvidia-smi` in a GPU job.
- **Outbound internet from compute nodes** (decides whether harmony/HF files must be staged): vacchelp@uvm.edu.
- **Per-job `/dev/shm` and `/tmp` size limits** (matters for TP>1): vacchelp@uvm.edu.
- **Exposing a job's TCP port to the Flask host, and persistent service beyond 48 h** (`week` GPUs, reservations, Secure Cluster Proxmox): vacchelp@uvm.edu; see [../vacc/serving-an-llm.md](../vacc/serving-an-llm.md).
- **Is gpt-oss-120b in `/gpfs1/llm`?** (only Llama-family listed): vacchelp@uvm.edu or the Sharing LLMs process.
- **Throughput cost of LoRA-forced Marlin vs Triton MoE on H200**: measure with `vllm bench serve` (§7).
- **Accuracy of BF16-trained adapters over the MXFP4 base** vs merged BF16 or QAT-MXFP4: measure with the gpt-oss eval harness.
- **Online `--quantization mxfp4` on a BF16 gpt-oss checkpoint**: undocumented; test it.
- **`config.json` after `merge_and_unload()` + `save_pretrained`**: if `quantization_config` remains, vLLM may misload; inspect the artifact.
- **SM120 attention backend** (FlashInfer sinks vs Triton) in v0.33.0: confirm by running; see [#30135](https://github.com/vllm-project/vllm/issues/30135).
- **First release containing [PR #65825](https://github.com/vllm-project/vllm/pull/65825)** (LoRA at TP 4/8; expected v0.34.x [INFERENCE]).
