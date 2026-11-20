# cat-GPT research

Research notes for cat-GPT: a fine-tuned gpt-oss-120b served with vLLM on UVM's VACC, behind a Flask API-key gateway.

**Live notes (Excalidraw):** https://excalidraw.com/#room=e502e9292837b1627005,gKfhUyEqcwbmAt0t8KvyLw

The part after the comma in that link is the room's encryption key. Anyone with the full link can view and edit the board, so keep this repo private.

## Contents

| Folder | Covers |
| --- | --- |
| [gpt-oss-deployment/](gpt-oss-deployment/README.md) | The deployment plan: vLLM + gpt-oss-120b sizing, the Flask gateway and its security, the architecture diagram ([architecture.excalidraw](gpt-oss-deployment/architecture.excalidraw), generated from [architecture.mmd](gpt-oss-deployment/architecture.mmd)), and the local RTX 3070 test box ([test-box.md](gpt-oss-deployment/test-box.md)) |
| [vacc/](vacc/README.md) | VACC: hardware, access and tiers, Slurm partitions, software, storage, and policy for serving an LLM |
| [slurm/](slurm/README.md) | General Slurm reference pinned to 25.11.2 (VACC's version): commands, job scripts, GPUs, scheduling, accounting |

Start with [gpt-oss-deployment/README.md](gpt-oss-deployment/README.md).
