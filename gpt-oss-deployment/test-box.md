# Local test box for the cat-GPT deployment (RTX 3070 8 GB / i9-10900K / 64 GB)

Compiled 2026-11-20 from primary sources and from installing every section below on the box (`testbox`). Each command was run there, and each **Verify** block shows the output the box actually produced. Configs and launchers copied from the box are in [test-box-files/](test-box-files/). Markers: "(my arithmetic)" means a derived number; `[INFERENCE]` means a conclusion no source states.

## Purpose

[README.md](README.md) plans to serve gpt-oss-120b with vLLM in Apptainer on VACC (RHEL 9.6, Slurm, no Docker), behind nginx, gunicorn and Flask. This box runs the same stack at small scale.

| Testable here | Not testable here |
| --- | --- |
| Flask gateway: HMAC keys, allowlist, quotas, metering, SSE through gunicorn and nginx | gpt-oss-120b: 65.25 GB of MXFP4 weights ([vllm-gpt-oss-120b.md §1](vllm-gpt-oss-120b.md#1-model-facts)) against 8 GB of VRAM |
| `vllm serve` flags `--uds`, `--api-key`, `--enable-lora`/`--lora-modules` and `--sse-keep-alive-interval`, under Apptainer `--nv -e` | gpt-oss-20b in vLLM: its safetensors total 13.76 GB, more than 8 GB |
| LoRA serving plumbing on Ampere (vLLM uses Marlin for MXFP4 MoE on Ampere, [vllm-gpt-oss-120b.md §3](vllm-gpt-oss-120b.md#3-hardware-and-kernel-support-in-vllm)). A stand-in model doesn't exercise that kernel | H200 throughput, Marlin vs Triton, BF16 vs MXFP4 evals ([README.md](README.md#things-to-measure-once-a-job-runs)) |
| Harmony format and reasoning effort on a real gpt-oss model (20b in llama.cpp, with MoE weights partly in RAM) | VACC networking, production walltime enforcement, `/dev/shm` limits ([README.md](README.md#blocking-unknowns-send-before-building)) |
| sbatch scripts, 48 h `MaxTime`, `--dependency` logic on single-node Slurm. One GPU can't overlap relay jobs | |
| `ssh -L` from a TCP port to vLLM's Unix socket | |

## This box

| Item | Value |
| --- | --- |
| GPU | RTX 3070 (LHR), 8 GB, PCI ID `10DE:2488`, sm_86. The [620.73.04 open-module README](https://github.com/NVIDIA/open-gpu-kernel-modules/blob/620.73.04/README.md) lists device 2488 |
| CPU / RAM | i9-10900K, 10 cores / 20 threads; 62 GiB usable |
| OS | Rocky Linux 9.9, kernel 5.14.0-741.22.1.el9_9; SELinux enforcing; cgroup v2; Secure Boot off |
| Disks | NVMe 1 TB on LVM: `/` 70 GB, `/home` 829 GB, swap 31 GB. Seagate ST4000DM004 4 TB: XFS, label `bulk`, mounted at `/bulk` by UUID with `nofail` |
| VACC-style tree | `/home/gpfs1/pi/catgpt/{containers,hf,tiktoken,models,adapters}`, symlinked from `/gpfs1` (because `/` is only 70 GB) |
| Network | Wi-Fi `wlp2s0` (campus DHCP). Remote access over Tailscale: `testbox`, 100.87.154.14 |
| SSH from the laptop | `ssh testbox`, using the ECDSA key `~/.ssh/id_ecdsa_testbox` through `~/.ssh/config`. The host key is ECDSA `SHA256:aRXOFCMvFfCOYBEzShttuGNpd5X3dyyDnI3oL4WuI4E` |

Disk names (`sda`, `sdb`) swap between boots. Before writing to any disk, address it by `/dev/disk/by-id/…` and check its model and serial.

## Versions

| Component | Version on this box | Reason | Source |
| --- | --- | --- | --- |
| OS | Rocky Linux 9.9 Minimal | RHEL 9 rebuild, the same family as VACC's RHEL 9.6 ([../vacc/software.md](../vacc/software.md)) | [dl.rockylinux.org](https://dl.rockylinux.org/pub/rocky/9/isos/x86_64/) |
| NVIDIA driver | 620.70.06, open kernel modules, CUDA UMD 13.5 | vLLM 0.33.0 images are CUDA 13 only and need R580+ ([README.md](README.md) decision 4) | [NVIDIA rhel9 repo](https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/) |
| CUDA toolkit | 13.5 (used only to build llama.cpp) | CUDA 13 dropped only pre-Turing GPUs | [CUDA release notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html) |
| Apptainer | 1.3.4, version-locked | Matches VACC. EPEL 9 carries a newer 1.6.x | [v1.3.4 release](https://github.com/apptainer/apptainer/releases/tag/v1.3.4) |
| vLLM image | `vllm/vllm-openai:v0.33.0` (8.4 GB SIF; torch 2.14.0+cu130) | Same as the deployment plan. vLLM 0.34.0 exists on PyPI; re-check the advisories before moving to it | [Docker Hub](https://hub.docker.com/r/vllm/vllm-openai/tags) |
| Slurm | 25.11.2, built as RPMs, version-locked | Matches VACC. EPEL 9 ships 22.05.11 | [download.schedmd.com](https://download.schedmd.com/slurm/) |
| Python | Miniforge 25.11.0-1; envs on Python 3.12.16 | VACC module `miniforge/25.11.0-py3.12` | [Miniforge release](https://github.com/conda-forge/miniforge/releases/tag/25.11.0-1) |
| Gateway libs | Flask 3.1.3, gunicorn 27.0.1, httpx 0.28.1, Flask-Limiter 4.1.1, openai 3.50.0 | Pinned in [flask-gateway-and-security.md](flask-gateway-and-security.md) | PyPI |
| Tools env | torch 2.15.0+cu132, transformers 5.23.0, peft 0.22.0, openai-harmony, gpt-oss | Builds the stand-in LoRA; harmony and evals | PyPI |
| nginx | 1.31.9 (nginx.org mainline) | Rocky AppStream stops at 1.26.3. Only 1.29.7+ defaults `proxy_http_version` to 1.1 ([flask-gateway-and-security.md §5](flask-gateway-and-security.md#5-streaming-sse-through-flask)) | [nginx packages](https://nginx.org/en/linux_packages.html) |
| Rate-limit store | valkey 8.1 (Rocky AppStream) | Flask-Limiter's `memory://` store is for development only | Rocky AppStream |
| llama.cpp | git `29b52d398`, CUDA build for sm_86 | gpt-oss-20b with MoE weights partly in RAM | [build.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#cuda) |
| Stand-in models | `Qwen/Qwen3-1.7B` (vLLM); `ggml-org/gpt-oss-20b-GGUF` → `gpt-oss-20b-MXFP4.gguf`, 12,109,566,624 bytes (llama.cpp) | Both fit in 8 GB. vLLM supports LoRA for Qwen3 | [vLLM supported models](https://docs.vllm.ai/en/v0.33.0/models/supported_models/) |

## 0. OS install and base packages

1. Download `Rocky-9.9-…-x86_64-minimal.iso` with its `.CHECKSUM` and `.CHECKSUM.asc`. Verify both:
   ```bash
   sha256sum -c --ignore-missing Rocky-9.9-*-minimal.iso.CHECKSUM      # OK
   gpg --import RPM-GPG-KEY-Rocky-9    # fingerprint 21CB 256A E16F C54C 6E65 2949 702D 426D 350D 275D
   gpg --verify Rocky-9.9-*-minimal.iso.CHECKSUM.asc Rocky-9.9-*-minimal.iso.CHECKSUM   # Good signature
   ```
   Write the ISO to USB with `dd … bs=4M conv=fsync oflag=direct`. Read it back with `head -c <iso bytes> /dev/sdX | sha256sum` and compare with the checksum file.
2. Install with "Minimal Install", hostname `testbox`, and your user marked as administrator (that adds it to `wheel`). Leave the security-profile/FIPS options off. Turn Secure Boot off in firmware so the DKMS-built NVIDIA modules load unsigned.
3. **Wi-Fi on a Minimal install.** The ISO doesn't install the NetworkManager Wi-Fi plugin, so `nmcli device status` shows the card as `unmanaged`. Install the packages from the USB stick. The ISO filesystem has the label `Rocky-9-9-x86_64-dvd`:
   ```bash
   sudo mount -o ro /dev/disk/by-label/Rocky-9-9-x86_64-dvd /mnt
   sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
   sudo rpm -Uvh /mnt/Minimal/Packages/n/NetworkManager-wifi-1.54.4-3.el9.x86_64.rpm /mnt/Minimal/Packages/w/wpa_supplicant-2.11-2.el9.x86_64.rpm /mnt/Minimal/Packages/w/wireless-regdb-2025.10.07-1.el9.noarch.rpm /mnt/Minimal/Packages/i/iw-6.17-1.el9.x86_64.rpm
   sudo systemctl restart NetworkManager
   sudo nmcli --ask device wifi connect "<SSID>"
   ```
   `NetworkManager-wifi` requires `wireless-regdb`, which requires `iw`. Nothing else is missing on a Minimal install.
4. **FIPS.** Check `cat /proc/sys/crypto/fips_enabled`. When it's `1`, sshd refuses ed25519 keys, has no ed25519 host key, and accepts only ECDSA/RSA. Some ML tooling that uses MD5 also breaks. Turn it off:
   ```bash
   sudo fips-mode-setup --disable && sudo reboot
   ```
5. Base packages (CRB + `epel-release` per [EPEL getting started](https://docs.fedoraproject.org/en-US/epel/getting-started/)):
   ```bash
   sudo hostnamectl set-hostname testbox
   sudo dnf -y update
   sudo dnf -y install dnf-plugins-core python3-dnf-plugin-versionlock pciutils
   sudo dnf config-manager --set-enabled crb
   sudo dnf -y install epel-release        # EPEL key FF8A D134 4597 106E CE81 3B91 8A38 72BF 3228 467C
   sudo dnf -y groupinstall "Development Tools"
   sudo dnf -y install git git-lfs tmux htop nvtop curl wget openssl
   ```

**Verify**
```
$ cat /etc/rocky-release; getenforce; stat -fc %T /sys/fs/cgroup; cat /proc/sys/crypto/fips_enabled
Rocky Linux release 9.9 (Blue Onyx)
Enforcing
cgroup2fs
0
$ dnf repolist | grep -Ei 'crb|epel'      # crb, epel listed
$ lspci | grep -i nvidia
01:00.0 VGA compatible controller: NVIDIA Corporation GA104 [GeForce RTX 3070 Lite Hash Rate] (rev a1)
```

## 1. Remote access: Tailscale, SSH, firewall

```bash
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo
sudo dnf -y install tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up --hostname=testbox            # open the printed URL and sign in
sudo systemctl enable --now sshd
```
From the laptop, copy the key over Tailscale with `ssh-copy-id -i ~/.ssh/<key>.pub ejorr@<100.x address>`. Then lock SSH down with [test-box-files/ssh/00-testbox.conf](test-box-files/ssh/00-testbox.conf), which sets `PasswordAuthentication no`, `KbdInteractiveAuthentication no` and `PermitRootLogin no`:
```bash
sudo cp 00-testbox.conf /etc/ssh/sshd_config.d/ && sudo sshd -t && sudo systemctl reload sshd
sudo firewall-cmd --permanent --add-service=ssh --add-service=https --remove-service=cockpit
sudo firewall-cmd --reload
```
The file must sort before Rocky's `01-permitrootlogin.conf`, which sets `PermitRootLogin yes`, because sshd keeps the first value it reads for each option.

**Verify**
```
$ sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
permitrootlogin no
passwordauthentication no
kbdinteractiveauthentication no
$ ssh -o PubkeyAuthentication=no testbox      # from laptop
Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
$ sudo firewall-cmd --list-services
dhcpv6-client https ssh
```

## 2. NVIDIA driver (open kernel modules, headless)

From the [NVIDIA Driver Installation Guide, RHEL](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/latest/red-hat-enterprise-linux.html). On Rocky, §0's CRB/EPEL steps replace the guide's `subscription-manager` lines.
```bash
sudo dnf -y install kernel-devel-matched kernel-headers
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
sudo dnf clean expire-cache
sudo dnf -y module enable nvidia-driver:open-dkms
sudo dnf -y install nvidia-driver-cuda kmod-nvidia-open-dkms   # repo key 610C 7B14 E068 A878 070D A4E9 9CD0 A493 D42D 0685
sudo reboot
```
The package ships `/usr/lib/modprobe.d/nvidia.conf`, which blacklists nouveau.

**Verify**
```
$ sudo dkms status
nvidia/620.70.06, 5.14.0-741.22.1.el9_9.x86_64, x86_64: installed
$ nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv
NVIDIA GeForce RTX 3070, 620.70.06, 8192 MiB, 8.6
$ lsmod | grep -E '^(nvidia|nouveau)'     # nvidia, nvidia_uvm, nvidia_modeset, nvidia_drm; no nouveau
```

## 3. Apptainer 1.3.4

```bash
sudo dnf -y install https://github.com/apptainer/apptainer/releases/download/v1.3.4/apptainer-1.3.4-1.x86_64.rpm
sudo dnf versionlock add apptainer
```
Method from the [Apptainer 1.3 admin guide](https://apptainer.org/docs/admin/1.3/installation.html). `apptainer-suid` isn't needed: Rocky 9 allows unprivileged user namespaces.

**Verify**
```
$ apptainer --version
apptainer version 1.3.4-1
$ apptainer exec docker://rockylinux:9 cat /etc/rocky-release
Rocky Linux release 9.9 (Blue Onyx)
```

## 4. Storage layout and the vLLM SIF

The sbatch sketch in [vllm-gpt-oss-120b.md §8](vllm-gpt-oss-120b.md#i-lora-fine-tune--base-mxfp4--adapter) uses `/gpfs1/pi/<PI>/…` and `$HOME/scratch/…`, and the box uses the same paths. `/` is 70 GB, so the tree lives on `/home`:
```bash
sudo mkdir -p /home/gpfs1/pi/catgpt/{containers,hf,tiktoken,models,adapters}
sudo chown -R $USER: /home/gpfs1 && sudo ln -s /home/gpfs1 /gpfs1
mkdir -p ~/scratch/{apptainer-cache,vllm-cache}
echo 'export APPTAINER_CACHEDIR=$HOME/scratch/apptainer-cache' >> ~/.bashrc && source ~/.bashrc
apptainer pull /gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif docker://vllm/vllm-openai:v0.33.0
```
**Apptainer binds only `$HOME`, not the rest of `/home`.** Inside the container `/gpfs1` doesn't exist, and with `HF_HUB_OFFLINE=1` vLLM fails with `LocalEntryNotFoundError`. Pass `--bind /home/gpfs1:/gpfs1` to every `apptainer exec` that reads from `/gpfs1`.

Bulk disk, addressed by stable ID. The second command checks model and serial before anything is written:
```bash
D=/dev/disk/by-id/ata-ST4000DM004-2CV104_ZTT46PCX
lsblk -dno MODEL,SERIAL $(readlink -f $D)     # must print ST4000DM004-2CV104 ZTT46PCX
sudo wipefs -a $(readlink -f $D) && sudo parted -s $D mklabel gpt mkpart bulk xfs 1MiB 100%
sudo mkfs.xfs -f -L bulk ${D}-part1
echo "UUID=$(sudo blkid -s UUID -o value ${D}-part1) /bulk xfs defaults,nofail 0 0" | sudo tee -a /etc/fstab
sudo mkdir -p /bulk && sudo systemctl daemon-reload && sudo mount /bulk && sudo chown $USER: /bulk
```

**Verify**
```
$ S=/gpfs1/pi/catgpt/containers/vllm-openai_v0.33.0.sif
$ apptainer exec -e --nv $S nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 3070 (UUID: GPU-…)
$ apptainer exec -e --nv $S vllm --version
0.33.0
$ apptainer exec -e --nv $S python3 -c "import torch;print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_capability())"
2.14.0+cu130 True (8, 6)
$ df -h /bulk | tail -1
/dev/sda1       3.7T   26G  3.7T   1% /bulk
```
If `nvidia-smi` works on the host but fails in the container, the host driver is older than the image's CUDA 13 ([vllm-gpt-oss-120b.md §6](vllm-gpt-oss-120b.md#gpu-access)).

## 5. Python: Miniforge 25.11.0-1

VACC uses Miniforge, with conda-forge as the only channel ([../vacc/software.md](../vacc/software.md)).
```bash
B=https://github.com/conda-forge/miniforge/releases/download/25.11.0-1
curl -LO $B/Miniforge3-25.11.0-1-Linux-x86_64.sh && curl -LO $B/Miniforge3-25.11.0-1-Linux-x86_64.sh.sha256
sha256sum -c Miniforge3-25.11.0-1-Linux-x86_64.sh.sha256
bash Miniforge3-25.11.0-1-Linux-x86_64.sh -b -p ~/miniforge3 && ~/miniforge3/bin/conda init bash && exec bash
conda create -y -n gateway python=3.12
conda run -n gateway pip install flask==3.1.3 gunicorn==27.0.1 httpx==0.28.1 Flask-Limiter==4.1.1 openai==3.50.0 redis pytest ruff pre-commit
conda create -y -n tools python=3.12
conda run -n tools pip install torch transformers peft huggingface_hub openai-harmony gpt-oss
```

**Verify**
```
$ conda run -n gateway python -c "import sys,flask,gunicorn,httpx,openai;print(sys.version.split()[0],flask.__version__,gunicorn.__version__,httpx.__version__,openai.__version__)"
3.12.16 3.1.3 27.0.1 0.28.1 3.50.0
$ conda config --show channels
channels:
  - conda-forge
```

## 6. Stand-in model and LoRA under vLLM

This exercises the production command shape: `--enable-lora --lora-modules catgpt=…`, `--uds` in a 0700 directory, `--api-key` as a shared secret between gateway and vLLM, and SSE keep-alives ([README.md](README.md) decisions 2–3).
```bash
conda activate tools
export HF_HOME=/gpfs1/pi/catgpt/hf
hf download Qwen/Qwen3-1.7B
python - <<'EOF'
# peft's default init sets every lora_B to zero, so the adapter's output equals the base model's
from transformers import AutoModelForCausalLM
from peft import LoraConfig, get_peft_model
m = AutoModelForCausalLM.from_pretrained("Qwen/Qwen3-1.7B", dtype="auto")
p = get_peft_model(m, LoraConfig(r=16, lora_alpha=32, target_modules=["q_proj","v_proj"], task_type="CAUSAL_LM"))
p.save_pretrained("/gpfs1/pi/catgpt/adapters/catgpt-lora")
EOF
python -c "import secrets;print(secrets.token_urlsafe(32))" > ~/.vllm_key && chmod 600 ~/.vllm_key
mkdir -p ~/vllm-sock && chmod 700 ~/vllm-sock
tmux new-session -d -s vllm "~/scratch/serve-qwen.sh > ~/scratch/vllm.log 2>&1"
```
The launcher is [test-box-files/scripts/serve-qwen.sh](test-box-files/scripts/serve-qwen.sh). It's the VACC sketch's `vllm serve` with `--bind /home/gpfs1:/gpfs1`, the stand-in model, `--max-lora-rank 16`, `--max-model-len 8192`, `--gpu-memory-utilization 0.85`, `--sse-keep-alive-interval 15` and `--uds`. The gpt-oss parsers (`--reasoning-parser openai_gptoss`, `--tool-call-parser openai`) are dropped because they don't apply to Qwen3.

Startup reports, from `~/scratch/vllm.log`:
- weights + non-torch: 3.5 GiB
- KV cache: 1.72 GiB, which is 16,096 tokens, or 1.96 concurrent 8k requests
- `Loaded new LoRA adapter: name 'catgpt'`

Startup takes about 60 s.

**Stopping vLLM:** killing the tmux session leaves the `VLLM::EngineCore` child running and holding about 6.5 GB of VRAM. It ignores SIGTERM. Check and clear it before starting another GPU job:
```bash
nvidia-smi --query-compute-apps=pid,process_name --format=csv,noheader
kill -KILL <EngineCore pid>
```

**Verify**
```
$ K=$(cat ~/.vllm_key); S=$HOME/vllm-sock/vllm.sock
$ curl -s --unix-socket $S -o /dev/null -w '%{http_code}\n' http://x/v1/models
401
$ curl -s --unix-socket $S -H "Authorization: Bearer $K" http://x/v1/models   # ids: qwen3-base, catgpt
$ curl -sN --unix-socket $S -H "Authorization: Bearer $K" -H 'Content-Type: application/json' http://x/v1/chat/completions \
    -d '{"model":"catgpt","stream":true,"stream_options":{"include_usage":true},"messages":[{"role":"user","content":"Say hi /no_think"}],"max_tokens":32}'
    # 17 data: lines; the last chunk before [DONE] has "usage":{"prompt_tokens":14,"total_tokens":28,"completion_tokens":14}
$ ss -ltn | grep -c ':8000 '
0
$ curl -s --unix-socket $S -o /dev/null -w '%{http_code}\n' http://x/metrics
200
```
`/metrics` answers without the key ([README.md](README.md) decision 2), so vLLM must sit behind the gateway's allowlist.

## 7. gpt-oss-20b in llama.cpp

vLLM can't fit gpt-oss-20b in 8 GB. llama.cpp can keep MoE expert weights in RAM with `--cpu-moe` / `--n-cpu-moe N` ([llama-server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)). The model has 24 layers.
```bash
sudo dnf -y install cuda-toolkit-13-5 cmake libcurl-devel
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
git clone https://github.com/ggml-org/llama.cpp ~/src/llama.cpp && cd ~/src/llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 && cmake --build build --config Release -j 20
conda run -n tools hf download ggml-org/gpt-oss-20b-GGUF gpt-oss-20b-MXFP4.gguf --local-dir /gpfs1/pi/catgpt/models/gpt-oss-20b-GGUF
tmux new-session -d -s llama ~/scratch/serve-gptoss20b.sh      # port 8081
```
The launcher is [test-box-files/scripts/serve-gptoss20b.sh](test-box-files/scripts/serve-gptoss20b.sh) (`--n-cpu-moe 12 -ngl 99 -c 16384`). VRAM and speed by setting, with nothing else on the GPU:

| Setting | VRAM | Decode tok/s |
| --- | --- | --- |
| `--cpu-moe` | 2.1 GB | 18.5 |
| `--n-cpu-moe 16` | 5.3 GB | 25.6 |
| `--n-cpu-moe 12` | 6.9 GB | 31.6 |
| `--n-cpu-moe 8` | does not fit | — |

**Verify**
```
$ curl -s localhost:8081/v1/chat/completions -H 'Content-Type: application/json' \
    -d '{"messages":[{"role":"system","content":"Reasoning: high"},{"role":"user","content":"What is 17*23? Answer with the number only."}]}'
    # message.content "391"; the reasoning is in a separate message.reasoning_content field
```

## 8. Slurm 25.11.2, single node

Build per [Slurm quickstart_admin](https://slurm.schedmd.com/quickstart_admin.html). `slurm.spec` hard-requires `mariadb-devel` even without accounting. The cgroup/v2 plugin needs hwloc, bpf and dbus. `AutoDetect=nvidia` needs no NVML library. SchedMD's download page lists checksums only for current releases, so the 25.11.2 tarball is checked against the GitHub tag instead:
```bash
sudo dnf -y install rpm-build munge munge-devel pam-devel readline-devel hwloc-devel dbus-devel libbpf-devel lua-devel perl-ExtUtils-MakeMaker python3 json-c-devel mariadb-devel
curl -LO https://download.schedmd.com/slurm/slurm-25.11.2.tar.bz2
mkdir v && tar xjf slurm-25.11.2.tar.bz2 -C v && git clone -q --depth 1 --branch slurm-25-11-2-1 https://github.com/SchedMD/slurm.git v/gh && rm -rf v/gh/.git
diff -rq v/slurm-25.11.2 v/gh | wc -l            # 0
rpmbuild -ta slurm-25.11.2.tar.bz2
cd ~/rpmbuild/RPMS/x86_64
sudo dnf -y install ./slurm-25.11.2-1.el9.x86_64.rpm ./slurm-perlapi-25.11.2-1.el9.x86_64.rpm ./slurm-slurmctld-25.11.2-1.el9.x86_64.rpm ./slurm-slurmd-25.11.2-1.el9.x86_64.rpm
sudo dnf versionlock add 'slurm*'
sudo /usr/sbin/create-munge-key && sudo systemctl enable --now munge
sudo useradd -r -s /sbin/nologin slurm
sudo mkdir -p /var/spool/slurmctld /var/spool/slurmd /var/log/slurm && sudo chown slurm: /var/spool/slurmctld /var/log/slurm
slurmd -C      # NodeName=testbox CPUs=20 … RealMemory=63679 Gres=gpu:nvidia_geforce_rtx_3070:1
```
Configs: [slurm.conf](test-box-files/slurm/slurm.conf), [gres.conf](test-box-files/slurm/gres.conf) (`AutoDetect=nvidia`) and [cgroup.conf](test-box-files/slurm/cgroup.conf) (`ConstrainDevices=yes`) go in `/etc/slurm/`. slurm.conf uses `RealMemory=60000`, the typed GRES that `slurmd -C` reports, `Features=GPU_SKU:RTX3070`, and partition `nvgpu` with `MaxTime=2-00:00:00` (VACC's 48 h cap). `testbox` must resolve, so add `127.0.1.1 testbox` to `/etc/hosts`. Then:
```bash
sudo systemctl enable --now slurmctld slurmd
```
VACC scripts carry `--constraint=GPU_SKU:H200`. Override that on the command line (`sbatch --constraint=GPU_SKU:RTX3070 job.sh`), since command-line options take precedence over `#SBATCH` lines. There's no accounting database, so use `scontrol show job` instead of `sacct`.

**Verify**
```
$ munge -n | unmunge | grep STATUS
STATUS:           Success (0)
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
nvgpu*       up 2-00:00:00      1   idle testbox
$ srun --gpus=1 nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 3070 (UUID: GPU-…)
$ srun --gpus=1 env | grep CUDA_VISIBLE
CUDA_VISIBLE_DEVICES=0
$ srun nvidia-smi -L                       # no GPU requested
No devices found.
$ sbatch --time=49:00:00 --wrap true; squeue -h -o '%i %T %r'
4 PENDING PartitionTimeLimit
$ srun --constraint=GPU_SKU:H200 --gpus=1 hostname
srun: error: Unable to allocate resources: Invalid feature specification
$ J1=$(sbatch --parsable --time=5 --gpus=1 --wrap 'sleep 90'); sbatch --time=5 --gpus=1 --dependency=after:$J1+1 --wrap 'sleep 5'
    # the second job shows PENDING (Dependency) and starts after J1 ends (one GPU)
```

## 9. Gateway host side: valkey, nginx, SSH tunnel

```bash
sudo dnf -y install valkey && sudo systemctl enable --now valkey
```
nginx mainline: create `/etc/yum.repos.d/nginx.repo` with the `[nginx-stable]` and `[nginx-mainline]` blocks from [nginx.org RHEL instructions](https://nginx.org/en/linux_packages.html), then:
```bash
sudo dnf config-manager --set-enabled nginx-mainline
sudo dnf -y install nginx
```
The repo key file holds three keys. The package is signed by `8540 A6F1 8833 A80E 9C16 53A4 2FD2 1310 B49F 6B46`. The other two are `573B FD6B 3D8F BC64 1079 A6AB ABF5 BD82 7BD9 BF62` and `9E9B E90E ACBC DE69 FE9B 204C BCDC D8A3 8D88 A2B3`. All three are listed in [NGINX's docs](https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/). nginx.org's install page lists only the 2011 key `573B…`.

TLS, config and SELinux. The site config is [test-box-files/nginx/catgpt.conf](test-box-files/nginx/catgpt.conf). It sets `listen 443 ssl`, `client_max_body_size 1m`, `limit_req` at 10 r/s with burst 20, `proxy_buffering off`, `proxy_read_timeout 300s` and `proxy_http_version 1.1`. Only `/v1/chat/completions` and `/v1/models` go upstream to gunicorn on 127.0.0.1:8080; everything else returns 404. The values come from [flask-gateway-and-security.md §4–§6](flask-gateway-and-security.md#5-streaming-sse-through-flask).
```bash
sudo mkdir -p /etc/nginx/tls
sudo openssl req -x509 -newkey rsa:3072 -nodes -days 365 -subj "/CN=testbox" \
  -addext "subjectAltName=DNS:testbox,DNS:localhost,IP:127.0.0.1,IP:100.87.154.14" \
  -keyout /etc/nginx/tls/testbox.key -out /etc/nginx/tls/testbox.crt
sudo chmod 600 /etc/nginx/tls/testbox.key
sudo cp catgpt.conf /etc/nginx/conf.d/ && sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
sudo setsebool -P httpd_can_network_connect 1       # SELinux: nginx may connect to 127.0.0.1:8080
sudo nginx -t && sudo systemctl enable --now nginx
```

SSH tunnel to vLLM's socket, in the same shape as production (gateway → `127.0.0.1:18000` → `ssh -L` → `--uds` socket; [ssh(1)](https://man.openbsd.org/ssh.1) supports `-L port:remote_socket`). Here the SSH hop is localhost instead of `login.vacc.uvm.edu`. The tunnel uses its own key, which can forward but can't run commands:
```bash
ssh-keygen -q -t ed25519 -N "" -C "testbox tunnel" -f ~/.ssh/id_ed25519_tunnel
echo "restrict,port-forwarding,command=\"/bin/false\" $(cat ~/.ssh/id_ed25519_tunnel.pub)" >> ~/.ssh/authorized_keys
ssh-keyscan -q localhost >> ~/.ssh/known_hosts
tmux new-session -d -s tunnel "ssh -N -o ExitOnForwardFailure=yes -i ~/.ssh/id_ed25519_tunnel -L 127.0.0.1:18000:$HOME/vllm-sock/vllm.sock localhost"
```

**Verify**
```
$ nginx -v; valkey-cli ping; getsebool httpd_can_network_connect
nginx version: nginx/1.31.9
PONG
httpd_can_network_connect --> on
$ curl -sk -o /dev/null -w '%{http_code}\n' https://localhost/v1/models    # 502 until the Flask gateway runs on :8080
$ curl -sk -o /dev/null -w '%{http_code}\n' https://localhost/metrics      # 404 (also from the laptop over Tailscale)
$ curl -s --max-time 3 http://localhost/                                   # port 80 closed
$ curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18000/v1/models
401
$ curl -s -H "Authorization: Bearer $(cat ~/.vllm_key)" http://127.0.0.1:18000/v1/models   # ids: qwen3-base, catgpt
$ ssh -i ~/.ssh/id_ed25519_tunnel localhost whoami; echo $?                # no output, exit 1
```

## Status and open items

- §0–§9 are installed and verified on `testbox` (2026-11-20).
- The Flask gateway (gunicorn on 127.0.0.1:8080) isn't written yet. Its reference code is in [flask-gateway-and-security.md §8](flask-gateway-and-security.md#8-reference-sketch-auth--streaming-proxy). End-to-end check once it runs:
  ```bash
  curl -skN https://testbox/v1/chat/completions -H "Authorization: Bearer <user key>" -H 'Content-Type: application/json' \
    -d '{"model":"catgpt","stream":true,"messages":[{"role":"user","content":"hi"}]}'
  ```
  Expected: tokens stream in incrementally; a bad user key gets 401 from Flask; `/metrics` gets 404.
- The temporary setup rule `/etc/sudoers.d/90-setup` (NOPASSWD for ejorr) is to be deleted after setup.
- Before leaving vLLM 0.33.0: check whether 0.34.0 includes the LoRA TP>2 fix (PR #65825, [README.md](README.md)) and review new advisories.
- Unknown: whether `--uds` under `$HOME` works the same on VACC compute nodes. It depends on SSH access into a job's node ([README.md](README.md#blocking-unknowns-send-before-building)).
- Unknown: the gateway host OS on campus (Silk or an ETS research VM).
