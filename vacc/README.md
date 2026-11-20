# UVM VACC (Vermont Advanced Computing Center): research notes

Compiled 2026-11-11 from primary sources only: UVM's VACC site, the VACC user docs, UVM ETS pages and KB, UVM News, NSF award records, and NVIDIA/Intel product pages. Every page was accessed on **2026-11-11**. Claims are cited inline. Unless a note says otherwise, "(my arithmetic)" marks figures I derived. **Uncertain**, **conflict** and **stale** mark doubtful points.

## Contents

1. [What the VACC is](#what-the-vacc-is)
2. [History and timeline](#history-and-timeline)
3. [Who runs it, and contacts](#who-runs-it-and-contacts)
4. [Systems at a glance](#systems-at-a-glance) → details in **[hardware.md](hardware.md)**
5. [Access in one minute](#access-in-one-minute) → details in **[access.md](access.md)** (eligibility, login, tiers, costs)
6. [Scheduler in one minute](#scheduler-in-one-minute) → details in **[slurm-and-jobs.md](slurm-and-jobs.md)**
7. [Software in one minute](#software-in-one-minute) → details in **[software.md](software.md)**
8. [Storage in one minute](#storage-in-one-minute) → details in **[storage.md](storage.md)** (filesystems, quotas, Globus, compliance)
9. [Training, office hours, support](#training-office-hours-support)
10. [Acknowledgement / citation text](#acknowledgement--citation-text)
11. [Recent news, upgrades, retirements](#recent-news-upgrades-retirements)
12. [Source map](#source-map)
13. [Open questions / not found](#open-questions--not-found)
14. **Deployment follow-up (2026-11-13):** [serving-an-llm.md](serving-an-llm.md) covers running an LLM service on the VACC. For the full gpt-oss-120b + vLLM + Flask plan, see [../gpt-oss-deployment/README.md](../gpt-oss-deployment/README.md).

## What the VACC is

- "The Vermont Advanced Computing Center (VACC) is a research facility offering computing services to UVM faculty, staff and students. Our high-performance computing (HPC) clusters support large-scale computation, low-latency networking for MPI workloads, and high-throughput AI and machine learning workflows" ([VACC home](https://www.uvm.edu/vacc)).
- **Name:** current UVM pages say "Vermont Advanced Computing **Center**" ([VACC home](https://www.uvm.edu/vacc)). The ETS service catalogue and older news say "Vermont Advanced Computing **Core**" ([ETS catalog](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc); [UVM News 2019](https://www.uvm.edu/uvmnews/news/uvm-completes-warp-speed-upgrade-its-supercomputer)). The ETS catalogue calls it "a high performance computing (HPC) core sponsored by the Office of the VP for Research and ETS". The [Cost page](https://www.uvm.edu/vacc/cost-and-payment) says it is funded by a tiered fee policy.
- Mission pillars: high-impact research, computational education, and sustainable infrastructure ([Mission and History](https://www.uvm.edu/vacc/mission-and-history)).
- UVM policy: "The VACC is the default research computing environment and should be used whenever possible for all compute needs" ([ETS Research Computing](https://www.uvm.edu/it/research-computing)).

## History and timeline

| Year | Event | Source |
| --- | --- | --- |
| 2003 | Campus HPC needs assessment with NASA and Sen. Leahy support and an AAAS expert panel. "Established in 2003 with support from NASA and the National Science Foundation" | [Mission and History](https://www.uvm.edu/vacc/mission-and-history) |
| 2005 | **Conflict:** "Established in 2005 with funding from NASA ... first ... installation was a CPU cluster with 72 nodes", the "BlueMoon cluster" | [IceCore news, 2025-12-10](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm) |
| — | BlueMoon "primarily developed using IBM systems architecture", with "three major upgrades" since. Dates not given | [Mission and History](https://www.uvm.edu/vacc/mission-and-history) |
| 2019 | **DeepGreen** V100 GPU cluster, $1M NSF grant, unveiled 2019-07-31 | [UVM News](https://www.uvm.edu/uvmnews/news/uvm-completes-warp-speed-upgrade-its-supercomputer) |
| 2020 | AMD University Program, "$1 million award from the AMD HPC Fund" | [Mission and History](https://www.uvm.edu/vacc/mission-and-history) |
| 2021 | NSF MRI grant ($1,035,737, with EPSCoR) for **DataMountain** | [Mission and History](https://www.uvm.edu/vacc/mission-and-history) |
| 2023 | AMD $100,000 gift for GPU teaching. NSF EPSCoR **SOCKS** award (2023 to 2028, $20M; $1.2M of it for cluster hardware) | [Mission and History](https://www.uvm.edu/vacc/mission-and-history); [NSF 2242829](https://api.nsf.gov/services/v1/awards/2242829.json) |
| 2025 | NSF MRI award **2510406** ($2,165,729, starting 2025-09-01) for **IceCore**. Phase 1: 64 × H200 | [NSF 2510406](https://api.nsf.gov/services/v1/awards/2510406.json); [IceCore news](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm) |
| 2026-01 | RHEL 9.4→9.6, Slurm 25.05→25.11. `/gpfs3` wiped and rebuilt as `/gpfs3tmp` with a 60-day purge | [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/) |
| 2026-03-09 | **DeepGreen shut down permanently** | [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/) |
| 2026-03 to 06 | Power, cooling and UPS overhaul. IceCore phase 2 (H200 SXM, RTX Pro 6000) and new EPYC 9655 nodes brought online. GPU-feature scheduling (April). Normal operation from 2026-06-14 | [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/) |
| 2026-06-10 | OOD update. Per-job private `/tmp`, `/var/tmp` and `/dev/shm` | [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/) |
| Summer 2026 | "Secure Cluster" announced. Launch **not confirmed** | [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications) |
| 2027-01-05 | Next scheduled maintenance | [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/) |

## Who runs it, and contacts

From [Contact Us](https://www.uvm.edu/vacc/contact-us):
- **Director:** Chris Danforth, Professor of Mathematics and Statistics. He is also PI of the IceCore NSF award ([NSF 2510406](https://api.nsf.gov/services/v1/awards/2510406.json)). The 2019 director was Adrian Del Maestro ([UVM News 2019](https://www.uvm.edu/uvmnews/news/uvm-completes-warp-speed-upgrade-its-supercomputer)).
- **Executive Director:** Andrea (Andi) Elledge, aelledge@uvm.edu. She handles billing, funding and vouchers ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).
- **IT staff listed:** Mike Austin (Chief Technology Officer), Jim Lawson (Research Computing Team Lead), Bennet Fauber, Travis Bartlett and Robert Minvielle (Sr. Systems Engineers), Katy Czar and Evan Hinchliffe (Systems Engineers), Shelly Johnson (Sr. Research Facilitator), and Terry Barrett (Development Team Leader, Spatial Analysis Laboratory).
- **Governance:** the ETS catalogue says the VACC is "sponsored by the Office of the VP for Research and ETS" ([ETS catalog](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc)). The Voucher Fund is issued by the Office of the VP for Research ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)). No advisory committee or governance charter was found.
- **Channels:**
  - Technical help and tickets: **vacchelp@uvm.edu** ([Getting Help](https://www.uvm.edu/vacc/docs/start_guide/get_help/)).
  - Admin and billing: **vacc@uvm.edu**.
  - Phone: 802-656-8867.
  - Address: Innovation Hall 422, Burlington, VT 05405.
- A help ticket should include the problem description, `module list` output, working directory, the command run, error logs, the job ID and the job script path ([Getting Help](https://www.uvm.edu/vacc/docs/start_guide/get_help/)).

## Systems at a glance

| System | Type | Headline specs (from the [spec page](https://www.uvm.edu/vacc/cluster-specifications)) |
| --- | --- | --- |
| **BlueMoon** | CPU | 88 nodes, 12,584 cores, 99.8 TB RAM. Mainly 2 × EPYC 9655/9654 (192 cores, 1.5 TB) and 2 × EPYC 7763 (128 cores, 1 TB). One 4 TB large-memory node. 200 Gb IB on the newest class |
| **IceCore** | GPU | 104 × H200 (16 nodes × 4 NVL + 5 nodes × 8 SXM) and 48 × RTX Pro 6000 (6 × 8), plus 8 × H100 and 4 × A100. 1 TB RAM per node. 100 GbE plus 200 Gb IB (**conflict:** the maintenance log says NDR 400 Gb) |
| **DataMountain** | Sharded MongoDB | 8 nodes × 2 × Xeon 6348 (56 cores), 8 TB RAM each |
| **Secure Cluster** | Planned | 3 × L40S GPU nodes, 1 × 1.5 TB node, 2 Proxmox nodes. "Summer 2026" |
| Storage | GPFS (IBM Spectrum Scale) | 2.8 PB, about 25% flash. 4 I/O nodes with HDR IB |
| *DeepGreen* | *Retired 2026-03-09* | V100s |
| *BlackDiamond* | *Retired; date unknown* | AMD MI50s (unverified details) |

Full tables, vendor models and every conflict: **[hardware.md](hardware.md)**.

**Stale secondary pages:** the [ETS Research Computing page](https://www.uvm.edu/it/research-computing) still says "more than 4,500 processing cores and over 100 GPUs". The [ETS catalogue](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc) and the [UVM KB VACC article](https://uvm.edu/it/kb/article/vermont-advanced-computing-center) (updated 2025-11-21) still list BlackDiamond, Bluemoon and DeepGreen. Use the VACC spec page instead.

## Access in one minute

- **Eligible:** UVM PIs (faculty, and post-docs optionally) apply. Students, staff and external collaborators must be **sponsored by a PI** (externals need a UVM NetID requested by the PI). Export-control screening applies ([Request Allocation](https://www.uvm.edu/vacc/request-allocation); [Getting an account](https://www.uvm.edu/vacc/docs/start_guide/request_acct/)).
- **Apply:** a short form (project title, lay summary, needs, tier, funding). Sponsored users are added through the [PI dashboard](https://vacc.w3.uvm.edu/accounts/owner_detail.php).
- **Log in:**
  - `ssh netid@login.vacc.uvm.edu` with the NetID password, no VPN needed ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
  - Web: **https://ondemand.vacc.uvm.edu**, which needs campus or VPN ([OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)).
  - MFA requirements: **not documented.**
- **Cost (FY26):**
  - Tier 1 is free for UVM faculty and staff (under 250k CU/yr).
  - Tier 2 is $1,000 (250k to 3M CU).
  - Tier 3 is $4,000 (over 3M CU).
  - 1 CU = 1 core-hour = 1 GPU-minute ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).
  - Vouchers of up to $10k are available from the VP for Research.

Details: **[access.md](access.md)**.

## Scheduler in one minute

- **Slurm 25.11.2**. Accounts are named `pi-<netid>`.
- Partitions:
  - `general` (default, 48 h max)
  - `short` (3 h)
  - `week` (7 d)
  - `nvgpu` (GPU, 48 h)
  - `gpu-debug` (A100, 3 h, strict limits)
  - `gpu-preempt` (CRREL H200s, preemptible)
  - restricted `hgnodes` (SOCKS H100s) and `goldenmaple` (CRREL)
- **GPU jobs must pass a `--constraint` GPU feature**, such as `GPU_FP:FP64`, `GPU_SKU:H200`, `GPU_MEM:140GB` or `GPU_ANY` ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/); [GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/)).
- Interactive jobs use `srun ... --pty /bin/bash`.
- Job arrays and fairshare: **not documented.**

Details and example scripts: **[slurm-and-jobs.md](slurm-and-jobs.md)**.

## Software in one minute

- RHEL 9.6, Lmod plus Spack, about 212 modules.
- GCC 13.3.0, oneAPI 2024.2.1, CUDA 11.8 to 13.0.2, Open MPI 4.1.6 / 5.0.5-ib / 5.0.7.
- **Miniforge replaced Anaconda** (2026; Anaconda removed for licence reasons).
- Apptainer 1.3.4.
- LLM model library at `/gpfs1/llm` (Llama 2 to 4), plus ollama and llama.cpp modules.
- Licence-gated: Amber, Gaussian, NAMD, ORCA, VMD and Schrodinger.

Details: **[software.md](software.md)**.

## Storage in one minute

- `/gpfs1`: home plus `/gpfs1/pi/<PI>`. Backed up.
- `/gpfs2/scratch`: not backed up.
- `/gpfs3tmp`: 60-day purge, no backup.
- `/netfiles`: ETS Research Storage, 10 TB free for faculty.
- Quotas are per PI group and per tier. Tier 1 gets gpfs1 2/4 TB soft/hard and gpfs2 4/8 TB, with a 7-day grace period.
- Transfers: scp/sftp to `login.vacc.uvm.edu`, or the Globus collection "UVM VACC".
- **No statement that the cluster is approved for HIPAA, PHI or CUI data.** Regulated data goes to the ETS Secure Enclave.

Details: **[storage.md](storage.md)**.

## Training, office hours, support

- **Research Computing Virtual Café:** drop-in office hours on Microsoft Teams, run jointly with ETS Research Computing. In Fall 2026 they alternate Thursdays 9:00 to 10:30 and Mondays 14:00 to 15:30, roughly every other week, from Sept 10 to Dec 7. There is no café on Nov 23 (Thanksgiving) ([Research Computing Events](https://www.uvm.edu/it/research-computing-events)).
- **One-on-one onboarding** through vacchelp@uvm.edu ([Services](https://www.uvm.edu/vacc/services-we-provide)).
- **Programming assistance** from Research Facilitators, funded through grants ([Services](https://www.uvm.edu/vacc/services-we-provide)).
- **Workshops:** ETS says the team "holds occasional workshops". A "Presentations and Workshops" archive page is linked ([ETS Research Computing](https://www.uvm.edu/it/research-computing)), but I did not read it. The Mission page mentions "hands-on workshops, web-based training" ([Mission and History](https://www.uvm.edu/vacc/mission-and-history)). No 2026 workshop schedule was found.
- **HPC in the classroom:** Jupyter on OOD, with GPU reservations for class time ([Services](https://www.uvm.edu/vacc/services-we-provide)).

## Acknowledgement / citation text

From [Citations and Assets for Grants](https://www.uvm.edu/vacc/citations-and-assets-grants). Acknowledgement is **required**, and the publication details and DOI should also be emailed to vacc@uvm.edu.

- **BlueMoon:** "The authors acknowledge the Vermont Advanced Computing Center (VACC) at the University of Vermont for providing computational resources that have contributed to the research results reported within this paper."
- **IceCore:** the same sentence, plus "Specifically, computations were supported by the National Science Foundation under Award No. 2510406."
- **SOCKS:** the same sentence, plus "Specifically, this material is based upon work supported by the National Science Foundation under Award No. 2242829."
- A downloadable Word document of cluster specs for grant proposals is linked from that page. Its URL could not be resolved in the page text I extracted. The older .docx URLs found by search now return UVM's 404 page.
- Grant budget boilerplate (line F6021, account code 80047) is on [Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment). See [access.md](access.md#paying).

## Recent news, upgrades, retirements

- **2025-12-10:** "IceCore Advances a New Era of Discovery at UVM". The article claims more than 100 petaflops and a 25× capacity increase, with phase 1 (64 × H200) in fall 2025 and phase 2 (40 × H200 SXM + 48 × RTX PRO 6000) in 2026 ([CEMS news](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm)).
- **2026-02-23 to 2026-06-14:** data-centre power, cooling and UPS work. The maintenance log records frequent 50% capacity periods ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)).
- **2026-03-09:** DeepGreen (V100) retired.
- **2026-03 to 06:** Anaconda removed and replaced by Miniforge ([Conda transition](https://www.uvm.edu/vacc/docs/beyond_basics/conda_transition/)).
- **2026-04:** GPU-feature constraints introduced in Slurm.
- **2026-08:** live storage-network work (Aug 4, 6, 11). Full shutdown on Aug 18 for software updates ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). The year is inferred from page context.
- **BlackDiamond (AMD MI50):** sunset around the RHEL 9 move, according to an old docs page that now returns 404. The date is **unverified**.
- **Environmental claims:** see the [AI Workloads page](https://www.uvm.edu/vacc/artificial-intelligence-workloads) and [hardware.md](hardware.md#data-centre-and-environment).

## Source map

- VACC site: [home](https://www.uvm.edu/vacc), [mission-and-history](https://www.uvm.edu/vacc/mission-and-history), [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications), [cost-and-payment](https://www.uvm.edu/vacc/cost-and-payment), [request-allocation](https://www.uvm.edu/vacc/request-allocation), [citations-and-assets-grants](https://www.uvm.edu/vacc/citations-and-assets-grants), [services-we-provide](https://www.uvm.edu/vacc/services-we-provide), [data-management](https://www.uvm.edu/vacc/data-management), [artificial-intelligence-workloads](https://www.uvm.edu/vacc/artificial-intelligence-workloads), [contact-us](https://www.uvm.edu/vacc/contact-us).
- VACC user docs: [uvm.edu/vacc/docs](https://www.uvm.edu/vacc/docs/), an MkDocs Material site with 48 pages, read in full through its search index. It is also mirrored at `docs.vacc.w3.uvm.edu` according to search results. The old KB at `vacckb.helpline.w3.uvm.edu` is still cited by the ETS catalogue, and old `uvm.edu/vacc/kb/...` URLs now redirect to the VACC home.
- ETS: [Research Computing](https://www.uvm.edu/it/research-computing), [Events / Virtual Café](https://www.uvm.edu/it/research-computing-events), [VACC service catalogue](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc), [KB: VACC](https://uvm.edu/it/kb/article/vermont-advanced-computing-center), [KB: Globus](https://www.uvm.edu/it/kb/article/globus-data-transfer-service/), [Secure Enclave](https://www.uvm.edu/it/secure-enclave).
- News and awards: [UVM News 2019 (DeepGreen)](https://www.uvm.edu/uvmnews/news/uvm-completes-warp-speed-upgrade-its-supercomputer), [CEMS 2025 (IceCore)](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm), [NSF 2510406](https://api.nsf.gov/services/v1/awards/2510406.json), [NSF 2242829](https://api.nsf.gov/services/v1/awards/2242829.json).
- Vendors: [NVIDIA H200](https://www.nvidia.com/en-us/data-center/h200/), [NVIDIA RTX PRO 6000 Server](https://www.nvidia.com/en-us/data-center/rtx-pro-6000-blackwell-server-edition/), [Intel Xeon 6740E](https://www.intel.com/content/www/us/en/products/sku/240359/intel-xeon-6740e-processor-96m-cache-2-40-ghz/specifications.html).

## Open questions / not found

**Not found on any primary page:**
1. **MFA and SSH keys.** Does SSH to `login.vacc.uvm.edu` require Duo? Are SSH keys allowed? How many login nodes are there?
2. **Fairshare, priority and QOS.** There is no documentation of fairshare, priority weights, QOS, per-user core/GPU caps on `general`, `week` or `nvgpu`, or what happens once a group exceeds its tier's CU band (hard stop or just a tier review).
3. **Job arrays.** There is no VACC guidance and no `MaxArraySize`.
4. **Default time and memory** for `week` and `nvgpu`, and the name of the classroom GPU partition.
5. **Regulated data.** There is no HIPAA, PHI or CUI statement for the VACC, and no compliance scope or launch confirmation for the "Secure Cluster" (summer 2026).
6. **Prices** for extra GPFS storage and for condo/dedicated hardware. There is no public condo policy beyond "must join Tier 2 or 3" and MOUs.
7. **DataMountain access.** How users request MongoDB access is not documented.
8. **BlackDiamond retirement date and final specs.** The relevant pages now 404.
9. **Workshop schedule** for 2026. The presentations archive was not read.
10. **Vendor confirmation** for most CPU SKUs. Only the Xeon 6740E and the NVIDIA GPUs were checked against vendor pages.
11. **Per-job `/tmp`.** Its backing and size are undocumented.
12. **Node-name scheme** for the IB groups `ib1`/`ib2`/`ib3`.

**Conflicts and stale items to treat with care:**
- Founding year: 2003 ([Mission](https://www.uvm.edu/vacc/mission-and-history)) or 2005 ([IceCore news](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm)).
- IceCore InfiniBand: 200 Gb (spec page) or NDR 400 Gb (maintenance log).
- EPYC 9655 node count: 16 (spec page) or 17 (maintenance log).
- gpfs1 backups: "approximately 3 times a week" (Cost page) or daily with 7d/4w/3m retention (user docs).
- DeepGreen size: 80 GPUs / >1 PF (2019 news) or "over 70 GPUs" / >8 PF mixed precision (Mission page).
- IceCore speed-up: "25-fold" (news) or "100 times faster" (Mission page).
- FP64-capable GPU count: "112" against the 4 + 8 + 104 = 116 implied by the same page's inventory.
- H200 memory: 140 GB (VACC GPU page and feature tag) or 141 GB (spec page and NVIDIA). H200 NVL link: about 300 GB/s (VACC) or 900 GB/s (NVIDIA).
- Intel MPI: "not supported" (Slurm Examples) or "use oneapi" (MPI page).
- `gpu-preempt` has 2 CRREL H200 nodes (partitions page), but GoldenMaple is "three" nodes (maintenance log).
- Stale cluster lists (BlackDiamond/DeepGreen, "4,500 cores") on the ETS catalogue, the ETS Research Computing page and the UVM KB. Stale `python3.12-anaconda` example in the Module Collections docs. DeepGreen still mentioned on the Services and Cost pages.
- The OOD version is given as "2.4.4" on 2026-06-10, which looks inconsistent with upstream numbering. Unverified.
- The SSH page's example prompts mention `login.uvm.edu`, but the documented host is `login.vacc.uvm.edu`.
- The "multiple nodes" Slurm example uses `--nodes=1`.
