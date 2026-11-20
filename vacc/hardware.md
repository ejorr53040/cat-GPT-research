# VACC hardware

Back to [README](README.md). All pages accessed 2026-11-11 unless noted otherwise.

The main source is the official [Cluster Specifications page](https://www.uvm.edu/vacc/cluster-specifications). It is also served at `https://www.uvm.edu/vacc/cluster-specs`, which returns the same content. The 2026 data-centre log on the [Maintenance page](https://www.uvm.edu/vacc/docs/maintenance/) adds vendor models and network speeds.

## Current systems at a glance

| System | Role | Size (per the spec page) | Status |
| --- | --- | --- | --- |
| **BlueMoon** | CPU cluster | 88 nodes, 12,584 cores, 99.8 TB RAM | In service |
| **IceCore** | GPU cluster | 104 × H200 + 48 × RTX Pro 6000, plus legacy H100/A100 classes | In service (phase 2 brought up in spring 2026) |
| **DataMountain** | Sharded MongoDB, large-memory database cluster | 8 nodes × 56 cores, 8 TB RAM each | In service (status not dated) |
| **Secure Cluster** | Planned secure environment | 3 GPU nodes + 1 large-memory node + 2 Proxmox nodes | Spec page says "Will Be Available Summer 2026". Whether it launched was **not found** |
| DeepGreen | V100 GPU cluster | 80 × V100 (2019) | **Retired 2026-03-09** |
| BlackDiamond | AMD MI50 GPU cluster | — | **Retired**. Only a search snippet confirms this, see below |

Source for all rows except the last two: [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications).

## BlueMoon (CPU)

From [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications): "A CPU cluster composed of 88 nodes, with a total of 12,584 CPU cores and 99.8TB of memory."

| Node class | Nodes | CPUs | Cores/node | RAM/node | Ethernet | InfiniBand |
| --- | --- | --- | --- | --- | --- | --- |
| node500 | 16 | 2 × AMD EPYC 9655 | 192 | 1.5 TB | 100 Gb | 200 Gb IB |
| node400 | 21 | 2 × AMD EPYC 9654 | 192 | 1.5 TB | 25 Gb | IB (speed not given) |
| node300s | 39 | 2 × AMD EPYC 7763 | 128 | 1 TB | 25 Gb | IB (speed not given) |
| node200 | 9 | 2 × Intel Xeon Gold 6230 | 40 | 96 GB | 10 Gb | none |
| Large memory | 1 | 2 × AMD EPYC 7543 | 64 | 4 TB | 25 Gb | not stated |
| High clock | 2 | 2 × AMD EPYC 7F52 | 32 | 256 GB | 25 Gb | IB |

Software stack listed for BlueMoon: RHEL 9.6 with GNU compilers (gcc, Fortran), Slurm 25.11.2, and Lmod, which the page calls a "Package Manager" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

**Consistency check (my arithmetic):** the classes add up to 16+21+39+9+1+2 = 88 nodes and 3,072+4,032+4,992+360+64+64 = 12,584 cores. RAM comes to about 99.9 TB. All three totals agree with the headline numbers.

**Possible conflict:** the [Maintenance page](https://www.uvm.edu/vacc/docs/maintenance/) (entry dated 2026-02-23) says VACC acquired "17 (seventeen) HPE DL365 compute nodes with 2x AMD EPYC 9655 CPUs, NDR200 IB, 100Gb Eth, 1.5 TB RAM". The spec page lists 16 node500 nodes. Either one node is not in production yet, or one of the two pages is wrong.

**Vendor model, per the maintenance page:** the EPYC 9655 nodes are HPE DL365 ([maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). The vendor of the older classes was **not found**. The [Mission and History page](https://www.uvm.edu/vacc/mission-and-history) says the original BlueMoon was "primarily developed using IBM systems architecture" and has had "three major upgrades".

Node names seen in the docs: `node413` ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)), which suggests the node4xx class.

## IceCore (GPU)

The headline on [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications) reads: "A GPU cluster comprised of 104 Nvidia H200 GPUs and 48 Nvidia Pro 6000 GPUs. Nodes have 100 Gb Ethernet and 200 Gb InfiniBand, as well as 1.0 TB of RAM and 128 or 192 cores".

| Class | Nodes | GPUs/node | GPU | CPUs | Cores/node | RAM | Network |
| --- | --- | --- | --- | --- | --- | --- | --- |
| IceCore H200 NVL | 16 | 4 | NVIDIA H200 NVL 141 GB | 2 × Intel Xeon 6740E | 192 | 1.0 TB | 100 GbE, 200 Gb IB |
| IceCore H200 SXM | 5 | 8 | NVIDIA H200 SXM 141 GB | 2 × Intel Xeon Platinum 8593Q | 128 | 1.0 TB | 100 GbE, 200 Gb IB |
| IceCore RTX Pro 6000 | 6 | 8 | NVIDIA RTX Pro 6000 96 GB | 2 × Intel Xeon 6740E | 192 | 1.0 TB | 100 GbE, 200 Gb IB |
| H100 class | 2 | 4 | NVIDIA H100 80 GB | 2 × Intel Xeon Platinum 8462Y+ | 64 | 1 TB | 100 GbE, IB |
| A100 class | 2 | 2 | NVIDIA A100 40 GB | 2 × AMD EPYC 7763 | 128 | 1 TB | 25 GbE, IB |

Software listed for IceCore: RHEL 9.6, Slurm 25.11.2, Lmod, and "CUDA 11, 12, 13" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

GPU totals: 16×4 + 5×8 = 104 H200, which matches. 6×8 = 48 RTX Pro 6000, which matches. 2×4 = 8 H100 and 2×2 = 4 A100. That makes 164 GPUs in all. The [GPU Features page](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/) gives the same per-SKU counts (A100 4, H100 8, H200 104, RTX 6000 Pro 48) and says "160+ GPUs".

### Vendor hardware (from the 2026-02-23 maintenance entry)

Per the [Maintenance page](https://www.uvm.edu/vacc/docs/maintenance/):
- 5 × **HPE Cray XD670**: 8 × H200 SXM (700 W TDP, 141 GB HBM each), 1 TB RAM, 100 Gb Ethernet, **NDR (400 Gb) IB**.
- 6 × **HPE DL380a**: 8 × "RTX 6000 Server Edition" (96 GB), 1 TB RAM, 100 Gb Ethernet, NDR (400 Gb) IB.
- 16 × **HPE DL380a**: 4 × H200 NVL (600 W TDP), 1 TB RAM, 100 Gb Ethernet, NDR (400 Gb) IB. "11 of these already in production, in temporary racks. Three of these comprise GoldenMaple."
- Cooling for the new hardware: Motivair MCDU-40 cooling distribution unit plus 3 Motivair ChilledDoors (rear-door heat exchangers).

### Conflicts and caveats

- **InfiniBand speed:** the spec page says 200 Gb IB for IceCore. The maintenance page says NDR (400 Gb) for the same nodes. One possibility is 400 Gb NDR adapters on a 200 Gb fabric, but no page says so. **Unresolved.**
- **Cores in the headline:** the summary says "128 or 192 cores ... (H200 nodes vs. Pro 6000 nodes, respectively)". The table gives the H200 NVL nodes 192 cores, so the "respectively" only holds for the SXM nodes.
- **Unit typos on the spec page:** "141 Gb" and "96 Gb" should almost certainly be GB.
- **H200 memory:** VACC's own GPU Features page lists the H200 as 140 GB and uses the feature tag `GPU_MEM:140GB`. The spec page and NVIDIA's [H200 page](https://www.nvidia.com/en-us/data-center/h200/) say 141 GB.
- **H200 NVL interconnect:** VACC's GPU Features page lists about 300 GB/s for the H200 NVL ("NVLink Bridge 4.0 + PCIe Gen5"). NVIDIA's [H200 page](https://www.nvidia.com/en-us/data-center/h200/) lists 900 GB/s per GPU over a 2- or 4-way NVLink bridge (NVIDIA marks these as preliminary specs). The figure VACC users actually get depends on the bridge topology, which no page documents.
- **FP64 GPU count:** the GPU Features page says `GPU_FP:FP64` reaches "112 GPUs (A100, H100, H200)". By its own inventory that is 4 + 8 + 104 = **116**.
- **GoldenMaple vs gpu-preempt:** the maintenance page says three of the H200 NVL nodes make up GoldenMaple. The [Slurm Partitions page](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/) says `gpu-preempt` "currently contains two nodes, each with four H200 GPUs" belonging to CRREL. That may simply mean two of the three are in the preempt pool. **Unclear.**
- **Funding:** NSF award [2510406](https://api.nsf.gov/services/v1/awards/2510406.json) ("MRI: Track 2 Acquisition of a Transformational High-Performance Computing Cluster ...") gave $2,165,729. It runs 2025-09-01 to 2028-08-31, with PI Christopher M. Danforth. The abstract mentions "64 NVIDIA GPUs", which is phase 1. The [Mission and History page](https://www.uvm.edu/vacc/mission-and-history) rounds the award to "$2.1 million".
- **Performance claims:** the [IceCore news story (2025-12-10)](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm) claims "more than 100 petaflops", a "25-fold" capacity increase, and two phases: 64 H200 in fall 2025, then 40 H200 SXM + 48 RTX PRO 6000 Blackwell Server Edition in 2026. The history page says "100 times faster than previous UVM systems". The two multipliers disagree, and no precision or benchmark is given for the petaflop figure.

### Vendor spec cross-checks (vendor pages)

- NVIDIA H200 SXM / NVL: 141 GB, 4.8 TB/s, FP64 34 / 30 TFLOPS, FP32 67 / 60 TFLOPS, TDP up to 700 W / 600 W ([nvidia.com/h200](https://www.nvidia.com/en-us/data-center/h200/), "preliminary specifications").
- NVIDIA RTX PRO 6000 Blackwell Server Edition: 96 GB GDDR7 ECC, 1,597 GB/s, 120 TFLOPS FP32, PCIe Gen 5, up to 600 W. No FP64 figure is published ([nvidia.com](https://www.nvidia.com/en-us/data-center/rtx-pro-6000-blackwell-server-edition/)). VACC lists FP32 as 125 TF/s and FP64 at 1/64 of FP32 ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/)).
- Intel Xeon 6740E: 96 cores / 96 threads, 2.4 GHz base, 250 W ([Intel ARK](https://www.intel.com/content/www/us/en/products/sku/240359/intel-xeon-6740e-processor-96m-cache-2-40-ghz/specifications.html), via search result). Two sockets give 192 cores, which matches VACC.
- I did **not** fetch vendor pages for the other CPUs (EPYC 9655/9654/7763/7543/7F52, Xeon Gold 6230, Platinum 8593Q/8462Y+, Xeon 6348). The AMD page timed out. VACC's per-node core counts imply 96/96/64/32/16/20/64/32/28 cores per socket. That is consistent with what I know of these SKUs, but it is **not verified from a vendor page here**.

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

There is also a contradiction about H100 form factor. The GPU Features page defines a `GPU_SKU:H100_SXM` feature and credits the H100 with NVLink. The spec page just says "NVIDIA H100 80 GB" without a form factor. Not resolved.

## DataMountain

"A large memory, sharded MongoDB to support near real-time access to enormous data files ... Comprised of 8 nodes, each with two Intel Xeon 6348 CPUs (56 cores per node), 8 TB of RAM, and 25 Gb Ethernet" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

It was funded by NSF "MRI: Acquisition of a Massive Database to Accelerate Data Science Discovery" (2021, $1,035,737, joint EPSCoR support) ([Mission and History](https://www.uvm.edu/vacc/mission-and-history)). How users get access to DataMountain was **not found** in the user docs.

## Secure Cluster (announced)

"Will Be Available Summer 2026. Three GPU Nodes, each equipped with an NVIDIA L40S GPU, an AMD EPYC 9354P, and 192GB of RAM. One Large Memory Node with an AMD EPYC 9554P and 1.5TB of RAM. Two Proxmox Nodes, each equipped with an AMD EPYC 9354P and 384GB of RAM." ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).

As of 2026-11-11 the page still reads "Will Be Available Summer 2026", and nothing in the docs says whether it launched. I found no statement of which compliance regimes it targets (HIPAA, CUI, etc.). See [storage.md](storage.md#security-and-compliance) for the separate ETS Secure Enclave.

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

These arrays add up to about 4.6 PB raw (my arithmetic), against the stated 2.8 PB of GPFS. The gap could be RAID/replication overhead or arrays that are not part of GPFS. **Not explained** on the page.

How storage maps to filesystems (gpfs1/gpfs2/gpfs3tmp) is covered in [storage.md](storage.md).

## Retired systems

### DeepGreen (2019 to 2026-03-09)
- Unveiled 2019-07-31. NSF funded it with $1M. It added "80 high performance graphics processing units ... containing 460,000 processing cores", "over 1 petaflop", and was housed in "UVM's primary datacenter in South Burlington" ([UVM News, 2019-07-31](https://www.uvm.edu/uvmnews/news/uvm-completes-warp-speed-upgrade-its-supercomputer)).
- **Conflicting figures:** the [Mission and History page](https://www.uvm.edu/vacc/mission-and-history) says "over 70 GPUs ... mixed-precision calculations exceeding 8 petaflops, using the NVIDIA Tesla V100". The [IceCore news story](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm) says "80 GPUs capable of over 8 petaflops". The 2019 story said ">1 petaflop", which is probably FP64 against mixed precision, but no page says so.
- **Retired:** "March 9: ... DeepGreen was shut down permanently. No more V100 GPUs will be available." ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). Its slot was replaced by H200 nodes.
- Stale references remain. The [Services page](https://www.uvm.edu/vacc/services-we-provide) still describes DeepGreen in classes ("As of Fall 2020 ..."). The [Cost page](https://www.uvm.edu/vacc/cost-and-payment) voucher text mentions "GPUs (i.e. DeepGreen)". The [ETS service catalog](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc) and the [UVM KB article (updated 2025-11-21)](https://uvm.edu/it/kb/article/vermont-advanced-computing-center) still list "BlackDiamond, Bluemoon, DeepGreen".

### BlackDiamond (AMD GPUs)
- The [Mission and History page](https://www.uvm.edu/vacc/mission-and-history) mentions a 2020 "$1 million award from the AMD HPC Fund" and a 2023 AMD gift of $100,000 "to support teaching and training on GPU systems". It does not name BlackDiamond.
- **Unverified (search snippets only; the source pages now 404 or redirect):** a search snippet attributed to the old VACC KB page `uvm.edu/vacc/kb/knowledge-base/blackdiamond` described 6 nodes, each with 1 × AMD EPYC 7642 and 8 × AMD Radeon Instinct MI50 (32 GB). That is 48 MI50s, which matches a snippet of the March 2023 spec .docx. A snippet of the old "move to rh9" page said BlackDiamond would be sunset with the RHEL 9 transition because AMD was ending MI50 software support. I could not open any of these pages on 2026-11-11 (404 or redirect to the VACC home), so treat all of it as **historical and unverified**.
- It is absent from the current spec page, partition list and GPU inventory, so it is effectively retired. The exact retirement date was **not found**.

## Data centre and environment

- The facility is in the South Burlington technology park ([IceCore news](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm); [2019 news](https://www.uvm.edu/uvmnews/news/uvm-completes-warp-speed-upgrade-its-supercomputer)). The staff mailing address is Innovation Hall 422, Burlington ([Contact](https://www.uvm.edu/vacc/contact-us)).
- 2026 works ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)): new power circuits (A/B sides), a new secondary cooling loop, and replacement of the 20-year-old UPSes. The work ran March to June 2026, at 50% capacity on many days, and normal operation resumed 2026-06-14.
- Cooling and energy ([AI Workloads](https://www.uvm.edu/vacc/artificial-intelligence-workloads)): no evaporative cooling, outside-air cooling for much of the year, and chillers using a low-GWP refrigerant. VACC estimates 63 to 135 t CO2/yr on Vermont's grid, against 1,500 to 2,200 t on fossil power, and says an industry-average evaporative data centre would use "~1 million gallons per year" of water.
