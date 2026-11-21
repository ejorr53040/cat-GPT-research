# Serving an LLM from the VACC: policy, networking, long runs, alternatives, cost

Back to [README](README.md). Compiled 2026-11-13 from primary sources. "(my arithmetic)" marks derived numbers; "(my observation)" marks network checks run from off campus. **Uncertain**, **Conflict** and **Not found** mark doubtful points.

Scope: a fine-tuned gpt-oss-120b served by vLLM on VACC GPUs, behind a Flask app that end users reach with an API key. Covers whether VACC/UVM allow it and how; not vLLM flags or Flask code.

## Contents

1. [Short answer](#short-answer)
2. [Allowed / not allowed / undocumented](#allowed--not-allowed--undocumented)
3. [Policy](#policy)
4. [Networking](#networking)
5. [Long runs and keeping a service up](#long-runs-and-keeping-a-service-up)
6. [Alternatives at UVM](#alternatives-at-uvm)
7. [Costs](#costs)
8. [Data: prompts, FERPA, PHI](#data-prompts-ferpa-phi)
9. [Who to contact, and a draft email](#who-to-contact-and-a-draft-email)
10. [Open questions](#open-questions)

## Short answer

- **No VACC page allows or forbids an always-on inference service.** vLLM inside a Slurm job is an expected workload: "LLM inference servers like vLLM", "LLM inference (vLLM, TGI)" ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/)). Nothing covers 24/7 operation or exposing it to users.
- **UVM server rule:** "servers are the responsibility of official IT units sanctioned by the CIO and should not be run by individuals or individual groups unless a formal approval and documentation process has occurred"; a server is "a host that provides a network accessible service" ([UVM Data Classification Matrix, 2025-07](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf)). A user-facing API fits that definition, so approval is required before launch.
- **GPU jobs are capped at 48 h** (`nvgpu`). The only other GPU partition, `gpu-preempt`, cancels outside jobs ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)). 24/7 service = ~183 resubmissions/year, each subject to queue wait (my arithmetic: 8,760 h ÷ 48 h).
- **Compute nodes are not reachable from outside.** Only SSH to `login.vacc.uvm.edu` is public; OOD needs campus or VPN. No documented port forwarding or route from a web host to a compute node.
- **Cost: tiers are flat fees.** 1 GPU all year = 525,600 CU (Tier 2, $1,000); 8 GPUs all year = 4,204,800 CU (Tier 3, $4,000); 1 GPU for a 15-week semester = 151,200 CU (free Tier 1) (my arithmetic; [Costs](#costs)).
- **Data classification conflicts.** Matrix: VACC approved for **Low Risk** only. UVM AI tools page: "VACC Research Computing AI" **Low to Moderate**, High with consultation. Non-health FERPA records are Moderate. IRB policy bars AI tools from identifiable FERPA data in human-subjects research.

## Allowed / not allowed / undocumented

"Allowed" = a primary page says so. "Not allowed" = a page forbids it or a rule clearly covers it. "Undocumented" = nothing found either way.

| Item | Status | Basis |
| --- | --- | --- |
| Run vLLM inside a Slurm GPU job | **Allowed** | GPU Features names vLLM and TGI and gives constraints ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/)) |
| GPU job longer than 48 h on `nvgpu` | **Not allowed** | "maximum time of 48 hours" ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)) |
| GPUs in `week` (7 days) | **Undocumented**, probably none [INFERENCE] | `week` "runs on a smaller set of nodes than the general partition"; `general` "does not contain nodes with GPUs" ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)) |
| `gpu-preempt` (CRREL H200s) for a service | **Allowed, jobs can be cancelled**; max time not stated | "Do not submit jobs to this partition if you are not willing to have them cancelled" ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)) |
| Persistent/always-on service on compute nodes | **Undocumented** | No VACC page mentions services, daemons or uptime; the UVM server rule applies |
| Network-accessible server run by an individual or group | **Needs approval** | Data Classification Matrix "servers" note ([Short answer](#short-answer)) |
| Flask app or any long-lived process on a login node | **Not allowed** under the guidelines | Login nodes are for "editing source/command files and running short test programs", ~<5 min, <5 GB, ≤2 CPUs ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/#login-vs-compute-nodes)); "Please do not use VS Code to ssh to the login nodes" ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)) |
| Inbound connections to compute nodes | **Undocumented**; node names do not resolve publicly (my observation) | [Networking](#networking) |
| SSH port forwarding (`ssh -L`) via login nodes | **Undocumented** | No VACC doc mentions it |
| OOD `/node/` or `/rnode/` proxy | **Undocumented**; would still need OOD login plus campus/VPN | [Networking](#networking) |
| Outbound internet from GPU nodes (HF, pip, conda) | **Works per VACC's own scripts; no written policy** | VACC's `llama-4-setup` builds a conda+pip env (incl. `git+https://github.com/...`) in an `nvgpu` job ([build script](https://gitlab.uvm.edu/vacc-tools/llama-4-setup/-/raw/main/benchmarking_setup/build_benchmarking_conda_env.sbat); [environment.yaml](https://gitlab.uvm.edu/vacc-tools/llama-4-setup/-/raw/main/benchmarking_setup/environment.yaml)). OOD VS Code Tunnel runs on a compute node and makes "outbound connections to a service hosted in Azure" ([VACC VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/); [VS Code docs](https://code.visualstudio.com/docs/remote/tunnels)) |
| Docker | **Not available**; Apptainer 1.3.4 only | [software.md](software.md#containers) |
| VACC login without a UVM NetID | **Not allowed** without PI sponsorship and a NetID | [access.md](access.md#who-is-eligible); [Request Allocation](https://www.uvm.edu/vacc/request-allocation) |
| End users without VACC accounts calling a VACC-hosted API | **Undocumented**; AUP may apply | AUP forbids "allowing others to use one's University-provided information and communication technology services except as otherwise permitted" ([Policy 1.8.2 PDF](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf), §4.b.ix). Whether serving outputs counts as "use" is for VACC/ISO |
| Commercial use / private enterprise | **Not allowed** | "not to use computers ... for the operation of private enterprises" ([AUP 1.8.2](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf), item 7) |
| Adding a network service to the UVM network | **Needs ETS approval** beyond "properly configured computers and printers" | "no other device or network service ... may be placed on the network without approval from ETS Telecommunication and Network Services" ([AUP 1.8.2](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf), §4.f). Whether a software API counts is **Uncertain** |
| Admin GPU reservation for a service | **Undocumented** for research; exists for classes | "class time-based reservation system" ([Services](https://www.uvm.edu/vacc/services-we-provide)); only root or SlurmUser can create reservations ([Slurm reservations](https://slurm.schedmd.com/archive/slurm-25.11.2/reservations.html)) |
| Self-requeue (`scontrol requeue`) or `--dependency` chaining | **Undocumented** at VACC; standard Slurm | Only VACC mention is `REQUEUE` in a `--mail-type` comment ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/#submitting-a-job-with-sbatch)) |
| Fine-tuned model in central `/gpfs1/llm` | **Allowed on request**; judged on efficiency, security, demand | [Sharing LLMs](https://www.uvm.edu/vacc/docs/start_guide/sharing_llms/#requesting-a-model-be-added-to-the-central-library) |
| Regulated data (PHI, CUI) on main VACC | **Not allowed** (Restricted; VACC is Low only) | [Data Classification Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf); [storage.md](storage.md#security-and-compliance) |
| Moderate data (e.g. non-health FERPA) on VACC LLMs | **Conflict** | Matrix: Low only. [AI tools page](https://www.uvm.edu/ai/supported-and-approved-ai-tools): Low to Moderate |

## Policy

### What VACC pages say

- **AI Workloads page** covers only environmental claims; nothing on inference, serving, users or limits ([AI Workloads](https://www.uvm.edu/vacc/artificial-intelligence-workloads)).
- **GPU Features:** "LLM inference servers like vLLM are memory-bound. The primary concern is fitting the model in VRAM." Recommends `GPU_MEM:140GB` or `GPU_MEM:96GB` for "LLM inference (vLLM, TGI)" ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/#summary)).
- **Scope:** "a research facility offering computing services to UVM faculty, staff and students" ([VACC home](https://www.uvm.edu/vacc)); teaching use supported ("HPC in the Classroom", [Services](https://www.uvm.edu/vacc/services-we-provide)).
- **Login nodes:** "cluster users are expected to submit most computations to the job scheduler" ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/#login-vs-compute-nodes)). An all-day web server falls outside these guidelines.
- **Acceptable-use / services policy page:** **Not found** on the VACC site or docs.
- **"VACC Locally Hosted LLMs":** the UVM AI site's link with this label points to `/vacc/services-we-provide`, which has no LLM content ([AI tools page](https://www.uvm.edu/ai/supported-and-approved-ai-tools); [Services](https://www.uvm.edu/vacc/services-we-provide)). Researcher guidelines say VACC "hosts local LLMs for research use that provides data protection in a closed environment" ([Guidelines for Researchers](https://www.uvm.edu/ai/guidelines-researchers)). **Not found:** any published VACC-hosted LLM *service*. What exists: the `/gpfs1/llm` model library, `ollama`/`llama.cpp` modules, and `llama-4-setup` batch scripts ([software.md](software.md#ai--llm-resources)).

### UVM-wide rules that apply

- **Server approval** ([Data Classification Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf), "Server Risk Classification Examples"): servers "should not be run by individuals or individual groups unless a formal approval and documentation process has occurred. If you believe data is being run on local servers and not going through Enterprise Technology Services, contact the Information Security Office." A "Server requiring NetID or LCOM username authentication" is **Moderate**; one that "does not require user authentication and only contains low risk data" is **Low**. API-key auth is unclassified; **Uncertain** where it lands.
- **AUP** ([Policy 1.8.2, effective 2010-04-12](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf); [policy page](https://www.uvm.edu/policies/computer-communication-and-network-technology-acceptable-use)):
  - §1.a: accounts "may only be used by the individual to whom they are assigned".
  - §4.b.ix: no "allowing others to use one's University-provided ... services except as otherwise permitted".
  - §4.f: no "network service ... without approval from ETS Telecommunication and Network Services".
  - Item 7: no "operation of private enterprises".
  - Application to an LLM endpoint is **Uncertain**; needs an ETS/ISO answer.
- **Non-UVM users:** no page addresses serving outputs to them. External VACC *accounts* need PI sponsorship, a UVM NetID and export-control screening, with "significant restrictions on providing goods or services ... to Iranians and Iranian institutions" ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)). Whether screening extends to API users is **Not found**; ask exportcontrols@uvm.edu if external users are planned.
- **Contract review:** "If your department wants to purchase solutions with AI components, they must go through Contract Review" ([AI tools page](https://www.uvm.edu/ai/supported-and-approved-ai-tools)). A self-hosted open-weight model is not a purchase; **Uncertain** whether it applies.

## Networking

### What is reachable from where

| Endpoint | Reachability | Source |
| --- | --- | --- |
| `login.vacc.uvm.edu:22` | Public, no VPN: "you do not need to be connect to the UVM VPN to access the VACC via SSH" | [SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/). Resolves to 132.198.57.101/.103/.104; TCP 22 open off campus (my observation) |
| `ondemand.vacc.uvm.edu:443` | Campus or VPN only | [OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/). Off-campus TCP 443 rejected (my observation) |
| Slurm dashboard | Campus or VPN only | [Slurm Status Dashboard](https://www.uvm.edu/vacc/docs/start_guide/slurmdash/) |
| Compute/GPU nodes (e.g. `h2xnode01`, `*.cluster`) | **Not found**; names do not resolve in public DNS (my observation). Reachability from campus hosts (Silk, research VMs) **Not found** | [GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/); [User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/) |
| Inbound ports on compute nodes | **Not found**; no firewall/port policy published | — |
| Outbound from compute nodes | Works in practice (see table above); **no written policy**, no proxy settings documented | — |

### Tunnelling and port forwarding

- **No SSH tunnel pattern is documented.** The only "tunnel" is the OOD **VS Code Tunnel** app: it "will launch a VS Code Tunnel on a compute node", authenticates with a Microsoft UVM account, and "Connecting to the VS Code tunnel using the URL via a web browser is not supported" ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)). It relays via "Microsoft dev tunnels" over outbound connections to Azure ([VS Code docs](https://code.visualstudio.com/docs/remote/tunnels)).
- **Jupyter** is offered only as an OOD app; no `ssh -L` recipe ([OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/#interactive-apps); [JupyterLab](https://www.uvm.edu/vacc/docs/beyond_basics/jupyter_lab/)).
- **Generic pattern (not VACC-documented):** `ssh -L 8000:<gpu-node>:8000 netid@login.vacc.uvm.edu`. Requires `AllowTcpForwarding` on login nodes (**Not found**); Duo MFA on SSH **Not found** ([access.md](access.md#ssh)). An unattended tunnel would need non-interactive auth; SSH keys are undocumented.
- **Third-party relays** (dev tunnels port forwarding, ngrok, Cloudflare Tunnel) bypass the missing inbound route but expose a UVM-hosted service without the approval required by the Matrix and AUP §4.f. Not addressed by any page; require written approval.

### Open OnDemand proxy (`/node/`, `/rnode/`)

- Upstream OOD: "The reverse proxy will proxy a request to any specified host and port ... This is disabled by default." `/node/<host>/<port>/...` passes the full path; `/rnode/<host>/<port>/...` strips the prefix; hosts limited by `host_regex` ([OOD: Enable Reverse Proxy](https://osc.github.io/ood-documentation/latest/how-tos/app-development/interactive/setup/enable-reverse-proxy.html); [ood_portal.yml reference](https://osc.github.io/ood-documentation/latest/reference/files/ood-portal-yml.html#configure-reverse-proxy)).
- VACC runs Jupyter and RStudio as OOD apps, which use this proxy, so it is probably enabled [INFERENCE]; `host_regex` unknown.
- **Not usable as a public API front door:** every request needs a UVM NetID login and campus/VPN ([OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)). Usable only for on-campus developer browser testing.

### Implication for the architecture [INFERENCE]

No published path exists from the internet or another UVM host to a GPU-node port. Each design needs VACC/ETS approval:
1. VACC opens a route from a specific campus host (Silk or a research VM running Flask) to the GPU nodes.
2. VACC runs an approved gateway.
3. The service runs off the main cluster.

A reverse connection from the GPU job to the Flask host (e.g. job-initiated SSH tunnel) uses only outbound connectivity, but is still a network service under the Matrix definition and needs the same approval.

## Long runs and keeping a service up

### VACC facts

- `nvgpu`: 48 h, "no memory limit". `general`: 48 h, no GPUs. `week`: 1 week, "smaller set of nodes", no GPU statement. `short`: 3 h. `gpu-debug`: 3 h, 1 GPU, 1 running job/user, "should not be used to run jobs". `gpu-preempt`: CRREL H200s, max time not stated, outside jobs cancelled ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/); [slurm-and-jobs.md](slurm-and-jobs.md#partitions)).
- **Maintenance:** "Jobs that would run into this maintenance window will not be permitted to start until after the maintenance is complete." Next window **2027-01-05** ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). For 48 h jobs: no new start in the 48 h before a window (my arithmetic); service down for the whole window (2026-08-18 ran ~07:00–18:00).
- **No SLA published** (**Not found**); 2026 power work ran the cluster at reduced capacity with non-UPS circuits ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/#mayjune-2026)).
- **Reservations:** only the classroom system is mentioned ([Services](https://www.uvm.edu/vacc/services-we-provide)); "Reservations can be created, updated, or destroyed only by user root or the configured SlurmUser" ([reservations, 25.11.2](https://slurm.schedmd.com/archive/slurm-25.11.2/reservations.html)). A standing GPU reservation must come from VACC admins.
- **Requeue, `--signal`, `--dependency`:** not in VACC docs. Standard behaviour: [../slurm/job-scripts.md](../slurm/job-scripts.md), [../slurm/cheatsheet.md](../slurm/cheatsheet.md). Site settings (`JobRequeue`, `bf_window`, preemption, QOS) need `scontrol show config` ([../slurm/README.md](../slurm/README.md#vacc-gaps-the-slurm-docs-help-explain)).

### Generic Slurm options (Slurm 25.11.2, the version VACC runs)

Quotes from [sbatch(1), 25.11.2](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) unless noted.

| Option | What it does | Use for a service |
| --- | --- | --- |
| `--signal=[{R\|B}:]<sig>[@sig_time]` | "When a job is within sig_time seconds of its end time, send it the signal"; "may be sent up to 60 seconds earlier". `B:` signals "only the batch shell" | Drain vLLM, deregister the endpoint, or requeue |
| `scontrol requeue <jobid>` | "Requeue a running, suspended or finished Slurm batch job into pending state" ([scontrol(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html)); restarts "from its beginning with the same job ID" | Self-requeue from a `--signal` trap; job returns to **pending**, so there is a gap |
| `--requeue[=expedited]` | Requeue after node failure/preemption; `expedited` = "the highest possible priority" only if `SlurmctldParameters=enable_expedited_requeue` | Survive node failures; VACC setting unknown |
| `--dependency=after:<jobid>+<min>` | Starts once the named job has started and `<min>` minutes have passed | **Overlapping hand-off:** successor eligible ~1 h before the 48 h limit; still must win the queue |
| `--dependency=singleton` | "only one job by that name and owned by that user can be running or suspended at any point in time" | Prevents duplicates; also prevents overlap, so not for zero-gap hand-off |
| `--time-min` | Lets backfill shorten the time limit to start sooner | Successor starts in a gap, with a shorter run |

Patterns for crossing the 48 h limit (generic; not VACC-documented):
1. **Overlapping relay (minimal downtime).** Job *n* runs vLLM and publishes `host:port` to GPFS or the frontend; at start it submits *n+1* with `--dependency=after:$SLURM_JOB_ID+2820` (47 h). When *n+1* is healthy, the frontend switches and *n* exits. Cost: ~2.1% extra GPU time (my arithmetic: 1 ÷ 47); the overlap needs double the GPUs (e.g. 2 × 4 H200s).
2. **Signal and self-requeue (fewest moving parts).** `#SBATCH --signal=B:USR1@600` plus `trap 'scontrol requeue $SLURM_JOB_ID' USR1`. Same job ID; down from requeue until restart plus model load.
3. **Ask VACC** for a reservation, a QOS with longer `MaxWall`, or condo nodes (all admin-side, undocumented).

Frequency: 182.5 hand-offs/year, 52.5 per 15-week semester (my arithmetic: 8,760 h or 2,520 h ÷ 48 h).

## Alternatives at UVM

| Option | What it offers | Fit for Flask frontend | Fit for inference endpoint | Source |
| --- | --- | --- | --- | --- |
| **Silk** web hosting (ETS SAA) | Free to students, faculty, staff. Python **WSGI** via NGINX Unit (apps "cannot be started as a service that directly listens for network requests"). Python 3.10/3.12/3.14. 20 GB disk; "most sites are limited to 4GB of simultaneous memory". TLS included. `<netid>.w3.uvm.edu`, or `*.uvm.edu` with web-team approval. Restarts Tuesdays 2:00–2:30 am. Daily backups | **Fits:** Flask is WSGI; Silk supports "a custom web application" ([KB: web hosting options](https://www.uvm.edu/it/kb/article/uvm-web-hosting-options/)). SSE streaming under NGINX Unit **Uncertain** | No GPUs | [Silk hosting overview](https://silk.uvm.edu/hosting-questions); [Silk Python](https://silk.uvm.edu/manual/python); [ETS catalog: Silk](https://catalog.etsweb.w3.uvm.edu/it/catalog/service/web-hosting-silk) |
| **ETS Research VMs** | VMware, RHEL 8/9 or Windows Server 2019. Faculty get "one free VM" (12 cores, 48 GB RAM, 100 GB); larger ~$2,990 or ~$6,525 one-time for 5 years. "there is no queue for work". ETS-managed patching. For "production code/applications that cannot run on the VACC". Access requires "the UVM network" (VPN or Zoo) | **Fits** Flask or an API gateway. Public exposure (firewall, DNS) **Not found**; ask SAA | VM page lists 5 × R7525, **no GPUs**. **Conflict:** 2026 report says "4 x NVIDIA L40 GPUs" (48 GB each, [NVIDIA L40](https://www.nvidia.com/en-us/data-center/l40/)), below gpt-oss-120b's "single 80GB GPU" ([model card](https://huggingface.co/openai/gpt-oss-120b)); would need multi-GPU tensor parallelism | [Research VMs](https://www.uvm.edu/it/research-computing-virtual-machines); [KB: Research VMs remote access](https://www.uvm.edu/it/kb/article/research-vms-remote-access/); [Spring 2026 Research Computing Report](https://www.uvm.edu/d10-files/documents/2026-05/Spring2026_ResearchComputingReport.pdf), p. 12 |
| **"Secure Cluster" / Secure Enclave** | Spec page: "Will Be Available Summer 2026"; three GPU nodes "each equipped with an NVIDIA L40S GPU", one 1.5 TB node, "Two Proxmox Nodes" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)). Report: VDI-based Secure Enclave "launched spring 2026", NIST 800-171; separate restricted-data VACC cluster targeting NIST 800-223 "before the end of 2026" ([report](https://www.uvm.edu/d10-files/documents/2026-05/Spring2026_ResearchComputingReport.pdf), p. 12). **Conflict** on launch timing | Unlikely: VDI-based, restricted networking ([storage.md](storage.md#security-and-compliance)) | **Poor:** one 48 GB L40S per node ([NVIDIA L40S](https://www.nvidia.com/en-us/data-center/l40s/)) < 80 GB model footprint | as cited |
| **Dedicated / condo nodes** | "If you purchase dedicated hardware for the VACC, you are required to join Tier 2 or Tier 3"; MOUs stay in effect ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)). Owner partitions exist (`goldenmaple`, `hgnodes`) ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)) | — | Only route to a GPU without the 48 h limit, if VACC permits longer jobs on owner nodes. Owner walltime, prices, network exposure **Not found** | as cited |
| **Existing UVM LLM services** | Microsoft Copilot (Low–High), Anthropic Claude (Low–Moderate, High with consultation), "VACC Research Computing AI" ("Run open-source large language models on high-performance computing systems", on request via [Research Computing Facilitation](https://www.uvm.edu/it/research-computing-facilitation)), VACC Transcription (Whisper) ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools)). ETS: multi-model AI service "targeted for an initial winter deployment and broader production use in the spring"; evaluating "multi-model gateways for programmatic access" ([ETS news](https://www.uvm.edu/it/news/expanding-uvms-ai-tools-and-services); [AI Taskforce Fall 2026](https://www.uvm.edu/it/news/ai-taskforce-updates-fall-2026)) | Replaces a custom frontend only if it can host a custom fine-tune (**Not found**) | No published API endpoint for a custom model; ask ets-ai@uvm.edu | as cited |

UVM's research-computing framework puts the VACC first, then "UVM's Virtual Server Environment ... in those cases where the VACC does not meet a researcher's needs" ([ETS Research Computing](https://www.uvm.edu/it/research-computing)).

## Costs

Rules: 1 CU = 1 GPU-minute or 1 core-hour. Flat yearly fees per PI group (UVM fiscal year): Tier 1 free (<250,000 CU, UVM faculty/staff only), Tier 2 $1,000 (250,000–3,000,000), Tier 3 $4,000 (>3,000,000). Usage is pooled across the PI and all sponsored users ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment); [PI info: compute](https://www.uvm.edu/vacc/docs/pi-info/compute/); [access.md](access.md#allocations-tiers-and-compute-units)).

All figures are my arithmetic. Year = 8,760 h; 15-week semester = 2,520 h.

| GPUs | GPU CU / year, 24/7 | Tier | GPU CU / semester | Tier | + 16 cores/GPU, year | Tier | + 16 cores/GPU, semester | Tier |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 525,600 | 2 ($1,000) | 151,200 | 1 (free) | 665,760 | 2 | 191,520 | 1 |
| 2 | 1,051,200 | 2 ($1,000) | 302,400 | 2 ($1,000) | 1,331,520 | 2 | 383,040 | 2 |
| 4 | 2,102,400 | 2 ($1,000) | 604,800 | 2 ($1,000) | 2,663,040 | 2 | 766,080 | 2 |
| 8 | 4,204,800 | 3 ($4,000) | 1,209,600 | 2 ($1,000) | 5,326,080 | 3 ($4,000) | 1,532,160 | 2 |

Notes:
- **CPU cores in GPU jobs billed? Uncertain.** The `my_compute_usage` example sums 10 CPU-hours + 5.5 GPU-hours = 340 CU (10 + 5.5 × 60) ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/#my_compute_usage)), but does not show whether the CPU-hours came from the GPU job. "+16 cores/GPU" columns assume they are billed; 16 = 8× H200 SXM node ratio (128 ÷ 8). 4× H200 NVL nodes have 48 cores/GPU (192 ÷ 4) ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).
- **Thresholds:** Tier 1 ≈ 4,167 GPU-hours (≈174 GPU-days). Tier 2 tops out ≈ 5.7 GPUs all year.
- **Semester figure assumes no other PI-group usage.** 1 GPU/semester leaves ~98,800 Tier 1 CU for everything else, including fine-tuning. Relay overlap (+2.1%) and fine-tuning push toward Tier 2.
- **GPU count:** stock MXFP4 gpt-oss-120b fits "into a single 80GB GPU" ([model card](https://huggingface.co/openai/gpt-oss-120b)); a fine-tune in another format plus KV-cache headroom may need more.
- **Fair share:** 8 H200s 24/7 ≈ 7.7% of the cluster's 104 H200s (my arithmetic). Usage "is evaluated twice yearly, and if it appears that an adjustment might be needed, the VACC administrator will contact you directly" ([PI info: compute](https://www.uvm.edu/vacc/docs/pi-info/compute/#compute-hour-allocation)). Consequence of exceeding a tier band **Not found** ([access.md](access.md#allocations-tiers-and-compute-units)).
- Tier fees "will change annually" ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)); figures are **FY26**.

## Data: prompts, FERPA, PHI

- **Data Classification Matrix (2025-07), "Approved Services for Research":** VACC under **Low Risk only**. Moderate = "Coded data with no additional requirements"; High = "Identifiable Data (human subject research)"; Restricted = CUI, export-controlled, PHI ([Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf)).
- **UVM AI tools page:** "VACC Research Computing AI" — "Allowed data: Low to Moderate Risk; High Risk with consultation" ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools)). **Conflict** with the Matrix; neither is more recent. Resolve with ISO before handling Moderate data.
- **FERPA classes** (Matrix, "Data Compliance Classification Examples"): non-health, non-financial FERPA = **Moderate**; "Health-related (physical and mental) FERPA data" = **High**; HIPAA = **Restricted**; "Student records and admission applications" = Moderate. Student prompts revealing coursework, grades or accommodations are probably at least Moderate [INFERENCE].
- **IRB (human-subjects research only):** IRB Policies §8.12 (2026-02-13): "The AI tool may not have access to the following data in identifiable format ... (FERPA)-protected data"; "AI tools should only be used with institutional data classified as low risk" unless contracted ([IRB Policies §8.12](https://www.uvm.edu/rpo/irb-policies-and-procedures#8p12)). Applies if prompt logs are research data about students.
- **PHI/CUI:** not on main VACC. Secure options: ETS Secure Enclave and the planned restricted-data cluster ([report](https://www.uvm.edu/d10-files/documents/2026-05/Spring2026_ResearchComputingReport.pdf), p. 12; [storage.md](storage.md#security-and-compliance)); neither has GPUs large enough for gpt-oss-120b (L40S, 48 GB).
- **Log storage on VACC:** home directories are PI-group-readable by default ([storage.md](storage.md#data-organisation-and-sharing)); prompt logs need `umask 0007` or ACLs; `/gpfs3tmp` purges after 60 days. PIs must "comply with any restrictions on access to data that may come with data use agreements" ([PI info: general](https://www.uvm.edu/vacc/docs/pi-info/general/#your-disk-usage-and-data-storage)).
- **Research VMs:** "Coded data only" ([ETS Research Computing Resources](https://www.uvm.edu/it/research-computing-resources)), equal to the Matrix's Moderate ceiling.

## Who to contact, and a draft email

| Who | For |
| --- | --- |
| **vacchelp@uvm.edu** (802-656-8867) | Services in jobs, networking, walltime, reservations, model library ([Contact](https://www.uvm.edu/vacc/contact-us)) |
| **vacc@uvm.edu**; Andi Elledge (aelledge@uvm.edu), Executive Director | Tiers, condo nodes, MOUs, Voucher Fund ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)) |
| **iso@uvm.edu** (Information Security Office) | Server approval, data classification of prompts ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools); [Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf)) |
| **saa@uvm.edu** (Systems Architecture & Administration) | Silk site, research VM, public exposure of a VM ([Silk](https://silk.uvm.edu/hosting-questions); [KB](https://www.uvm.edu/it/kb/article/research-vms-remote-access/)) |
| **ets-ai@uvm.edu** | Whether the planned multi-model gateway can front a VACC-hosted model ([ETS news](https://www.uvm.edu/it/news/expanding-uvms-ai-tools-and-services)) |
| Research Computing Facilitation ([go.uvm.edu/researchcomputingcontact](https://go.uvm.edu/researchcomputingcontact)) | "VACC Research Computing AI" requests ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools)) |
| exportcontrols@uvm.edu; IRB (Research Protections Office) | Only for non-UVM users or human-subjects research on prompts |
| Virtual Café office hours | Informal first conversation ([Events](https://www.uvm.edu/it/research-computing-events)) |

**Draft questions for vacchelp@uvm.edu** (send with the PI's Slurm account `pi-<netid>`):

1. We want to serve a fine-tuned gpt-oss-120b with vLLM to a small group of users through a Flask app with API keys. Does the VACC allow a long-running inference service on `nvgpu`? If so, under what conditions (GPU count, hours, users)?
2. Is there a supported way to keep a GPU service running past the 48 h `nvgpu` limit: a reservation, a QOS with a longer `MaxWall`, a `week`-like GPU partition, or condo nodes? Is self-requeue (`--signal` + `scontrol requeue`) or overlapping `--dependency=after:<id>+<min>` relay jobs acceptable?
3. Does `week` contain any GPU nodes?
4. Networking: can a campus host (a Silk app or an ETS research VM) open TCP connections to a port on an IceCore node? If not, can a fixed route or firewall exception be arranged? Is TCP forwarding (`ssh -L`/`-R`) enabled on the login nodes, and does SSH there require Duo?
5. Is the OOD `/node` or `/rnode` reverse proxy enabled, and for which hosts?
6. Outbound: may jobs download from Hugging Face, PyPI and GHCR/Docker Hub (for Apptainer pulls) from compute nodes? Is there a proxy or rate limit?
7. Billing: are the CPU cores and memory in a GPU job charged in addition to the GPU-minutes? Does exceeding a tier's CU band stop jobs?
8. Data: the Data Classification Matrix lists VACC as Low Risk, but the AI tools page says "VACC Research Computing AI" allows Low to Moderate. Which applies to user prompts that may contain non-health FERPA data?
9. Would you host our fine-tuned weights in `/gpfs1/llm`, or should they stay in `/gpfs1/pi/<PI>`?
10. Is there an existing VACC-hosted LLM endpoint (the "VACC Locally Hosted LLMs" link on uvm.edu/ai) we should use instead?

## Open questions

Contact in brackets.
1. Are persistent services on compute nodes allowed, and with what limits? [vacchelp@uvm.edu]
2. Does a VACC-hosted API need "formal approval" as a server under the Matrix, and who signs off? [iso@uvm.edu]
3. Do AUP §4.b.ix and §4.f cover API keys for people without VACC accounts or outside UVM? [iso@uvm.edu]
4. GPUs in `week`; walltime on `gpu-preempt`, `hgnodes` and owner partitions. [vacchelp@uvm.edu]
5. Compute-node inbound reachability, `AllowTcpForwarding`, SSH MFA, OOD `/rnode` and `host_regex`, outbound proxy policy. [vacchelp@uvm.edu]
6. CPU-core billing in GPU jobs; enforcement above a tier band. [vacc@uvm.edu]
7. VACC data class: Low (Matrix) vs Low–Moderate (AI tools page). [iso@uvm.edu]
8. Secure Cluster/Enclave launch status, whether they are the same system, what the Proxmox nodes host. [vacchelp@uvm.edu]
9. Can a research VM be exposed publicly (DNS, inbound 443); can the report's L40 GPUs be requested? [saa@uvm.edu]
10. Does SSE streaming work on Silk/NGINX Unit; can Silk reach VACC compute nodes? [saa@uvm.edu]
11. Is there an actual "VACC Locally Hosted LLMs" service? [vacchelp@uvm.edu or ets-ai@uvm.edu]
12. ETS multi-model gateway timeline; can it proxy to a custom VACC endpoint? [ets-ai@uvm.edu]
13. Condo pricing, terms, MOU template. [aelledge@uvm.edu]
14. Export control for API users outside UVM. [exportcontrols@uvm.edu]
