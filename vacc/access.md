# Access, accounts, allocations and costs

Back to [README](README.md). All pages accessed 2026-11-11.

## Who is eligible

- Accounts are either **PI accounts** or **sponsored user accounts**. Faculty and post-docs can apply for a PI account. Post-docs may instead be sponsored by their hiring PI. Students must be sponsored by a PI, usually their advisor or lab PI ([Getting an account](https://www.uvm.edu/vacc/docs/start_guide/request_acct/)).
- The [Request Allocation page](https://www.uvm.edu/vacc/request-allocation) says applicants must be "either a Principal Investigator (PI) or an IT support person working with a PI". Students: "Do NOT fill out this form."
- Tier 1 (free) is "Available only to UVM Faculty and Staff" ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).
- ETS catalogue: eligible are "Primary Investigators (PIs) at UVM" and "Current students, faculty, and staff who are sponsored by a PI". Requirement: "A valid UVM NetID" ([ETS service catalog](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc)).
- **External users:** a PI can sponsor an external collaborator by asking vacchelp@uvm.edu for a UVM NetID (full name, email, affiliation). Export-control rules apply. Restricted-party screening is advised for people from China, Russia, Iran, North Korea or Cuba, and seven named Chinese universities may not be sponsored. Contact: exportcontrols@uvm.edu ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)).
- The [IceCore NSF award abstract](https://api.nsf.gov/services/v1/awards/2510406.json) mentions access for Northern New England institutions, the UVM Health Network and state agencies. **No page explains how non-UVM institutions get IceCore access** beyond NetID sponsorship.

## How to get an account

1. A PI fills out the application. It asks for a project title, a one-paragraph lay description, expected resources ("acceptable to state that you don't know"), a tier choice, and funding source(s). Funding details are not needed for Tier 1 ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)). The application link is on that page. The URL behind the "Go to the application" button was not captured.
2. After approval, the PI adds sponsored users by NetID through the [Dashboard for Account Owners](https://vacc.w3.uvm.edu/accounts/owner_detail.php) ("Sponsored Users" → green "add"). Users get an email when their account is processed. If access takes more than 2 days, contact Andrea Elledge (aelledge@uvm.edu) ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)).
3. A "Welcome to the VACC" email arrives when the account is ready ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
4. **Supplemental collaborators:** a user sponsored by another PI can be given access to your GPFS files and Slurm account. There is no form for this; email vacchelp@uvm.edu ([PI info: general](https://www.uvm.edu/vacc/docs/pi-info/general/)).
5. PIs must remove users who no longer work for them. Home directories are deleted when sponsorship ends ([PI info: general](https://www.uvm.edu/vacc/docs/pi-info/general/); [Managing Data Access](https://www.uvm.edu/vacc/docs/pi-info/access/)).

The [IceCore news story](https://www.uvm.edu/cems/news/icecore-advances-new-era-discovery-uvm) quotes the Executive Director: "a straightforward application process where we just ask you to provide us a small summary of what it is you're doing".

## Logging in

### SSH
- Host: **`login.vacc.uvm.edu`**: `ssh your_netid@login.vacc.uvm.edu`, authenticated with the NetID password ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
- **VPN is not needed for SSH:** "Unlike access via Open OnDemand, you do not need to be connect to the UVM VPN to access the VACC via SSH" ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
- Login node names seen in examples: `vacc-login1`, `vacc-login4` (`SLURM_SUBMIT_HOST vacc-login4.cluster`) ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)). The number of login nodes was **not found**.
- Inconsistency: the same SSH page shows example prompts mentioning `login.uvm.edu` ("The authenticity of host 'login.uvm.edu' ..."). That looks like a leftover. Use `login.vacc.uvm.edu`.
- **MFA / Duo:** none of the VACC docs mention MFA, Duo or SSH keys for cluster login. UVM in general uses Duo (it is linked in the KB sidebar of [uvm.edu/it/kb](https://uvm.edu/it/kb/article/vermont-advanced-computing-center)), but whether SSH to the VACC requires Duo or allows key-based login was **not found**.
- Login-node etiquette: tests should run under 5 minutes, use under 5 GB of memory and no more than 2 CPUs. Everything else goes through Slurm ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/)). The docs ask users not to use VS Code Remote-SSH to login nodes and to use the VS Code Tunnel app instead ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)).

### Open OnDemand (web)
- URL: **https://ondemand.vacc.uvm.edu**. Log in with your UVM NetID and password. "College of Medicine login username and password will not work." It requires being **on campus or on the UVM VPN** ([Open OnDemand](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)).
- Features: file management, job management (Active Jobs, Job Composer), shell access, and interactive apps. The OOD page lists Jupyter Notebook, RStudio Server and MATLAB ([Open OnDemand](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)). Other pages mention a **JupyterLab** mode ([JupyterLab](https://www.uvm.edu/vacc/docs/beyond_basics/jupyter_lab/)), a **Desktop** session ([LLM tools](https://www.uvm.edu/vacc/docs/beyond_basics/llm/)), and a **VS Code Tunnel** app ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)).
- OOD was updated to version 2.4.4 on 2026-06-10 ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). That looks like a typo, because upstream OOD releases are numbered 3.x/4.x, but **unverified**.

### VS Code Tunnel
An OOD app starts a tunnel on a compute node inside tmux. You sign in with your Microsoft UVM account (device code), then connect from local VS Code to the tunnel "vsc-<account>-vacc". Login is cached for 24 hours. Browser-based tunnel access is not supported ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)).

### Slurm status dashboard
VACC runs "HPC Dashboard" (slurmdash), a live view of the cluster with job-efficiency scoring and cluster power draw in kW. It requires the campus network or VPN. Its URL is not printed in the indexed text ([Slurm Status Dashboard](https://www.uvm.edu/vacc/docs/start_guide/slurmdash/)).

## Allocations, tiers and compute units

From [Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment). Account owners join one tier each year, on the UVM fiscal-year calendar. Tier fees "will change annually".

| Tier | Cost FY26 | Compute units / year |
| --- | --- | --- |
| 1 | No cost to user (subsidised by VACC; **UVM faculty and staff only**) | Under 250,000 |
| 2 | $1,000 | 250,000 to 3,000,000 |
| 3 | $4,000 | Over 3,000,000 |

- **Compute unit (CU):** 1 CU = 1 core-hour of wall-clock CPU allocation. For GPUs (A100, H100, H200, RTX 6000), 1 CU = 1 minute of one GPU, so 60 CU per GPU-hour ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment); [User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)).
- **Worked example (my arithmetic):** Tier 1's 250,000 CU is about 4,167 GPU-hours, or 250,000 core-hours.
- Limits apply to the PI and all sponsored users combined. CU usage is reviewed twice a year, and an admin contacts you if a tier change looks needed ([PI info: compute](https://www.uvm.edu/vacc/docs/pi-info/compute/)). The docs do not say whether exceeding your CU band blocks jobs or only triggers a tier conversation. **Not found.**
- `my_compute_usage` reports CPU-hours, GPU-hours and CUs per user per account ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)).
- Anyone who buys dedicated hardware for the VACC must be in Tier 2 or 3, and existing hardware MOUs stay in effect ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)). This is the only condo/buy-in language on the official pages. CRREL-owned nodes (GoldenMaple / `gpu-preempt`) and SOCKS-funded H100s (`hgnodes`) are examples of owner-restricted hardware ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)). No public condo price list was found.

