#!/bin/bash
SIF=/gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif
rm -f $HOME/vllm-sock/vllm.sock
exec apptainer exec -e --nv --bind /home/gpfs1:/gpfs1 \
  --env HF_HOME=/gpfs1/pi/catgpt/hf --env HF_HUB_OFFLINE=1 \
  --env VLLM_CACHE_ROOT=$HOME/scratch/vllm-cache \
  --env VLLM_API_KEY="$(cat ~/.vllm_key)" \
  $SIF vllm serve Qwen/Qwen3-1.7B \
    --served-model-name qwen3-base \
    --enable-lora --max-loras 1 --max-lora-rank 16 \
    --lora-modules catgpt=/gpfs1/pi/catgpt/adapters/catgpt-lora \
    --max-model-len 8192 --gpu-memory-utilization 0.85 \
    --sse-keep-alive-interval 15 \
    --uds $HOME/vllm-sock/vllm.sock
