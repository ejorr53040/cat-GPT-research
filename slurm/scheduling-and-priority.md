# Scheduling, priority, fairshare, preemption, reservations

Back to [README](README.md). All pages were accessed 2026-11-11 (Slurm 25.11.2 archive).

## The main scheduler and backfill

From the [Scheduling Configuration Guide](https://slurm.schedmd.com/archive/slurm-25.11.2/sched_config.html):
- **Event-driven passes.** On submit, completion and similar events, Slurm makes a quick scheduling attempt over `default_queue_depth` jobs (default 100).
- **Main loop.** Every `sched_interval` (default 60 s) the main loop considers all pending jobs. Both passes go strictly by priority: "once any job ... in a partition is left pending, no other jobs in that partition will be scheduled".
- **Backfill** (`sched/backfill`, the default) "will start lower priority jobs if doing so does not delay the expected start time of any higher priority jobs".
  - It reserves resources for higher-priority jobs at their expected start times. Those expected starts are what `squeue --start` reports.
  - "Reasonably accurate time limits are important for backfill scheduling to work well."
  - The FAQ adds: "The most common problem is failing to set job time limits. If all jobs have the same time limit ... backfill will not be effective" ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).
- **Backfill defaults (admin-tunable):**
  - `bf_interval=30` s
  - `bf_window=1440` min (one day). The guide says it should be "at least as long as the highest allowed time limit … to prevent job starvation".
  - `bf_resolution=60` s
  - `bf_max_job_test=100`
  - `bf_max_job_user=0` (no per-user limit)
