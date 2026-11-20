# Slurm workload manager: research notes

Compiled 2026-11-11 from primary sources only: SchedMD's Slurm documentation, the SchedMD/slurm GitHub repository (source, CHANGELOG, `slurm.spec`, `contribs/`), and the release notes. **Every page was accessed on 2026-11-11.**

**Which docs version.** VACC runs **Slurm 25.11.2** ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md)). The live site at `slurm.schedmd.com` already documents **26.05** (its release-notes page is headed "Release Notes for Slurm 26.05" ([current release notes](https://slurm.schedmd.com/release_notes.html))). So these notes cite SchedMD's **version-pinned archive for 25.11.2**: `https://slurm.schedmd.com/archive/slurm-25.11.2/<page>.html`. Anything that changed in a specific release is marked **(version-specific)**. **Unverified** and **inference** mark points I could not pin to a page. "At VACC" notes link back to the [VACC notes](../vacc/README.md) and only apply general Slurm behaviour to them. They are not new VACC research.

## Contents

1. [What Slurm is](#what-slurm-is)
2. [Architecture](#architecture)
3. [History, licence, ownership](#history-licence-ownership)
4. [Versioning and release cadence](#versioning-and-release-cadence)
5. [What's new in 25.05 and 25.11](#whats-new-in-2505-and-2511)
6. [User commands](#user-commands): details in **[commands.md](commands.md)**
7. [Job scripts, arrays, het jobs, MPI](#job-scripts-in-one-minute): details in **[job-scripts.md](job-scripts.md)**
8. [GPUs](#gpus-in-one-minute): details in **[gpus.md](gpus.md)**
9. [Scheduling and priority](#scheduling-in-one-minute): details in **[scheduling-and-priority.md](scheduling-and-priority.md)** (backfill, multifactor, Fair Tree, preemption, reservations)
10. [Accounting, limits, states, reason codes](#accounting-and-limits-in-one-minute): details in **[accounting-and-limits.md](accounting-and-limits.md)**
11. [Cheat sheet](cheatsheet.md) (commands, pitfalls, and "why is my job pending?")
12. [VACC gaps the Slurm docs help explain](#vacc-gaps-the-slurm-docs-help-explain)
13. [Source map](#source-map)
14. [Open questions / not found](#open-questions--not-found)

## What Slurm is

- "Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters." It needs no kernel changes. It has three key functions: allocating access to resources (nodes) for some duration, providing a framework to start, execute and monitor work on those nodes, and "arbitrat[ing] contention for resources by managing a queue of pending work" ([Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html)).
- Entities: **nodes**; **partitions**, which group nodes and "can be considered job queues"; **jobs**, which are allocations of resources to a user for a time; and **job steps**, which are sets of (possibly parallel) tasks inside a job. Partitions may overlap ([Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html)).
- Name: "SLURM" first stood for "Simple Linux Utility for Resource Management". In 2012 the spelling changed to "Slurm" and the acronym was dropped ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).

## Architecture

From the [Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html):

| Component | Role |
| --- | --- |
| `slurmctld` | Central manager that monitors resources and work. An optional backup can take over on failure |
| `slurmd` | Daemon on each compute node. It "waits for work, executes that work, returns status, and waits for more work". The slurmd daemons provide fault-tolerant hierarchical communications |
| `slurmdbd` | Optional database daemon that records accounting for one or more clusters in a single database |
| `slurmrestd` | Optional REST API daemon |
| `slurmstepd` | Per-step process started by slurmd (see its [man page](https://slurm.schedmd.com/archive/slurm-25.11.2/slurmstepd.html)) |

- Almost everything is a **plugin**: accounting storage, energy gathering, authentication, containers, credentials, GRES (GPUs), job submit, job accounting gather, MPI, preemption, priority, process tracking, scheduler, node selection, site factor, switch, task affinity and network topology ([Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html)).
- Defaults that matter to users, all from [slurm.conf(5)](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html):
  - `SchedulerType=sched/backfill`
  - `SelectType=select/cons_tres` (cores, memory and GPUs allocated individually)
  - `PriorityType=priority/multifactor`, but **every `PriorityWeight*` defaults to 0**
  - `PreemptType` unset and `PreemptMode=OFF`
  - `DefMemPerCPU=0` (unlimited)
  - `JobRequeue=1`, `KillWait=30` s, `MinJobAge=300` s, `MaxArraySize=1001`, `MaxJobCount=10000`
- To see what a site actually runs, use `scontrol show config` (the [FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html) uses `scontrol show config | grep SchedulerType` and `grep InactiveLimit`).

## History, licence, ownership

- First release in **2002**. **SchedMD** was founded in **2010** "to continue developing Slurm". The FAQ says Slurm "powers a majority of the TOP500 supercomputers" ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).
- "Slurm was produced at Lawrence Livermore National Laboratory in collaboration with various organizations" ([DISCLAIMER at tag slurm-25-11-2-1](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/DISCLAIMER)).
- **Licence: GNU GPL v2**, with an OpenSSL linking exception. Some `contribs/` tools carry other licences ([COPYING](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/COPYING); [FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)). Man pages say "version 2 of the License, or (at your option) any later version" ([sshare(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sshare.html)).
- **NVIDIA acquired SchedMD**, announced 2025-12-15, terms undisclosed. NVIDIA says Slurm stays open source and vendor-neutral. **Secondary sourcing only:** I found press coverage (e.g. [heise](https://heise.de/-11115881), [Evertiq](https://evertiq.com/design/2025-12-17-nvidia-acquires-slurm-developer-schedmd)) but did not fetch the NVIDIA or SchedMD announcement itself. Treat the details as unverified.
- EPEL packages Slurm, but SchedMD does not support that build ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).

## Versioning and release cadence

From the [Upgrade Guide](https://slurm.schedmd.com/archive/slurm-25.11.2/upgrades.html):
- Versions are **YY.MM.patch**. For example, 23.11 is the November 2023 major release and `.4` is a maintenance release. Major releases may change RPCs, state files and configuration. Maintenance releases carry bug fixes.
- Major releases came every **9 months** until **24.05**, which started a **6-month cycle** (May and November).
- Since 24.11, upgrades are supported from the **previous three** major releases. **25.11 accepts 25.05, 24.11 and 24.05.**
- **Support for 25.11 ends May 2027** (18 months). 25.05 support ends November 2026. The table lists 26.05 as ending "November 2028 (18 months)", which does not add up; 18 months would be November 2027. **This is probably a typo in the doc.**
- 25.11.2 is git tag `slurm-25-11-2-1`. The annotated tag is dated **2026-01-15** ([GitHub tag API](https://api.github.com/repos/SchedMD/slurm/git/refs/tags/slurm-25-11-2-1)). The 25.11 series reached 25.11.9 by 2026-11-11 ([archive index](https://slurm.schedmd.com/archive/)). 26.05 is current, and its patch releases had reached 26.05.6.
- At VACC: the 25.05→25.11 upgrade happened on 2026-01-07/08 ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md)). That predates the 25.11.2 tag date, so 25.11.2 must have been applied later. **Inference.**

## What's new in 25.05 and 25.11

**25.11** ([25.11 release notes](https://slurm.schedmd.com/archive/slurm-25.11.2/release_notes.html)):
- **Expedited requeue.** Batch jobs with `--requeue=expedite` requeue on node failure, or when the script exits non-zero and an Epilog fails. They then run at the highest priority. The sbatch man page spells the option `--requeue[=expedited]` and requires `SlurmctldParameters=enable_expedited_requeue` ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)). **The two spellings conflict.**
- `squeue --running-over` / `--running-under`: filter running jobs by elapsed time.
- New reservation access controls: `AllowQOS` and `AllowPartition`.
- `job_container` is renamed to **`namespace`**, and there is a new **`namespace/linux`** plugin (filesystem, PID and user namespaces). `NamespaceType` replaces `JobContainerType`.
- OpenMetrics (Prometheus) telemetry from slurmctld, and `/livez`, `/readyz` and `/healthz` probes.
- An experimental async-reply mode for slurmctld.
- "Mode 3" hierarchical resources.
- topology/block options: `--consolidate-segments` and `--spread-segments`.
- NVIDIA IMEX channel options.
- Admins can retroactively change AllocTRES with `sacctmgr`.
- REST API v0.0.44 added. v0.0.41 deprecated (to be removed in 26.05).
- `node_features/knl_generic` removed.
- PMIx: the server no longer puts the node's HWLOC topology into `PMIX_LOCAL_TOPO` by default. The new `PMIxShareServerTopology=true` setting brings it back.
- 25.11.2 fixes include a PMIx 5.0.8/5.0.9 client hang and a reservation starting while GRES were still in use ([CHANGELOG/slurm-25.11.md](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/CHANGELOG/slurm-25.11.md)).

**25.05** ([25.05 release notes](https://slurm.schedmd.com/archive/slurm-25.05.0/release_notes.html)):
- Optional TLS for all Slurm RPC traffic.
- Multiple topologies per partition.
- Hierarchical resources (beta).
- An OR operator in license requests.
- `sacctmgr` can dump and load QOS.
- `srun --wait-for-children` (cgroup/v2 only).
- The FrontEnd mode was removed and **cgroup/v1 was deprecated**.

## User commands

| Command | One-line purpose (sources in [commands.md](commands.md)) |
| --- | --- |
| `sbatch` | Submit a batch script. It returns at once with a job ID |
| `srun` | Launch a parallel step, either inside an allocation or by creating one |
| `salloc` | Get an allocation and run a command or shell in it |
| `squeue` | Show pending and running jobs. `--start` shows estimated start times; `--me` shows only yours |
| `scancel` | Cancel or signal jobs |
| `sinfo` | Show partition and node state |
| `sacct` | Show accounting records. **By default only jobs since midnight today** |
| `sstat` | Show live usage of a *running* step |
| `scontrol` | Show or modify jobs, nodes, partitions and config: `show job`, `hold`, `release`, `update`, `requeue`, `top`, `write batch_script` |
| `sshare` | Show fairshare (`-l` adds Level FS) |
| `sprio` | Show the priority breakdown of pending jobs (`-w` shows weights) |
| `sacctmgr` | Manage the accounting database (associations, QOS). Users can run `show`/`list` |
| `seff` | **contrib** Perl script (Princeton, 2015). Summarises one job's CPU and memory efficiency |

## Job scripts in one minute

- `#SBATCH` lines are read until the first non-comment, non-blank line. Shell variables are not expanded in them. Command-line options override environment variables, which override the script ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
- `--mem` is per node, `--mem-per-cpu` per usable CPU, and `--mem-per-gpu` per GPU. The three are mutually exclusive, and `--mem=0` means all memory on each node.
- Default output is `slurm-%j.out`, or `slurm-%A_%a.out` for arrays.
- Arrays use `--array=0-99%10`, which caps it at 10 tasks running at once. The highest index is `MaxArraySize-1`, and `MaxArraySize` defaults to 1001.
- For dependencies, see `afterok` / `afterany` / `afternotok` / `aftercorr` / `singleton`.
- Heterogeneous jobs separate components with `:` or with `#SBATCH hetjob`.
- MPI: launch with `srun` using PMIx/PMI-2. That is "the preferred mode of operation" for Open MPI, and Intel MPI calls srun "recommended".

Full details: **[job-scripts.md](job-scripts.md)**.

## GPUs in one minute

- GPUs are a GRES. Nothing is allocated unless you ask for it with `--gres=gpu[:type]:n` (per node), `--gpus=[type:]n` (per job), `--gpus-per-node`, `--gpus-per-task` or `--gpus-per-socket` ([GRES](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html)).
- Slurm sets `CUDA_VISIBLE_DEVICES` for each step. Under cgroup device constraint the numbering is **relative**, so it always starts at 0.
- **MIG** has been supported since 21.08, with MIGs pre-partitioned (no dynamic MIG).
- **MPS** and **sharding** let several jobs share one GPU. Sharding gives no isolation.

Full details: **[gpus.md](gpus.md)**.

## Scheduling in one minute

- **Backfill** starts lower-priority jobs if that "does not delay the expected start time of any higher priority job". **Accurate `--time` is the key** ([Scheduling Configuration Guide](https://slurm.schedmd.com/archive/slurm-25.11.2/sched_config.html)).
- The scheduler evaluates jobs in this order: those that can preempt, then those with a reservation, then partition PriorityTier, then job priority, then submit time, then job ID ([Multifactor](https://slurm.schedmd.com/archive/slurm-25.11.2/priority_multifactor.html)).
- Priority is a weighted sum: site + age + association + fairshare + job size + partition + QOS + TRES − nice.
- Fairshare defaults to the **Fair Tree** algorithm.
- Preemption is by partition PriorityTier or by QOS, with modes CANCEL, REQUEUE or SUSPEND(+GANG).

Full details: **[scheduling-and-priority.md](scheduling-and-priority.md)**.

## Accounting and limits in one minute

- An **association** is the tuple (cluster, account, user, optional partition) ([Accounting](https://slurm.schedmd.com/archive/slurm-25.11.2/accounting.html)).
- Limits are checked in this order: partition QOS, job QOS, user association, account associations (going up), root, and finally partition limits ([Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html)).
- Usage is billed as CPU-seconds unless `TRESBillingWeights` is set.
- Pending reasons map one-to-one onto these limits, e.g. `QOSMaxJobsPerUserLimit` or `AssocGrpGRES` ([Job Reason Codes](https://slurm.schedmd.com/archive/slurm-25.11.2/job_reason_codes.html)).

Full details: **[accounting-and-limits.md](accounting-and-limits.md)**.

## VACC gaps the Slurm docs help explain

These are general mechanisms. The VACC configuration values are still unknown, but most can be read with the read-only commands shown here. **Running them on VACC is untested.**

| VACC gap ([vacc/README.md](../vacc/README.md#open-questions--not-found)) | What Slurm's docs say, and how to check |
| --- | --- |
| Fairshare, priority weights, QOS undocumented | Multifactor is the default plugin, but all weights default to 0, so the VACC config decides what counts. `sprio -w` shows the weights, `sprio -l` each pending job's factors, and `sshare -l` (Fair Tree Level FS) where your account stands. `sacctmgr show qos` lists QOS. See [scheduling-and-priority.md](scheduling-and-priority.md) |
| How the voucher's "priority cluster access" works | Possible Slurm mechanisms are a higher-priority QOS, more fairshare shares on the association, a partition with a higher PriorityTier, or a reservation. **Which one VACC uses is unknown.** `sacctmgr show assoc user=$USER` and `sacctmgr show qos` would reveal the first two |
| Per-user core/GPU caps on `general`, `week`, `nvgpu` | Such caps would live in association or QOS limits (`MaxTRESPerUser`, `GrpTRES`, `MaxJobsPerUser`…) or in partition limits. When one bites, the job pends with a matching reason, e.g. `QOSMaxGRESPerUser`. See [accounting-and-limits.md](accounting-and-limits.md) |
| Group "exceeds its CU band": hard stop or not? | Slurm can do either. Fairshare alone never cuts anyone off ("does not involve a fixed allotment"). A hard stop needs `GrpTRESMins` with `limits` enforcement (running jobs are killed when it is reached unless `safe`), a `UsageThreshold`, or a `NoDecay` QOS |
| Job arrays and `MaxArraySize` | Arrays are standard Slurm. The default `MaxArraySize` is 1001. Each task counts as a job against `MaxJobs`/`MaxSubmitJobs`. Check with `scontrol show config \| grep -i -E 'MaxArraySize\|MaxJobCount'` |
| Default time and memory for `week`/`nvgpu` | `scontrol show partition week` shows `DefaultTime`, `MaxTime`, `DefMemPerCPU`/`DefMemPerNode` and so on. The global default memory is "0 (unlimited)" unless the site sets one |
| `gpu-preempt`: what happens to preempted jobs | Depends on `PreemptType` / `PreemptMode` (CANCEL, REQUEUE or SUSPEND) and `GraceTime`. VACC says jobs are "cancelled". If the mode were REQUEUE, `--no-requeue` would make them cancel instead. Check `scontrol show partition gpu-preempt` (`PreemptMode`, `PriorityTier`, `GraceTime`) |
| GPU `--constraint` mandatory, with a "scheduler warning" otherwise | Slurm's own docs note that typed-GRES limits are not enforced on untyped requests. They suggest a **job_submit/lua** plugin to force users to name a type. A site warning on a missing GPU feature is consistent with such a plugin. **Inference** |
| Private `/tmp`, `/var/tmp`, `/dev/shm` per job (since 2026-06-10) | This matches Slurm's **namespace** plugins (`namespace/tmpfs`, or `namespace/linux`, new in 25.11). They give each job a private `/tmp` and `/dev/shm`, configurable through `Dirs=`, and remove the contents at job end ([Namespace plugins](https://slurm.schedmd.com/archive/slurm-25.11.2/namespace.html)). **Which plugin VACC uses is unknown** |
| Jobs held before a maintenance window | Consistent with a `MAINT` reservation. Jobs whose `--time` would overlap it cannot use the reserved nodes, so a shorter `--time` may let a job run before the window. **Inference** (see [scheduling-and-priority.md](scheduling-and-priority.md#reservations)) |
| `my_job_statistics` vs `seff` | `seff` is a SchedMD **contrib** script. It is "roughly equivalent to" an `sacct` query ([contribs/seff/seff](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/contribs/seff/seff)) |

## Source map

All of these are under `https://slurm.schedmd.com/archive/slurm-25.11.2/` unless noted:
- **Concepts:** `overview`, `quickstart`, `faq`, `upgrades`, `release_notes`
- **Man pages:** `sbatch`, `srun`, `salloc`, `squeue`, `scancel`, `sinfo`, `sacct`, `sstat`, `scontrol`, `sshare`, `sprio`, `sacctmgr`, `slurm.conf`
- **Guides:** `gres`, `priority_multifactor`, `fair_tree`, `classic_fair_share`, `preempt`, `qos`, `resource_limits`, `accounting`, `tres`, `job_array`, `heterogeneous_jobs`, `mpi_guide`, `sched_config`, `reservations`, `job_reason_codes`, `job_state_codes`, `job_exit_code`, `namespace`
- **GitHub, tag `slurm-25-11-2-1`:** `COPYING`, `DISCLAIMER`, `CHANGELOG/slurm-25.11.md` (and the 22.05 and 23.11 changelogs), `contribs/seff/seff`, `contribs/README`, `slurm.spec`

## Open questions / not found

1. **NVIDIA acquisition of SchedMD:** I did not fetch the primary announcement. The date (2025-12-15) and the "stays open source" pledge come from press coverage only.
2. **Expedited requeue spelling:** the release notes say `--requeue=expedite` and sbatch(1) says `--requeue[=expedited]`. Not tested.
3. **Upgrade Guide typo:** 26.05 end of support is listed as "November 2028 (18 months)", which does not match 18 months. Probably November 2027.
4. **When 25.11.2 was released:** only the git tag date (2026-01-15) was found. No dated SchedMD announcement was checked.
5. **Archive gaps:** the 25.11.2 archive pages `sched_backfill`, `sharing`, `mig_support`, `gres_sharding` and `mc_support` came back as stubs or 404s. MIG and sharding were taken from `gres.html` instead.
6. **Not researched in depth:** burst buffers, federation, power saving, containers (`scrun`), the REST API endpoints, `scrontab`, licenses beyond the basics, and topology/block.
7. **seff accuracy:** I read only its header, which describes the `sacct` query it is roughly equivalent to. How it computes efficiency for GPU jobs was not checked, and it does not appear to report GPU utilisation. **Unverified.**
8. **All VACC-specific values** (weights, QOS names, limits, PreemptMode, namespace plugin, MaxArraySize) stay unknown until someone runs the read-only commands above on VACC.
