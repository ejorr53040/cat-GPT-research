# User commands

Back to [README](README.md). All pages were accessed 2026-11-11. Man pages are the **25.11.2** archive: `https://slurm.schedmd.com/archive/slurm-25.11.2/<cmd>.html`.

General rule from the [FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html): srun treats everything after the first non-option token as the command and its arguments. `srun -N2 uptime -pdebug` passes `-pdebug` to `uptime`, so put srun options **before** the program.

Several man pages carry a **PERFORMANCE** warning: do not call `sshare`, `squeue` and similar commands in tight shell loops, because each call is an RPC to slurmctld and enough of them can degrade it ([sshare(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sshare.html)).

## sbatch ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html))

- sbatch submits a script and "exits immediately after the script is successfully transferred to the Slurm controller and assigned a Slurm job ID". The script runs once, on the first allocated node. "Other than the batch script itself, Slurm does no movement of user files."
- Options and output-file patterns are covered in [job-scripts.md](job-scripts.md).
- `--test-only`: validates the script and "return[s] an estimate of when a job would be scheduled to run". No job is submitted.
- `--wrap="cmd"`: wraps a command string in an `sh` script.
- `-H/--hold`: submit held (priority 0). Release with `scontrol release <id>`.
- `--begin=now+1hour`, `--begin=16:00`, `--begin=2026-11-12T08:00`: defer eligibility.

## srun ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/srun.html))

- Outside an allocation, srun creates one and launches tasks. Inside an allocation it only launches a **job step** ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).
- `--pty`: runs task 0 in a pseudo-terminal. This is the usual `srun --pty bash` interactive pattern.
- `--exact`: the step gets only what it asked for. By default a step gets all non-GRES resources on each node of the step allocation. An explicit `-c` implies `--exact`.
- `--overlap`: lets steps share CPUs, memory and GRES with other steps. By default parallel steps do not share.
- `--mpi=pmix|pmi2|none|list`: see [job-scripts.md](job-scripts.md#mpi-and-multi-node).
- `--cpu-bind`, `--gpu-bind` (≡ `--tres-bind=gres/gpu:…`), `-m/--distribution`: see [job-scripts.md](job-scripts.md#task-binding--affinity).
- **(version-specific)** In 22.05, srun stopped inheriting `SLURM_CPUS_PER_TASK` and read `SRUN_CPUS_PER_TASK` instead. **23.11 reverted this**, going back to `SLURM_CPUS_PER_TASK` ([CHANGELOG 22.05](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/CHANGELOG/slurm-22.05.md); [CHANGELOG 23.11](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/CHANGELOG/slurm-23.11.md)). In 25.11, srun's input variable `SLURM_CPUS_PER_TASK` is "Same as -c", so srun inside an sbatch job with `--cpus-per-task` picks it up. Old site docs that tell you to export `SRUN_CPUS_PER_TASK` are 22.05/23.02-era advice.

## salloc ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/salloc.html))

- salloc gets an allocation, runs the given command (the user's default shell if none), and releases the allocation when the command exits.
- **Where the shell runs depends on configuration.** Since 20.11 the recommended setup is `LaunchParameters=use_interactive_step`. That makes salloc start the shell on an allocated compute node "rather than locally to wherever salloc was invoked" ([slurm.conf(5)](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html); [FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)). Without it, the shell stays on the login node and you use `srun` to reach the compute node. Check with `scontrol show config | grep LaunchParameters`.

## squeue ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/squeue.html))

- The default format is `"%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"`. The last column is the **reason** for pending jobs and the node list for running ones.
- `--me` is the same as `--user=<me>`. `-t PD` / `-t R` filter by state.
- `--start` shows the expected start time and nodes for pending jobs, sorted by start time. It needs the backfill plugin. Jobs with dependencies get no estimate ([FAQ](https://slurm.schedmd.com/archive/slurm-25.11.2/faq.html)).
- `-r/--array` puts one array task per line. Format codes `%F` and `%K` give the array job ID and task ID ([Job arrays](https://slurm.schedmd.com/archive/slurm-25.11.2/job_array.html)).
- **(new in 25.11)** `--running-over=<time>` and `--running-under=<time>` ([25.11 release notes](https://slurm.schedmd.com/archive/slurm-25.11.2/release_notes.html)).

## scancel ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/scancel.html))

- `scancel <id>` cancels a job. `scancel 20_[1-3]` cancels array tasks, and `scancel 20` cancels the whole array ([Job arrays](https://slurm.schedmd.com/archive/slurm-25.11.2/job_array.html)).
- `-u <user>`, `-t PENDING|RUNNING|SUSPENDED`, and `-n <name>` filter what gets cancelled.
- `-s/--signal=<sig>` sends a signal instead of terminating the job.
- `-b/--batch` signals only the batch shell. By default, signals other than SIGKILL are not sent to the batch step.

## sinfo ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/sinfo.html))

- Default format: `"%#P %.5a %.10l %.6D %.6t %N"` (partition, availability, time limit, node count, state, nodes).
- `-N` gives one line per node and partition. `-s` summarises.
- Useful format codes:
  - `%f`: features (what `--constraint` matches)
  - `%G`: GRES
  - `%C`: CPUs as allocated/idle/other/total
  - `%m`: memory in MB
  - `%e`: free memory
  - `%T`: long state
- Example: `sinfo -N -o "%N %P %C %m %f %G"`.

## sacct ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/sacct.html))

- **Default time window:** `--starttime` defaults to 00:00 today, unless `-s` is given (then "now") or `-j` is given (then the Unix epoch). So `sacct` with no arguments shows only today's jobs; add `-S 2026-11-01` or `-j <id>`.
- Non-root users see only their own jobs by default. `PrivateData` in slurmdbd.conf may restrict this further.
- `-X/--allocations` shows only the job allocation, without steps. In that case "utilization statistics ... will be reported as zero".
- `-o/--format=` picks fields (`--helpformat` lists them). `%N` sets a width, e.g. `jobname%30`. `SACCT_FORMAT` sets the same thing from the environment.
- `-s <states>` filters by state. Pending jobs only match if they have an EligibleTime.
- `-b/--brief` shows JobID, State and ExitCode. `--units=G` scales the units.
- Example from [GRES](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html) for GPU memory and utilisation high-water marks: `sacct -j 1277.0 --format=tresusageinave -p`.
- A typical efficiency query, from the header comment of `seff`: `sacct -P -n -a --format JobID,User,Group,State,Cluster,AllocCPUS,REQMEM,TotalCPU,Elapsed,MaxRSS,ExitCode,NNodes,NTasks -j <job_id>` ([contribs/seff/seff](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/contribs/seff/seff)).
- The database stores names in lower case, so sacct output can differ in case from other commands.

## sstat ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/sstat.html))

- sstat shows live status (CPU, tasks, nodes, RSS, VM) for **running** steps. `-j` is required.
- The step defaults to the lowest-numbered regular step. Use `<id>.batch` for the batch script itself and `<id>.extern` for the extern step (which needs `PrologFlags=contain`). `--allsteps` shows every step.
- With `jobacct_gather/cgroup` on cgroup/v2, virtual-memory fields read 0.

## scontrol ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/scontrol.html))

- `scontrol show job <id>`, `show node <n>`, `show partition <p>`, `show reservation`, and `show config`.
- `hold` / `release` / `uhold`:
  - Holding a pending job sets its priority to 0.
  - When an admin holds a job it is an admin-hold, which only an admin can release.
  - Holding a running job does not stop it.
- `update JobId=<id> TimeLimit=…` and similar. You can use `TimeLimit+=30`.
  - "Only a privileged user can increase a running or suspended job's TimeLimit."
  - **Inference** from the "privileged" wording, not stated outright: a user can still lower their own job's limit.
- `requeue <id>`: puts a batch job back into the pending state.
- `top <id>`: moves your job ahead of your *own* similar jobs by adjusting nice values. It is "disabled by default for unprivileged users" unless `SchedulerParameters=enable_user_top`.
- `write batch_script <id> [-]`: recovers the script of a job you own.

## sshare and sprio

See [scheduling-and-priority.md](scheduling-and-priority.md#reading-your-priority-sprio-and-sshare).

## sacctmgr ([man](https://slurm.schedmd.com/archive/slurm-25.11.2/sacctmgr.html))

- sacctmgr manages the accounting database: clusters, accounts, users, associations and QOS. Users can run the read-only forms (`show` / `list`):
  - `sacctmgr show assoc user=$USER format=cluster,account,user,partition,fairshare,qos,grptres,maxtres,maxjobs,maxwall`. **The format field names are unverified;** use `sacctmgr show assoc --helpformat` to check.
  - `sacctmgr show qos format=name,priority,maxwall,maxtresperuser,maxjobsperuser`. The [QOS page](https://slurm.schedmd.com/archive/slurm-25.11.2/qos.html) shows `sacctmgr show qos format=name,priority` and `…,GrpTRES`.
  - `sacctmgr list associations … tree` prints accounts as a hierarchy.

## seff (contrib)

- `contribs/seff/seff` is a Perl script, "Copyright 2015 Princeton University Research Computing", version 2.1. Usage is `seff [Options] <Jobid>` ([source](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/contribs/seff/seff)).
- It ships in the **`slurm-contribs`** RPM, which obsoletes the old `slurm-seff` package ([slurm.spec](https://github.com/SchedMD/slurm/blob/slurm-25-11-2-1/slurm.spec)). It is not a core command, so a site may not install it.
- At VACC: `seff` exists, and VACC also has `my_job_statistics` ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#vacc-helper-commands)).
