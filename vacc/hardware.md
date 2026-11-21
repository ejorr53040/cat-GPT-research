# VACC hardware

Back to [README](README.md). Compiled 2026-11-11.

Main source: [Cluster Specifications](https://www.uvm.edu/vacc/cluster-specifications). The 2026 entries on the [Maintenance page](https://www.uvm.edu/vacc/docs/maintenance/) add vendor models and network speeds.

## Current systems at a glance

| System | Role | Size (per the spec page) | Status |
| --- | --- | --- | --- |
| **BlueMoon** | CPU cluster | 88 nodes, 12,584 cores, 99.8 TB RAM | In service |
| **IceCore** | GPU cluster | 104 × H200 + 48 × RTX Pro 6000, plus H100/A100 classes | In service |
| **DataMountain** | Sharded MongoDB, large-memory database cluster | 8 nodes × 56 cores, 8 TB RAM each | In service |
| **Secure Cluster** | Planned secure environment | 3 GPU nodes + 1 large-memory node + 2 Proxmox nodes | "Will Be Available Summer 2026"; launch **not found** |
| DeepGreen | V100 GPU cluster | — | **Retired 2026-03-09** ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)) |
| BlackDiamond | AMD MI50 GPU cluster | — | **Retired**; absent from current spec page and partitions |

## BlueMoon (CPU)

From [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications):

| Node class | Nodes | CPUs | Cores/node | RAM/node | Ethernet | InfiniBand |
| --- | --- | --- | --- | --- | --- | --- |
| node500 | 16 | 2 × AMD EPYC 9655 | 192 | 1.5 TB | 100 Gb | 200 Gb IB |
| node400 | 21 | 2 × AMD EPYC 9654 | 192 | 1.5 TB | 25 Gb | IB (speed not given) |
| node300s | 39 | 2 × AMD EPYC 7763 | 128 | 1 TB | 25 Gb | IB (speed not given) |
| node200 | 9 | 2 × Intel Xeon Gold 6230 | 40 | 96 GB | 10 Gb | none |
| Large memory | 1 | 2 × AMD EPYC 7543 | 64 | 4 TB | 25 Gb | not stated |
| High clock | 2 | 2 × AMD EPYC 7F52 | 32 | 256 GB | 25 Gb | IB |

Software: RHEL 9.6, GNU compilers, Slurm 25.11.2, Lmod ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

