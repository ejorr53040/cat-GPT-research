# Serving an LLM from the VACC: policy, networking, long runs, alternatives, cost

Back to [README](README.md). Compiled 2026-11-13 from primary sources only: VACC site and user docs (the docs were read in full through their search index, `https://www.uvm.edu/vacc/docs/search/search_index.json`, 273 sections), UVM ETS pages and KB, UVM policy PDFs, the UVM AI site, the VACC Tools GitLab group, Silk docs, Open OnDemand docs, Slurm 25.11.2 man pages, and NVIDIA/Hugging Face pages. Every page was accessed on **2026-11-13**. Claims are cited inline. "(my arithmetic)" marks derived numbers, and "(my observation)" marks network checks I ran myself on 2026-11-13 from an off-campus connection (Burlington Telecom, AS33604). **Uncertain**, **Conflict**, **Stale** and **Not found** mark doubtful points.

The deployment in question is a fine-tuned gpt-oss-120b served by vLLM on VACC GPUs, with a Flask app in front that end users reach using an API key. This note covers whether the VACC and UVM allow that and how. It does not cover vLLM flags or Flask code.

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

- **No VACC page allows or forbids an always-on inference service.** Running vLLM *inside a Slurm job* is an expected workload: the GPU Features page names "LLM inference servers like vLLM" and "LLM inference (vLLM, TGI)" ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/)). Nothing covers keeping one up around the clock or exposing it to users.
- **The UVM-wide rule that matters most:** "servers are the responsibility of official IT units sanctioned by the CIO and should not be run by individuals or individual groups unless a formal approval and documentation process has occurred". A server is defined as "a host that provides a network accessible service" ([UVM Data Classification Matrix, 2025-07](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf)). An API that end users call fits that definition, so get approval before launch.
- **GPU jobs are capped at 48 h** (`nvgpu`). No documented GPU partition allows longer jobs except `gpu-preempt`, where jobs can be cancelled ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)). A 24/7 service therefore needs about 183 resubmissions a year (my arithmetic: 8,760 h ÷ 48 h), and each one can wait in the queue.
- **Compute nodes are not reachable from outside.** Only SSH to `login.vacc.uvm.edu` is public. OOD needs campus or the VPN. The docs describe no port forwarding, and no route from a web host to a compute node.
- **Cost is low, because tiers are flat fees.** One GPU running all year is 525,600 CU (Tier 2, $1,000). Eight GPUs all year is 4,204,800 CU (Tier 3, $4,000). One GPU for a 15-week semester is 151,200 CU, which fits in free Tier 1 (my arithmetic; table [below](#costs)).
- **Data: the sources conflict.** The Data Classification Matrix lists the VACC as approved for **Low Risk** research data only. The UVM AI tools page says "VACC Research Computing AI" is approved for **Low to Moderate**, and High with consultation. Student records (FERPA) are Moderate. For human-subjects research, IRB policy bars AI tools from identifiable FERPA data.

## Allowed / not allowed / undocumented

"Allowed" means a primary page says so. "Not allowed" means a page forbids it or the rule clearly covers it. "Undocumented" means I found nothing either way.

| Item | Status | Basis |
| --- | --- | --- |
| Run vLLM (an inference server) inside a Slurm GPU job | **Allowed** | GPU Features names vLLM and TGI as workloads and gives constraints for them ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/)) |
| A GPU job longer than 48 h on `nvgpu` | **Not allowed** | "maximum time of 48 hours" ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)) |
| GPUs in the `week` partition (7 days) | **Undocumented**, probably none | `week` "runs on a smaller set of nodes than the general partition", and `general` "does not contain nodes with GPUs". `nvgpu` is where GPU jobs "should" go ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)). That `week` has no GPUs is my inference |
| `gpu-preempt` (CRREL H200s) for a long-running service | **Allowed, but jobs can be cancelled.** Max time not stated | "outside jobs will be cancelled ... Do not submit jobs to this partition if you are not willing to have them cancelled" ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)) |
| A persistent or always-on service on compute nodes | **Undocumented** | No VACC page mentions services, daemons or uptime. The UVM server rule (row below) applies |
| Running a network-accessible server as an individual or research group | **Needs approval** | Data Classification Matrix "servers" note, quoted in [Short answer](#short-answer) |
| Running the Flask app or any long-lived process on a login node | **Not allowed** under the guidelines | Login nodes are for "editing source/command files and running short test programs", roughly <5 min, <5 GB and ≤2 CPUs ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/#login-vs-compute-nodes)). Also "Please do not use VS Code to ssh to the login nodes" ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)) |
| Inbound connections to compute nodes from campus or the internet | **Undocumented**. Compute-node names do not resolve publicly (my observation) | See [Networking](#networking) |
| SSH port forwarding (`ssh -L`) through the login nodes | **Undocumented** | No `ssh -L`, "tunnel" (other than VS Code) or "port forward" text in any of the 273 docs sections |
| OOD `/node/` or `/rnode/` proxy to an arbitrary port | **Undocumented** at VACC. Even if enabled, it needs OOD login plus campus/VPN | See [Networking](#networking) |
| Outbound internet from GPU compute nodes (HF weights, pip, conda) | **Works in practice per VACC's own scripts. No written policy** | VACC's `llama-4-setup` builds a conda+pip environment (including `git+https://github.com/...`) inside an `nvgpu` job ([build script](https://gitlab.uvm.edu/vacc-tools/llama-4-setup/-/raw/main/benchmarking_setup/build_benchmarking_conda_env.sbat); [environment.yaml](https://gitlab.uvm.edu/vacc-tools/llama-4-setup/-/raw/main/benchmarking_setup/environment.yaml)). The OOD VS Code Tunnel runs on a compute node, and VS Code tunnels "make outbound connections to a service hosted in Azure" ([VACC VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/); [VS Code docs](https://code.visualstudio.com/docs/remote/tunnels)) |
| Docker | **Not available**. Apptainer 1.3.4 only | [software.md](software.md#containers) |
| Users without a UVM NetID logging into the VACC | **Not allowed** without PI sponsorship and a NetID | [access.md](access.md#who-is-eligible); [Request Allocation](https://www.uvm.edu/vacc/request-allocation) |
| End users without VACC accounts calling an API hosted on the VACC | **Undocumented**. The AUP may apply | AUP forbids "allowing others to use one's University-provided information and communication technology services except as otherwise permitted" ([Policy 1.8.2 PDF](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf), §4.b.ix). Whether serving model outputs counts as "use" is an interpretation question for VACC/ISO |
| Commercial use or a private enterprise | **Not allowed** | "Users agree not to use computers ... for the operation of private enterprises or for private fund-raising" ([AUP 1.8.2](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf), item 7) |
| Adding a network service to the UVM network | **Needs ETS approval** for anything beyond "properly configured computers and printers" | "no other device or network service such as routers, hubs, sniffers, or wireless access points may be placed on the network without approval from ETS Telecommunication and Network Services" ([AUP 1.8.2](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf), §4.f). Whether a software API counts as a "network service" here is **Uncertain** |
| Admin reservation of GPUs for a long-running service | **Undocumented** for research. Reservations exist for classes | Classroom "no-wait access to GPUs via a class time-based reservation system" ([Services](https://www.uvm.edu/vacc/services-we-provide)). Only root or SlurmUser can create reservations ([Slurm reservations](https://slurm.schedmd.com/archive/slurm-25.11.2/reservations.html)) |
| Self-requeue (`scontrol requeue`) or job chaining (`--dependency`) | **Undocumented** at VACC. Standard Slurm | No VACC page mentions requeue, `--signal` or `--dependency`. The only mention is `REQUEUE` in the `--mail-type` comment ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/#submitting-a-job-with-sbatch)) |
| Hosting a fine-tuned model in the central `/gpfs1/llm` library | **Allowed on request.** Approval weighs efficiency, security and demand | [Sharing LLMs](https://www.uvm.edu/vacc/docs/start_guide/sharing_llms/#requesting-a-model-be-added-to-the-central-library) |
| Regulated data (PHI, CUI) on the main VACC | **Not allowed** (Restricted class; VACC is listed as Low Risk only) | [Data Classification Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf); [storage.md](storage.md#security-and-compliance) |
| Moderate-risk data (e.g. non-health FERPA student records) on VACC LLMs | **Conflict** | Matrix: VACC is Low only. [AI tools page](https://www.uvm.edu/ai/supported-and-approved-ai-tools): "VACC Research Computing AI", Low to Moderate |

## Policy

### What VACC pages say

- **AI Workloads page:** it covers only environmental claims (no evaporative cooling, low-carbon grid, 63 to 135 t CO₂/yr). It says **nothing** about inference, serving, users or limits ([AI Workloads](https://www.uvm.edu/vacc/artificial-intelligence-workloads)).
- **GPU Features page:** vLLM is presented as a normal workload. "LLM inference servers like vLLM are memory-bound. The primary concern is fitting the model in VRAM." The page recommends `GPU_MEM:140GB` or `GPU_MEM:96GB` for "LLM inference (vLLM, TGI)" ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/#summary)). The inventory row for the RTX 6000 Pro reads "ML inference, large model inference".
- **Scope of the facility:** "a research facility offering computing services to UVM faculty, staff and students" ([VACC home](https://www.uvm.edu/vacc)). Teaching use is supported ("HPC in the Classroom", [Services](https://www.uvm.edu/vacc/services-we-provide)).
- **Login nodes:** "cluster users are expected to submit most computations to the job scheduler ... The login nodes are meant for tasks like editing source/command files and running short test programs". Rough limits are <5 min, <5 GB and ≤2 CPUs ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/#login-vs-compute-nodes)). No page says "do not run services on login nodes" in so many words, but a web server running all day is outside these guidelines.
- **Acceptable-use page:** **Not found.** The VACC site has no AUP, terms-of-service, or "services" policy page. The full list of VACC site pages is home, mission, specs, cost, allocation, citations, services, data management, AI workloads and contact ([VACC home](https://www.uvm.edu/vacc) navigation). No docs section matched "acceptable", "prohibit" or "not permitted" in a policy sense.
- **"VACC Locally Hosted LLMs":** the UVM AI site's menu has a link with this label, but it points to `/vacc/services-we-provide`. That page says nothing about LLMs ([AI tools page](https://www.uvm.edu/ai/supported-and-approved-ai-tools) link target; [Services](https://www.uvm.edu/vacc/services-we-provide)). The researcher guidelines also say "The Vermont Advanced Computing Center (VACC) hosts local LLMs for research use that provides data protection in a closed environment" and link `uvm.edu/vacc/services`, which redirects to the same page ([Guidelines for Researchers](https://www.uvm.edu/ai/guidelines-researchers)). **Stale or Not found:** there is no published description of a VACC-hosted LLM *service*. What exists is the `/gpfs1/llm` model library, the `ollama`/`llama.cpp` modules and the `llama-4-setup` batch scripts ([software.md](software.md#ai--llm-resources)).

### UVM-wide rules that apply

- **Server approval** ([Data Classification Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf), "Server Risk Classification Examples"): "A server is defined as a host that provides a network accessible service. NOTE: servers are the responsibility of official IT units sanctioned by the CIO and should not be run by individuals or individual groups unless a formal approval and documentation process has occurred. If you believe data is being run on local servers and not going through Enterprise Technology Services, contact the Information Security Office." The same table puts a "Server requiring NetID or LCOM username authentication" in **Moderate**, and a server that "does not require user authentication and only contains low risk data" in **Low**. API-key authentication is not classified. **Uncertain** where an API-key service lands.
- **AUP** ([Computer, Communication, and Network Technology Acceptable Use, Policy 1.8.2, effective 2010-04-12](https://www.uvm.edu/d10-files/documents/2024-12/compuse.pdf); [policy page](https://www.uvm.edu/policies/computer-communication-and-network-technology-acceptable-use)). Relevant parts:
  - §1.a: accounts "may only be used by the individual to whom they are assigned".
  - §4.b.ix: no "allowing others to use one's University-provided information and communication technology services except as otherwise permitted".
  - §4.f: no "network service ... may be placed on the network without approval from ETS Telecommunication and Network Services".
  - Item 7: no "operation of private enterprises".
  - The policy is from 2010 and predates hosted APIs. How it applies to an LLM endpoint is **Uncertain** and needs an ETS/ISO answer.
- **Serving non-UVM users:** no VACC or UVM page addresses serving outputs to people outside UVM. VACC *accounts* for externals require PI sponsorship, a UVM NetID and export-control screening. There are "significant restrictions on providing goods or services ... to Iranians and Iranian institutions" ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)). Whether export-control screening extends to API users is **Not found**; ask exportcontrols@uvm.edu if users outside UVM are planned.
- **Contract review for AI:** "If your department wants to purchase solutions with AI components, they must go through Contract Review" ([AI tools page](https://www.uvm.edu/ai/supported-and-approved-ai-tools)). A self-hosted open-weight model is not a purchase, so this probably does not apply. **Uncertain.**

## Networking

### What is reachable from where

| Endpoint | Reachability | Source |
| --- | --- | --- |
| `login.vacc.uvm.edu:22` | Public, no VPN: "Unlike access via Open OnDemand, you do not need to be connect to the UVM VPN to access the VACC via SSH" | [SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/). (My observation: the name resolves to 132.198.57.101, .103 and .104, which suggests round-robin over three login nodes, and TCP 22 accepted a connection from off campus) |
| `ondemand.vacc.uvm.edu:443` | Campus or VPN only: "You are on-campus or connected to the VPN" | [OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/). (My observation: off campus, a TCP connection to 132.198.57.106:443 failed within 3 ms, consistent with a firewall reject) |
| Slurm dashboard | Campus or VPN only | [Slurm Status Dashboard](https://www.uvm.edu/vacc/docs/start_guide/slurmdash/) |
| Compute/GPU nodes (e.g. `h2xnode01`, `vacc-login4.cluster` as named in the docs) | **Not found.** The names in the docs use a `.cluster` suffix or none ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/); [User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)) | (My observation: neither name resolves in public DNS.) Whether campus hosts (Silk, research VMs) can open TCP connections to compute-node ports is **Not found** |
| Inbound ports on compute nodes | **Not found.** No firewall or port policy is published | — |
| Outbound from compute nodes | Works in practice. See the table row above (VACC's `llama-4-setup` conda/pip build in an `nvgpu` job; VS Code tunnels from compute nodes). **No written policy**, and no proxy settings are documented | — |

### Tunnelling and port forwarding

- **No SSH tunnel pattern is documented.** The VACC docs' only "tunnel" is the OOD **VS Code Tunnel** app. It "will launch a VS Code Tunnel on a compute node", runs in tmux, and authenticates with a Microsoft UVM account by device code. "Connecting to the VS Code tunnel using the URL via a web browser is not supported" ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)). Upstream: "Tunneling securely transmits data from one network to another via Microsoft dev tunnels ... VS Code will make outbound connections to a service hosted in Azure" ([VS Code docs](https://code.visualstudio.com/docs/remote/tunnels)).
- **Jupyter** is offered only as an OOD interactive app (Notebook, Lab). No `ssh -L` recipe exists ([OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/#interactive-apps); [JupyterLab](https://www.uvm.edu/vacc/docs/beyond_basics/jupyter_lab/)).
- **Generic pattern (not VACC-documented):** `ssh -L 8000:<gpu-node>:8000 netid@login.vacc.uvm.edu`. This only works if the login nodes allow `AllowTcpForwarding`, which is **Not found**, and whether SSH needs Duo MFA is also **Not found** ([access.md](access.md#ssh)). An unattended tunnel from a web host would also need non-interactive authentication. SSH keys are undocumented.
- **Third-party relays** (Microsoft dev tunnels port forwarding, ngrok, Cloudflare Tunnel) would get around the missing inbound route. They would also expose a UVM-hosted service without the approval the Data Classification Matrix and AUP §4.f call for. No page addresses them. Do not use them without written approval.

### Open OnDemand proxy (`/node/`, `/rnode/`)

- Upstream OOD 4.2 docs: "The reverse proxy will proxy a request to any specified host and port ... This can be used to connect to Jupyter notebook servers, RStudio servers, VNC servers ... This is disabled by default." The URL forms are `/node/<host>/<port>/...` (full path passed through) and `/rnode/<host>/<port>/...` (prefix stripped). Allowed hosts are limited by `host_regex` ([OOD: Enable Reverse Proxy](https://osc.github.io/ood-documentation/latest/how-tos/app-development/interactive/setup/enable-reverse-proxy.html); [ood_portal.yml reference](https://osc.github.io/ood-documentation/latest/reference/files/ood-portal-yml.html#configure-reverse-proxy)).
- VACC runs Jupyter and RStudio Server as OOD apps, and upstream OOD proxies those through this reverse proxy. So `/node`/`/rnode` is **probably** enabled at VACC (inference). The VACC docs never mention it, and its `host_regex` is unknown.
- **It is not usable as a public API front door.** Every OOD request needs a UVM NetID login, and OOD itself needs campus or the VPN ([OOD](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)). API-key clients outside that path cannot reach it. It could work for a developer's own browser testing on campus.

### Implication for the architecture (my inference)

The VACC publishes no path from the internet, or from another UVM host, to a port on a GPU node. Each of the three possible designs needs VACC/ETS approval:
1. VACC opens a route from a specific campus host (Silk or a research VM running Flask) to the GPU nodes.
2. VACC runs an approved gateway.
3. The service runs somewhere other than the main cluster.

A reverse connection from the GPU job out to the Flask host, such as an SSH tunnel opened by the job, uses only outbound connectivity, which works in practice. It is still a network service under the Matrix definition, and the same approval question applies.

## Long runs and keeping a service up

### VACC facts

- `nvgpu`: max 48 h, "no memory limit". `general`: 48 h, no GPUs. `week`: 1 week, "smaller set of nodes" with no GPU statement. `short`: 3 h. `gpu-debug`: 3 h, 1 GPU, 1 running job per user, "should not be used to run jobs". `gpu-preempt`: CRREL H200s, max time not stated, outside jobs cancelled ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)). Details: [slurm-and-jobs.md](slurm-and-jobs.md#partitions).
- **Maintenance holds:** "Jobs that would run into this maintenance window will not be permitted to start until after the maintenance is complete." The next scheduled window is **2027-01-05** ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). For a 48 h job, that means no new start in the 48 h before a window (my arithmetic). The service is down for the whole window. The 2026-08-18 window ran from 7:00 to about 18:00.
- **Unscheduled capacity loss in 2026:** during the power work, the cluster ran at 50% several times. From May 28 to June 9, "B-side circuits not UPS backed. Any power disruption will mean those compute nodes will crash" ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/#mayjune-2026)). That work is finished. It shows the cluster has no uptime commitment, and no SLA is published (**Not found**).
- **Reservations:** the only VACC mention is the classroom "class time-based reservation system" ([Services](https://www.uvm.edu/vacc/services-we-provide)). In Slurm, "Reservations can be created, updated, or destroyed only by user root or the configured SlurmUser" ([reservations, 25.11.2](https://slurm.schedmd.com/archive/slurm-25.11.2/reservations.html)). So a standing GPU reservation for a service has to come from VACC admins, and no page offers one.
- **Requeue, `--signal`, `--dependency`:** the VACC docs say **nothing**. Standard Slurm behaviour is summarised in [../slurm/job-scripts.md](../slurm/job-scripts.md) and [../slurm/cheatsheet.md](../slurm/cheatsheet.md). Site settings such as `JobRequeue`, `bf_window`, preemption and QOS limits are unknown until someone runs `scontrol show config` on the cluster ([../slurm/README.md](../slurm/README.md#vacc-gaps-the-slurm-docs-help-explain)).

### Generic Slurm options (Slurm 25.11.2, the version VACC runs)

All quotes are from [sbatch(1), 25.11.2](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) unless noted.

| Option | What it does | Use for a service |
| --- | --- | --- |
| `--signal=[{R\|B}:]<sig>[@sig_time]` | "When a job is within sig_time seconds of its end time, send it the signal". It "may be sent up to 60 seconds earlier". `B:` signals "only the batch shell" | Give vLLM time to drain, deregister the endpoint, or requeue itself |
| `scontrol requeue <jobid>` | "Requeue a running, suspended or finished Slurm batch job into pending state" ([scontrol(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html)). A requeued job restarts its script "from its beginning with the same job ID" (sbatch `--requeue`) | Self-requeue from a `--signal` trap. The job goes back to **pending** and waits in the queue again, so there is a gap |
| `--requeue[=expedited]` | Allows requeue after node failure or preemption. `expedited` gives "the highest possible priority" only if the site sets `SlurmctldParameters=enable_expedited_requeue` | Survive node failures. Whether VACC enables expedited requeue is unknown |
| `--dependency=after:<jobid>+<min>` | The job can start once the named job has started and `<min>` minutes have passed | **Overlapping hand-off:** submit the successor so it becomes eligible about 1 h before the predecessor's 48 h limit. It still has to win the queue |
| `--dependency=singleton` | "only one job by that name and owned by that user can be running or suspended at any point in time" | Stop two copies from running by accident. It also rules out overlap, so it is the wrong choice for zero-gap hand-off |
| `--time-min` | Lets backfill shorten the time limit to start sooner | Helps a successor start in a gap, at the cost of a shorter run |

Keeping a service up across the 48 h limit (generic patterns; not documented or endorsed by VACC):
1. **Overlapping relay, best for uptime.** Job *n* runs vLLM and publishes its `host:port` to a file on GPFS or to the frontend. Just after it starts, it submits job *n+1* with `--dependency=after:$SLURM_JOB_ID+2820` (47 h). When *n+1* is healthy, the frontend switches over and *n* exits. With 1 h of overlap per 47 h, it costs about 2.1% extra GPU time (my arithmetic: 1 ÷ 47). The overlap window also needs the GPUs twice over, for example 2 × 4 H200s.
2. **Signal and self-requeue, simplest.** `#SBATCH --signal=B:USR1@600` plus a `trap 'scontrol requeue $SLURM_JOB_ID' USR1`. Same job ID, but the service is down from the requeue until the job starts again, plus the model load time.
3. **Ask VACC** for a reservation, a QOS with a longer `MaxWall`, or dedicated (condo) nodes. All three are admin-side and none is documented.

Frequency: 182.5 hand-offs a year, or 52.5 per 15-week semester (my arithmetic: 8,760 h or 2,520 h ÷ 48 h).

## Alternatives at UVM

| Option | What it offers | Fit for Flask frontend | Fit for inference endpoint | Source |
| --- | --- | --- | --- | --- |
| **Silk** web hosting (ETS SAA) | Free to current students, faculty and staff. Python **WSGI** apps through NGINX Unit ("cannot be started as a service that directly listens for network requests"). Python 3.10, 3.12 and 3.14. 20 GB disk, "most sites are limited to 4GB of simultaneous memory". TLS included. Site at `<netid>.w3.uvm.edu`, or `*.uvm.edu` with web-team approval. Restarts Tuesdays 2:00 to 2:30 am. Daily backups | **Good.** Flask is WSGI. Silk is meant for "a custom web application" ([KB: web hosting options](https://www.uvm.edu/it/kb/article/uvm-web-hosting-options/)). Whether streaming responses (SSE) work under NGINX Unit is **Uncertain** | No GPUs | [Silk hosting overview](https://silk.uvm.edu/hosting-questions); [Silk Python](https://silk.uvm.edu/manual/python); [ETS catalog: Silk](https://catalog.etsweb.w3.uvm.edu/it/catalog/service/web-hosting-silk). (My observation: the VACC docs mirror `docs.vacc.w3.uvm.edu` is a CNAME for `silk.uvm.edu`) |
| **ETS Research VMs** | VMware, RHEL 8/9 or Windows Server 2019. Faculty get "one free VM" (12 cores, 48 GB RAM, 100 GB). Larger ones cost ~$2,990 or ~$6,525 one-time for 5 years. "there is no queue for work". Patching is managed by ETS. Meant for "production code/applications that cannot run on the VACC". Access requires "the UVM network", by VPN or through Zoo | **Good** for the Flask app or an API gateway. Public exposure (inbound firewall, DNS) is **Not found**; ask SAA | VM page hosts: 5 × R7525 (EPYC 75F3, 1 TB). **No GPUs listed.** **Conflict:** the 2026 research-computing report says the VM environment has "4 x NVIDIA L40 GPUs" (48 GB each per [NVIDIA L40](https://www.nvidia.com/en-us/data-center/l40/)). Below gpt-oss-120b's own "single 80GB GPU" footprint ([model card](https://huggingface.co/openai/gpt-oss-120b)), so it would need multi-GPU tensor parallelism even if offered | [Research VMs](https://www.uvm.edu/it/research-computing-virtual-machines); [KB: Research VMs remote access](https://www.uvm.edu/it/kb/article/research-vms-remote-access/); [Spring 2026 Research Computing Report](https://www.uvm.edu/d10-files/documents/2026-05/Spring2026_ResearchComputingReport.pdf), p. 12 |
| **"Secure Cluster" / Secure Enclave** | Spec page: "Will Be Available Summer 2026". Three GPU nodes "each equipped with an NVIDIA L40S GPU", one 1.5 TB node, "Two Proxmox Nodes" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)). The 2026 report describes a "University-wide VDI-based Secure Enclave ... launched spring 2026 (NVIDIA L40S nodes, large memory node, secure VMs)", targeting NIST 800-171, plus a separate "VACC HPC cluster for restricted data" targeting NIST 800-223 "before the end of 2026" ([report](https://www.uvm.edu/d10-files/documents/2026-05/Spring2026_ResearchComputingReport.pdf), p. 12). **Conflict** on launch timing. Probably the same hardware (inference) | Unlikely. The enclave is VDI-based with restricted networking ([storage.md](storage.md#security-and-compliance)) | **Poor for gpt-oss-120b.** One L40S per node at 48 GB ([NVIDIA L40S](https://www.nvidia.com/en-us/data-center/l40s/)) is below the 80 GB the model card cites | as cited |
| **Dedicated / condo nodes** | "If you purchase dedicated hardware for the VACC, you are required to join Tier 2 or Tier 3". MOUs stay in effect ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)). Owner partitions exist (`goldenmaple`, `hgnodes`) ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)) | — | **Possibly the cleanest route** to a GPU with no 48 h limit, if VACC lets owners run longer jobs on their own nodes. Walltime on owner partitions, prices and network exposure are **Not found** | as cited |
| **Existing UVM LLM services** | Microsoft Copilot (Low to High), Anthropic Claude (Low to Moderate, High with consultation), "VACC Research Computing AI" ("Run open-source large language models on high-performance computing systems", upon request, via [Research Computing Facilitation](https://www.uvm.edu/it/research-computing-facilitation)), VACC Transcription (Whisper) ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools)). ETS (2026-10-14): "A multi-model AI service, being explored in partnership with UMass Amherst, is targeted for an initial winter deployment and broader production use in the spring", and "We continue to evaluate potential multi-model gateways for programmatic access to AI services" ([ETS news](https://www.uvm.edu/it/news/expanding-uvms-ai-tools-and-services)). The CIO lists a "web-based GenAI Platform with access to multiple large language models" in Phase 1 ([AI Taskforce Fall 2026](https://www.uvm.edu/it/news/ai-taskforce-updates-fall-2026)) | Could replace a custom frontend only if it can host a custom fine-tune. **Not found** | No published **API** endpoint for a custom model. Ask ets-ai@uvm.edu whether the coming gateway can front a VACC-hosted model | as cited |

The UVM research-computing framework puts the VACC first, then "UVM's Virtual Server Environment ... in those cases where the VACC does not meet a researcher's needs" ([ETS Research Computing](https://www.uvm.edu/it/research-computing)). A 24/7 public endpoint is arguably such a case.

## Costs

Rules: 1 CU = 1 GPU-minute, or 1 core-hour. Tiers are flat yearly fees per PI group on the UVM fiscal year: Tier 1 free (<250,000 CU, UVM faculty and staff only), Tier 2 $1,000 (250,000 to 3,000,000), Tier 3 $4,000 (>3,000,000). Usage is pooled across the PI and every sponsored user ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment); [PI info: compute](https://www.uvm.edu/vacc/docs/pi-info/compute/); [access.md](access.md#allocations-tiers-and-compute-units)).

All figures below are my arithmetic. A year is 8,760 h. A semester is 15 weeks, or 2,520 h.

| GPUs | GPU CU / year, 24/7 | Tier | GPU CU / semester | Tier | + 16 cores/GPU, year | Tier | + 16 cores/GPU, semester | Tier |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 525,600 | 2 ($1,000) | 151,200 | 1 (free) | 665,760 | 2 | 191,520 | 1 |
| 2 | 1,051,200 | 2 ($1,000) | 302,400 | 2 ($1,000) | 1,331,520 | 2 | 383,040 | 2 |
| 4 | 2,102,400 | 2 ($1,000) | 604,800 | 2 ($1,000) | 2,663,040 | 2 | 766,080 | 2 |
| 8 | 4,204,800 | 3 ($4,000) | 1,209,600 | 2 ($1,000) | 5,326,080 | 3 ($4,000) | 1,532,160 | 2 |

Notes:
- **Are CPU cores in a GPU job billed too? Uncertain.** The `my_compute_usage` example shows 10 CPU-hours and 5.5 GPU-hours adding up to 340 CU, which is 10 + 5.5 × 60 ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/#my_compute_usage)). So CPU-hours and GPU-hours are summed, but the example does not show whether the CPU-hours came from the same GPU job. The "+16 cores/GPU" columns assume they are billed. 16 is the cores-per-GPU ratio of the 8× H200 SXM nodes (128 cores ÷ 8). The 4× H200 NVL nodes have 48 cores per GPU (192 ÷ 4) ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).
- **Thresholds:** Tier 1 covers about 4,167 GPU-hours, or about 174 GPU-days. Tier 2 tops out at 3,000,000 CU, about 5.7 GPUs running all year.
- **The semester figure assumes nothing else in the PI group.** One GPU for a semester uses 151,200 of the 250,000 Tier 1 CU and leaves about 98,800 for everything else, fine-tuning included. Relay overlap (about +2.1%) and fine-tuning runs push toward Tier 2.
- **How many GPUs:** gpt-oss-120b with its stock MXFP4 MoE weights fits "into a single 80GB GPU" ([model card](https://huggingface.co/openai/gpt-oss-120b)). A fine-tune saved in another format, plus KV-cache headroom, may need more. The GPU count comes from the model and serving setup, not from this note.
- **Flat fees hide the real cost:** 8 H200s held 24/7 is about 7.7% of the cluster's 104 H200s (my arithmetic). At $4,000 a year, VACC may decide that is not a fair-share use. CU usage "is evaluated twice yearly, and if it appears that an adjustment might be needed, the VACC administrator will contact you directly" ([PI info: compute](https://www.uvm.edu/vacc/docs/pi-info/compute/#compute-hour-allocation)). What happens above a tier band is **Not found** ([access.md](access.md#allocations-tiers-and-compute-units)).
- Tier fees "will change annually" ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)). These are **FY26** figures.

## Data: prompts, FERPA, PHI

- **The Data Classification Matrix (2025-07), "Approved Services for Research",** lists **VACC under Low Risk only**. Moderate covers "Coded data with no additional requirements", High covers "Identifiable Data (human subject research)", and Restricted covers CUI, export-controlled data and PHI ([Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf)).
- **The UVM AI tools page** lists "VACC Research Computing AI" with "Allowed data: Low to Moderate Risk; High Risk with consultation". Its example inappropriate use is "Model fine-tuning with classified documents produced by the Department of Defense" ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools)). **Conflict** with the Matrix. The AI page is more specific to LLM use, but neither page is dated more recently than the other.
- **FERPA classes** (Matrix, "Data Compliance Classification Examples"): "Non-Health ... non-financial FERPA data" is **Moderate**. "Health-related (physical and mental) FERPA data" is **High**. HIPAA is **Restricted**. "Student records and admission applications" are Moderate. So prompts typed by students that reveal their own coursework, grades or accommodations would probably be at least Moderate (inference).
- **IRB (human-subjects research only):** IRB Policies §8.12, published 2026-02-13, says: "The AI tool may not have access to the following data in identifiable format ... Family Educational Rights and Privacy Act (FERPA)-protected data". It adds "AI tools should only be used with institutional data classified as low risk" unless contracted ([IRB Policies §8.12](https://www.uvm.edu/rpo/irb-policies-and-procedures#8p12)). If the app's prompt logs are research data about students, this applies. **Stale:** the same section says UVM "does not have a contract or agreement with any other AI tools" beyond Copilot, while the AI tools page now lists Claude.
- **PHI/CUI:** not on the main VACC (Restricted). Secure options are the ETS Secure Enclave and the planned restricted-data VACC cluster ([report](https://www.uvm.edu/d10-files/documents/2026-05/Spring2026_ResearchComputingReport.pdf), p. 12; [storage.md](storage.md#security-and-compliance)). Neither has GPUs big enough for gpt-oss-120b as published (L40S, 48 GB).
- **Storage of logs on the VACC:** home directories are readable by the PI group by default ([storage.md](storage.md#data-organisation-and-sharing)). Prompt logs need `umask 0007` or ACLs, and the 60-day purge on `/gpfs3tmp` matters for retention. PIs must "comply with any restrictions on access to data that may come with data use agreements" and can ask vacchelp for help ([PI info: general](https://www.uvm.edu/vacc/docs/pi-info/general/#your-disk-usage-and-data-storage)).
- **Research VMs:** "Coded data only" ([ETS Research Computing Resources](https://www.uvm.edu/it/research-computing-resources)). That is the same ceiling as the Matrix's Moderate column.

## Who to contact, and a draft email

| Who | For |
| --- | --- |
| **vacchelp@uvm.edu** (802-656-8867) | Technical questions: services in jobs, networking, walltime, reservations, model library ([Contact](https://www.uvm.edu/vacc/contact-us)) |
| **vacc@uvm.edu**; Andi Elledge (aelledge@uvm.edu), Executive Director | Tiers, condo nodes, MOUs, Voucher Fund ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)) |
| **iso@uvm.edu** (Information Security Office) | Server approval under the Data Classification Matrix, data classification of prompts ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools); [Matrix](https://www.uvm.edu/d10-files/documents/2025-07/Data_Risk_Classification_Matrix.pdf)) |
| **saa@uvm.edu** (Systems Architecture & Administration) | Silk site, research VM, public exposure of a VM ([Silk](https://silk.uvm.edu/hosting-questions); [KB](https://www.uvm.edu/it/kb/article/research-vms-remote-access/)) |
| **ets-ai@uvm.edu** | Whether the planned multi-model gateway could front a VACC-hosted model ([ETS news](https://www.uvm.edu/it/news/expanding-uvms-ai-tools-and-services)) |
| Research Computing Facilitation ([go.uvm.edu/researchcomputingcontact](https://go.uvm.edu/researchcomputingcontact)) | "VACC Research Computing AI" requests ([AI tools](https://www.uvm.edu/ai/supported-and-approved-ai-tools)) |
| exportcontrols@uvm.edu; IRB (Research Protections Office) | Only if non-UVM users, or human-subjects research on the prompts |
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

Not confirmable from public pages; who to ask is in brackets.
1. **Persistent services on compute nodes.** Whether they are allowed at all, and any limits [vacchelp@uvm.edu].
2. **Server approval.** Whether a VACC-hosted API counts as a "server" needing "formal approval and documentation" under the Data Classification Matrix, and who signs off (VACC or ISO) [iso@uvm.edu].
3. **AUP interpretation.** Whether §4.b.ix ("allowing others to use ... services") and §4.f ("network service") cover giving API keys to people without VACC accounts, or outside UVM [iso@uvm.edu].
4. **GPUs in `week`, and walltime on `gpu-preempt`, `hgnodes` and owner partitions** [vacchelp@uvm.edu].
5. **Network paths.** Inbound reachability of compute nodes from campus hosts, firewall rules, `AllowTcpForwarding` on login nodes, MFA on SSH, whether OOD `/rnode` is enabled and its `host_regex`, and any outbound proxy policy [vacchelp@uvm.edu].
6. **Billing of CPU cores inside GPU jobs**, and enforcement above a tier band [vacc@uvm.edu].
7. **Data-class conflict.** VACC is Low only in the Matrix, but Low to Moderate on the AI tools page [iso@uvm.edu].
8. **Secure Cluster / Secure Enclave.** Actual launch status, whether the spec page's "Secure Cluster" is the report's "Secure Enclave", and what the Proxmox nodes host [vacchelp@uvm.edu].
9. **Research VMs.** Whether a VM can be exposed publicly (DNS, inbound 443), and whether the L40 GPUs in the 2026 report can be requested [saa@uvm.edu].
10. **Silk.** Whether streaming HTTP responses (SSE) work under NGINX Unit, and whether Silk can reach VACC compute nodes [saa@uvm.edu].
11. **"VACC Locally Hosted LLMs".** The link label on uvm.edu/ai points to a page with no LLM content. Is there a hosted service? [vacchelp@uvm.edu or ets-ai@uvm.edu].
12. **The ETS multi-model gateway.** Timeline, and whether it can proxy to a custom VACC-hosted endpoint [ets-ai@uvm.edu].
13. **Condo pricing and terms.** No public price list or MOU template exists [aelledge@uvm.edu].
14. **Export control for API users outside UVM** [exportcontrols@uvm.edu].
