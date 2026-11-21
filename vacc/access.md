# Access, accounts, allocations and costs

Back to [README](README.md). Compiled 2026-11-11.

## Who is eligible

- Accounts are either **PI accounts** or **sponsored user accounts**. Faculty and post-docs can apply for a PI account; post-docs may instead be sponsored by their hiring PI. Students must be sponsored by a PI ([Getting an account](https://www.uvm.edu/vacc/docs/start_guide/request_acct/)).
- Applicants must be "either a Principal Investigator (PI) or an IT support person working with a PI"; students: "Do NOT fill out this form" ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)).
- Tier 1 (free) is "Available only to UVM Faculty and Staff" ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).
- Requirement: "A valid UVM NetID" ([ETS service catalog](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc)).
- **External users:** a PI can sponsor an external collaborator by asking vacchelp@uvm.edu for a UVM NetID (full name, email, affiliation). Export-control rules apply: restricted-party screening is advised for people from China, Russia, Iran, North Korea or Cuba, and seven named Chinese universities may not be sponsored. Contact: exportcontrols@uvm.edu ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)).
- How non-UVM institutions get IceCore access beyond NetID sponsorship is **not found**.

## How to get an account

1. A PI fills out the application: project title, one-paragraph lay description, expected resources ("acceptable to state that you don't know"), tier, and funding source(s). Funding details are not needed for Tier 1 ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)).
2. After approval, the PI adds sponsored users by NetID through the [Dashboard for Account Owners](https://vacc.w3.uvm.edu/accounts/owner_detail.php) ("Sponsored Users" → green "add"). If access takes more than 2 days, contact Andrea Elledge (aelledge@uvm.edu) ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)).
3. A "Welcome to the VACC" email arrives when the account is ready ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
4. **Supplemental collaborators:** a user sponsored by another PI can be given access to your GPFS files and Slurm account by emailing vacchelp@uvm.edu ([PI info: general](https://www.uvm.edu/vacc/docs/pi-info/general/)).
5. PIs must remove users who no longer work for them. Home directories are deleted when sponsorship ends ([PI info: general](https://www.uvm.edu/vacc/docs/pi-info/general/); [Managing Data Access](https://www.uvm.edu/vacc/docs/pi-info/access/)).

## Logging in

### SSH
- `ssh your_netid@login.vacc.uvm.edu`, authenticated with the NetID password ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
- **No VPN needed for SSH** ([SSH](https://www.uvm.edu/vacc/docs/start_guide/ssh/)).
- Login node names in examples: `vacc-login1`, `vacc-login4` ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)). Number of login nodes **not found**.
- The SSH page's example prompts show `login.uvm.edu`; use `login.vacc.uvm.edu`.
- **MFA / Duo / SSH keys:** not mentioned in the VACC docs. **Not found.**
- Login-node limits: tests under 5 minutes, under 5 GB memory, at most 2 CPUs; everything else through Slurm ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/)). Do not use VS Code Remote-SSH to login nodes; use the VS Code Tunnel app ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)).

### Open OnDemand (web)
- URL: **https://ondemand.vacc.uvm.edu**. UVM NetID and password (College of Medicine logins do not work). Requires **campus network or UVM VPN** ([Open OnDemand](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)).
- Features: file management, job management (Active Jobs, Job Composer), shell, and interactive apps: Jupyter Notebook, RStudio Server, MATLAB ([Open OnDemand](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)), JupyterLab ([JupyterLab](https://www.uvm.edu/vacc/docs/beyond_basics/jupyter_lab/)), Desktop ([LLM tools](https://www.uvm.edu/vacc/docs/beyond_basics/llm/)), VS Code Tunnel ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)).

### VS Code Tunnel
An OOD app starts a tunnel on a compute node inside tmux. Sign in with your Microsoft UVM account (device code), then connect from local VS Code to the tunnel "vsc-<account>-vacc". Login is cached for 24 hours. Browser-based tunnel access is not supported ([VS Code Tunnel](https://www.uvm.edu/vacc/docs/beyond_basics/vscodetunnel/)).

### Slurm status dashboard
"HPC Dashboard" (slurmdash): live cluster view with job-efficiency scoring and power draw. Requires campus network or VPN ([Slurm Status Dashboard](https://www.uvm.edu/vacc/docs/start_guide/slurmdash/)).

## Allocations, tiers and compute units

From [Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment). Account owners join one tier each UVM fiscal year. Tier fees "will change annually".

| Tier | Cost FY26 | Compute units / year |
| --- | --- | --- |
| 1 | No cost to user (subsidised by VACC; **UVM faculty and staff only**) | Under 250,000 |
| 2 | $1,000 | 250,000 to 3,000,000 |
| 3 | $4,000 | Over 3,000,000 |

- **Compute unit (CU):** 1 CU = 1 core-hour of wall-clock CPU allocation. For GPUs (A100, H100, H200, RTX 6000), 1 CU = 1 GPU-minute, so 60 CU per GPU-hour ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment); [User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)).
- Tier 1's 250,000 CU ≈ 4,167 GPU-hours or 250,000 core-hours (my arithmetic).
- Limits apply to the PI and all sponsored users combined. CU usage is reviewed twice a year; an admin makes contact if a tier change is needed ([PI info: compute](https://www.uvm.edu/vacc/docs/pi-info/compute/)). Whether exceeding the band blocks jobs is **not found**.
- `my_compute_usage` reports CPU-hours, GPU-hours and CUs per user per account ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)).
- Owners of dedicated hardware must be in Tier 2 or 3; existing hardware MOUs stay in effect ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)). Owner-restricted examples: CRREL nodes (GoldenMaple / `gpu-preempt`), SOCKS H100s (`hgnodes`) ([Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/)). No public condo price list.

Disk quotas per tier are listed in [storage.md](storage.md#quotas).

## Paying

From [Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment):
- **Existing award:** check the budget allows it, get sponsor approval, then contact Andi Elledge (aelledge@uvm.edu).
- **New proposal:** budget line "computer devices and VACC charges: F6021 (for account code 80047)". The page supplies budget-justification text.
- **Internal funds** (start-up, incentive): Andi Elledge arranges a transfer.
- **VACC Voucher Fund** (Office of the VP for Research): up to **$10,000**, including priority access and services, for faculty without grant or department funding. Must be spent within the fiscal year.
- **Additional disk:** current gpfs2 (High Throughput Storage) price plus installation and maintenance fee, 4-year life. Email vacc@uvm.edu. No published price.

## Other services (not compute)

- One-on-one onboarding through vacchelp@uvm.edu. Programming assistance from Research Facilitators if a grant funds a share of their time ([Services](https://www.uvm.edu/vacc/services-we-provide)).
- **HPC in the classroom:** OnDemand plus Jupyter on a "dedicated educational SLURM partition that provides no-wait access to GPUs via a class time-based reservation system" ([Services](https://www.uvm.edu/vacc/services-we-provide)). Partition name **not found** on the [partition page](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/).
- UVM framework: VACC first, research VMs second, physical workstations by exception ([ETS Research Computing](https://www.uvm.edu/it/research-computing)).
