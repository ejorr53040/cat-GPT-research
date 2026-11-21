# Slurm workload manager: research notes

VACC runs **Slurm 25.11.2** ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md)). These notes cite SchedMD's version-pinned archive, `https://slurm.schedmd.com/archive/slurm-25.11.2/<page>.html`, plus the SchedMD/slurm GitHub repository at tag `slurm-25-11-2-1`. The live `slurm.schedmd.com` documents 26.05. Markers: **(version-specific)** for behaviour tied to a release; **Unverified** / **inference** for points not pinned to a page. "At VACC" notes apply general Slurm behaviour to the [VACC notes](../vacc/README.md).

## Contents

| File | Covers |
| --- | --- |
| [commands.md](commands.md) | `sbatch`, `srun`, `salloc`, `squeue`, `scancel`, `sinfo`, `sacct`, `sstat`, `scontrol`, `sacctmgr`, `seff` |
| [job-scripts.md](job-scripts.md) | `#SBATCH` directives, resource requests, output files, environment variables, dependencies, arrays, heterogeneous jobs, interactive jobs, MPI, binding, exit codes |
| [gpus.md](gpus.md) | GRES, GPU options, `CUDA_VISIBLE_DEVICES`, GPU accounting, MIG, MPS, sharding, constraints vs GRES types |
| [scheduling-and-priority.md](scheduling-and-priority.md) | Backfill, evaluation order, multifactor priority, Fair Tree, `sprio`/`sshare`, preemption, reservations |
| [accounting-and-limits.md](accounting-and-limits.md) | Associations, limit hierarchy, QOS, TRES and billing, job states, pending reason codes |
| [cheatsheet.md](cheatsheet.md) | Commands, pitfalls, "why is my job pending?" |

