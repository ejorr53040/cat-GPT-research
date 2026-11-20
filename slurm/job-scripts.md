# Job scripts, arrays, heterogeneous jobs, interactive jobs, MPI

Back to [README](README.md). All pages were accessed 2026-11-11. Unless noted, quotes are from [sbatch(1) 25.11.2](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html).

## `#SBATCH` directives

- "#SBATCH directives are read directly by Slurm, so shell-specific syntax including variable names will be read as literal text. Once the first non-comment, non-whitespace line has been reached in the script, no more #SBATCH directives will be processed."
- Precedence: "Environment variables will override any options set in a batch script, and command line options will override any environment variables." The environment variables meant here are the `SBATCH_*` input variables.
- The batch script runs as a single copy on the first node of the allocation. To use the other nodes or tasks, start steps with `srun`.
- **Environment:** `--export=ALL` is the default, so the submitting shell's environment is copied. `SLURM_*` variables are always propagated. `--export=NONE` passes only `SLURM_*` and SPANK variables and then loads the user's login environment on the node as if `--get-user-env` were given. With `NONE`, set `SLURM_EXPORT_ENV=ALL` inside the script so that srun steps don't inherit `NONE`.
- Processes launched by srun are exec'ed directly, not through a shell. `~/.bashrc` and `~/.profile` are **not** run for them ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).

## Resource requests

| Option | Meaning (sbatch(1) 25.11.2) |
| --- | --- |
| `-N, --nodes=<min>[-max]` | Node count. "The partition's node limits supersede those of the job" |
| `-n, --ntasks=<n>` | sbatch "does not launch tasks". This tells Slurm that steps will run up to n tasks. The default is one task per node, but `--cpus-per-task` changes that default |
| `-c, --cpus-per-task=<n>` | CPUs per task, all on the same node. Example from the man page: 4 tasks × 3 CPUs on 4-CPU nodes gives 4 nodes, where a bare request for 12 CPUs might give 3 |
| `--ntasks-per-node=<n>` | Tasks per node. Mostly for MPI |
| `--mem=<size>[K/M/G/T]` | Memory **per node**. The default unit is MB. The default is `DefMemPerNode` and the cap `MaxMemPerNode`. **`--mem=0` gives the job all the memory on each node** |
| `--mem-per-cpu=<size>` | Memory per **usable allocated CPU**. If it exceeds `MaxMemPerCPU`, Slurm raises `--cpus-per-task` to fit, so you may get more CPUs than you asked for |
| `--mem-per-gpu=<size>` | Memory per allocated GPU. `--mem`, `--mem-per-cpu` and `--mem-per-gpu` are **mutually exclusive** |
| `-t, --time=<t>` | Formats: `min`, `min:sec`, `h:m:s`, `d-h`, `d-h:m`, `d-h:m:s`. The default is the partition's default. If you ask for more than the partition's limit, the job is "left in a PENDING state (possibly indefinitely)". At the limit, Slurm sends SIGTERM, then SIGKILL after `KillWait` (default 30 s, per [slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)) |
| `--time-min=<t>` | Lets backfill shrink `--time` down to this value if that starts the job sooner |
| `-C, --constraint=<expr>` | Required node features. Operators: `&` (AND), `\|` (OR), `[a\|b]` (matching OR, so every node has the same one), `feat*N` (counts), and parentheses. Without parentheses the expression is parsed left to right: `foo\|bar&baz` means "(foo and baz) or (bar and baz)" |
| `--prefer=<expr>` | Soft features: Slurm tries these first and falls back to `--constraint` |
| `-G/--gpus`, `--gpus-per-node`, `--gpus-per-task`, `--gres` | See [gpus.md](gpus.md) |
| `--exclusive[=user\|mcs\|topo]` | No node sharing. You get all CPUs and GRES on each node, **but only the memory you asked for**. Add `--mem=0` for all of it |
| `-p`, `-A`, `-q` | Partition, account and QOS. `-q` may be a list ordered by priority |
| `--signal=[B:]<sig>[@secs]` | Send a signal secs seconds before the time limit (default 60 s; may arrive up to 60 s early). `B:` signals only the batch shell |
| `--requeue` / `--no-requeue` | Whether a batch job may be requeued after node failure or preemption. The cluster default comes from `JobRequeue`, which is 1 ([slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)) |
| `--mail-type=` | `NONE, BEGIN, END, FAIL, REQUEUE, ALL, INVALID_DEPEND, STAGE_OUT, TIME_LIMIT, TIME_LIMIT_90/80/50, ARRAY_TASKS` |

