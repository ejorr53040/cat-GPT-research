# Serving a fine-tuned gpt-oss-120b with vLLM on VACC

Compiled 2026-11-13 from primary sources only: OpenAI's model card and repos, the Hugging Face model repo, vLLM docs, vLLM source and GitHub issues, the vLLM recipes site, NVIDIA's Model-Optimizer repo, and the Apptainer and Hugging Face Hub docs. Everything was accessed on **2026-11-13**. Claims are cited inline. "(my arithmetic)" marks numbers I derived, and "[INFERENCE]" marks conclusions I drew from code or docs that no source states outright. VACC facts come from the earlier notes in [../vacc/](../vacc/README.md) and are not re-researched here.

## Versions this note applies to

- **vLLM v0.33.0** is the latest release. It was published 2026-11-02. The GitHub API lists it under the tag string `v0.33.0rc3`, but the release is named `v0.33.0` and a `v0.33.0` git tag exists ([release](https://github.com/vllm-project/vllm/releases/tag/v0.33.0)). The Docker Hub tags `vllm/vllm-openai:v0.33.0` and `:latest` were both pushed 2026-11-02 ([Docker Hub](https://hub.docker.com/r/vllm/vllm-openai/tags)).
- **v0.33.0 drops CUDA 12.9.** "release wheels and images are CUDA 13.0 only. The CUDA 12.9 wheels and the `-cu129` / `-cu129-ubuntu2404` images are no longer published" ([v0.33.0 notes](https://github.com/vllm-project/vllm/releases/tag/v0.33.0)). v0.32.0 (2026-10-18) still ships `vllm/vllm-openai:v0.32.0-cu129` alongside a CUDA 13.0 default ([v0.32.0 notes](https://github.com/vllm-project/vllm/releases/tag/v0.32.0)).
- Source-code statements were read at the `v0.32.0` tag, and the parts that matter were re-checked at `v0.33.0`. Each citation says which tag it refers to.
- **Two gpt-oss recipe pages exist, and they differ.**
  - The Markdown recipe at [docs.vllm.ai/projects/recipes … GPT-OSS](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) now says it is "kept as a historical reference". The page footer dates it May 10, 2026.
  - The current recipe is [recipes.vllm.ai/openai/gpt-oss-120b](https://recipes.vllm.ai/openai/gpt-oss-120b). Its JSON gives `date_updated: 2026-09-22` and `min_vllm_version: 0.10.1`, and is generated from `recipes/models/openai/gpt-oss-120b.yaml` in the vLLM repo ([JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json)).

## 1. Model facts

| Item | Value | Source |
| --- | --- | --- |
| Total / active params | 116.83 B total, 5.13 B active per token. Of these, MLP 114.71 B, attention 0.96 B, embed+unembed 1.16 B | [Model card, Table 1](https://arxiv.org/abs/2508.10925) |
| Architecture | 36 layers, residual dim 2880, MoE with 128 experts and top-4 routing, SwiGLU with clamping. Attention alternates between a 128-token banded window and dense layers. 64 query heads of dim 64, GQA with 8 KV heads, learned attention sinks | [Model card §2.2](https://arxiv.org/abs/2508.10925); [config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json) |
| Context length | 131,072 tokens via YaRN (`max_position_embeddings: 131072`, `initial_context_length: 4096`, rope factor 32) | [Model card §2.2](https://arxiv.org/abs/2508.10925); [config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json) |
| Quantization | MoE weights are post-trained in **MXFP4** at 4.25 bits/param. Attention, router, embeddings and `lm_head` stay BF16 (`modules_to_not_convert`). "All evals were performed with the same MXFP4 quantization" | [Model card §2.1](https://arxiv.org/abs/2508.10925); [config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json); [HF card](https://huggingface.co/openai/gpt-oss-120b) |
| Checkpoint size | 60.8 GiB per the model card. The HF repo's 15 top-level `model-*.safetensors` files total **65,248,893,184 bytes ≈ 65.25 GB**, which is 60.8 GiB (my arithmetic). The whole repo is **195.8 GB**, because it also holds `original/` (65.25 GB) and `metal/model.bin` (65.24 GB). vLLM needs only the top-level files | [Model card](https://arxiv.org/abs/2508.10925); [HF file list](https://huggingface.co/openai/gpt-oss-120b/tree/main) (sizes from the HF API) |
| Tokenizer | `o200k_harmony`, 201,088 tokens | [Model card §2.3](https://arxiv.org/abs/2508.10925) |
| License | "Apache 2.0 license and our gpt-oss usage policy" ([model card §1](https://arxiv.org/abs/2508.10925)). The repo's `USAGE_POLICY` file reads in full: "We aim for our tools to be used safely, responsibly, and democratically, while maximizing your control over how you use them. By using OpenAI gpt-oss-120b, you agree to comply with all applicable law." | [USAGE_POLICY](https://huggingface.co/openai/gpt-oss-120b/blob/main/USAGE_POLICY) |
| Response format | The models were trained on the **harmony** format and "should only be used with the harmony format as it will not work correctly otherwise". Channels are `analysis` (chain of thought), `commentary` (tool calls) and `final` (answer). Role priority is System > Developer > User > Assistant > Tool. Reasoning traces from past assistant turns should be dropped in multi-turn use | [HF card](https://huggingface.co/openai/gpt-oss-120b); [Model card §2.5.1](https://arxiv.org/abs/2508.10925); [openai/harmony](https://github.com/openai/harmony) |
| Reasoning effort | low, medium or high, set in the system prompt (e.g. "Reasoning: high"). The harmony library defaults to `ReasoningEffort.MEDIUM` | [Model card §2.5.2](https://arxiv.org/abs/2508.10925); [harmony `__init__.py`](https://github.com/openai/harmony/blob/main/python/openai_harmony/__init__.py) |
| Tool use | Trained with a browsing tool, a stateful Python (Jupyter) tool, and developer-defined functions declared in the Developer message. Can interleave CoT and tool calls. Supports Structured Outputs | [Model card §1, §2.5.3](https://arxiv.org/abs/2508.10925) |
| Chain of thought | Fully exposed, but "not intended to be shown to end users" | [HF card](https://huggingface.co/openai/gpt-oss-120b) |
| Fine-tuning | "can be fine-tuned on a single H100 node" | [HF card](https://huggingface.co/openai/gpt-oss-120b) |

## 2. Memory sizing

### What the sources say

- OpenAI says gpt-oss-120b "fit[s] into a single 80GB GPU (like NVIDIA H100 or AMD MI300X)" ([HF card](https://huggingface.co/openai/gpt-oss-120b)). The archived OpenAI cookbook says "Best with ≥60GB VRAM" ([cookbook: run-vllm](https://developers.openai.com/cookbook/articles/gpt-oss/run-vllm), marked "archived and may reference outdated models or APIs"). The vLLM launch blog says 63 GB on disk and that a single GPU is "often not recommended for the best performance" ([vLLM blog, 2025-08-05](https://vllm.ai/blog/2025-08-05-gpt-oss)).
- **Known H100 limit (vLLM recipe, undated within the page, page last edited 2026-05-10):** "On H100 using tensor parallel size 1, default gpu memory utilization, and batched token will cause CUDA Out-of-memory." The fix given is `--gpu-memory-utilization 0.95 --max-num-batched-tokens 1024`. Also: "When running TP2 on H100, set your gpu memory utilization below 0.95" ([recipe, Known Limitations](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- **Conflict within the current recipe JSON:** the `default` variant says `vram_minimum_gb: 96` but also "fits on 1xA100 80GB" ([recipe JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json)).
- In v0.33.0 the default `gpu_memory_utilization` is **0.92** ([`config/cache.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/cache.py)).
- vLLM's hybrid KV-cache manager covers gpt-oss's sliding-window + full-attention mix. Sliding-window layers "reserve slots only for the most recent `sliding_window_size` tokens" ([hybrid KV cache manager design, v0.33.0](https://docs.vllm.ai/en/v0.33.0/design/hybrid_kv_cache_manager/); [vLLM blog](https://vllm.ai/blog/2025-08-05-gpt-oss)).

### KV cache per token (my arithmetic from config.json)

- Each layer stores K+V: 2 × 8 KV heads × 64 dims × 2 bytes (BF16) = 2,048 B per token.
- Only the **18 full-attention layers** grow with context: 18 × 2,048 = **36,864 B/token (36 KiB)**. The 18 sliding-window layers hold at most about 128 tokens plus one block per sequence, roughly 5 MB per sequence, which is negligible.
- A full 131,072-token sequence therefore needs about **4.83 GB** of KV with a BF16 KV cache, and about 2.42 GB with `--kv-cache-dtype fp8`.
- With TP=N, each GPU holds 1/N of the KV heads, so the per-GPU cost per token falls by N while total capacity (below) stays the same.

### Sizing table (my arithmetic)

Method: KV budget = utilisation × vendor capacity × GPUs − weights.

- **The budget is an upper bound.** Activation workspace and CUDA-graph memory come out of it as well, and no source quantifies them for gpt-oss.
- Vendor capacities are decimal GB: H200 141 GB, H100 80 GB, RTX Pro 6000 96 GB, A100 40 GB ([../vacc/hardware.md](../vacc/hardware.md)).
- The usable memory vLLM reports at startup will differ.
- Weights:
  - MXFP4 = 65.25 GB (HF file sizes).
  - Merged BF16 = 116.83 B × 2 B = **233.7 GB**. That agrees exactly with a published BF16 conversion, [`unsloth/gpt-oss-120b-BF16`](https://huggingface.co/unsloth/gpt-oss-120b-BF16), whose safetensors total 233,658,385,752 bytes.
- "Full-ctx seqs" means how many simultaneous 131k-token sequences fit with a BF16 KV cache.

| Checkpoint | GPUs (TP) | Weights per GPU | KV budget @0.92 | Tokens of KV @0.92 | Full-ctx seqs | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| MXFP4 | 1× H200 | 65.2 GB | 64.5 GB | ~1.75 M | ~13 | **Fits comfortably.** The vLLM recipe's default for H200 is TP1 |
| MXFP4 | 2× H200 (TP2) | 32.6 GB | 194.2 GB | ~5.27 M | ~40 | Lower latency, more KV |
| MXFP4 | 1× H100 80 GB | 65.2 GB | 8.4 GB (10.8 @0.95) | ~0.23 M (0.29 M) | ~1.7 (2.2) | **Marginal.** Recipe documents OOM at defaults |
| MXFP4 | 2× H100 (TP2) | 32.6 GB | 82.0 GB | ~2.22 M | ~17 | OK. Keep util < 0.95 (recipe) |
| MXFP4 | 1× RTX Pro 6000 96 GB | 65.2 GB | 23.1 GB | ~0.63 M | ~4.8 | Fits. Kernel caveats in §3 |
| MXFP4 | 2× RTX Pro 6000 (TP2) | 32.6 GB | 111.4 GB | ~3.02 M | ~23 | PCIe only. VACC calls RTX 6000 multi-GPU "not recommended" ([../vacc/hardware.md](../vacc/hardware.md#gpu-inventory-as-vacc-documents-it)) |
| MXFP4 | 1× A100 40 GB | 65.2 GB | — | — | — | **Does not fit** |
| MXFP4 | 2× A100 40 GB (TP2) | 32.6 GB | 8.4 GB total | ~0.23 M | ~1.7 | Marginal. PCIe Gen4, which VACC calls not recommended for multi-GPU. Only 2 A100s per node |
| BF16 merged | 2× H200 (TP2) | 116.8 GB | 25.8 GB | ~0.70 M | ~5 | Tight but possible |
| BF16 merged | **4× H200 (TP4)** | 58.4 GB | 285.2 GB | ~7.74 M | ~59 | **Recommended minimum for BF16.** One full H200 NVL node, or half an SXM node |
| BF16 merged | 8× H200 SXM (TP8) | 29.2 GB | 804 GB | ~21.8 M | ~166 | Whole SXM node |
| BF16 merged | 4× H100 (TP4) | 58.4 GB | 60.7 GB | ~1.65 M | ~12.6 | Possible. H100 access may be restricted (see §8) |
| BF16 merged | 4× RTX Pro 6000 (TP4) | 58.4 GB | 119.6 GB | ~3.24 M | ~25 | PCIe only, not recommended by VACC |

- Valid TP sizes are 1, 2, 4 or 8, because there are 64 query heads and 8 KV heads ([config.json](https://huggingface.co/openai/gpt-oss-120b/blob/main/config.json)) [INFERENCE: vLLM shards heads evenly].
- `GptOssForCausalLM` also supports pipeline parallelism ([supported models, v0.33.0](https://docs.vllm.ai/en/v0.33.0/models/supported_models/)).
- **LoRA adds GPU memory.** In v0.33.0 each MoE layer allocates stacked expert LoRA buffers sized `max_loras × experts × max_lora_rank × (hidden + 2·intermediate + intermediate + hidden)` ([`lora/layers/fused_moe.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/lora/layers/fused_moe.py)). For gpt-oss-120b at TP1 that is about **132.7 MB per rank per adapter slot** (my arithmetic: 128 × 14,400 × 36 layers × 2 B). That works out to:
  - rank 16: ≈2.1 GB
  - rank 32: ≈4.2 GB
  - rank 64: ≈8.5 GB

  This is per `--max-loras` slot, before the attention-layer LoRA. On a single H100 that buffer alone uses up the KV headroom.

## 3. Hardware and kernel support in vLLM

### Official statements

- vLLM's recipe (page edited 2026-05-10) says: "you can run it on NVIDIA H100, H200, B200 as well as MI300x, MI325x, MI355x and Radeon AI PRO R9700. We are actively working on ensuring this model can work on Ampere, Ada Lovelace, and RTX 5090" ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- The current recipe marks h100, h200, b200, mi300x, mi325x, mi355x, ironwood and arc_pro_b70 as "verified". **No RTX Pro 6000 / SM120 entry exists** ([recipe JSON, 2026-09-22](https://recipes.vllm.ai/openai/gpt-oss-120b.json)).
- **Ampere conflict.** The same recipe page says "GPT-OSS works on Ampere devices by default, using the `TRITON_ATTN` attention backend and Marlin MXFP4 MoE" ([recipe, A100 section](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). Ampere support landed in v0.10.1 ("[gpt-oss] Enable gpt-oss on ampere", #22714) ([v0.10.1 notes](https://github.com/vllm-project/vllm/releases/tag/v0.10.1)). The "actively working on Ampere" line is **stale**.
- **Launch-time kernels** ([vLLM blog, 2025-08-05](https://vllm.ai/blog/2025-08-05-gpt-oss)):
  - Hopper: OpenAI Triton `matmul_ogs` MoE kernel plus FlashAttention 3 with sink support.
  - Blackwell (B200): FlashInfer MXFP4 MoE plus FlashInfer attention.

### What vLLM v0.32.0/v0.33.0 actually selects (read from source)

**MoE kernel.** `_get_priority_backends_for_gpt_oss()` tries backends in this order ([`fused_moe/oracle/mxfp4.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/model_executor/layers/fused_moe/oracle/mxfp4.py); the list is byte-identical at [v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/layers/fused_moe/oracle/mxfp4.py)):

1. FlashInfer TRT-LLM (SM100 family only)
2. AITER (ROCm)
3. OAI Triton (SM90 ≤ CC < SM130)
4. FlashInfer CUTLASS (the W4A16 MXFP4 scheme on SM90 only)
5. Marlin (CC ≥ 7.5)

On **SM120** the code deliberately moves Triton behind Marlin. The comment reads: "Consumer Blackwell: the OAI Triton kernels run but their 99KB shared memory budget caps them at small tiles, so MARLIN prefills ~10% faster at equal decode throughput. Keep TRITON as an opt-in."

**Attention.** vLLM picks the first backend that supports sinks:

- On non-SM100 CUDA the priority is FLASH_ATTN, then FLASHINFER, then TRITON_ATTN ([`platforms/cuda.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/platforms/cuda.py)).
- FLASH_ATTN supports sinks only on FA3 or FA4. FA3 is chosen only for CC 9.x, and FA4 only for CC 10.x. Everything else falls back to FA2 ([`fa_utils.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/v1/attention/backends/fa_utils.py)).
- TRITON_ATTN always supports sinks ([`triton_attn.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/v1/attention/backends/triton_attn.py)).

| VACC GPU | CC | MoE kernel (default, no LoRA) | Attention | Status / evidence |
| --- | --- | --- | --- | --- |
| H200 NVL / SXM | 9.0 | OAI Triton `matmul_ogs` (MXFP4 W4A16) | FlashAttention 3 with sinks | **Verified** in the recipe. Use `GPT-OSS_Hopper.yaml`-style flags |
| H100 | 9.0 | Same as H200 | FA3 | **Verified** in the recipe. Memory-tight at TP1 |
| RTX Pro 6000 Blackwell | **12.0** | **Marlin** (MXFP4 weight-only, BF16 activations). Triton is opt-in via `--moe-backend triton`. FlashInfer TRT-LLM is SM100-only. The SM120 `b12x` MoE rejects expert biases ("kernel does not support expert biases", [`b12x.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/layers/fused_moe/b12x.py)), and gpt-oss has them | TRITON_ATTN. FlashInfer sinks on SM120 depend on a TRT-LLM attention check ([`flashinfer.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/v1/attention/backends/flashinfer.py)) | **Runs, but not in the verified list. Expect lower throughput** than SM100's native-FP4 path. Evidence below |
| A100 40 GB | 8.0 | Marlin | TRITON_ATTN | Supported since v0.10.1, but the model **does not fit** one 40 GB card (§2) |

**RTX Pro 6000 (SM120) evidence:**

- [Issue #30135](https://github.com/vllm-project/vllm/issues/30135) (open, filed 2025-12-05): "MXFP4 models still fall back to the Marlin kernel for RTX PRO 6000".
- A March 2026 log there and in [PR #31089](https://github.com/vllm-project/vllm/pull/31089) shows `Using TRITON_ATTN attention backend` and `Using Marlin backend` on an RTX PRO 6000.
- A vLLM maintainer (mgoin, 2026-03-09) said the "no native FP4" warning "isn't actually something to be concerned about since GPT-OSS is already a weight-only checkpoint i.e. MXFP4 W4A16". He closed PR #31089 (SM120 Triton MXFP4) because "this kernel seems slower than Marlin on SM120".
- [Issue #34817](https://github.com/vllm-project/vllm/issues/34817) (gpt-oss-120b on an RTX PRO 6000 Server Edition) was auto-closed as stale with no fix.
- [Issue #23497](https://github.com/vllm-project/vllm/issues/23497) (open) holds community configs that run gpt-oss-120b on RTX Pro 6000 with `--kv-cache-dtype fp8`.
- **Uncertain:** whether the recipe's Blackwell flags (`--quantization-config.moe.activation mxfp8`, FlashInfer MXFP4×MXFP8) apply to SM120. The code gates FlashInfer TRT-LLM MXFP4 to `is_device_capability_family(100)` ([`trtllm_mxfp4_moe.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/model_executor/layers/fused_moe/experts/trtllm_mxfp4_moe.py)), so on SM120 they should not select it [INFERENCE]. **Do not copy the B200 recipe to the RTX Pro 6000.**

**Blackwell recipe flags, for reference.** "On vLLM v0.28.0+ the FlashInfer TRTLLM MXFP4 MoE path is selected automatically on Blackwell; it can be pinned explicitly with `--moe-backend flashinfer_trtllm --quantization-config.moe.activation mxfp8`" ([recipe JSON guide](https://recipes.vllm.ai/openai/gpt-oss-120b.json)). This is B200 / SM100, which VACC does not have.

**Driver requirement.** "CUDA 13 requires an R580 or newer driver". The vLLM image ships CUDA forward-compatibility libraries, enabled with `VLLM_ENABLE_CUDA_COMPATIBILITY=1`, that support R535/R570 hosts on "select professional and datacenter NVIDIA GPUs" ([GPU install docs, v0.33.0](https://docs.vllm.ai/en/v0.33.0/getting_started/installation/gpu/)). The v0.33.0 image is built `FROM nvidia/cuda:13.0.3-base-ubuntu24.04` ([Dockerfile @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docker/Dockerfile)). VACC's host driver version is **not found** in the prior notes. VACC does offer a `cuda/13.0.2` module ([../vacc/software.md](../vacc/software.md)), which suggests an R580+ driver [INFERENCE].

## 4. Fine-tunes: what they produce and how vLLM serves them

### What the official fine-tuning guides produce

- **OpenAI cookbook / Hugging Face TRL guide** ([cookbook: fine-tune-transfomers](https://developers.openai.com/cookbook/articles/gpt-oss/fine-tune-transfomers); written for gpt-oss-20b on one H100):
  - Load with `Mxfp4Config(dequantize=True)` and `torch_dtype=torch.bfloat16`, which **dequantizes the MXFP4 experts to BF16**.
  - Apply PEFT LoRA with `target_modules="all-linear"` plus `target_parameters=[...mlp.experts.gate_up_proj, ...mlp.experts.down_proj]` for selected layers. Example: `r=8`, `lora_alpha=16`.
  - Train with TRL `SFTTrainer` (`trl>=0.20.0`, `peft>=0.17.0`, `transformers>=4.55.0`).
  - Output is a **PEFT LoRA adapter**. For inference the guide loads the base, applies the adapter, and calls `merge_and_unload()`, which yields a merged model in the base's loaded dtype. It never re-quantizes to MXFP4.
- **HF `gpt-oss-recipes`** `sft.py` supports both "full-parameter training and LoRA training". Full-parameter runs use `accelerate` + ZeRO-3 "on one node of 8 GPUs", and LoRA runs on one GPU ([huggingface/gpt-oss-recipes](https://github.com/huggingface/gpt-oss-recipes)). A full fine-tune produces a **BF16 checkpoint** of about 233.7 GB (§2).
- **NVIDIA Model-Optimizer** ([examples/gpt-oss README](https://github.com/NVIDIA/Model-Optimizer/blob/main/examples/gpt-oss/README.md), commit `85fa6e2`, 2026-10-26):
  - "Dequantizing the MXFP4 models to BF16 and performing BF16 training is a viable option. However this results in a BF16 weights model which is about 4x of the original model size. … MXFP4 Post Training Quantization (PTQ) … degrades the finetuned model accuracy."
  - Its fix is **QAT** (`mtq.MXFP4_MLP_WEIGHT_ONLY_CFG` / recipe `general/ptq/mxfp4_mlp_weight_only`), followed by `convert_oai_mxfp4_weight_only.py`, which "transforms a Hugging Face–compatible BF16 checkpoint into the same MXFP4 weight-only format used by the original GPT-OSS release". The script can also merge a LoRA-QAT adapter (`--lora_path … --base_path openai/gpt-oss-120b`).
  - "Using one node with 8 x 80 GB GPUs, you could perform QAT with LoRA on GPT OSS 120B model." The README's vLLM deployment step is just `vllm serve <model_path>`.

### (a) Serving LoRA adapters directly (`--enable-lora`)

- **Supported.** `GptOssForCausalLM` is marked LoRA ✅ ([supported models, v0.33.0](https://docs.vllm.ai/en/v0.33.0/models/supported_models/)). The class implements `SupportsLoRA` with `is_3d_moe_weight = True` ([`gpt_oss.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/models/gpt_oss.py)), so it accepts PEFT `target_parameters`-style fused 3D expert adapters (`...experts.gate_up_proj.lora_A.weight`) ([LoRA docs, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/lora/)). Support came from the work tracked in [issue #23610](https://github.com/vllm-project/vllm/issues/23610), closed 2025-10-21.
- **LoRA forces the Marlin MoE kernel** [INFERENCE from source]:
  - With LoRA enabled, kernels that lack `supports_lora()` are rejected ([`modular_kernel.py` @v0.32.0](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/model_executor/layers/fused_moe/modular_kernel.py)), and monolithic kernels are refused ("Monolithic kernels are not supported for Fused MoE LoRA", [`lora/layers/fused_moe.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/lora/layers/fused_moe.py)).
  - Of the default-priority MXFP4 kernels, only `MarlinExperts` mixes in `LoRAExpertsMixin`. The OAI Triton, FlashInfer TRT-LLM and FlashInfer CUTLASS experts do not ([`marlin_moe.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/layers/fused_moe/experts/marlin_moe.py)).
  - On H200, a LoRA deployment therefore gives up the Hopper Triton MoE kernel. The throughput cost is **not published**.
- **Known bug at TP 4/8 — avoid it.** [PR #65825](https://github.com/vllm-project/vllm/pull/65825), merged **2026-11-05** (after v0.33.0), fixes "GPT-OSS MXFP4 expert LoRA sharding under tensor parallelism … mismatched intermediate-channel slices at TP=4/8 for both 2D and 3D expert LoRA". The fixed line is absent from `v0.33.0`'s `lora/layers/fused_moe.py` (checked).
  - For gpt-oss (intermediate 2880 = 90 MXFP4 blocks), TP2 gives 1440 = 1440, so it is unaffected. TP4 gives 736 vs 720 and TP8 gives 384 vs 360, both wrong (my arithmetic).
  - **Use TP1 or TP2 for LoRA on ≤ v0.33.0.**
- **Other recent LoRA fixes for gpt-oss.** [Issue #60811](https://github.com/vllm-project/vllm/issues/60811) (closed 2026-10-10) fixed silently wrong outputs with `--enable-mixed-moe-lora-format`. The default 3D path "does not have this particular mismatch". [PR #65108](https://github.com/vllm-project/vllm/pull/65108) (open) affects only the ROCm `triton_kernels` 3.8 path. Taken together, gpt-oss MoE LoRA is new and still being fixed. **Validate outputs against the merged model before production.**
- **Defaults and flags.** `max_lora_rank` defaults to 16 and accepts {1, 8, 16, 32, 64, 128, 256, 320, 512}. `max_loras` defaults to 1 ([`config/lora.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/lora.py)). Adapters load at start with `--lora-modules name=path`, or at runtime via `/v1/load_lora_adapter` when `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True` ([LoRA docs](https://docs.vllm.ai/en/v0.33.0/features/lora/)). The adapter is then addressed by its `name` in the request's `model` field.
- **Base precision.** The adapter was trained against BF16-dequantized experts but is served over the MXFP4 base. Whether that mismatch costs accuracy is **not quantified** by any source found. ModelOpt's QAT is the documented way to avoid it.

### (b) Serving a merged BF16 checkpoint

- vLLM has a non-MXFP4 weight path for gpt-oss (`_load_weights_other`, with `.gate_up_proj` / `.down_proj` mapped to unquantized `w13_weight` / `w2_weight`) ([`gpt_oss.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/models/gpt_oss.py)). I found no recipe or test that serves gpt-oss-120b in BF16, so treat this as **Uncertain until smoke-tested**.
- **Size and GPUs:** about 233.7 GB, so at least 2× H200 and in practice 4× H200 at TP4 (§2).
- **Uncertain:** after `Mxfp4Config(dequantize=True)` + `merge_and_unload()` + `save_pretrained`, check that the saved `config.json` no longer declares `quantization_config.quant_method: mxfp4`. vLLM picks the loader from that field ([`gpt_oss.py` `load_weights`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/model_executor/models/gpt_oss.py)). I did not find a source that says what transformers writes there.
- **Option to shrink it at load time (Uncertain for gpt-oss):** vLLM online quantization can quantize MoE weights of a BF16 checkpoint to MXFP4 at load, e.g. `--quantization mxfp4 --quantization-config '{"linear":{"activation":null,"weight":null}}'` ([online quantization, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/quantization/online/)). The docs show this only for Llama/Qwen. It is untested for gpt-oss's biased, clamped SwiGLU experts. It is also PTQ, which ModelOpt says "degrades the finetuned model accuracy".

### (c) Re-quantized MXFP4 checkpoint

- ModelOpt's `convert_oai_mxfp4_weight_only.py` produces "the same MXFP4 weight-only format used by the original GPT-OSS release", which "can be deployed to supported runtimes just like the original GPT-OSS MXFP4 models" ([Model-Optimizer README](https://github.com/NVIDIA/Model-Optimizer/blob/main/examples/gpt-oss/README.md)).
- It keeps the 65 GB footprint, the 1× H200 TP1 layout, and the fast Hopper Triton MoE kernel.
- Two costs: an extra QAT stage (recommended learning rate 1e-5, "a few million to billion tokens"), and a dependency on NVIDIA tooling.

### Tradeoffs

| Path | Serving GPUs (H200) | MoE kernel on H200 | Accuracy risk | Ops notes |
| --- | --- | --- | --- | --- |
| (a) Base MXFP4 + LoRA adapter | 1 (TP1) or 2 (TP2) | Marlin (forced) | Adapter trained on BF16, served on MXFP4. New code with recent bugfixes | Smallest artifact. Several adapters can share one base. TP4/8 LoRA broken ≤ v0.33.0 |
| (a′) Merge LoRA → BF16 | 4 (TP4) | Unquantized path | Lowest (matches training precision) | 234 GB on disk and in VRAM |
| (b) Full FT → BF16 | 4 (TP4), or 8 | Unquantized path | Lowest | 234 GB. BF16 serving of gpt-oss-120b is not a published vLLM recipe |
| (c) LoRA/full FT → QAT → MXFP4 | 1 (TP1) | OAI Triton (default Hopper) | QAT recovers PTQ loss per NVIDIA. Must evaluate | Best serving efficiency. Extra training step |

## 5. Serving with `vllm serve`

### Commands from the recipes

- Current recipe for H200 ([recipe JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json), 2026-09-22):
  ```bash
  vllm serve openai/gpt-oss-120b \
    --tensor-parallel-size 1 \
    --tool-call-parser openai \
    --enable-auto-tool-choice
  ```
- The H100 entry shows `--tensor-parallel-size 8`. That reflects the strategy rule "TP size is set to the GPU count at deploy time" on an 8-GPU H100 profile, not a minimum ([recipe JSON](https://recipes.vllm.ai/openai/gpt-oss-120b.json)).
- The legacy recipe's Hopper config file `GPT-OSS_Hopper.yaml` ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)):
  ```yaml
  no-enable-prefix-caching: true   # "recommend always adding this flag if running with synthetic dataset" — for benchmarking
  max-cudagraph-capture-size: 2048
  max-num-batched-tokens: 8192
  stream-interval: 20
  ```
  `stream-interval 20` maximises throughput, but it makes streaming arrive in 20-token chunks ([recipe, Configs and Parameters](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). For an interactive chat frontend, leave it at the default of 1 ([`config/scheduler.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/scheduler.py)) [INFERENCE: a UX tradeoff].
- **Throughput vs latency** ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)): TP1 gives "the best throughput per GPU", and TP 2/4/8 give "better per-user latencies". The B200 suggestions are max throughput at TP1 with maximum BS, min latency at TP 4–8 with BS ≈ 8, and balanced at TP2 with BS 128.

### Key flags (vLLM v0.33.0)

| Flag | Meaning / default | Source |
| --- | --- | --- |
| `--tensor-parallel-size N` | GPUs per replica. 1, 2, 4 or 8 for this model | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--max-model-len` | Defaults to the model maximum (131,072). Lowering it "may improve the performance" | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--gpu-memory-utilization` | Default **0.92** in v0.33.0 | [`config/cache.py`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/cache.py) |
| `--async-scheduling` | **On by default** unless something is incompatible (`async_scheduling=None` means auto-enable). `--no-async-scheduling` turns it off. Passing the flag explicitly is harmless | [`config/vllm.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/vllm.py); [`config/scheduler.py`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/config/scheduler.py) |
| `--max-num-seqs`, `--max-num-batched-tokens` | Batch size and per-step token budget. The recipe recommends 8192 | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--kv-cache-dtype fp8` | In the Blackwell config only, not the Hopper config | [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--served-model-name` | The name clients put in `model`. With LoRA, adapters are addressed by their `--lora-modules` name | [LoRA docs](https://docs.vllm.ai/en/v0.33.0/features/lora/) |
| `--host` / `--port` | `host` defaults to `None`, and the launcher binds `(args.host or "", args.port)`, i.e. **all interfaces**. Default port **8000**. **Conflict:** the legacy recipe says "By default, it uses 127.0.0.1"; the v0.33.0 code says otherwise (checked 2026-11-13). Always pass `--host` or `--uds` | [`entrypoints/common/cli_args.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py); [`launchers/launcher.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/launchers/launcher.py); [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--api-key` / `VLLM_API_KEY` | Bearer token, but it "only authenticates endpoints under the `/v1`, `/v2`, `/inference`, and `/cohere` path prefixes". `/invocations`, `/pause`, `/abort_requests`, `/update_weights`, `/metrics`, `/tokenize` and others stay unauthenticated. "Do not rely exclusively on `--api-key`". The docs recommend a reverse proxy that allowlists endpoints | [security, v0.33.0](https://docs.vllm.ai/en/v0.33.0/usage/security/); [`cli_args.py`](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/common/cli_args.py) |
| `--tool-call-parser openai --enable-auto-tool-choice` | Function calling for gpt-oss. "only tool_choice="auto" is supported" | [tool calling, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/tool_calling/); [recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--reasoning-parser openai_gptoss` | Registered reasoning parser name for gpt-oss. It is missing from the docs' parser table | [`reasoning/__init__.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/reasoning/__init__.py) |
| `--tool-server demo` or `--tool-server host:port,...` | Built-in browser/python tools (Responses API only). `demo` needs `pip install gpt-oss` and either Docker or `PYTHON_EXECUTION_BACKEND=dangerously_use_uv` | [recipe, Tool Use](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html) |
| `--enable-lora --lora-modules n=path --max-lora-rank R --max-loras K` | LoRA serving | [LoRA docs](https://docs.vllm.ai/en/v0.33.0/features/lora/) |

**Parser selection:** in v0.33.0, `ParserManager` returns **no parser** when neither `--tool-call-parser` nor `--reasoning-parser` is set. When either is set for a `gpt_oss` model, it "always" returns `HarmonyParser` ([`parser/parser_manager.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/parser/parser_manager.py); [`chat_completion/serving.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/chat_completion/serving.py)). Pass at least `--tool-call-parser openai` so that reasoning and final text come back as separate fields [INFERENCE].

### Endpoints and how reasoning is exposed

- `/v1/chat/completions` ([recipe, Usage](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)):
  - "No tool will be invoked but reasoning and final text output will be returned structurally."
  - Function calling works. Built-in browser and python tools do not (Harmony support matrix).
  - Reasoning comes back in `message.reasoning`. It was formerly `reasoning_content`, and clients reading the old name "could silently read an empty `reasoning_content`" ([reasoning outputs, v0.33.0](https://docs.vllm.ai/en/v0.33.0/features/reasoning_outputs/)).
- `/v1/responses` is the endpoint "recommended by OpenAI". It supports built-in tools (browsing, python, MCP) and uses `openai-harmony` ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). Its known limits:
  - "Usage accounting is currently broken and only returns all zeros"
  - streaming is "fairly barebone"
  - annotations are unsupported
  - function calling is not supported with streaming

  Usage accounting matters if the Flask app meters per-user tokens.
- `/v1/completions` is raw text in and text out with no template ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). Using it means formatting harmony yourself.
- **Reasoning effort:**
  - Chat Completions takes `reasoning_effort`. vLLM accepts only `high`, `medium` or `low` for harmony and writes it into the harmony system message ([`harmony_utils.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/entrypoints/openai/parser/harmony_utils.py)).
  - The Responses API takes `reasoning.effort` ([reasoning outputs](https://docs.vllm.ai/en/v0.33.0/features/reasoning_outputs/)).
  - When unset, harmony defaults to medium ([harmony](https://github.com/openai/harmony/blob/main/python/openai_harmony/__init__.py)).
- **Hiding the chain of thought:** `include_reasoning: false` works on both APIs, streaming and non-streaming. Reasoning is still generated, and vLLM "also suppresses per-token metadata (logprobs and token IDs) to prevent leaking reasoning content" ([reasoning outputs](https://docs.vllm.ai/en/v0.33.0/features/reasoning_outputs/)). OpenAI says the CoT is "not intended to be shown to end users" ([HF card](https://huggingface.co/openai/gpt-oss-120b)), so the Flask layer should strip `reasoning` or force `include_reasoning=false` [INFERENCE].

## 6. Running under Apptainer on Slurm (no Docker)

### Image

- The official image is `vllm/vllm-openai`. Its entrypoint is `ENTRYPOINT ["vllm", "serve"]`, and it runs as root by default ([Dockerfile @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/docker/Dockerfile); [Docker deployment, v0.33.0](https://docs.vllm.ai/en/v0.33.0/deployment/docker/)).
- Tags: `v0.33.0` (CUDA 13.0 only) and `v0.32.0` / `v0.32.0-cu129`. The `v0.33.0` image is about 10.9 GB on Docker Hub ([Docker Hub](https://hub.docker.com/r/vllm/vllm-openai/tags)).
- `apptainer pull docker://…` "actually runs a apptainer build behind the scenes", stores the result as a SIF, and caches the blobs ([Apptainer 1.3: Docker and OCI](https://apptainer.org/docs/user/1.3/docker_and_oci.html)).
- When a Docker image has only an ENTRYPOINT, Apptainer converts it into the runscript ([same page, "CMD / ENTRYPOINT Behaviour"](https://apptainer.org/docs/user/1.3/docker_and_oci.html)). So `apptainer run img.sif <model> <flags>` is equivalent to `vllm serve <model> <flags>`, and `apptainer exec img.sif vllm serve …` is the explicit form.
- VACC sets `APPTAINER_CACHEDIR` to scratch and recommends `-e` (clean environment) ([../vacc/software.md](../vacc/software.md#containers)).

### GPU access

- `--nv` makes `/dev/nvidiaX` available, binds the host CUDA driver libraries, and sets `LD_LIBRARY_PATH`. The container's application must have been "compiled for a CUDA version, and device capability level, that is supported by the host card and driver" ([Apptainer 1.3: GPU](https://apptainer.org/docs/user/1.3/gpu.html)). For the CUDA 13 image that means an R580+ host driver, or the compat libraries (§3).
- "By default, Apptainer makes all host devices available in the container". To limit which GPUs CUDA sees, use `CUDA_VISIBLE_DEVICES` / `APPTAINERENV_CUDA_VISIBLE_DEVICES` ([Apptainer 1.3: GPU](https://apptainer.org/docs/user/1.3/gpu.html)). Slurm sets `CUDA_VISIBLE_DEVICES` for the job's GPUs ([../slurm/gpus.md](../slurm/gpus.md)), and Apptainer passes the host environment through unless `-e`/`--cleanenv` is used ([Apptainer 1.3: environment](https://apptainer.org/docs/user/1.3/environment_and_metadata.html)). **With VACC's recommended `-e`, pass it explicitly**: `--env CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES` [INFERENCE].

### Shared memory (`/dev/shm`)

- vLLM's Docker docs need `--ipc=host` or `--shm-size` because "vLLM uses PyTorch, which uses shared memory to share data between processes under the hood, particularly for tensor parallel inference" ([GPU install / Docker, v0.33.0](https://docs.vllm.ai/en/v0.33.0/getting_started/installation/gpu/)).
- Apptainer has no such cap. In the default configuration `/dev` (and with it `/dev/shm`), `$HOME`, `/tmp` and `/var/tmp` are bind-mounted from the host ([Apptainer 1.3: bind paths](https://apptainer.org/docs/user/1.3/bind_paths_and_mounts.html)).
- On VACC that host `/dev/shm` is the **per-job private** `/dev/shm`, deleted at job end. Its size limit is **not documented** ([../vacc/storage.md](../vacc/storage.md#filesystems)). TP1 makes little use of cross-process shared memory [INFERENCE]. Ask VACC before relying on TP4/TP8.

### Model weights, caches and offline mode

- `HF_HOME` sets where the Hub cache and token live (default `~/.cache/huggingface`). `HF_HUB_OFFLINE=1` means "no HTTP calls will be made to the Hugging Face Hub … only the cached files will be accessed" ([HF Hub env vars](https://huggingface.co/docs/huggingface_hub/en/package_reference/environment_variables)).
- Pre-download on a login or data-transfer node. Then either point `vllm serve` at a local directory, or set `HF_HOME` to the cache on GPFS and run with `HF_HUB_OFFLINE=1`.
- **Exclude `original/*` and `metal/*`** to save about 130 GB (§1). The safetensors total 65.25 GB, which fits Tier 1 gpfs1 (2 TB soft) ([../vacc/storage.md](../vacc/storage.md#quotas)).
- **Harmony vocab download (gotcha).** `openai-harmony` loads the `o200k` vocab either from `TIKTOKEN_ENCODINGS_BASE` (a local dir) or by downloading `https://openaipublic.blob.core.windows.net/encodings/` into `TIKTOKEN_RS_CACHE_DIR`, which defaults to the OS temp dir (`/tmp/tiktoken-rs-cache`) ([harmony `public_encodings.rs`](https://github.com/openai/harmony/blob/main/src/tiktoken_ext/public_encodings.rs)).
  - On VACC, `/tmp` is per-job and wiped, so every job downloads it again. Without outbound internet, startup fails with `HarmonyError: error downloading or loading vocab file`.
  - vLLM's documented fix is to pre-download `o200k_base.tiktoken` and `cl100k_base.tiktoken` and `export TIKTOKEN_ENCODINGS_BASE=<dir>` ([recipe, Troubleshooting](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- `VLLM_CACHE_ROOT` (default `~/.cache/vllm`) holds `torch.compile` artifacts. Persisting it avoids recompiling on every start ([Docker deployment, v0.33.0](https://docs.vllm.ai/en/v0.33.0/deployment/docker/); [`envs.py` @v0.33.0](https://github.com/vllm-project/vllm/blob/v0.33.0/vllm/envs.py)). Put it on scratch, not `$HOME`.

### Ports and networking

- `--net` "will cause the container to join a new network namespace". For non-privileged users, "none is the only network configuration that can be used", and it "isolates the container network from the host network" ([Apptainer 1.3: networking](https://apptainer.org/docs/user/1.3/networking.html)). So run **without** `--net`; `vllm serve --port P` then listens directly on the compute node's interfaces [INFERENCE from the same page].
- Two jobs on the same node cannot both use 8000, so pick a free port per job.
- Whether the Flask host can reach a compute-node port, and whether VACC allows a long-running service at all, is outside this note (see the VACC policy research and Open questions). If Flask runs elsewhere, bind vLLM to the node's internal interface, not `0.0.0.0`, and keep `--api-key` as a Flask↔vLLM shared secret, not as user credentials ([security](https://docs.vllm.ai/en/v0.33.0/usage/security/)).

## 7. Throughput and latency

- **No official per-GPU numbers found** for gpt-oss-120b in vLLM, OpenAI or recipe sources. The vLLM recipe's sample benchmark output is all placeholders (`xxx.xx`). It gives the method instead: `vllm bench serve --dataset-name random --random-input-len 1024 --random-output-len 1024 --max-concurrency … --num-prompts ≥5×concurrency` ([recipe, Benchmarking](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)).
- **Accuracy reproduced by vLLM** (120B, no tools), GPQA / AIME25: low 65.3 / 51.2, medium 72.4 / 79.6, high 79.4 / 93.0 ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html)). These numbers make a useful regression check for a fine-tune served on VACC.
- **RTX Pro 6000, one contributor-reported number:** at batch 1, MXFP4 Triton gave "160 flow/s" against Marlin's "201 flow/s" with `--max-model-len 131072` at TP1 (units presumably tokens/s; the vLLM build was from about December 2025) ([PR #31089](https://github.com/vllm-project/vllm/pull/31089)). That is one user's test, not a vLLM benchmark.
- OpenAI's model card plots accuracy against average CoT+answer length. Higher reasoning effort means longer outputs, roughly 2k tokens at low to 16k+ at high for AIME ([model card Fig. 3](https://arxiv.org/abs/2508.10925)). That drives latency per request more than the hardware choice [INFERENCE].

## 8. Recommended configurations on VACC

GPU features and partitions are from [../vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#node-constraints---constraint---c):

- Constraints: `GPU_SKU:H200` | `H200_NVL` | `H200_SXM` | `H100` | `RTX6000` | `A100`, `GPU_MEM:140GB`, `GPU_CC:9.0` | `12.0`, `GPU_GEN:HOPPER` | `BLACKWELL`.
- Partitions: `nvgpu` (48 h max) and `week`. GPU availability on `week` is unknown.
- Cost (my arithmetic, using 1 CU = 1 GPU-minute, [../vacc/access.md](../vacc/access.md#allocations-tiers-and-compute-units)): 1 GPU running 24/7 for a year is 525,600 CU, already above Tier 1's 250k. 4 GPUs come to 2.10 M CU (Tier 2), and 8 GPUs to 4.20 M CU (Tier 3).
- **Avoid H100 for this.** The prior notes say the SOCKS-funded H100s (`hgnodes`) are owner-restricted ([../vacc/access.md](../vacc/access.md#allocations-tiers-and-compute-units)), and only 8 exist.

### (i) LoRA fine-tune → base MXFP4 + adapter

- **Hardware:** 1× H200, TP1. Use `--constraint=GPU_SKU:H200` (either form factor) or `GPU_MEM:140GB`. TP2 is the upgrade for latency or more KV. Do not use TP4/TP8 with LoRA on ≤ v0.33.0 (§4a).
- **Fallback hardware:** 1× RTX Pro 6000, `--constraint=GPU_SKU:RTX6000` (or `GPU_CC:12.0`). It works: Marlin MoE + Triton attention, about 0.6 M tokens of KV at 0.92 utilisation. It is not on vLLM's verified list. Keep the rank and `--max-loras` small, because each rank-64 slot costs about 8.5 GB (§2).
- **Image:** `vllm/vllm-openai:v0.33.0`, or a newer release that contains PR #65825 if TP>2 is ever needed.
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
  - `--max-model-len 32768` is a placeholder. Set it to the real input+output limit, because the recipe says shorter is faster.
- **Before going live:**
  - Run the gpt-oss GPQA/AIME eval at low effort against both the adapter and the merged-BF16 model to catch LoRA or kernel mismatches (§4a). The recipe runs it with `python -m gpt_oss.evals`.
  - Also consider path (c): QAT-merge to MXFP4 so the deployment can run without `--enable-lora` on the faster Triton MoE kernel.

### (ii) Full fine-tune → BF16 checkpoint (about 234 GB)

- **Preferred:** convert to MXFP4 with ModelOpt QAT + `convert_oai_mxfp4_weight_only.py` (§4c). Then serve exactly like the base model on **1× H200, TP1** (`GPU_SKU:H200`), with no LoRA flags. The default Hopper Triton MoE kernel and FA3 apply.
- **If kept in BF16:**
  - Hardware: **4× H200, TP4**, on one node. `--gpus=4 --constraint=GPU_SKU:H200_NVL` takes a whole NVL node. `--constraint=GPU_SKU:H200_SXM` takes half an SXM node, with NVSwitch at about 900 GB/s against about 300 GB/s for the NVL bridge per VACC ([../vacc/hardware.md](../vacc/hardware.md#gpu-inventory-as-vacc-documents-it)). For TP4 all-reduce, prefer `H200_SXM` [INFERENCE].
  - KV headroom is about 285 GB at 0.92. 2× H200 TP2 fits only about 26 GB of KV (§2).
  - Flags: `--tensor-parallel-size 4 --tool-call-parser openai --enable-auto-tool-choice --reasoning-parser openai_gptoss`, with the same Apptainer wrapper as above and `--gpus=4`.
  - Smoke-test first, because BF16 gpt-oss-120b is not a published vLLM recipe (§4b).
  - Cost is 4× the CU of the MXFP4 option.
- **Avoid for BF16:** RTX Pro 6000 ×4 (PCIe, not recommended by VACC), A100 (too small), H100 ×4 (restricted, and only about 61 GB of KV).

## Open questions

- **NVIDIA driver version on IceCore nodes.** The CUDA 13.0 image needs R580+, or forward-compatibility mode on R535/R570. Not in VACC docs. Ask vacchelp@uvm.edu, or run `nvidia-smi` in a GPU job.
- **Outbound internet from compute nodes.** This decides whether harmony/HF downloads work in a job or must be staged (`TIKTOKEN_ENCODINGS_BASE`, `HF_HUB_OFFLINE`). vacchelp@uvm.edu.
- **Per-job `/dev/shm` and `/tmp` size limits** (introduced 2026-06-10). Matters for TP>1. vacchelp@uvm.edu.
- **Can a Slurm job expose a TCP port** to the Flask host (and which host is that)? Is there a sanctioned way to run a persistent inference service longer than 48 h (`week` partition GPUs, reservations, the Secure Cluster's Proxmox nodes)? vacchelp@uvm.edu. The VACC service-policy research covers this.
- **Is gpt-oss-120b in `/gpfs1/llm`?** The prior notes list only Llama-family models. vacchelp@uvm.edu, or request it via the Sharing LLMs process.
- **The real throughput cost of LoRA forcing Marlin MoE on H200**, compared with the default Triton kernel. Not published. Measure it with `vllm bench serve` (§7).
- **Accuracy of BF16-trained adapters served over the MXFP4 base**, compared with merged BF16 or QAT-MXFP4. Not quantified by OpenAI, HF, NVIDIA or vLLM sources found. Measure it with the gpt-oss eval harness.
- **Whether vLLM's online `--quantization mxfp4` works on a BF16 gpt-oss checkpoint** (biased, clamped SwiGLU experts). Not documented. Ask on vLLM GitHub or test it.
- **What `config.json` transformers writes** after `Mxfp4Config(dequantize=True)` + `merge_and_unload()` + `save_pretrained`. If `quantization_config` remains, vLLM may misload. Check the artifact; the HF transformers docs/issues would be the owner.
- **SM120 (RTX Pro 6000) is not on vLLM's verified list for gpt-oss.** Whether FlashInfer sink attention activates on SM120 in v0.33.0, or Triton attention is always used, could not be confirmed without running it. vLLM GitHub, issue [#30135](https://github.com/vllm-project/vllm/issues/30135).
- **LoRA at TP 4/8.** Fixed on `main` by [PR #65825](https://github.com/vllm-project/vllm/pull/65825) (2026-11-05). Confirm which release first contains it (expected v0.34.x [INFERENCE]) before using LoRA above TP2.
