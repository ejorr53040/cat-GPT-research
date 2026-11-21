#!/bin/bash
# gpt-oss-20b in llama.cpp on the RTX 3070: MoE weights of the first 12 of 24 layers stay in RAM (~6.9 GB VRAM, ~31 tok/s)
exec ~/src/llama.cpp/build/bin/llama-server -m /gpfs1/pi/catgpt/models/gpt-oss-20b-GGUF/gpt-oss-20b-MXFP4.gguf \
  --n-cpu-moe 12 -ngl 99 -c 16384 --host 127.0.0.1 --port 8081
