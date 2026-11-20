# Slurm, partitions and jobs

Back to [README](README.md). All pages accessed 2026-11-11.

## Scheduler

- **Slurm 25.11.2** on BlueMoon and IceCore ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)). It was upgraded from 25.05 to 25.11 on 2026-01-07/08 ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)).
- `seff` output names the Slurm cluster **`vacc2`** ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/)).
- Slurm accounts are named `pi-<PI NetID>`, for example `pi-grundoon`. If you belong to several groups, `my_accounts` lists your accounts, and the last one listed is your default ([User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/); [PI info: compute](https://www.uvm.edu/vacc/docs/pi-info/compute/)).
- Since 2026-06-10, jobs run in a namespace with private `/tmp`, `/var/tmp` and `/dev/shm`, which are deleted when the job ends ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)).
- The scheduler backfills: "the slurm scheduler looks for jobs that can fit in the gaps between larger jobs ... being conservative in your resource requests will result in jobs running sooner" ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/)).
- **Fairshare, priority weights and QOS: not documented.** No VACC page mentions fairshare, QOS or priority factors. The Voucher Fund page promises "priority cluster access" without saying how it is implemented ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).

## Partitions

From [Slurm Partitions](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_partitions/):

| Partition | Purpose / hardware | Default time | Max time | Other limits |
| --- | --- | --- | --- | --- |
| `general` | **Default** partition. Most nodes, no GPUs | 30 min | **48 h** | — |
| `short` | Debugging and short tasks | 30 min | **3 h** | — |
| `week` | Long jobs, on a smaller set of nodes | not stated | **1 week** | — |
| `nvgpu` | NVIDIA GPU partition. GPU jobs only | not stated | **48 h** | "no memory limit" |
| `gpu-debug` | 2 nodes × 2 A100. Interactive debugging only | not stated | **3 h** | 2 submitted / 1 running per user. 1 GPU, ≤32 CPUs, ≤350 GB RAM per job |
| `gpu-preempt` | 2 nodes × 4 H200 owned by CRREL. Others may use them when idle | not stated | not stated | **Outside jobs are cancelled** when CRREL needs the nodes |
| `hgnodes` | H100 nodes funded by SOCKS | — | — | Restricted to SOCKS researchers (contact vacchelp@uvm.edu) |
| `goldenmaple` | Bought by CRREL (Cold Regions Research and Engineering Laboratory) | — | — | Restricted. Non-CRREL users go through `gpu-preempt` |

Notes:
- The partition page does not give core, node or GPU-per-user caps for `general`, `week` or `nvgpu`. **Not found.**
- The [Services page](https://www.uvm.edu/vacc/services-we-provide) mentions a classroom GPU partition with time-based reservations. It is not listed here.
- The `gpu-debug` limit of 350 GB per job is odd against the 1 TB A100 nodes, but it is what the page says.

## Node constraints (`--constraint` / `-C`)

From [Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/). Run `show_node_constraints` for the current list.

| Constraint | Meaning |
| --- | --- |
| `intel` | Intel CPUs |
| `ib` / `noib` | Any InfiniBand node / no InfiniBand |
| `ib1`, `ib2`, `ib3` | InfiniBand group 1, 2, 3. The docs don't say which hardware is in each group |
| `10g` | 10 Gb Ethernet nodes |
| `hc` | High-clock nodes (the EPYC 7F52 class) |
| `cascadelake` | Cascade Lake CPUs (the Xeon Gold 6230 / node200 class) |
| `gpu_any` / `GPU_ANY` | Any GPU. Running jobs lists it lower-case, GPU Features upper-case |
| `GPU_FP:FP64`, `GPU_FP:FP32` | GPUs with full-rate FP64, or any GPU |
| `GPU_SKU:A100`, `H100`, `H100_SXM`, `H200`, `H200_NVL`, `H200_SXM`, `RTX6000` | A specific GPU model |
| `GPU_GEN:AMPERE`, `HOPPER`, `BLACKWELL` | GPU architecture |
| `GPU_MEM:40GB`, `80GB`, `96GB`, `140GB` | GPU memory |
| `GPU_CC:8.0`, `9.0`, `12.0` | CUDA compute capability |

GPU rules, from [GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/):
- "All GPU jobs on the VACC must include a `--constraint` specifying a valid GPU feature. Jobs submitted without one will receive a scheduler warning." These GPU features went live around 2026-04-05 to 2026-04-12 ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/): "New scheduler configuration in place (GPU features)").
- Constraints can be combined with AND (`&`), OR (`|`) or matching-OR (`[A|B]`, which puts the same type on every node). Features are text tags, so "at least 80 GB" has to be written as `GPU_MEM:80GB|GPU_MEM:96GB|GPU_MEM:140GB`.
- Impossible combinations are rejected at submit time: `Requested node configuration is not available`.
- The RTX 6000 Pro has FP64 at about 1/64 of its FP32 rate. Use `GPU_FP:FP64` for CFD, quantum chemistry (Gaussian) and similar double-precision work.
- To inspect: `sinfo -p nvgpu -o "%N %f" | grep GPU` and `scontrol show node h2xnode01 | grep Features`. The node name `h2xnode01` suggests the H200 nodes use an `h2x` prefix.
- On multi-node jobs, the docs call the A100 and RTX 6000 "not recommended for multi-gpu workloads".

GPU billing: 1 GPU-minute = 1 CU ([Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment)).

