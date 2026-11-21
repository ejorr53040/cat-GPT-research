# Slurm cheat sheet (25.11)

Back to [README](README.md). Each line links to its source; fuller notes are in the sibling files. `<id>` stands for a job ID.

## Submit and run

| Task | Command | Source |
| --- | --- | --- |
| Submit a script | `sbatch job.sh` | [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) |
| One-liner job | `sbatch --wrap="python x.py" -t 10` | [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) |
| Estimate the start time without submitting | `sbatch --test-only job.sh` | [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) |
| Interactive shell | `srun -p <part> -t 1:00:00 --mem=4G --pty bash` or `salloc …` | [srun](https://slurm.schedmd.com/archive/slurm-25.11.2/srun.html), [FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html) |
| Array of 100 tasks, at most 10 running | `sbatch --array=0-99%10 job.sh` (index in `$SLURM_ARRAY_TASK_ID`) | [job_array](https://slurm.schedmd.com/archive/slurm-25.11.2/job_array.html) |
| Run after a job succeeds | `sbatch -d afterok:<id> next.sh` | [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) |
| One job at a time with a given name | `sbatch -J name -d singleton job.sh` | [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) |
| Warn the script 5 min before the time limit | `#SBATCH --signal=B:USR1@300` | [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html) |
| MPI | `srun --mpi=pmix ./app` (`srun --mpi=list` shows what is available) | [mpi_guide](https://slurm.schedmd.com/archive/slurm-25.11.2/mpi_guide.html) |
| GPUs | `--gpus=2`, `--gpus-per-node=4`, `-n4 --gpus-per-task=1`, `--gres=gpu:<type>:1` | [gres](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html) |

## Watch and inspect

| Task | Command | Source |
| --- | --- | --- |
| My jobs | `squeue --me` (`-t PD` for pending only, `-r` to expand arrays) | [squeue](https://slurm.schedmd.com/archive/slurm-25.11.2/squeue.html) |
| When will my jobs start? | `squeue --me --start` | [squeue](https://slurm.schedmd.com/archive/slurm-25.11.2/squeue.html) |
| Full job detail | `scontrol show job <id>` | [scontrol](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html) |
| Recover a job's script | `scontrol write batch_script <id> -` | [scontrol](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html) |
| Partitions, nodes, features, GPUs | `sinfo`; `sinfo -N -o "%N %P %C %m %f %G"`; `scontrol show partition <p>` | [sinfo](https://slurm.schedmd.com/archive/slurm-25.11.2/sinfo.html) |
| Live usage of a running job | `sstat -j <id>.batch` or `sstat -j <id> --allsteps` | [sstat](https://slurm.schedmd.com/archive/slurm-25.11.2/sstat.html) |
| Finished jobs | `sacct -S 2026-11-01 -X -o jobid,jobname,partition,state,exitcode,elapsed,alloctres%50` | [sacct](https://slurm.schedmd.com/archive/slurm-25.11.2/sacct.html) |
| Memory and CPU use per step | `sacct -j <id> -o jobid,state,elapsed,totalcpu,reqmem,maxrss` | [sacct](https://slurm.schedmd.com/archive/slurm-25.11.2/sacct.html) |
| GPU memory and utilisation (if tracked) | `sacct -j <id>.<step> -o tresusageinmax -p` | [gres](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html) |
| Efficiency summary | `seff <id>` (a contrib script; may not be installed) | [seff source](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/contribs/seff/seff) |

## Priority, fairshare and limits

| Task | Command | Source |
| --- | --- | --- |
| Why is my job's priority what it is? | `sprio -l -u $USER`; `sprio -w` shows the weights | [sprio](https://slurm.schedmd.com/archive/slurm-25.11.2/sprio.html) |
| Where does my group stand? | `sshare -l` (Level FS: below 1 means over-served, above 1 under-served) | [fair_tree](https://slurm.schedmd.com/archive/slurm-25.11.2/fair_tree.html) |
| My associations and limits | `sacctmgr show assoc user=$USER` | [sacctmgr](https://slurm.schedmd.com/archive/slurm-25.11.2/sacctmgr.html) |
| QOS list | `sacctmgr show qos format=name,priority,…` | [qos](https://slurm.schedmd.com/archive/slurm-25.11.2/qos.html) |
| Site configuration | `scontrol show config \| grep -E 'Priority\|Preempt\|SchedulerParameters\|MaxArraySize\|DefMem\|InactiveLimit\|LaunchParameters'` | [slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html) |

## Control

| Task | Command | Source |
| --- | --- | --- |
| Cancel | `scancel <id>`; `scancel -u $USER -t PENDING`; `scancel <id>_[1-3]` | [scancel](https://slurm.schedmd.com/archive/slurm-25.11.2/scancel.html) |
| Hold / release | `scontrol hold <id>` / `scontrol release <id>` | [scontrol](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html) |
| Shorten the time limit | `scontrol update JobId=<id> TimeLimit=2:00:00`. Only privileged users can *increase* it on a running job | [scontrol](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html) |
| Lower your own job's priority | `sbatch --nice=100 …` | [priority_multifactor](https://slurm.schedmd.com/archive/slurm-25.11.2/priority_multifactor.html) |

## Time formats

`--time` takes `min`, `min:sec`, `h:m:s`, `d-h`, `d-h:m` or `d-h:m:s`. Seconds are rounded up to whole minutes ([sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).

## Pitfalls

1. **A missing or oversized `--time` kills backfill.** Jobs that all carry the partition maximum can't be backfilled. A `--time` above the partition limit pends with `PartitionTimeLimit`, "possibly indefinitely" ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html); [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
2. **`sacct` with no arguments shows only today's jobs.** Use `-S` or `-j` ([sacct](https://slurm.schedmd.com/archive/slurm-25.11.2/sacct.html)).
3. **`--mem` is per node, `--mem-per-cpu` is per CPU, and they can't be combined.** `--exclusive` alone gives you every CPU but **not** all memory; add `--mem=0` ([sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
4. **`-n` vs `-c`.** Threaded (OpenMP) programs need one task with `-c N`, not `-n N` ([sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)). VACC's docs give the same advice ([vacc](../vacc/slurm-and-jobs.md#resource-flags-the-docs-recommend)).
5. **`#SBATCH` stops at the first command.** Directives after any executable line are ignored, and `$VARS` in them are literal text ([sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
6. **srun options go before the program.** `srun ./a.out -N2` passes `-N2` to `a.out` ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).
7. **Steps get all of the job's GPUs by default.** For concurrent steps, give each `srun` its own `--gpus`/`--gres` plus `--exact` ([gres](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html); [srun](https://slurm.schedmd.com/archive/slurm-25.11.2/srun.html)).
8. **`CUDA_VISIBLE_DEVICES` is renumbered from 0 inside a cgroup**, and NVML's order differs from CUDA's unless `CUDA_DEVICE_ORDER=PCI_BUS_ID` ([gres](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html)).
9. **Typed and untyped GPU requests can't be mixed** between a job and its steps ([gres](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html)).
10. **The batch script's exit code is the job's exit code.** A failed `srun` followed by a successful `echo` shows COMPLETED. Check per-step states in `sacct` ([job_exit_code](https://slurm.schedmd.com/archive/slurm-25.11.2/job_exit_code.html)).
11. **`afterok` on an array uses the highest task exit code**, and a dependency that fails never runs ([job_array](https://slurm.schedmd.com/archive/slurm-25.11.2/job_array.html); [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
12. **`~/.bashrc` is not sourced for srun tasks.** The submitting environment is exported, because `--export=ALL` is the default ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html); [sbatch](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
13. **Idle allocations get purged after `InactiveLimit`** if no step is active ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).
14. **`SRUN_CPUS_PER_TASK` is obsolete advice.** It was needed only in 22.05/23.02. Since 23.11, srun reads `SLURM_CPUS_PER_TASK` again ([CHANGELOG 23.11](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/CHANGELOG/slurm-23.11.md)).
15. **Polling `squeue` or `sacct` in tight loops loads slurmctld.** Every call is an RPC to slurmctld ([sshare](https://slurm.schedmd.com/archive/slurm-25.11.2/sshare.html) PERFORMANCE).

## Why is my job pending? (reason → action)

Source: [Job Reason Codes](https://slurm.schedmd.com/archive/slurm-25.11.2/job_reason_codes.html). The "Do" column is inferred from the definitions.

| Reason | Means | Do |
| --- | --- | --- |
| `Priority` | Higher-priority jobs are ahead | Wait. Check `sprio`, `sshare` |
| `Resources` | Nothing free that fits | Wait, or shrink the request or `--time` |
| `Dependency` / `DependencyNeverSatisfied` | Waiting on another job / that can never happen | Wait / cancel the job |
| `JobHeldUser` / `JobHeldAdmin` | Held | `scontrol release` / ask the admins |
| `QOSMaxJobsPerUserLimit`, `QOSMax*PerUser*` | Your per-user QOS cap is in use | Wait for your own jobs to finish |
| `AssocGrp*` / `QOSGrp*` | The group-wide cap is in use | Wait for your group's jobs |
| `*PerJob*`, `PartitionTimeLimit`, `PartitionNodeLimit` | The request exceeds a cap and won't run as is | Fix the request |
| `ReqNodeNotAvail` / `Reservation` | Nodes reserved (maintenance?), down or drained | Shorten `--time` or wait |
| `JobArrayTaskLimit` | Array `%` throttle | Expected |
| `Constraints` / `BadConstraints` | Features unavailable / impossible | Check `sinfo -o "%N %f"` |
| `None` | Not yet evaluated in this cycle | Wait a minute |