**Conflict:** the [Maintenance page](https://www.uvm.edu/vacc/docs/maintenance/) (2026-02-23) lists 17 HPE DL365 nodes with 2 × EPYC 9655, NDR200 IB, 100 Gb Eth, 1.5 TB RAM; the spec page lists 16 node500 nodes.

## IceCore (GPU)

Spec-page headline: 104 H200 and 48 RTX Pro 6000 GPUs; nodes have 100 Gb Ethernet, 200 Gb InfiniBand, 1.0 TB RAM, and 128 or 192 cores ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

| Class | Nodes | GPUs/node | GPU | CPUs | Cores/node | RAM | Network |
| --- | --- | --- | --- | --- | --- | --- | --- |
| IceCore H200 NVL | 16 | 4 | NVIDIA H200 NVL 141 GB | 2 × Intel Xeon 6740E | 192 | 1.0 TB | 100 GbE, 200 Gb IB |
| IceCore H200 SXM | 5 | 8 | NVIDIA H200 SXM 141 GB | 2 × Intel Xeon Platinum 8593Q | 128 | 1.0 TB | 100 GbE, 200 Gb IB |
| IceCore RTX Pro 6000 | 6 | 8 | NVIDIA RTX Pro 6000 96 GB | 2 × Intel Xeon 6740E | 192 | 1.0 TB | 100 GbE, 200 Gb IB |
| H100 class | 2 | 4 | NVIDIA H100 80 GB | 2 × Intel Xeon Platinum 8462Y+ | 64 | 1 TB | 100 GbE, IB |
| A100 class | 2 | 2 | NVIDIA A100 40 GB | 2 × AMD EPYC 7763 | 128 | 1 TB | 25 GbE, IB |

Software: RHEL 9.6, Slurm 25.11.2, Lmod, "CUDA 11, 12, 13" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

Totals: 104 H200, 48 RTX Pro 6000, 8 H100, 4 A100 = 164 GPUs (my arithmetic); matches the per-SKU counts on [GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/).

### Vendor hardware (from the 2026-02-23 maintenance entry)

Per the [Maintenance page](https://www.uvm.edu/vacc/docs/maintenance/):
- 5 × **HPE Cray XD670**: 8 × H200 SXM (700 W TDP, 141 GB HBM each), 1 TB RAM, 100 Gb Ethernet, **NDR (400 Gb) IB**.
- 6 × **HPE DL380a**: 8 × "RTX 6000 Server Edition" (96 GB), 1 TB RAM, 100 Gb Ethernet, NDR (400 Gb) IB.
- 16 × **HPE DL380a**: 4 × H200 NVL (600 W TDP), 1 TB RAM, 100 Gb Ethernet, NDR (400 Gb) IB. Three of these make up GoldenMaple (CRREL).

### Conflicts and caveats

- **InfiniBand speed:** spec page says 200 Gb IB; maintenance page says NDR 400 Gb for the same nodes. **Unresolved.**
- **H200 memory:** VACC's GPU Features page lists 140 GB and uses the tag `GPU_MEM:140GB`; the spec page and [NVIDIA](https://www.nvidia.com/en-us/data-center/h200/) say 141 GB. Use the tag as written.
- **H200 NVL interconnect:** VACC lists ~300 GB/s ("NVLink Bridge 4.0 + PCIe Gen5"); [NVIDIA](https://www.nvidia.com/en-us/data-center/h200/) lists 900 GB/s per GPU over a 2- or 4-way NVLink bridge. Actual bandwidth depends on bridge topology, which is undocumented.
- **FP64 GPU count:** GPU Features says `GPU_FP:FP64` reaches "112 GPUs (A100, H100, H200)"; its own inventory gives 116.
- **GoldenMaple vs gpu-preempt:** three H200 NVL nodes are GoldenMaple (maintenance page); `gpu-preempt` "currently contains two nodes, each with four H200 GPUs" ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)). **Unclear.**
- **H100 form factor:** GPU Features defines `GPU_SKU:H100_SXM` and lists NVLink; the spec page gives no form factor.

### Vendor spec cross-checks (vendor pages)

- NVIDIA H200 SXM / NVL: 141 GB, 4.8 TB/s, FP64 34 / 30 TFLOPS, FP32 67 / 60 TFLOPS, TDP up to 700 W / 600 W ([nvidia.com/h200](https://www.nvidia.com/en-us/data-center/h200/)).
- NVIDIA RTX PRO 6000 Blackwell Server Edition: 96 GB GDDR7 ECC, 1,597 GB/s, PCIe Gen 5, up to 600 W ([nvidia.com](https://www.nvidia.com/en-us/data-center/rtx-pro-6000-blackwell-server-edition/)). VACC lists FP64 at 1/64 of FP32 ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/)).

### GPU inventory as VACC documents it

From [GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/):

| GPU | Gen | VRAM | FP32 | FP64 rate | CC | Cards | GPU-GPU link (VACC's figure) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A100 | Ampere | 40 GB | 19.5 TF/s | 1/2 FP32 | 8.0 | 4 | PCIe Gen4 ~32 GB/s (not recommended for multi-GPU) |
| H100 | Hopper | 80 GB | ~65 TF/s | 1/2 | 9.0 | 8 | NVLink ~300 GB/s |
| H200 SXM | Hopper | 140 GB* | ~65 TF/s | 1/2 | 9.0 | 40 (of 104) | NVLink + NVSwitch ~900 GB/s |
| H200 NVL | Hopper | 140 GB* | ~65 TF/s | 1/2 | 9.0 | 64 (of 104) | NVLink Bridge + PCIe Gen5 ~300 GB/s |
| RTX 6000 Pro | Blackwell | 96 GB | 125 TF/s | 1/64 | 12.0 | 48 | PCIe Gen5 ~64 GB/s (not recommended for multi-GPU) |

*VACC says 140 GB. The spec page and NVIDIA say 141 GB.

## DataMountain

"A large memory, sharded MongoDB to support near real-time access to enormous data files ... Comprised of 8 nodes, each with two Intel Xeon 6348 CPUs (56 cores per node), 8 TB of RAM, and 25 Gb Ethernet" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)). How users get access is **not found**.

## Secure Cluster (announced)

"Will Be Available Summer 2026. Three GPU Nodes, each equipped with an NVIDIA L40S GPU, an AMD EPYC 9354P, and 192GB of RAM. One Large Memory Node with an AMD EPYC 9554P and 1.5TB of RAM. Two Proxmox Nodes, each equipped with an AMD EPYC 9354P and 384GB of RAM." ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

Launch status and compliance scope (HIPAA, CUI, etc.) are **not found**. See [storage.md](storage.md#security-and-compliance) for the separate ETS Secure Enclave.

## Storage hardware

From [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications):
- IBM Spectrum Scale (GPFS): **2.8 PB** total, "roughly 25% of capacity on NVMe/Flash".
- 4 I/O nodes with 100 GbE and 200 Gb HDR InfiniBand, serving:
  - IBM FS7300: 664 TB flash plus an expansion drawer with 754 TB of spinning disk
  - Dell MD3460 plus expansion drawer: 564 TB disk
  - Dell ME4084: 682 TB spinning disk
  - IBM FS7200: 187 TB NVMe FlashCore Module
  - IBM FS5600: 633 TB NVMe FlashCore Module plus 1.1 PB spinning disk
- Ethernet: "100Gb, 40Gb, 25Gb, and 10Gb Ethernet connections to different portions of the cluster."

How storage maps to filesystems (gpfs1/gpfs2/gpfs3tmp) is covered in [storage.md](storage.md).

## Data centre and environment

- Facility: South Burlington technology park ([IceCore news](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm)). Staff address: Innovation Hall 422, Burlington ([Contact](https://www.uvm.edu/vacc/contact-us)).
- Power, cooling and UPS work ran March to June 2026, often at 50% capacity; normal operation resumed 2026-06-14 ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)).
