# Accounting, associations, QOS, limits, job states, reason codes

Back to [README](README.md). Sources: Slurm 25.11.2 archive.

## Associations

- "Accounting records are maintained based upon what we refer to as an Association, which consists of four elements: cluster, account, user names and an optional partition name" ([Accounting](https://slurm.schedmd.com/archive/slurm-25.11.2/accounting.html)). Accounts form a tree under `root`.
- Associations live in the database behind **slurmdbd** (MySQL or MariaDB) and are managed with `sacctmgr`.
- A user's default account is used when the job gives no `-A` ([Accounting](https://slurm.schedmd.com/archive/slurm-25.11.2/accounting.html)).
- **`AccountingStorageEnforce`** decides what is enforced. With nothing set (the default), jobs run "based upon policies configured in Slurm on each cluster" ([Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html)). The options:

  | Option | What it enforces |
  | --- | --- |
  | `associations` | No job without a valid association |
  | `limits` | Association and QOS limits. Implies `associations` |
  | `qos` | A valid QOS is required |
  | `safe` | With TRES-minute limits, a job starts only if it can run to completion |
  | `wckeys` | Jobs may only use WCKeys the user has access to |

- Lowering limits never cancels running jobs. **Deleting an association immediately cancels its running and pending jobs** ([Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html)).

At VACC: accounts are `pi-<PI NetID>`. `my_accounts` lists yours, and the last one listed is the default ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#scheduler)). `sacctmgr show assoc user=$USER` should show the association rows, with shares, QOS and limits. **Untested at VACC.**

## Limit hierarchy

From [Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html). The first level in this list that defines a limit wins:
1. Partition QOS
2. Job QOS. Levels 1 and 2 swap if the job QOS has `Flags=OverPartQOS`
3. User association
4. Account association(s), going up the tree
5. Root/cluster association
6. Partition limit
7. None

**Exception:** `MaxTime`/`MaxWall` and `Min`/`MaxNodes` can never exceed the **partition's** value. The QOS flags `PartitionTimeLimit` and `PartitionMaxNodes`/`PartitionMinNodes` lift that cap.

## Association limits

| Limit | Meaning |
| --- | --- |
| `Fairshare` | Shares for fairshare. Can be `parent` |
| `GrpJobs` / `GrpSubmitJobs` | Running / running-plus-pending jobs for the association **and its children** |
| `GrpJobsAccrue` | How many pending jobs can accrue age priority |
| `GrpTRES` | TRES in use at once, e.g. `cpu=1500,mem=200,gres/gpu=50` |
| `GrpTRESMins` | Total TRES-minutes, past + present + future. **When reached, all running jobs using that TRES in the group are killed** and new ones blocked. Decays with `PriorityDecayHalfLife` |
| `GrpTRESRunMins` | TRES-minutes of the jobs currently running (counted against their time limits) |
| `GrpWall` | Aggregate wall time. Decays |
| `MaxJobs` / `MaxSubmitJobs` / `MaxJobsAccrue` | Per association, without children |
| `MaxTRESPerJob`, `MaxTRESPerNode`, `MaxTRESMinsPerJob` | Per-job size caps |
| `MaxWallDurationPerJob` | "The job will be denied at submission" if it asks for more |
| `QOS` | The QOS values the association may use |

TRES limits are set and cleared like this: `sacctmgr modify user bob set GrpTRES=cpu=1500,mem=200,gres/gpu=50` sets them, and the same command with `=-1` for each value unsets them.

## QOS

From [QOS](https://slurm.schedmd.com/archive/slurm-25.11.2/qos.html) and [Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html).

A QOS affects three things:
1. **Priority**, if `PriorityWeightQOS > 0`.
2. **Preemption**, if `PreemptType=preempt/qos`.
3. **Limits**, which take precedence over association limits.

Request one with `--qos=`. When a cluster is added, a QOS named **`normal`** is created by default.

**QOS limits:**
- Group totals: `GrpJobs`, `GrpSubmitJobs`, `GrpTRES`, `GrpTRESMins`, `GrpTRESRunMins`, `GrpWall`
- Per user: `MaxJobsPerUser`, `MaxSubmitJobsPerUser`, `MaxTRESPerUser`
- Per account: `MaxJobsPerAccount`, `MaxSubmitJobsPerAccount`, `MaxTRESPerAccount`
- Per job and node: `MaxTRESPerJob`, `MaxTRESPerNode`, `MaxTRESMinsPerJob`, `MaxWallDurationPerJob`, `MinTRESPerJob`
- Age accrual: `MaxJobsAccruePerUser`, `MaxJobsAccruePerAccount`
- Backfill: `MinPrioThreshold`

**Other QOS knobs:**
- `GraceTime`: preemption grace period.
- `UsageFactor`: multiplies the usage the QOS charges. 0 means "free" and 2 means double.
- `UsageThreshold` with `Flags=EnforceUsageThreshold`: jobs are held while the association's fairshare is below the threshold.
- `LimitFactor`: scales association `Grp`/`Max` TRES limits.

**QOS flags:**

| Flag | Effect |
| --- | --- |
| `DenyOnLimit` | Reject at submit instead of pending forever |
| `NoDecay` | `GrpTRESMins`, `GrpWall` and usage never decay, which turns the QOS into a quota |
| `NoReserve` | No backfill reservations |
| `OverPartQOS` | Job QOS beats the partition QOS |
| `PartitionTimeLimit`, `PartitionMaxNodes`, `PartitionMinNodes` | Exceed the partition's limits |
| `RequiresReservation` | Job must name a reservation |
| `Relative` | Limits are percentages (since 23.11, **version-specific**) |
| `UsageFactorSafe` | Combine with `safe` enforcement |

**Partition QOS:**
- Set with `QOS=` on a partition line in slurm.conf. The partition gets the QOS's limits, but its jobs do **not** get the QOS's priority or preemption.
- A partition QOS's limits are shared across every partition that uses that QOS. They are not counted per partition.

**Default behaviour when a limit is hit:** "if a job request breaches a given limit on its own, the job will pend unless the job's QOS has the DenyOnLimit flag set" ([Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html)).

**Typed-GRES limit gap:** `MaxTRESPerUser=gres/gpu:tesla=1` is not enforced on an untyped `--gres=gpu:2` request. See [gpus.md](gpus.md#limits-on-typed-gpus-why-sites-force-a-type-or-feature).

## TRES and billing

From [TRES](https://slurm.schedmd.com/archive/slurm-25.11.2/tres.html) and [Multifactor](https://slurm.schedmd.com/archive/slurm-25.11.2/priority_multifactor.html):
- **TRES types:** BB, Billing, CPU, Energy, FS, GRES, IC, License, Mem, Node, Pages, VMem.
- **Tracked by default:** Billing, CPU, Energy, Memory, Node, FS/Disk, Pages and VMem. Sites append others with `AccountingStorageTRES=gres/gpu,…`.
- **Billing.** `TRESBillingWeights` (per partition) sets each job's **billing** TRES, and that value drives fairshare usage and billing limits. The default is `CPU=1`, so usage is allocated CPU-seconds. The page's example uses `TRESBillingWeights="CPU=1.0,Mem=0.25G,GRES/gpu=2.0"`. By default the weighted TRES are **summed**. `PriorityFlags=MAX_TRES` takes the per-node maximum instead, and `MAX_TRES_GRES` adds GPUs on top of that maximum.
- Billing only CPUs under-counts memory-heavy jobs: "if a job requests 1CPU and 64GB of memory on a 16CPU, 64GB node the job will only be billed for 1CPU when it really used the whole node".

At VACC: VACC's own billing unit is the CU, with 1 GPU-minute = 1 CU ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#node-constraints---constraint---c)). Whether CUs are computed from Slurm's billing TRES or from a separate script (`my_compute_usage`) is **unknown**. `sacct -X -j <id> -o jobid,alloctres%60` shows `billing=` for a job.

## Job states

From [Job State Codes](https://slurm.schedmd.com/archive/slurm-25.11.2/job_state_codes.html). A job has one base state plus optional flags. `squeue` and `sacct` show a single state, and a recognised flag is shown instead of the base state.

**Base states:**

| State | Meaning |
| --- | --- |
| PENDING | Queued, with a reason |
| RUNNING | |
| SUSPENDED | |
| COMPLETED | Exit code 0 on all nodes |
| FAILED | Non-zero exit or another failure |
| CANCELLED | |
| TIMEOUT | Hit the time limit |
| OUT_OF_MEMORY | |
| NODE_FAIL | |
| PREEMPTED | |
| BOOT_FAIL | |
| DEADLINE | |

**Flags:** COMPLETING, CONFIGURING, **EXPEDITING** (new with 25.11 expedited requeue), LAUNCH_FAILED, POWER_UP_NODE, REQUEUED, REQUEUE_HOLD, RESIZING, SIGNALING, SPECIAL_EXIT, STAGE_OUT, STOPPED, and others.

## Pending reason codes

From [Job Reason Codes](https://slurm.schedmd.com/archive/slurm-25.11.2/job_reason_codes.html). "There may be multiple reasons why a job cannot start, in which case only the reason that was encountered by the attempted scheduling method will be displayed."

**Common reasons:**

| Reason | Meaning |
| --- | --- |
| `Priority` | "One of [sic] more higher priority jobs exist for the partition associated with the job or for the advanced reservation" |
| `Resources` | "The resources requested by the job are not available (e.g., already used by other jobs)" |
| `Dependency` / `DependencyNeverSatisfied` | Waiting on another job, or that job's outcome makes the dependency impossible |
| `BeginTime` | `--begin` not reached yet |
| `JobHeldUser` / `JobHeldAdmin` | Held. `scontrol release` (users can release only user holds) |
| `JobArrayTaskLimit` | The array's `%N` throttle has been reached |
| `ReqNodeNotAvail` | Required node busy, reserved, down or drained. The reason also lists `UnavailableNodes` |
| `Reservation` / `ReservationDeleted` | Waiting for its reservation, or the reservation is gone |
| `PartitionTimeLimit` / `PartitionNodeLimit` / `PartitionConfig` | Request exceeds the partition's limits. Fix the request |
| `AccountNotAllowed` / `QOSNotAllowed` / `InvalidAccount` / `InvalidQOS` | Bad account or QOS for this association or partition |
| `Constraints` / `BadConstraints` | Features can't be satisfied now / ever |
| `Licenses` | Waiting for a license (`-L`) |
| `None` | Not yet considered in the current backfill cycle |
| `SchedDefer` | Immediate allocation requested, but `defer` is set |

**Limit families.** The pattern of the name tells you which limit is involved:

| Pattern | Meaning | Examples |
| --- | --- | --- |
| `AssocGrp*` | The association's aggregate limit has been reached. Usually waits for others' jobs to finish | `AssocGrpCpuLimit`, `AssocGrpGRES`, `AssocGrpMemLimit`, `AssocGrpJobsLimit`, `AssocGrpBillingMinutes`, `AssocGrpCPUMinutesLimit` |
| `AssocMax*` | The request exceeds a per-job or per-node maximum for the association | `AssocMaxWallDurationPerJobLimit`, `AssocMaxCpuPerJobLimit`, `AssocMaxGRESPerJob`, `AssocMaxJobsLimit`, `AssocMaxSubmitJobLimit` |
| `QOSGrp*` | The QOS aggregate has been reached | `QOSGrpCpuLimit`, `QOSGrpGRES`, `QOSGrpNodeLimit`, `QOSGrpJobsLimit` |
| `QOSMax*PerUser*` | The **per-user** limit of the QOS | `QOSMaxJobsPerUserLimit` ("the number of jobs a user is allowed to run at a given time has been met"), `QOSMaxCpuPerUserLimit`, `QOSMaxGRESPerUser`, `QOSMaxMemoryPerUser`, `QOSMaxNodePerUserLimit`, `QOSMaxSubmitJobPerUserLimit` |
| `QOSMax*PerJob` / `*PerNode` | Single-job or per-node caps of the QOS | `QOSMaxWallDurationPerJobLimit`, `QOSMaxGRESPerJob`, `QOSMaxCpuPerNode` |
| `Max*PerAccount` | The QOS's per-account limit | `MaxJobsPerAccount`, `MaxGRESPerAccount`, `MaxCpuPerAccount` |
| `QOSMin*` | The request is below the QOS minimum | `QOSMinGRES`, `QOSMinCpuNotSatisfied` |
| `*Minutes` / `*RunMinutes` | TRES-minutes budgets: past+present+future, or currently running | `AssocGrpGRESMinutes`, `QOSGrpCPURunMinutesLimit` |
| `QOSUsageThreshold` | Association fairshare is below the QOS `UsageThreshold` | — |
| `MaxMemPerLimit` | Exceeds memory per CPU or per node | — |

**How to read them:**
- A **`*Grp*`** or **per-user running** reason clears by itself as other jobs end.
- A **`*PerJob`**, **`Partition*Limit`** or **`QOSMin*`** reason means the request itself can never fit. Shrink it, or cancel and resubmit.
- With `DenyOnLimit`, those cases are rejected at submit instead of pending.

These two points are **inference** from the limit definitions above ("If this limit is reached, new jobs will be queued but only allowed to run after…").

**Termination reasons** (`TimeLimit`, `OutOfMemory`, `NonZeroExitCode`, `NodeDown`, `SystemFailure`, `JobLaunchFailure`, `Prolog`, `InactiveLimit`) appear on finished jobs.