## Resource flags the docs recommend

From [Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/):
- `--partition`, `--nodes`, `--ntasks-per-node` (MPI only), `--cpus-per-task` (threads), `--mem` (per node; preferred over `--mem-per-cpu`), `--time`.
- For non-MPI multithreaded software, use one node and one task, and raise `--cpus-per-task`.
- Mail options: `--mail-type=BEGIN|END|FAIL|REQUEUE|ALL|NONE`.
- Time format: `days-hrs:min:sec`.

## Example job scripts (verbatim from the docs)

### Basic batch job ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/))
```bash
#!/bin/sh
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=4G
#SBATCH --time=5:00
#SBATCH --job-name=testjob
#SBATCH --output=%x_%j.out
#SBATCH --mail-type=NONE
cd /gpfs1/home/j/s/jshmoe
python test.py
```
Submit with `sbatch test_job.sh`.

### Single node, multiple cores ([Slurm Examples](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_examples/))
```bash
#!/bin/bash
#SBATCH --job-name=multi_core
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=15:00
module purge
my_job_header
/gpfs1/sw/examples/slurm/omp_multiply/bin/omp_multiply
```

### MPI ([Using MPI](https://www.uvm.edu/vacc/docs/beyond_basics/use_mpi/); [Slurm Examples](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_examples/))
```bash
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --cpus-per-task=1
#SBATCH --constraint=ib1          # only for InfiniBand runs
module purge
module load gcc openmpi/5.0.5-ib  # "-ib" builds support InfiniBand; plain openmpi does not
mpirun /gpfs1/sw/examples/mpi/integration
```
- The example template is at `/gpfs1/sw/examples/mpi/first_mpi_job.sbat`.
- **Doc bug:** the "Multiple nodes" example on the Slurm Examples page sets `--nodes=1` even though its comment says "Run on a two nodes". That example also loads `gcc/13.3.0-xp3epyt openmpi/5.0.7`.
- InfiniBand MPI software must be compiled on an IB node, inside a job that uses an `ib` constraint ([Using MPI](https://www.uvm.edu/vacc/docs/beyond_basics/use_mpi/)).

### GPU ([GPU Features](https://www.uvm.edu/vacc/docs/beyond_basics/gpu_features/))
```bash
#!/bin/bash
#SBATCH --partition=nvgpu          # partition implied by docs; their snippet omits it
#SBATCH --gpus=1
#SBATCH --constraint=GPU_FP:FP64
#SBATCH --time=04:00:00
python my_job.py
```
Multi-GPU with NCCL: `--gpus=4 --constraint=GPU_SKU:H200`. LLM sizing guide: 7B and 13B FP16 models run on `GPU_ANY`. A 70B FP16 model needs `GPU_MEM:140GB`. A 70B INT8 model needs at least 80 GB.

### Licensed software
Schrodinger jobs need `#SBATCH --license=maestro:1` ([Maestro](https://www.uvm.edu/vacc/docs/beyond_basics/maestro/)).

## Interactive jobs

```bash
srun --partition=general --nodes=1 --ntasks=1 --mem=4G --time=30:00 --pty /bin/bash
```
([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/)). `salloc` is mentioned as an alternative ([Maestro](https://www.uvm.edu/vacc/docs/beyond_basics/maestro/)). Open OnDemand interactive apps also run as Slurm jobs ([Open OnDemand](https://www.uvm.edu/vacc/docs/start_guide/ondemand/)).

## Job arrays and many small tasks

- **Job arrays are not documented** anywhere in the VACC user guide; a search of all 48 doc pages found no mention of `--array`. Standard Slurm arrays presumably work, but there is no VACC guidance or array-size limit.
- A `launcher/3.7` module exists, described as "A framework for running lots of short serial commands; alternative to job arrays" ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)).
- For Nextflow, VACC recommends the **`local` executor inside one Slurm job** over the `slurm` executor ([Nextflow](https://www.uvm.edu/vacc/docs/beyond_basics/nextflow/)).

## VACC helper commands

From [User Tools](https://www.uvm.edu/vacc/docs/beyond_basics/user_tools/):

| Command | What it does |
| --- | --- |
| `my_help` | Lists the `my_*` tools |
| `my_accounts [user]` | Slurm accounts you can charge. The last one is the default |
| `my_compute_usage [-s/-e dates] [-y FY23] [-a acct] [--csv]` | CPU-hours, GPU-hours and CUs per user, for the past 365 days by default |
| `my_gpfs_quota` | Group and personal usage on gpfs1, gpfs2 and gpfs3 |
| `my_job_header` | Put in a job script to log SLURM_* variables and ulimits |
| `my_job_statistics <jobid>` | Walltime, CPU and memory efficiency (similar to `seff`) |
| `show_node_constraints` | Lists the current constraints ([Running jobs](https://www.uvm.edu/vacc/docs/start_guide/running_jobs/)) |
| `groupquota` | PI-group disk usage ([Data and Storage](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/)). Possibly an older name for `my_gpfs_quota`, **unclear** |

## Maintenance windows

- Next scheduled maintenance: **2027-01-05**.
- Past windows include 2026-01-07/08 (RHEL 9.4→9.6, Slurm 25.05→25.11), 2026-06-10, and 2026-08-18 (full shutdown 7:00 to about 18:00 for software updates).
- Jobs that would run into a maintenance window are held until it ends ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)).
- The August entries carry no year; from context they are 2026.