**What a "CPU" is:** with hyperthreading a CPU is a hardware thread, otherwise a core. Jobs are generally still allocated whole cores, so 3 tasks on a node with `ThreadsPerCore=2` get 2 full cores ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)). The `--mem-per-cpu` examples in sbatch(1) show `salloc -n3 --mem-per-cpu=100` ending up with `cpu=4,mem=400M` allocated on 2-thread cores.

**Memory enforcement:** memory requests "will not be strictly enforced unless Slurm is configured to use an enforcement mechanism" (cgroup `ConstrainRAMSpace` or `OverMemoryKill`). The slurmstepd process's own 20 to 200 MiB counts toward the job's total memory.

## Output files

- The default is `slurm-%j.out` for both stdout and stderr, written on the first node. For arrays the default is `slurm-%A_%a.out`.
- `-o/--output`, `-e/--error` and `--open-mode=append|truncate` (the default comes from `JobFileAppend`).
- Filename patterns:

  | Pattern | Expands to |
  | --- | --- |
  | `%j` | Job ID |
  | `%x` | Job name |
  | `%A` | Array master job ID |
  | `%a` | Array index |
  | `%J` | jobid.stepid |
  | `%u` | User name |
  | `%N` | Short host name. Gives one file per node |
  | `%t` | Task rank. Gives one file per task |
  | `%r` | Restart count |
  | `%%` | A literal `%` |

  A number between `%` and the letter zero-pads the value: `job%4j.out` becomes `job0128.out`.
