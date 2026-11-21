# UVM VACC (Vermont Advanced Computing Center): research notes

Compiled 2026-11-11 from primary sources. "(my arithmetic)" marks derived figures. **Uncertain**, **Conflict** and **Not found** mark doubtful points.

## Contents

1. [What the VACC is](#what-the-vacc-is)
2. [Who runs it, and contacts](#who-runs-it-and-contacts)
3. [Systems at a glance](#systems-at-a-glance) → details in **[hardware.md](hardware.md)**
4. [Access in one minute](#access-in-one-minute) → details in **[access.md](access.md)** (eligibility, login, tiers, costs)
5. [Scheduler in one minute](#scheduler-in-one-minute) → details in **[slurm-and-jobs.md](slurm-and-jobs.md)**
6. [Software in one minute](#software-in-one-minute) → details in **[software.md](software.md)**
7. [Storage in one minute](#storage-in-one-minute) → details in **[storage.md](storage.md)** (filesystems, quotas, Globus, compliance)
8. [Training, office hours, support](#training-office-hours-support)
9. [Acknowledgement / citation text](#acknowledgement--citation-text)
10. [Source map](#source-map)
11. [Open questions / not found](#open-questions--not-found)
12. [serving-an-llm.md](serving-an-llm.md) covers running an LLM service on the VACC. The full gpt-oss-120b + vLLM + Flask plan is in [../gpt-oss-deployment/README.md](../gpt-oss-deployment/README.md).

## What the VACC is

- UVM's research computing facility: HPC clusters for large-scale computation, low-latency MPI networking, and AI/ML workflows, for UVM faculty, staff and students ([VACC home](https://www.uvm.edu/vacc)).
- Older pages call it the Vermont Advanced Computing **Core** ([ETS catalog](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc)). It is sponsored by the Office of the VP for Research and ETS, and funded by a tiered fee policy ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).
- UVM policy: "The VACC is the default research computing environment and should be used whenever possible for all compute needs" ([ETS Research Computing](https://www.uvm.edu/it/research-computing)).

## Who runs it, and contacts

From [Contact Us](https://www.uvm.edu/vacc/contact-us):
- **Director:** Chris Danforth (also PI of the IceCore NSF award, [NSF 2510406](https://api.nsf.gov/services/v1/awards/2510406.json)).
- **Executive Director:** Andrea (Andi) Elledge, aelledge@uvm.edu. Billing, funding and vouchers ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).
- **IT staff:** Mike Austin (CTO), Jim Lawson (Research Computing Team Lead), Bennet Fauber, Travis Bartlett, Robert Minvielle (Sr. Systems Engineers), Katy Czar, Evan Hinchliffe (Systems Engineers), Shelly Johnson (Sr. Research Facilitator), Terry Barrett (Development Team Leader, Spatial Analysis Laboratory).
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
| **IceCore** | GPU | 104 × H200 (16 nodes × 4 NVL + 5 nodes × 8 SXM) and 48 × RTX Pro 6000 (6 × 8), plus 8 × H100 and 4 × A100. 1 TB RAM per node. 100 GbE plus 200 Gb IB (**Conflict:** maintenance log says NDR 400 Gb) |
| **DataMountain** | Sharded MongoDB | 8 nodes × 2 × Xeon 6348 (56 cores), 8 TB RAM each |
| **Secure Cluster** | Planned | 3 × L40S GPU nodes, 1 × 1.5 TB node, 2 Proxmox nodes. "Summer 2026" |
| Storage | GPFS (IBM Spectrum Scale) | 2.8 PB, about 25% flash. 4 I/O nodes with HDR IB |

DeepGreen (V100) was retired 2026-03-09 and BlackDiamond (AMD MI50) is retired ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). Full tables: **[hardware.md](hardware.md)**.

## Access in one minute

- **Eligible:** UVM PIs (faculty, and post-docs optionally) apply. Students, staff and external collaborators must be **sponsored by a PI** (externals need a UVM NetID requested by the PI). Export-control screening applies ([Request Allocation](https://www.uvm.edu/vacc/request-allocation); [Getting an account](https://www.uvm.edu/vacc/docs/start_guide/request_acct/)).
- **Apply:** a short form (project title, lay summary, needs, tier, funding). Sponsored users are added through the [PI dashboard](https://vacc.w3.uvm.edu/accounts/owner_detail.php).
- **Log in:**
  - `ssh netid@login.vacc.uvm.edu` with the NetID password, no VPN needed ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
  - Web: **https://ondemand.vacc.uvm.edu**, which needs campus or VPN ([OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)).
  - MFA requirements: **not documented.**
- **Cost (FY26)** ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)):
  - Tier 1 is free for UVM faculty and staff (under 250k CU/yr).
  - Tier 2 is $1,000 (250k to 3M CU).
  - Tier 3 is $4,000 (over 3M CU).
  - 1 CU = 1 core-hour = 1 GPU-minute.
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
- **Miniforge replaced Anaconda** (2026, licence reasons).
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

- **Research Computing Virtual Café:** drop-in office hours on Microsoft Teams with ETS Research Computing. Fall 2026: alternating Thursdays 9:00 to 10:30 and Mondays 14:00 to 15:30, Sept 10 to Dec 7; none on Nov 23 ([Research Computing Events](https://www.uvm.edu/it/research-computing-events)).
- **One-on-one onboarding** through vacchelp@uvm.edu ([Services](https://www.uvm.edu/vacc/services-we-provide)).
- **Programming assistance** from Research Facilitators, funded through grants ([Services](https://www.uvm.edu/vacc/services-we-provide)).
- **Workshops:** occasional; archive linked from [ETS Research Computing](https://www.uvm.edu/it/research-computing). No 2026 schedule found.
- **HPC in the classroom:** Jupyter on OOD, with GPU reservations for class time ([Services](https://www.uvm.edu/vacc/services-we-provide)).

## Acknowledgement / citation text

From [Citations and Assets for Grants](https://www.uvm.edu/vacc/citations-and-assets-grants). Acknowledgement is **required**; also email publication details and DOI to vacc@uvm.edu.

- **BlueMoon:** "The authors acknowledge the Vermont Advanced Computing Center (VACC) at the University of Vermont for providing computational resources that have contributed to the research results reported within this paper."
- **IceCore:** the same sentence, plus "Specifically, computations were supported by the National Science Foundation under Award No. 2510406."
- **SOCKS:** the same sentence, plus "Specifically, this material is based upon work supported by the National Science Foundation under Award No. 2242829."
- A Word document of cluster specs for grant proposals is linked from that page.
- Grant budget boilerplate (line F6021, account code 80047): see [access.md](access.md#paying).

## Source map

- VACC site: [home](https://www.uvm.edu/vacc), [mission-and-history](https://www.uvm.edu/vacc/mission-and-history), [cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications), [cost-and-payment](https://www.uvm.edu/vacc/cost-and-payment), [request-allocation](https://www.uvm.edu/vacc/request-allocation), [citations-and-assets-grants](https://www.uvm.edu/vacc/citations-and-assets-grants), [services-we-provide](https://www.uvm.edu/vacc/services-we-provide), [data-management](https://www.uvm.edu/vacc/data-management), [artificial-intelligence-workloads](https://www.uvm.edu/vacc/artificial-intelligence-workloads), [contact-us](https://www.uvm.edu/vacc/contact-us).
- VACC user docs: [uvm.edu/vacc/docs](https://www.uvm.edu/vacc/docs/) (48 pages), including the [Maintenance log](https://www.uvm.edu/vacc/docs/maintenance/).
- ETS: [Research Computing](https://www.uvm.edu/it/research-computing), [Events / Virtual Café](https://www.uvm.edu/it/research-computing-events), [VACC service catalogue](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc), [KB: VACC](https://uvm.edu/it/kb/article/vermont-advanced-computing-center), [KB: Globus](https://www.uvm.edu/it/kb/article/globus-data-transfer-service/), [Secure Enclave](https://www.uvm.edu/it/secure-enclave).
- Awards: [NSF 2510406](https://api.nsf.gov/services/v1/awards/2510406.json) (IceCore), [NSF 2242829](https://api.nsf.gov/services/v1/awards/2242829.json) (SOCKS).
- Vendors: [NVIDIA H200](https://www.nvidia.com/en-us/data-center/h200/), [NVIDIA RTX PRO 6000 Server](https://www.nvidia.com/en-us/data-center/rtx-pro-6000-blackwell-server-edition/), [Intel Xeon 6740E](https://www.intel.com/content/www/us/en/products/sku/240359/intel-xeon-6740e-processor-96m-cache-2-40-ghz/specifications.html).

## Open questions / not found

**Not found on any primary page:**
1. **MFA and SSH keys:** whether SSH requires Duo, whether keys are allowed, number of login nodes.
2. **Fairshare, priority, QOS:** no weights, QOS, per-user caps on `general`/`week`/`nvgpu`, or what happens when a group exceeds its tier's CU band.
3. **Job arrays:** no VACC guidance, no `MaxArraySize`.
4. **Defaults:** time and memory for `week` and `nvgpu`; name of the classroom GPU partition.
5. **Regulated data:** no HIPAA/PHI/CUI statement; no compliance scope or launch confirmation for the "Secure Cluster".
6. **Prices:** extra GPFS storage and condo/dedicated hardware.
7. **DataMountain access:** request process undocumented.
8. **Per-job `/tmp`:** backing and size undocumented.
9. **IB groups:** which nodes are in `ib1`/`ib2`/`ib3`.

**Conflicts that affect which number to use:**
- IceCore InfiniBand: 200 Gb (spec page) or NDR 400 Gb (maintenance log).
- EPYC 9655 node count: 16 (spec page) or 17 (maintenance log).
- gpfs1 backups: "approximately 3 times a week" (Cost page) or daily with 7d/4w/3m retention (user docs).
- H200 memory: 140 GB (VACC GPU page, `GPU_MEM:140GB` tag) or 141 GB (spec page, NVIDIA). H200 NVL link: ~300 GB/s (VACC) or 900 GB/s (NVIDIA).
- FP64-capable GPU count: "112" vs 4 + 8 + 104 = 116 from the same page's inventory.
- Intel MPI: "not supported" (Slurm Examples) or "use oneapi" (MPI page).
- `gpu-preempt`: 2 CRREL H200 nodes (partitions page) vs GoldenMaple "three" nodes (maintenance log).
- SSH page example prompts show `login.uvm.edu`; the documented host is `login.vacc.uvm.edu`.
- The "multiple nodes" Slurm example uses `--nodes=1`.