- **Multi-partition jobs.** A job that names several partitions gets one job-partition pair per partition. Backfill may reserve resources in each partition and start the job where it can start earliest. `bf_one_resv_per_job` limits this.
- **The pure FIFO alternative** is `sched/builtin`: strict priority order, and it disables heterogeneous jobs ([slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)).
- **Backfill and preemption.** Backfill reserves *whole nodes* for a preemptor. "Jobs may preempt more resources during a single backfill iteration than they requested" ([Preemption](https://slurm.schedmd.com/archive/slurm-25.11.2/preempt.html)).

**Order of evaluation.** The scheduler considers jobs in this order ([Multifactor](https://slurm.schedmd.com/archive/slurm-25.11.2/priority_multifactor.html)):
1. jobs that can preempt
2. jobs with an advanced reservation
3. partition **PriorityTier**
4. job priority
5. submit time
6. job ID

So "the job with the highest priority may not be the first to be evaluated".

At VACC: VACC's docs say jobs that fit "gaps between larger jobs" start sooner ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#scheduler)). That is backfill, and it only helps if your `--time` is realistic. Check `bf_window` with `scontrol show config | grep SchedulerParameters`. If the window is shorter than 7 days, `week` jobs may get no backfill reservation; the guide warns of starvation in that case. **Unverified at VACC.**

## Multifactor priority

Source: [Multifactor Priority Plugin](https://slurm.schedmd.com/archive/slurm-25.11.2/priority_multifactor.html).

```
Job_priority = site_factor
  + PriorityWeightAge       * age_factor
  + PriorityWeightAssoc     * assoc_factor
  + PriorityWeightFairshare * fair-share_factor
  + PriorityWeightJobSize   * job_size_factor
  + PriorityWeightPartition * priority_job_factor
  + PriorityWeightQOS       * QOS_factor
  + SUM(TRES_weight_<type> * TRES_factor_<type>)
  - nice_factor
```

- Each factor is a float from 0.0 to 1.0, and each weight is a 32-bit unsigned integer. Priority runs from 0 to 4294967295, and higher numbers are scheduled sooner.
- **In 25.11 the default `PriorityType` is `priority/multifactor`, but every `PriorityWeight*` defaults to 0** ([slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)). A site that set no weights gets roughly submit-order scheduling (**inference** from the formula plus the evaluation order).
- The page advises weights of about 1000 or more, so that the factors keep useful precision.

| Factor | Meaning |
| --- | --- |
| **Age** | Time spent eligible in the queue. Maxes out at `PriorityMaxAge` (default 7-0). It does not grow while the job waits on a dependency, or while it exceeds current limits. `GrpJobsAccrue`/`MaxJobsAccrue*` can cap how many of your jobs accrue age. Needs the accounting DB |
| **Association** | An integer priority set per association, normalised to the highest |
| **Fair-share** | Promised share versus consumed usage. See below. Needs the accounting DB |
| **Job size** | Nodes or CPUs requested. Favours large jobs unless `PriorityFavorSmall=YES`. `SMALL_RELATIVE_TO_TIME` divides size by time limit |
| **Nice** | `--nice=<n>` lowers your own job's priority. Only privileged users may use negative values. Range ±2147483645 |
| **Partition** | The partition's `PriorityJobFactor`, normalised. This is **not** `PriorityTier`, which acts before priority (see above) |
| **QOS** | The QOS `Priority`, normalised. It only counts if `PriorityWeightQOS > 0` ([QOS](https://slurm.schedmd.com/archive/slurm-25.11.2/qos.html)) |
| **Site** | Set by an admin, `scontrol`, or a job_submit or site_factor plugin |
| **TRES** | `PriorityWeightTRES=CPU=…,Mem=…,GRES/gpu=…`. The TRES factor scales with how much of each TRES the job asks for, so a bigger request scores higher. Defaults are 0 ([TRES](https://slurm.schedmd.com/archive/slurm-25.11.2/tres.html)) |

Decay and resets:
- `PriorityDecayHalfLife` (default 7-0) sets how fast past usage stops counting.
- `PriorityCalcPeriod` (default 5 min) sets how often decay and fairshare are recalculated.
- `PriorityUsageResetPeriod` (default NONE) can instead zero usage on a fixed schedule: DAILY, WEEKLY, MONTHLY, QUARTERLY or YEARLY.

## Fairshare

What it is ([Multifactor](https://slurm.schedmd.com/archive/slurm-25.11.2/priority_multifactor.html)):
- "The fair-share factor does not involve a fixed allotment, whereby a user's access to a machine is cut off once that allotment is reached."
- Instead, under-serviced accounts go first and over-serviced ones run "when the machine would otherwise go idle".
- Usage is counted in **allocated CPU-seconds** by default. Partitions can bill other TRES through `TRESBillingWeights` (see [accounting-and-limits.md](accounting-and-limits.md#tres-and-billing)).

**Fair Tree (the default since 19.05)** ([Fair Tree](https://slurm.schedmd.com/archive/slurm-25.11.2/fair_tree.html)):
- For each association, compute **Level Fairshare** against its siblings: `LF = S / U`.
  - `S` is the shares normalised among siblings.
  - `U` is the usage normalised among siblings.
  - LF > 1 means under-served, LF < 1 over-served, and no usage gives infinity.
- Sort the association tree by LF and walk it depth-first. Each user's final **FairShare = rank / number of user associations**, so the top user gets 1.0.
- The key property: "if accounts A and B are siblings and A has a higher fairshare factor than B, all children of A will have higher fairshare factors than all children of B."
- Your group's (account's) standing against other groups dominates. Your own usage only orders you within the group.
- Admin note: because Fair Tree ranks all users, `PriorityWeightFairshare` "can be usefully set to a much smaller value than usual".

**Classic fairshare** runs only if `PriorityFlags=NO_FAIR_TREE` ([Multifactor](https://slurm.schedmd.com/archive/slurm-25.11.2/priority_multifactor.html)). It uses `F = 2**(-U_E/S)` ([Classic Fairshare](https://slurm.schedmd.com/archive/slurm-25.11.2/classic_fair_share.html)).

**Fairshare=parent:** a user association with `Fairshare=parent` uses its parent's fairshare ([Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html)).

## Reading your priority (sprio and sshare)

**sprio** ([sprio(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sprio.html)):
- Shows the weighted priority components of **pending** jobs.
  - `-l` adds user, account, QOS and nice.
  - `-n` shows the normalised 0 to 1 values.
  - `-w` shows the configured weights.
  - `-u user`, `-j id` and `-p part` filter.
- Example from the man page:
  ```
  $ sprio -w
    JOBID   PRIORITY        AGE  FAIRSHARE    JOBSIZE  PARTITION        QOS
    Weights                1000     100000       1000      10000          1
  ```

**sshare** ([sshare(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sshare.html)):
- Columns:
  - **Raw Shares** / **Norm Shares**
  - **Raw Usage**: TRES-seconds, decayed
  - **Effectv Usage**
  - **FairShare**: the factor that feeds into priority
  - **Level FS**: with `-l`, under Fair Tree
- Useful forms: `sshare -l`, `sshare -A <account> -a`, and `sshare -U` (only your user rows).
- "Run `sshare -l` ... If you (UserA) have a lower FairShare value than another user (UserB) ... find the first common ancestor account" and compare the Level FS of the two child accounts below it ([Fair Tree](https://slurm.schedmd.com/archive/slurm-25.11.2/fair_tree.html)).

At VACC: weights, shares and the account tree are undocumented ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#scheduler)). `sprio -w` and `sshare -l` should show them. VACC accounts are `pi-<netid>`, so under Fair Tree each PI group competes as one sibling account. That is **inference**: the tree shape is unknown.

## Preemption

From [Preemption](https://slurm.schedmd.com/archive/slurm-25.11.2/preempt.html) and [slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html):

**`PreemptType`** (preemption is off unless this is set):
- `preempt/partition_prio`: a partition with a higher `PriorityTier` preempts a lower one. The default `PriorityTier` is 1, and equal tiers don't preempt each other.
- `preempt/qos`: a QOS lists which other QOS it may preempt. Preemption eligibility uses the **job's** QOS, not a partition QOS.

**`PreemptMode`** (set per partition or per QOS):

| Mode | What happens to the preempted job |
| --- | --- |
| `OFF` | Default. No preemption |
| `CANCEL` | Cancelled |
| `REQUEUE` | Requeued if possible, otherwise cancelled. This needs `--requeue` or `JobRequeue=1` (the default) |
| `SUSPEND` | Suspended and resumed later. Needs `GANG` set at cluster level. Suspended jobs keep their memory |
| `GANG` | Time-slicing |

Related settings:
- **`GraceTime`** (seconds, default 0). The job is sent SIGCONT and SIGTERM, then SIGKILL after the grace time. Not used for SUSPEND.
- **`PreemptExemptTime`**: minimum run time before a job can be preempted. Honoured only for REQUEUE and CANCEL.
- **QOS `NoReserve`**: jobs in such a QOS make no backfill reservations. It is meant for "standby" QOS ([QOS](https://slurm.schedmd.com/archive/slurm-25.11.2/qos.html)).
- **Order of victims:** the preemption list is ordered by QOS priority, by partition priority plus job size (smaller first), or youngest first with `youngest_first`.

At VACC: `gpu-preempt` lets outside users borrow CRREL's H200s, and "outside jobs are cancelled" when CRREL needs them ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#partitions)). That fits `partition_prio` (the `goldenmaple` partition with a higher PriorityTier over `gpu-preempt`) or `preempt/qos`, with `CANCEL` or `REQUEUE`. **The real mode is unverified.** Check it with `scontrol show partition gpu-preempt`. If `GraceTime` is non-zero, a preempted job gets SIGTERM first, so jobs there should checkpoint and trap SIGTERM. That is general advice, not VACC guidance.

## Reservations

From [Advanced Resource Reservation Guide](https://slurm.schedmd.com/archive/slurm-25.11.2/reservations.html):
- Only root or SlurmUser can create reservations, with `scontrol create reservation`. Users see them with `scontrol show reservation` and use them with `--reservation=<name>`.
- Reserved cores or nodes can only be used by jobs in that reservation. Other jobs can't use them, unless the reservation has the `FLEX` flag.
- A full-system maintenance reservation uses `flags=maint`.
- **(new in 25.11)** Reservations can restrict access by QOS and partition (`AllowQOS`, `AllowPartition`) ([25.11 release notes](https://slurm.schedmd.com/archive/slurm-25.11.2/release_notes.html)).
- Pending reasons involved: `Reservation` (waiting for its reservation to become active), `ReqNodeNotAvail` (required nodes are reserved, down or drained), and `ReservationDeleted` ([Job Reason Codes](https://slurm.schedmd.com/archive/slurm-25.11.2/job_reason_codes.html)).

At VACC: "jobs that would run into a maintenance window are held" ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#maintenance-windows)). This matches a MAINT reservation. A job can start before the window only if its `--time` ends before the window begins. So before maintenance, lowering `--time` with `scontrol update JobId=<id> TimeLimit=<shorter>` may let a pending job run. **Inference;** that a user may lower their own job's limit is likewise inferred from the "privileged" wording in [scontrol(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html).
