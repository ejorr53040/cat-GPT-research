# testbox config files

Copied from `testbox` on 2026-11-20. Install steps and verification are in [../test-box.md](../test-box.md).

| File | Installed at |
| --- | --- |
| [slurm/slurm.conf](slurm/slurm.conf) | `/etc/slurm/slurm.conf` |
| [slurm/gres.conf](slurm/gres.conf) | `/etc/slurm/gres.conf` |
| [slurm/cgroup.conf](slurm/cgroup.conf) | `/etc/slurm/cgroup.conf` |
| [nginx/catgpt.conf](nginx/catgpt.conf) | `/etc/nginx/conf.d/catgpt.conf` |
| [ssh/00-testbox.conf](ssh/00-testbox.conf) | `/etc/ssh/sshd_config.d/00-testbox.conf` |
| [scripts/serve-qwen.sh](scripts/serve-qwen.sh) | `~/scratch/serve-qwen.sh`: vLLM 0.33.0 in Apptainer, Qwen3-1.7B + `catgpt` LoRA on `~/vllm-sock/vllm.sock` |
| [scripts/serve-gptoss20b.sh](scripts/serve-gptoss20b.sh) | `~/scratch/serve-gptoss20b.sh`: llama-server, gpt-oss-20b on 127.0.0.1:8081 |

The vLLM key is read from `~/.vllm_key` (mode 600) at launch and isn't stored here.