In this file: [What Slurm is](#what-slurm-is) · [Architecture](#architecture) · [Licence and packaging](#licence-and-packaging) · [Versioning and release cadence](#versioning-and-release-cadence) · [What's new in 25.05 and 25.11](#whats-new-in-2505-and-2511) · [VACC gaps the Slurm docs help explain](#vacc-gaps-the-slurm-docs-help-explain) · [Source map](#source-map) · [Open questions / not found](#open-questions--not-found)

## What Slurm is

- An open-source cluster management and job scheduling system for Linux clusters. It allocates resources (nodes) for a duration, starts and monitors work on them, and manages a queue of pending work ([Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html)).
- Entities: **nodes**; **partitions**, which group nodes, act as job queues and may overlap; **jobs**, allocations of resources to a user for a time; **job steps**, sets of (possibly parallel) tasks inside a job ([Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html)).

## Architecture

From the [Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html):

| Component | Role |
| --- | --- |
| `slurmctld` | Central manager that monitors resources and work. An optional backup can take over on failure |
| `slurmd` | Daemon on each compute node: waits for work, executes it, returns status. Provides fault-tolerant hierarchical communications |
| `slurmdbd` | Optional database daemon that records accounting for one or more clusters |
| `slurmrestd` | Optional REST API daemon |
| `slurmstepd` | Per-step process started by slurmd ([man page](https://slurm.schedmd.com/archive/slurm-25.11.2/slurmstepd.html)) |

- Most functions are **plugins**: accounting storage, energy gathering, authentication, containers, credentials, GRES (GPUs), job submit, job accounting gather, MPI, preemption, priority, process tracking, scheduler, node selection, site factor, switch, task affinity, network topology ([Overview](https://slurm.schedmd.com/archive/slurm-25.11.2/overview.html)).
- Defaults that matter to users ([slurm.conf(5)](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)):
  - `SchedulerType=sched/backfill`
  - `SelectType=select/cons_tres` (cores, memory and GPUs allocated individually)
  - `PriorityType=priority/multifactor`, but **every `PriorityWeight*` defaults to 0**
  - `PreemptType` unset and `PreemptMode=OFF`
  - `DefMemPerCPU=0` (unlimited)
  - `JobRequeue=1`, `KillWait=30` s, `MinJobAge=300` s, `MaxArraySize=1001`, `MaxJobCount=10000`
- A site's actual values: `scontrol show config` (e.g. `scontrol show config | grep SchedulerType`) ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).

## Licence and packaging

- **GNU GPL v2** ("or any later version"), with an OpenSSL linking exception. Some `contribs/` tools carry other licences ([COPYING](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/COPYING); [FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html); [sshare(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sshare.html)).
- EPEL packages Slurm, but SchedMD does not support that build ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).

## Versioning and release cadence

From the [Upgrade Guide](https://slurm.schedmd.com/archive/slurm-25.11.2/upgrades.html):
- Versions are **YY.MM.patch**. Major releases may change RPCs, state files and configuration; maintenance releases carry bug fixes.
- Since 24.05, major releases come every **6 months** (May and November).
- Upgrades are supported from the **previous three** major releases: **25.11 accepts 25.05, 24.11 and 24.05.**
- **Support for 25.11 ends May 2027** (18 months). 25.05 support ends November 2026.
- 25.11.2 is git tag `slurm-25-11-2-1`, dated **2026-01-15** ([GitHub tag API](https://api.github.com/repos/SchedMD/slurm/git/refs/tags/slurm-25-11-2-1)). Later 25.11 maintenance releases exist ([archive index](https://slurm.schedmd.com/archive/)).
- At VACC: the 25.05→25.11 upgrade happened on 2026-01-07/08 ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md)).

## What's new in 25.05 and 25.11

**25.11** ([25.11 release notes](https://slurm.schedmd.com/archive/slurm-25.11.2/release_notes.html)):
- **Expedited requeue.** Batch jobs requeue on node failure, or when the script exits non-zero and an Epilog fails, then run at the highest priority. The release notes spell it `--requeue=expedite`; sbatch(1) spells it `--requeue[=expedited]` and requires `SlurmctldParameters=enable_expedited_requeue` ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)). **The spellings conflict; untested.**
- `squeue --running-over` / `--running-under`: filter running jobs by elapsed time.
- Reservation access controls `AllowQOS` and `AllowPartition`.
- `job_container` renamed to **`namespace`**; new **`namespace/linux`** plugin (filesystem, PID and user namespaces). `NamespaceType` replaces `JobContainerType`.
- OpenMetrics (Prometheus) telemetry from slurmctld; `/livez`, `/readyz`, `/healthz` probes.
- Experimental async-reply mode for slurmctld.
- "Mode 3" hierarchical resources.
- topology/block options `--consolidate-segments` and `--spread-segments`.
- NVIDIA IMEX channel options.
- Admins can retroactively change AllocTRES with `sacctmgr`.
- REST API v0.0.44 added; v0.0.41 deprecated (removal in 26.05).
- `node_features/knl_generic` removed.
- PMIx: the server no longer puts the node's HWLOC topology into `PMIX_LOCAL_TOPO` by default; `PMIxShareServerTopology=true` restores it.
- 25.11.2 fixes include a PMIx 5.0.8/5.0.9 client hang and a reservation starting while GRES were still in use ([CHANGELOG/slurm-25.11.md](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/CHANGELOG/slurm-25.11.md)).

**25.05** ([25.05 release notes](https://slurm.schedmd.com/archive/slurm-25.05.0/release_notes.html)):
- Optional TLS for all Slurm RPC traffic.
- Multiple topologies per partition.
- Hierarchical resources (beta).
- OR operator in license requests.
- `sacctmgr` can dump and load QOS.
- `srun --wait-for-children` (cgroup/v2 only).
- FrontEnd mode removed; **cgroup/v1 deprecated**.

## VACC gaps the Slurm docs help explain

General mechanisms only; VACC's configured values are unknown but most can be read with the read-only commands shown. **Running them on VACC is untested.**

| VACC gap ([vacc/README.md](../vacc/README.md#open-questions--not-found)) | What Slurm's docs say, and how to check |
| --- | --- |
| Fairshare, priority weights, QOS undocumented | Multifactor is the default plugin, but all weights default to 0, so the VACC config decides what counts. `sprio -w` (weights), `sprio -l` (each pending job's factors), `sshare -l` (Fair Tree Level FS), `sacctmgr show qos`. See [scheduling-and-priority.md](scheduling-and-priority.md) |
| How the voucher's "priority cluster access" works | Candidate mechanisms: higher-priority QOS, more fairshare shares on the association, a partition with higher PriorityTier, or a reservation. **Which one VACC uses is unknown.** `sacctmgr show assoc user=$USER` and `sacctmgr show qos` reveal the first two |
| Per-user core/GPU caps on `general`, `week`, `nvgpu` | Such caps live in association or QOS limits (`MaxTRESPerUser`, `GrpTRES`, `MaxJobsPerUser`…) or partition limits. A job hitting one pends with a matching reason, e.g. `QOSMaxGRESPerUser`. See [accounting-and-limits.md](accounting-and-limits.md) |
| Group "exceeds its CU band": hard stop or not? | Fairshare alone never cuts anyone off ("does not involve a fixed allotment"). A hard stop needs `GrpTRESMins` with `limits` enforcement (running jobs are killed when reached unless `safe`), a `UsageThreshold`, or a `NoDecay` QOS |
| Job arrays and `MaxArraySize` | Default `MaxArraySize` is 1001. Each task counts as a job against `MaxJobs`/`MaxSubmitJobs`. Check with `scontrol show config \| grep -i -E 'MaxArraySize\|MaxJobCount'` |
| Default time and memory for `week`/`nvgpu` | `scontrol show partition week` shows `DefaultTime`, `MaxTime`, `DefMemPerCPU`/`DefMemPerNode`. Global default memory is "0 (unlimited)" unless set |
| `gpu-preempt`: what happens to preempted jobs | Depends on `PreemptType` / `PreemptMode` (CANCEL, REQUEUE or SUSPEND) and `GraceTime`. VACC says jobs are "cancelled". Under REQUEUE, `--no-requeue` makes them cancel instead. Check `scontrol show partition gpu-preempt` (`PreemptMode`, `PriorityTier`, `GraceTime`) |
| GPU `--constraint` mandatory, with a "scheduler warning" otherwise | Typed-GRES limits are not enforced on untyped requests; SchedMD suggests a **job_submit/lua** plugin to force a type. A site warning on a missing GPU feature is consistent with such a plugin. **Inference** |
| Private `/tmp`, `/var/tmp`, `/dev/shm` per job (since 2026-06-10) | Matches Slurm's **namespace** plugins (`namespace/tmpfs`, or `namespace/linux`, new in 25.11): private `/tmp` and `/dev/shm` per job, configurable via `Dirs=`, removed at job end ([Namespace plugins](https://slurm.schedmd.com/archive/slurm-25.11.2/namespace.html)). **Which plugin VACC uses is unknown** |
| Jobs held before a maintenance window | Consistent with a `MAINT` reservation. Jobs whose `--time` overlaps it cannot use the reserved nodes, so a shorter `--time` may let a job run before the window. **Inference** (see [scheduling-and-priority.md](scheduling-and-priority.md#reservations)) |
| `my_job_statistics` vs `seff` | `seff` is a SchedMD **contrib** script, "roughly equivalent to" an `sacct` query ([contribs/seff/seff](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/contribs/seff/seff)) |

## Source map

Under `https://slurm.schedmd.com/archive/slurm-25.11.2/` unless noted:
- **Concepts:** `overview`, `quickstart`, `faq`, `upgrades`, `release_notes`
- **Man pages:** `sbatch`, `srun`, `salloc`, `squeue`, `scancel`, `sinfo`, `sacct`, `sstat`, `scontrol`, `sshare`, `sprio`, `sacctmgr`, `slurm.conf`
- **Guides:** `gres`, `priority_multifactor`, `fair_tree`, `classic_fair_share`, `preempt`, `qos`, `resource_limits`, `accounting`, `tres`, `job_array`, `heterogeneous_jobs`, `mpi_guide`, `sched_config`, `reservations`, `job_reason_codes`, `job_state_codes`, `job_exit_code`, `namespace`
- **GitHub, tag `slurm-25-11-2-1`:** `COPYING`, `DISCLAIMER`, `CHANGELOG/slurm-25.11.md` (and the 22.05 and 23.11 changelogs), `contribs/seff/seff`, `contribs/README`, `slurm.spec`

## Open questions / not found

1. **Expedited requeue spelling:** `--requeue=expedite` (release notes) vs `--requeue[=expedited]` (sbatch(1)). Not tested.
2. **Archive gaps:** the 25.11.2 archive pages `sched_backfill`, `sharing`, `mig_support`, `gres_sharding` and `mc_support` are stubs or 404s; MIG and sharding notes come from `gres.html`.
3. **Not covered:** burst buffers, federation, power saving, containers (`scrun`), REST API endpoints, `scrontab`, licenses beyond the basics, topology/block.
4. **seff and GPUs:** it does not appear to report GPU utilisation. **Unverified.**
5. **All VACC-specific values** (weights, QOS names, limits, PreemptMode, namespace plugin, MaxArraySize) are unknown until the read-only commands above are run on VACC.