- Outside an array, `%a` expands to 4294967294 (NO_VAL) ([Job arrays](https://slurm.schedmd.com/archive/slurm-25.11.2/job_array.html)).

## Environment variables set in the job (selection)

From sbatch(1) "OUTPUT ENVIRONMENT VARIABLES":
- **Job identity:** `SLURM_JOB_ID`, `SLURM_JOB_NAME`, `SLURM_JOB_NODELIST`, `SLURM_JOB_NUM_NODES`, `SLURM_JOB_PARTITION`, `SLURM_JOB_ACCOUNT`, `SLURM_JOB_QOS`
- **Tasks and CPUs:** `SLURM_NTASKS`, `SLURM_CPUS_PER_TASK` (set only if `-c` was given), `SLURM_CPUS_ON_NODE`, `SLURM_JOB_CPUS_PER_NODE`, `SLURM_TASKS_PER_NODE`
- **Memory:** `SLURM_MEM_PER_NODE`, `SLURM_MEM_PER_CPU`, `SLURM_MEM_PER_GPU`
- **GPUs:** `SLURM_GPUS`, `SLURM_GPUS_ON_NODE`, `SLURM_JOB_GPUS`
- **Arrays:** `SLURM_ARRAY_JOB_ID`, `SLURM_ARRAY_TASK_ID`, `_COUNT`, `_MIN`, `_MAX`, `_STEP`
- **Submission:** `SLURM_SUBMIT_DIR`, `SLURM_SUBMIT_HOST`
- **Restarts:** `SLURM_RESTART_COUNT`
- **Time:** `SLURM_JOB_START_TIME`, `SLURM_JOB_END_TIME`
- **Per task:** `SLURM_PROCID`, `SLURM_LOCALID`, `SLURM_NODEID`

## Dependencies (`-d, --dependency=`)

- Separate conditions with `,` (all must hold) or `?` (any one is enough). Use one kind of separator only.

  | Type | Starts after the listed jobs… |
  | --- | --- |
  | `after:id[+min]` | start, or are cancelled (plus optional minutes) |
  | `afterany:id` | end in any state. This is the default type |
  | `afterok:id` | finish with exit code 0 |
  | `afternotok:id` | fail (non-zero exit, node failure, timeout…) |
  | `aftercorr:id` | finish successfully, matched array task by array task |
  | `afterburstbuffer:id` | end and finish burst-buffer stage-out |
  | `singleton` | end, for all earlier jobs with the same name and user |

- `afterok`/`afternotok` must be submitted while the target job still exists, or within `MinJobAge` of its end (default 300 s).
- "Once a job dependency fails ... the dependent job will never be run." It stays pending with reason `DependencyNeverSatisfied`, unless `--kill-on-invalid-dep=yes` or the site sets `kill_invalid_depend`.
- For an array, `afterok`/`afternotok` look at the **highest** exit code of any task ([Job arrays](https://slurm.schedmd.com/archive/slurm-25.11.2/job_array.html)).

## Job arrays ([Job Array Support](https://slurm.schedmd.com/archive/slurm-25.11.2/job_array.html))

- Arrays work only with batch jobs: `--array=0-31`, `--array=1,3,5,7`, `--array=1-7:2` (step), or `--array=0-15%4` (at most 4 tasks running at once).
- The minimum index is 0 and the maximum is `MaxArraySize-1`. **`MaxArraySize` defaults to 1001**; the hard ceiling is 4000001. Each task counts as a job toward `MaxJobCount` (default 10000) ([slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)). Tasks "still act like regular jobs" for limits such as `MaxJobs` and `MaxSubmitJobs`.
- Task IDs: `<ArrayJobID>_<index>`, e.g. `36_1`.
- Do not assume tasks run in order. The first task's record is a placeholder that often runs last.
- `squeue` shows the pending part on one line, e.g. `1080_[5-1024]`. Use `squeue -r` for one line per task.
- `scontrol update JobID=21845_2 …` changes a single task. Using the bare ArrayJobID changes all of them.
- Pending reason `JobArrayTaskLimit`: the `%` throttle has been reached ([Job Reason Codes](https://slurm.schedmd.com/archive/slurm-25.11.2/job_reason_codes.html)).

Illustrative script (my example, built from the options above):
```bash
#!/bin/bash
#SBATCH --job-name=sweep
#SBATCH --array=0-99%10
#SBATCH --time=00:30:00
#SBATCH --mem=2G
#SBATCH --output=logs/%x_%A_%a.out
python run.py --index "$SLURM_ARRAY_TASK_ID"
```

At VACC: there is no VACC guidance on arrays, and VACC offers a `launcher` module as an alternative ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#job-arrays-and-many-small-tasks)). To find the real cap, run `scontrol show config | grep -i MaxArraySize`.

## Heterogeneous jobs ([Heterogeneous Job Support](https://slurm.schedmd.com/archive/slurm-25.11.2/heterogeneous_jobs.html))

- Supported since 17.11. Each component can have its own partition, account, QOS and resources.
- On the command line, separate components with `:`, e.g. `sbatch -c4 --mem-per-cpu=1 -n128 : -c1 --mem-per-cpu=16 -n1 my.bash`. In a script, use a line `#SBATCH hetjob` between component blocks.
- Some options carry over to later components (`--job-name`, `--account`, `--dependency`…). Others reset (`--ntasks`, `--mem-per-cpu`).
- Steps target components with `srun --het-group=0,1`. Accounting shows `<het_job_id>+<offset>`.
- Running one MPI application across components "does not work with all MPI implementations". Sites can turn it off with `disable_hetjob_steps`.
- Heterogeneous jobs need the backfill scheduler. `sched/builtin` disables them ([slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)).

## Interactive jobs

- `srun --pty bash` with resource options runs task 0 on a pseudo-terminal ([srun(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/srun.html)).
- `salloc` with `LaunchParameters=use_interactive_step` is "the recommended way" since 20.11 ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)). See [commands.md](commands.md#salloc-man).
- Idle allocations can be purged after `InactiveLimit` seconds. A job is inactive "if it has no active job steps or if the srun command creating the job is not responding" ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).

## MPI and multi-node

From the [MPI Users Guide](https://slurm.schedmd.com/archive/slurm-25.11.2/mpi_guide.html):

There are three launch modes:
1. **srun launches the tasks directly** and wires them up over PMI-1, PMI-2 or PMIx. "Supported by most modern MPI implementations."
2. **mpirun inside the allocation uses srun underneath.**
3. **mpirun launches over ssh/rsh.** This is outside Slurm's control, binding and accounting suffer, and it "is not a recommended way". `pam_slurm_adopt` is "strongly recommended" if a site allows it.

Choosing the PMI and building against it:
- `MpiDefault` in slurm.conf sets the site default. `srun --mpi=<type>` (or `SLURM_MPI_TYPE`) overrides it, and `srun --mpi=list` shows what is available.
- PMIx support: Slurm 22.05+ supports PMIx v2 to v5. "Intel MPI doesn't officially support PMIx."
- **(version-specific)** 25.11.2 fixed a hang of PMIx 5.0.8 and 5.0.9 clients ([CHANGELOG 25.11](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/CHANGELOG/slurm-25.11.md)).

**Open MPI:**
- PMIx is native from Open MPI 3.1. Use `srun --mpi=pmix`, or set `MpiDefault=pmix`.
- Launching with srun against Slurm's PMI is "the preferred mode of operation since accounting features and affinity done by Slurm will become available".
- Open MPI cannot call `MPI_Comm_spawn()` inside a Slurm allocation.
- Segfaults can come from a memlock limit that is too low. The admin fix is `LimitMEMLOCK=infinity` on slurmd.

**Intel MPI:**
- `mpirun` uses Hydra. By default Slurm injects variables so that Hydra bootstraps through srun (`--external-launcher`).
- `srun` is "recommended": set `I_MPI_PMI_LIBRARY=/path/to/libpmi2.so`, then run `srun app`.

**MPICH and MVAPICH2:** both can use srun with PMI-1, PMI-2 or PMIx. MPICH supports PMIx from v4.

At VACC: VACC's docs use `mpirun` with `openmpi/5.0.5-ib` ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#mpi-using-mpi-slurm-examples)). Per Slurm's guide, the Slurm-integrated path would be `srun --mpi=pmix`. Whether VACC's Open MPI builds and slurm.conf support that is **unknown**; check with `srun --mpi=list`.

## Task binding / affinity

From [srun(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/srun.html):
- `--cpu-bind` works only when the `task/affinity` plugin is enabled. With no `--cpu-bind`, the binding comes from the first of these that is set:
  1. the nodes' `CpuBind`
  2. the partition's `CpuBind`
  3. `TaskPluginParam`
  4. **auto binding**, used when the step's sockets, cores or threads equal tasks × cpus-per-task
- Turn binding off with `--cpu-bind=none`. Set `SLURM_CPU_BIND=verbose` to see what was chosen.
- Threaded tasks inherit the parent's CPU mask, so a multithreaded task should "specify or clear the CPU binding itself", or use fat masks.
- `--gpu-bind` is the same as `--tres-bind=gres/gpu:…`. `--gpus-per-task` implies `--tres-bind=gres/gpu:per_task:<n>`.
- The full explanation is in [CPU Management](https://slurm.schedmd.com/archive/slurm-25.11.2/cpu_management.html), which I did not read in depth.

## Exit codes ([Job Exit Codes](https://slurm.schedmd.com/archive/slurm-25.11.2/job_exit_code.html))

- For sbatch the recorded exit code is the batch script's own exit code. Any non-zero code means state `FAILED` with reason `NonZeroExitCode`.
- Codes are 0 to 255. If a signal ended the job, it is shown after a colon (`exit:signal`).
- Each srun step's code is recorded separately.
- Pitfall: a script whose last command succeeds shows `COMPLETED` even if an earlier step failed. Use `set -e` or check the per-step codes in `sacct`. **This is my inference** from "the exit code that is captured is the output of the batch script".