Disk quotas per tier are listed in [storage.md](storage.md#quotas).

## Paying

From [Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment):
- **Existing award:** check that the budget allows it, get sponsor approval, then contact Andi Elledge (aelledge@uvm.edu).
- **New proposal:** budget line "computer devices and VACC charges: F6021 (for account code 80047)". The page supplies ready-made budget-justification text, which describes the VACC as "a multi-thousand-core 'big compute' Linux cluster with hundreds of terabytes of GPFS storage". That is understated next to the current 2.8 PB.
- **Internal funds** (start-up, incentive): Andi Elledge arranges a transfer.
- **VACC Voucher Fund** (from the Office of the VP for Research): up to **$10,000**, including priority access and services, for faculty without grant or department funding. It must be spent within the fiscal year.
- **Additional disk** costs the current gpfs2 (High Throughput Storage) price plus an installation and maintenance fee, with a 4-year life. Email vacc@uvm.edu. No dollar figure is published.

## Other services (not compute)

- One-on-one onboarding through vacchelp@uvm.edu. Programming assistance from Research Facilitators if a grant funds a share of their time ([Services](https://www.uvm.edu/vacc/services-we-provide)).
- **HPC in the classroom:** OnDemand plus Jupyter on a "dedicated educational SLURM partition that provides no-wait access to GPUs via a class time-based reservation system" ([Services](https://www.uvm.edu/vacc/services-we-provide)). The name of that partition does not appear on the [partition page](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/). **Not found.**
- UVM's research-computing framework says the VACC is "the default research computing environment". Research VMs come second, and physical workstations are an exception ([ETS Research Computing](https://www.uvm.edu/it/research-computing)).
