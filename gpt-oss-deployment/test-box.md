# Local test box for the cat-GPT deployment (RTX 3070 8 GB / i9-10900K / 64 GB)

Compiled 2026-11-20. Versions, package names and commands below were checked that day against primary sources: vendor docs, the Rocky/EPEL/NVIDIA/nginx package repositories, PyPI, Docker Hub, the Hugging Face API, GitHub release assets, and the earlier notes in this folder. Claims are cited inline. "(my arithmetic)" marks derived numbers. `[INFERENCE]` marks conclusions no source states. **Uncertain**, **Conflict** and **Not checked** mark doubtful points.

**None of these commands has been run on the box yet.** Every component has a **Verify** step. Don't start the next component until the current one passes.

## Purpose

The plan in [README.md](README.md) serves gpt-oss-120b with vLLM in Apptainer on VACC (RHEL 9.6, Slurm, no Docker), behind nginx, gunicorn and Flask. This box is a small copy of that stack. It is for testing everything except the real model at real scale.

| Can test here | Cannot test here |
| --- | --- |
| Flask gateway: HMAC keys, allowlist, quotas, metering, SSE through gunicorn and nginx | gpt-oss-120b itself: 65.25 GB of MXFP4 weights ([vllm-gpt-oss-120b.md §1](vllm-gpt-oss-120b.md#1-model-facts)) against 8 GB of VRAM |
| `vllm serve` flags: `--uds`, `--api-key`, `--enable-lora`/`--lora-modules`, `--sse-keep-alive-interval`, under Apptainer `--nv -e` | gpt-oss-20b in vLLM: its safetensors total 13.76 GB (HF API, 2026-11-20), which is more than 8 GB |
| LoRA on Ampere. vLLM selects Marlin for MXFP4 MoE on Ampere ([vllm-gpt-oss-120b.md §3](vllm-gpt-oss-120b.md#3-hardware-and-kernel-support-in-vllm)), but a stand-in model tests only the LoRA plumbing, not that kernel | H200 throughput, Marlin vs Triton comparisons, BF16 vs MXFP4 eval scores ([README.md, Things to measure](README.md#things-to-measure-once-a-job-runs)) |
| Harmony format, reasoning effort and `include_reasoning` on a real gpt-oss model (20b in llama.cpp, with MoE weights offloaded to RAM) | VACC networking, 48 h walltime enforcement in production, `/dev/shm` limits ([README.md, Blocking unknowns](README.md#blocking-unknowns-send-before-building)) |
| sbatch scripts, 48 h relay jobs, requeue on a single-node Slurm | |
| `ssh -L` tunnel from a TCP port to a vLLM Unix socket | |

## As built (2026-11-20)

Facts read off the box itself, which override any assumption above.

- **GPU: RTX 3070 (LHR), 8 GB**, not the RTX 3080 originally assumed. PCI ID `10DE:2488`, sm_86. Everything in this note still applies, with 8 GB of VRAM instead of 10 GB.
- **OS:** Rocky Linux 9.9 (Blue Onyx), kernel 5.14.0-741.22.1.el9_9. SELinux enforcing, cgroup v2, Secure Boot **disabled** (so the §0 signing question does not arise). Hostname `testbox`.
- **FIPS was on after install.** It made sshd refuse ed25519 keys and offer no ed25519 host key. It was turned off with `sudo fips-mode-setup --disable` and a reboot. Check: `cat /proc/sys/crypto/fips_enabled` → `0`, `update-crypto-policies --show` → `DEFAULT`.
- **Network:** Wi-Fi only (`wlp2s0`). The Minimal install leaves Wi-Fi "unmanaged" because it omits the Wi-Fi plugin. The fix is to install four RPMs from the install USB, mounted by label (`/dev/disk/by-label/Rocky-9-9-x86_64-dvd`), with `rpm -Uvh`: `NetworkManager-wifi`, `wpa_supplicant`, `wireless-regdb` and `iw`. The campus LAN address changes and is unreliable, so reach the box over **Tailscale** (`testbox`, 100.87.154.14).
- **SSH from the laptop:** use the ECDSA key `~/.ssh/id_ecdsa_testbox` through the `Host testbox` entry in `~/.ssh/config`. The host key is ECDSA `SHA256:aRXOFCMvFfCOYBEzShttuGNpd5X3dyyDnI3oL4WuI4E`.
- **Disks:**
  - NVMe (Samsung 970 EVO 1 TB) on LVM: `/` is **70 GB**, `/home` is 829 GB, swap is 31 GB. Because `/` is small, the VACC tree lives at `/home/gpfs1`, with `/gpfs1` as a symlink to it.
  - The Seagate ST4000DM004 4 TB (serial ZTT46PCX) is XFS, labelled `bulk`, mounted at `/bulk` by UUID with `nofail`.
  - **Device names change between boots.** The Seagate was `sdb` before one reboot and `sda` after it. Always address disks by `/dev/disk/by-id/…` and re-check model and serial before writing to one.
- **sudo:** a temporary `/etc/sudoers.d/90-setup` (NOPASSWD for ejorr) is in place during setup. **Delete it when setup is done.**

## Versions checked on 2026-11-20

| Component | Pin on this box | Why this version | Source |
| --- | --- | --- | --- |
| OS | Rocky Linux 9 (repo tree is at 9.9) | RHEL 9 rebuild, the same family as VACC's RHEL 9.6 ([../vacc/software.md](../vacc/software.md)) | [dl.rockylinux.org/pub/rocky/](https://dl.rockylinux.org/pub/rocky/) |
| NVIDIA driver | open kernel modules from the NVIDIA rhel9 repo, **≥ 580** (repo tops out at 620.70.06) | vLLM 0.33.0 images are CUDA 13 only and need R580+ ([README.md](README.md) decision 4). The box's GPU is PCI ID 10DE:2488, "GeForce RTX 3070 Lite Hash Rate" in the PCI ID database. The 620.73.04 open-module README lists device 2488 as "NVIDIA GeForce RTX 3070" | [CUDA rhel9 repo](https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/); [open-gpu-kernel-modules 620.73.04 README](https://github.com/NVIDIA/open-gpu-kernel-modules/blob/620.73.04/README.md) |
| CUDA toolkit (llama.cpp build only) | `cuda-toolkit-13-5` | CUDA 13 dropped only pre-Turing GPUs (Maxwell, Pascal, Volta). The 3070 (GA104) is Ampere, sm_86 | [CUDA release notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html) |
| Apptainer | **1.3.4** (GitHub RPM) | Matches VACC ([../vacc/software.md](../vacc/software.md)). EPEL 9 metadata showed `1.6.0~rc.2` on 2026-11-20, so don't take it from EPEL | [v1.3.4 release assets](https://github.com/apptainer/apptainer/releases/tag/v1.3.4); [EPEL mdapi](https://mdapi.fedoraproject.org/epel9/pkg/apptainer) |
| vLLM image | `vllm/vllm-openai:v0.33.0` | Same as the plan. **New:** vLLM **0.34.0** is now on PyPI and postdates the notes in this folder. Re-check the advisories before changing the pin | [Docker Hub tag](https://hub.docker.com/r/vllm/vllm-openai/tags); [PyPI](https://pypi.org/project/vllm/) |
| Slurm | **25.11.2**, built from source as RPMs | Matches VACC ([../vacc/hardware.md](../vacc/hardware.md)). EPEL 9 ships only 22.05.11. The newest 25.11 patch is 25.11.9 | [download.schedmd.com/slurm](https://download.schedmd.com/slurm/); [EPEL mdapi](https://mdapi.fedoraproject.org/epel9/pkg/slurm) |
| Python | Miniforge **25.11.0-1**, with envs on Python 3.12 | VACC's module is `miniforge/25.11.0-py3.12` ([../vacc/software.md](../vacc/software.md)) | [Miniforge release](https://github.com/conda-forge/miniforge/releases/tag/25.11.0-1) |
| Gateway libs | Flask 3.1.3, gunicorn 27.0.1, httpx 0.28.1, Flask-Limiter 4.1.1, openai 3.50.0 | Versions from [flask-gateway-and-security.md](flask-gateway-and-security.md). All still on PyPI. openai is now at 3.57.0 | PyPI JSON API |
| nginx | nginx.org **mainline** repo (1.31.9 current) | Rocky AppStream tops out at 1.26.3, older than the 1.29.7 that defaults `proxy_http_version` to 1.1 ([flask-gateway-and-security.md §5](flask-gateway-and-security.md#5-streaming-sse-through-flask)) | [nginx linux packages](https://nginx.org/en/linux_packages.html); Rocky AppStream listing |
| Rate-limit store | `valkey` 8.1 (Rocky AppStream). `redis` 6.2 is also there | Flask-Limiter's `memory://` store is dev-only ([flask-gateway-and-security.md](flask-gateway-and-security.md)) | Rocky AppStream listing |
| Stand-in models | `Qwen/Qwen3-1.7B` (vLLM, LoRA ✅ in vLLM's model table). `ggml-org/gpt-oss-20b-GGUF`, `gpt-oss-20b-MXFP4.gguf` (12.11 GB) for llama.cpp | Small enough for 8 GB. 1.7 B × 2 B ≈ 3.4 GB of BF16 weights (my arithmetic) | [vLLM supported models v0.33.0](https://docs.vllm.ai/en/v0.33.0/models/supported_models/); HF API |

## 0. OS: Rocky Linux 9

**Why:** VACC runs RHEL 9.6. Rocky shares its packages, SELinux policy, glibc and dnf, so a script that works here is likely to work on VACC `[INFERENCE]`.

**Install**
1. Download the Rocky 9 **Minimal** ISO from [rockylinux.org/download](https://rockylinux.org/download) and write it to USB.
2. Install with the "Minimal Install" environment, a hostname of `testbox`, your user in `wheel`, and the whole NVMe for the root filesystem. The vLLM image (about 10.9 GB compressed, per [vllm-gpt-oss-120b.md §6](vllm-gpt-oss-120b.md#6-running-under-apptainer-on-slurm-no-docker)), its SIF and the model caches take tens of GB.
3. **Uncertain:** with Secure Boot on, DKMS-built NVIDIA modules must be signed and the key enrolled. Turning Secure Boot off in firmware is the simple path for a test box. **Not checked** against NVIDIA's guide.
4. After first boot:
   ```bash
   sudo dnf -y update
   sudo dnf -y install dnf-plugins-core python3-dnf-plugin-versionlock
   sudo dnf config-manager --set-enabled crb          # EPEL needs CRB on Rocky
   sudo dnf -y install epel-release
   sudo dnf -y groupinstall "Development Tools"
   sudo dnf -y install git git-lfs tmux htop nvtop curl wget openssl
   sudo reboot
   ```
   Sources: CRB + `epel-release` from [EPEL getting started](https://docs.fedoraproject.org/en-US/epel/getting-started/). `git-lfs`, `tmux` and `python3-dnf-plugin-versionlock` are in Rocky BaseOS/AppStream. `nvtop` 3.3.2 is in EPEL 9.

**Verify**
```bash
cat /etc/rocky-release                 # Rocky Linux release 9.x
getenforce                             # Enforcing (keep it; VACC is RHEL)
dnf repolist | grep -Ei 'crb|epel'     # both listed
stat -fc %T /sys/fs/cgroup             # cgroup2fs (Slurm's cgroup/v2 needs it)
```

## 1. Remote access: SSH and Tailscale

**Install**
```bash
# SSH: copy your key from the main machine first:  ssh-copy-id you@testbox
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Tailscale (repo file checked: pkgs.tailscale.com/stable/rhel/9/tailscale.repo)
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo
sudo dnf -y install tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up

# Firewall (firewalld is on by default on Rocky)
sudo firewall-cmd --permanent --add-service=ssh --add-service=https
sudo firewall-cmd --reload
```
**Not checked:** the Tailscale install commands come from memory of Tailscale's docs. Only the repo file was fetched.

**Verify**
```bash
ssh -o PasswordAuthentication=yes -o PubkeyAuthentication=no you@testbox   # from main machine: must be refused
tailscale status                       # testbox listed, "online"
sudo firewall-cmd --list-services      # includes ssh https
```

## 2. NVIDIA driver (open kernel modules, headless)

**Why:** this provides `--nv` in Apptainer. The CUDA 13 vLLM image needs R580 or newer.

**Install** (from [NVIDIA Driver Installation Guide 620, RHEL](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/latest/red-hat-enterprise-linux.html). The guide's `subscription-manager` steps are RHEL-only. On Rocky, the CRB and EPEL steps in §0 replace them.)
```bash
sudo dnf -y install kernel-devel-matched kernel-headers
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
sudo dnf clean expire-cache
sudo dnf -y module enable nvidia-driver:open-dkms      # or pin a branch stream, e.g. 580-open
sudo dnf -y install nvidia-driver-cuda kmod-nvidia-open-dkms   # "Compute-only (headless)" set
sudo reboot
```
- The open kernel modules support this card: the 620.73.04 README lists device 2488 (RTX 3070).
- To stop `dnf update` from jumping driver branches, see the guide's [version-locking](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/latest/version-locking.html) chapter. **Not checked** in detail.

**Verify**
```bash
nvidia-smi                       # shows "NVIDIA GeForce RTX 3070", Driver Version >= 580, CUDA Version 13.x
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
lsmod | grep nvidia              # nvidia, nvidia_uvm loaded
```

## 3. Apptainer 1.3.4 (VACC's version)

**Why:** VACC has no Docker. vLLM runs as `apptainer exec -e --nv <sif> vllm serve …` ([vllm-gpt-oss-120b.md §6](vllm-gpt-oss-120b.md#6-running-under-apptainer-on-slurm-no-docker)).

**Install** (method from the [Apptainer 1.3 admin install guide](https://apptainer.org/docs/admin/1.3/installation.html), which shows the GitHub-RPM form for 1.3.6. The 1.3.4 assets exist on the [v1.3.4 release](https://github.com/apptainer/apptainer/releases/tag/v1.3.4).)
```bash
sudo dnf -y install https://github.com/apptainer/apptainer/releases/download/v1.3.4/apptainer-1.3.4-1.x86_64.rpm
sudo dnf versionlock add apptainer          # keep EPEL's 1.6.x from replacing it
```
- `apptainer-suid` is optional. Rocky 9 allows unprivileged user namespaces, so skip it unless a non-suid run fails `[INFERENCE]`.

**Verify**
```bash
apptainer --version                         # apptainer version 1.3.4-1...
dnf versionlock list | grep apptainer
apptainer exec docker://rockylinux:9 cat /etc/rocky-release   # pulls and runs as your user
```

## 4. VACC-style directories and the vLLM SIF

**Why:** the sbatch sketch in [vllm-gpt-oss-120b.md §8](vllm-gpt-oss-120b.md#i-lora-fine-tune--base-mxfp4--adapter) hard-codes `/gpfs1/pi/<PI>/...` and `$HOME/scratch/...`. Using the same paths here lets the scripts run unchanged.

**Install**
```bash
sudo mkdir -p /gpfs1/pi/catgpt && sudo chown $USER: /gpfs1/pi/catgpt
mkdir -p /gpfs1/pi/catgpt/{containers,hf,tiktoken,models,adapters}
mkdir -p ~/scratch/{apptainer-cache,vllm-cache}
echo 'export APPTAINER_CACHEDIR=$HOME/scratch/apptainer-cache' >> ~/.bashrc
source ~/.bashrc
apptainer pull /gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif docker://vllm/vllm-openai:v0.33.0
```

**Verify**
```bash
ls -lh /gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif
apptainer exec -e --nv /gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif nvidia-smi -L     # GPU 0: NVIDIA GeForce RTX 3070
apptainer exec -e --nv /gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif vllm --version    # 0.33.0
apptainer exec -e --nv /gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif \
  python3 -c "import torch;print(torch.cuda.is_available(), torch.cuda.get_device_capability())"  # True (8, 6)
```
If `nvidia-smi` works on the host but fails inside the container, the host driver is too old for the image's CUDA 13 ([vllm-gpt-oss-120b.md §6](vllm-gpt-oss-120b.md#gpu-access)).

## 5. Python: Miniforge 25.11.0-1

**Why:** VACC replaced Anaconda with Miniforge, and the `defaults` channel is not allowed ([../vacc/software.md](../vacc/software.md)).

**Install** (non-interactive `-b` flag from the [Miniforge README](https://github.com/conda-forge/miniforge))
```bash
curl -LO https://github.com/conda-forge/miniforge/releases/download/25.11.0-1/Miniforge3-25.11.0-1-Linux-x86_64.sh
curl -LO https://github.com/conda-forge/miniforge/releases/download/25.11.0-1/Miniforge3-25.11.0-1-Linux-x86_64.sh.sha256
sha256sum -c Miniforge3-25.11.0-1-Linux-x86_64.sh.sha256
bash Miniforge3-25.11.0-1-Linux-x86_64.sh -b -p ~/miniforge3
~/miniforge3/bin/conda init bash && exec bash

# Gateway env: versions from flask-gateway-and-security.md
conda create -y -n gateway python=3.12
conda activate gateway
pip install flask==3.1.3 gunicorn==27.0.1 httpx==0.28.1 Flask-Limiter==4.1.1 openai==3.50.0 \
            redis pytest ruff pre-commit

# Tools env: build the stand-in LoRA, harmony and evals
conda create -y -n tools python=3.12
conda activate tools
pip install torch transformers peft huggingface_hub openai-harmony gpt-oss
```
**Not checked:** whether the `gpt-oss` PyPI package (0.0.9) installs cleanly without a GPU build toolchain. If it fails, use only `openai-harmony`.

**Verify**
```bash
conda run -n gateway python -c "import flask,gunicorn,httpx,flask_limiter,openai;print(flask.__version__,gunicorn.__version__,httpx.__version__,openai.__version__)"
# 3.1.3 27.0.1 0.28.1 3.50.0
conda config --show channels        # conda-forge only, no 'defaults'
```

## 6. Stand-in model and LoRA under vLLM

**Why:** this exercises the exact production command shape on 8 GB: `--enable-lora --lora-modules catgpt=…`, `--uds` in a 0700 directory, `--api-key` as a gateway secret, and SSE keep-alives ([README.md](README.md) decisions 2–3).

**Install**
```bash
conda activate tools
export HF_HOME=/gpfs1/pi/catgpt/hf
hf download Qwen/Qwen3-1.7B           # older huggingface_hub: huggingface-cli download
python - <<'EOF'
# Zero-effect LoRA: peft's default init sets the B matrices to zero, so outputs equal the base model.
from transformers import AutoModelForCausalLM
from peft import LoraConfig, get_peft_model
m = AutoModelForCausalLM.from_pretrained("Qwen/Qwen3-1.7B", torch_dtype="auto")
p = get_peft_model(m, LoraConfig(r=16, lora_alpha=32, target_modules=["q_proj","v_proj"], task_type="CAUSAL_LM"))
p.save_pretrained("/gpfs1/pi/catgpt/adapters/catgpt-lora")
EOF
python -c "import secrets;print(secrets.token_urlsafe(32))" > ~/.vllm_key && chmod 600 ~/.vllm_key
mkdir -p ~/vllm-sock && chmod 700 ~/vllm-sock
```
- **Not checked:** I didn't re-read the peft source line that sets the default zero init. It is standard LoRA behaviour.
- The adapter only tests the plumbing. Train a real tiny adapter later if output differences need checking.

**Run** (interactively first, then as an sbatch job after §8)
```bash
SIF=/gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif
apptainer exec -e --nv \
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
```
- The gpt-oss-only flags in the VACC sketch (`--reasoning-parser openai_gptoss`, `--tool-call-parser openai`) are left out because they don't apply to Qwen3 `[INFERENCE]`.
- **Uncertain:** whether `-e` keeps `$HOME` mounted for `--uds`. Apptainer binds `$HOME` by default ([vllm-gpt-oss-120b.md §6](vllm-gpt-oss-120b.md#shared-memory-devshm)).

**Verify** (in a second shell)
```bash
K=$(cat ~/.vllm_key); S=$HOME/vllm-sock/vllm.sock
curl -s --unix-socket $S http://x/v1/models                                    # 401: key required
curl -s --unix-socket $S -H "Authorization: Bearer $K" http://x/v1/models      # lists qwen3-base and catgpt
curl -sN --unix-socket $S -H "Authorization: Bearer $K" -H 'Content-Type: application/json' \
  http://x/v1/chat/completions -d '{"model":"catgpt","stream":true,"stream_options":{"include_usage":true},
  "messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}'            # data: chunks, last chunk has "usage"
ss -ltnp | grep 8000                                                           # nothing: --uds means no TCP listener
curl -s --unix-socket $S http://x/metrics | head -3                            # README decision 2: non-/v1 paths are NOT key-protected
```
The last check should succeed without the key. That confirms why vLLM must never be exposed directly.

## 7. gpt-oss-20b in llama.cpp (harmony format on a real gpt-oss model)

**Why:** vLLM can't fit gpt-oss-20b in 8 GB. llama.cpp can keep MoE expert weights in system RAM (`--cpu-moe`, `--n-cpu-moe N`) ([llama-server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)). VACC also has a `llama.cpp/b9077-cuda` module ([../vacc/software.md](../vacc/software.md)).

**Install** (build from [llama.cpp docs/build.md, CUDA](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#cuda))
```bash
sudo dnf -y install cuda-toolkit-13-5 cmake libcurl-devel
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
git clone https://github.com/ggml-org/llama.cpp ~/src/llama.cpp && cd ~/src/llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86
cmake --build build --config Release -j 20
```
**Run**
```bash
~/src/llama.cpp/build/bin/llama-server -hf ggml-org/gpt-oss-20b-GGUF \
  --cpu-moe -ngl 99 -c 16384 --host 127.0.0.1 --port 8081
```
- gpt-oss-20b has 24 layers and 32 experts (HF `config.json`).
- `--cpu-moe` keeps all expert weights in RAM. Once that works, switch to `--n-cpu-moe N` and lower N until VRAM is nearly full.
- Jinja chat templates are on by default.
- **Not checked:** whether the `-hf` download selects `gpt-oss-20b-MXFP4.gguf` automatically when the repo also contains `eagle3-*` files. If it doesn't, download that file and pass `-m`.

**Verify**
```bash
nvidia-smi --query-gpu=memory.used --format=csv     # under 8 GB
curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"system","content":"Reasoning: low"},{"role":"user","content":"2+2?"}]}' | python -m json.tool
# expect a final answer; check whether reasoning comes back in a separate field (reasoning_content) or inline
```

## 8. Slurm 25.11.2, single node

**Why:** this tests the sbatch scripts, `--time=48:00:00`, the relay pattern `--dependency=after:<id>+2820` ([README.md](README.md) decision 5) and requeue, before spending VACC CU.

**Install**
- Build steps are from [Slurm quickstart_admin](https://slurm.schedmd.com/quickstart_admin.html).
- Package roles: `slurm`, `slurm-perlapi`, `slurm-slurmctld` and `slurm-slurmd` (same page, "Installing Packages").
- The cgroup/v2 plugin needs hwloc, bpf and dbus (same page). `AutoDetect=nvidia` needs no extra libraries (since 24.11).
- `munge` is in AppStream, and `munge-devel` is in CRB.
```bash
sudo dnf -y install rpm-build munge munge-devel pam-devel readline-devel hwloc-devel dbus-devel \
                    libbpf-devel lua-devel perl-ExtUtils-MakeMaker python3 json-c-devel
curl -LO https://download.schedmd.com/slurm/slurm-25.11.2.tar.bz2
rpmbuild -ta slurm-25.11.2.tar.bz2              # if it stops on missing BuildRequires, dnf install what it names
cd ~/rpmbuild/RPMS/x86_64
sudo dnf -y install ./slurm-25.11.2*.rpm ./slurm-perlapi-25.11.2*.rpm \
                    ./slurm-slurmctld-25.11.2*.rpm ./slurm-slurmd-25.11.2*.rpm
sudo dnf versionlock add 'slurm*'

# MUNGE: the Rocky munge 0.5.13 RPM ships /usr/sbin/create-munge-key
sudo /usr/sbin/create-munge-key
sudo systemctl enable --now munge

# SlurmUser and its directories must exist before the daemons start (quickstart_admin)
sudo useradd -r -s /sbin/nologin slurm
sudo mkdir -p /var/spool/slurmctld /var/spool/slurmd /var/log/slurm
sudo chown slurm: /var/spool/slurmctld /var/log/slurm
slurmd -C                                         # prints this machine's NodeName line; paste it below
```

Configuration sketch. **Not run.** Compare it against the [configurator](https://slurm.schedmd.com/configurator.html).

`/etc/slurm/slurm.conf`:
```
ClusterName=testbox
SlurmctldHost=testbox
SlurmUser=slurm
AuthType=auth/munge
StateSaveLocation=/var/spool/slurmctld
SlurmdSpoolDir=/var/spool/slurmd
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log
SelectType=select/cons_tres
ProctrackType=proctrack/cgroup
TaskPlugin=task/cgroup,task/affinity
GresTypes=gpu
# Paste the line from `slurmd -C` and add Gres/Features. 10900K = 10 cores / 20 threads.
NodeName=testbox CPUs=20 Boards=1 SocketsPerBoard=1 CoresPerSocket=10 ThreadsPerCore=2 RealMemory=60000 Gres=gpu:1 Features=GPU_SKU:RTX3070
PartitionName=nvgpu Nodes=testbox Default=YES MaxTime=2-00:00:00 State=UP
```
`/etc/slurm/gres.conf`: `AutoDetect=nvidia`
`/etc/slurm/cgroup.conf`: `ConstrainDevices=yes`

```bash
sudo systemctl enable --now slurmctld slurmd
```
- `MaxTime=2-00:00:00` reproduces VACC's 48 h `nvgpu` cap.
- VACC scripts use `--constraint=GPU_SKU:H200`. Override it here on the command line with `sbatch --constraint=GPU_SKU:RTX3070 job.sh`, since command-line options take precedence over `#SBATCH` lines.

**Verify**
```bash
munge -n | unmunge | grep STATUS           # Success (0)
sinfo                                      # nvgpu up, testbox idle
scontrol show node testbox | grep -i gres  # Gres=gpu:1
srun --gpus=1 nvidia-smi -L                # GPU 0: NVIDIA GeForce RTX 3070
srun --gpus=1 env | grep CUDA_VISIBLE      # CUDA_VISIBLE_DEVICES=0
sbatch --time=49:00:00 --wrap 'true'       # must be rejected/pending for exceeding MaxTime
# Relay test with minutes instead of hours:
J1=$(sbatch --parsable --time=5 --gpus=1 --wrap 'sleep 280')
J2=$(sbatch --parsable --time=5 --gpus=1 --dependency=after:$J1+3 --wrap 'sleep 60')
squeue                                     # J2 pending on (Dependency), and with one GPU it can't overlap J1
```
**Note:** the overlap that relay jobs rely on on VACC needs a second free GPU. On a one-GPU box, J2 waits for J1 to finish. Test the dependency logic here, not the overlap `[INFERENCE]`.

## 9. Gateway host side: valkey, nginx, gunicorn

**Why:** this is the campus-host half of [architecture.mmd](architecture.mmd).

**Install**
```bash
# Rate-limit store
sudo dnf -y install valkey && sudo systemctl enable --now valkey

# nginx mainline (repo text from nginx.org/en/linux_packages.html, "RHEL and derivatives")
sudo tee /etc/yum.repos.d/nginx.repo >/dev/null <<'EOF'
[nginx-stable]
name=nginx stable repo
baseurl=https://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=https://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
sudo dnf config-manager --set-enabled nginx-mainline
sudo dnf -y install nginx      # accept key only if fingerprint is 573B FD6B 3D8F BC64 1079 A6AB ABF5 BD82 7BD9 BF62

# Self-signed TLS for testing
sudo mkdir -p /etc/nginx/tls
sudo openssl req -x509 -newkey rsa:3072 -nodes -days 365 -subj "/CN=testbox" \
  -keyout /etc/nginx/tls/testbox.key -out /etc/nginx/tls/testbox.crt

# SELinux: let nginx connect to gunicorn on 127.0.0.1:8080
sudo setsebool -P httpd_can_network_connect 1
sudo systemctl enable --now nginx
```
- **Not checked:** the SELinux boolean name comes from standard RHEL policy and wasn't re-fetched.
- The nginx and gunicorn settings to apply are in [flask-gateway-and-security.md §5](flask-gateway-and-security.md#5-streaming-sse-through-flask): `proxy_buffering`/`X-Accel-Buffering: no`, `proxy_read_timeout`, `limit_req`, `client_max_body_size`, and gunicorn `-k gthread --threads N -b 127.0.0.1:8080`.

**Tunnel, as in production:** gateway → `127.0.0.1:18000` → `ssh -L` → vLLM's Unix socket. Here the SSH hop is localhost instead of `login.vacc.uvm.edu`. The OpenSSH `-L port:remote_socket` form forwards to a Unix socket ([ssh(1)](https://man.openbsd.org/ssh.1)).
```bash
ssh -N -L 127.0.0.1:18000:$HOME/vllm-sock/vllm.sock localhost
```

**Verify**
```bash
nginx -v                                   # nginx/1.29.7 or newer (mainline)
valkey-cli ping                            # PONG
getsebool httpd_can_network_connect        # on
curl -s -H "Authorization: Bearer $(cat ~/.vllm_key)" http://127.0.0.1:18000/v1/models   # via tunnel: lists catgpt
# After the Flask app exists, end to end:
curl -skN https://testbox/v1/chat/completions -H "Authorization: Bearer <user key>" \
  -H 'Content-Type: application/json' -d '{"model":"catgpt","stream":true,"messages":[{"role":"user","content":"hi"}]}'
# tokens arrive incrementally (not in one burst); a bad key gets 401 from Flask; /metrics via nginx is 404
```

## 10. Order and done-criteria

1. §0 → §1 → §2. Stop if `nvidia-smi` doesn't show driver ≥ 580.
2. §3 → §4. Stop if `vllm --version` or the CUDA check inside the SIF fails.
3. §5 → §6. This is the first real milestone: `catgpt` streams through `--uds` with usage counted.
4. §9: the gateway, nginx and the tunnel, end to end.
5. §8: Slurm. Then rerun §6 as an sbatch job based on the VACC sketch.
6. §7: llama.cpp gpt-oss-20b, any time after §2.

## Open questions

1. Secure Boot and DKMS signing on Rocky 9 (§0). Disabling it is the fallback.
2. Whether vLLM 0.34.0 fixes the LoRA-at-TP>2 bug (PR #65825 in [README.md](README.md)) and has new advisories. Re-check before changing the pin.
3. Whether `--uds` paths under `$HOME` behave the same on VACC compute nodes. This depends on the `ssh` into a job's node question in [README.md, Blocking unknowns](README.md#blocking-unknowns-send-before-building).
4. The OS of the real gateway host (Silk vs an ETS research VM) is unknown, so §9 may need changes there.
