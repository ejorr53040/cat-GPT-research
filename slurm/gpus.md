# GPUs: GRES, GPU options, CUDA_VISIBLE_DEVICES, MIG, MPS, sharding

Back to [README](README.md). Unless noted, the source is [Generic Resource (GRES) Scheduling, 25.11.2](https://slurm.schedmd.com/archive/slurm-25.11.2/gres.html).

## How GPUs are modelled

- GPUs are **generic resources (GRES)**. An admin declares them with `GresTypes=gpu` and `NodeName=… Gres=gpu:<type>:<n>` in slurm.conf, plus a `gres.conf` on each node.
- `AutoDetect=nvml` (or `nvidia`, `rsmi`, `nrt`, `oneapi`) can fill in the details. `AutoDetect=nvidia` was added in 24.11. It doesn't need NVML, but it "doesn't detect MIGs or NVlinks". **(version-specific)**
- The GPU **type** must match, or be a substring of, the name slurmd detects, e.g. `geforce_rtx_2060`. `slurmd -C` prints the detected name.
- "Jobs will not be allocated any generic resources unless specifically requested at job submit time."
- The `--gpu*` options need `select/cons_tres`, which is the default ([slurm.conf](https://slurm.schedmd.com/archive/slurm-25.11.2/slurm.conf.html)).

## Requesting GPUs

| Option | Scope | Form |
| --- | --- | --- |
| `--gres=gpu[:type]:n` | per **node** | `--gres=gpu:a100:2` |
| `-G, --gpus=[type:]n` | per **job** (total) | `--gpus=volta:3` |
| `--gpus-per-node=[type:]n` | per node (same as `--gres` for GPUs) | `--gpus-per-node=4` |
| `--gpus-per-task=[type:]n` | per task. Needs an explicit task count (`-n`) | `-n4 --gpus-per-task=1` |
| `--gpus-per-socket=[type:]n` | per socket | — |
| `--cpus-per-gpu=n` | CPUs per GPU. "Not compatible with the --cpus-per-task option" ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)) | — |
| `--mem-per-gpu=size` | Memory per GPU. Mutually exclusive with `--mem` and `--mem-per-cpu` | — |
| `--gpu-bind=…` | Bind tasks to GPUs (≡ `--tres-bind=gres/gpu:…`) | — |
| `--gpu-freq=…` | Set GPU and memory clocks | — |

Gotchas:
- **Typed and untyped requests don't mix.** If the job asked for `--gres=gpu:2`, a step cannot ask for `--gres=gpu:tesla:2`, and the reverse is also true.
- With `--gpus=N` over several nodes, "the allocation has to contain at least one GPU per node" ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
- `--gpus-per-task` sets up per-task GPU binding: it implies `--tres-bind=gres/gpu:per_task:<n>` ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).
- **Steps get all of the job's GRES by default**, "except those implicitly requested when a job is exclusive". To split GPUs across concurrent steps, give each `srun` its own `--gres`/`--gpus` (and `--exact`). The man page example:
  ```bash
  # sbatch --gres=gpu:4 -n4 -N1-1 gres_test.bash
  srun --gres=gpu:2 -n2 --exclusive show_device.sh &
  srun --gres=gpu:1 -n1 --exclusive show_device.sh &
  srun --gres=gpu:1 -n1 --exclusive show_device.sh &
  wait
  ```
- A suspended job keeps its GRES.

## `CUDA_VISIBLE_DEVICES`

- Slurm sets `CUDA_VISIBLE_DEVICES` for **each job step** on each node.
- `salloc` sets no global value.
- Under `sbatch`, the variable in the batch script only reflects the GPUs on **node zero**.
- If the site constrains devices with cgroups, the job sees **relative** numbering. A job that holds `/dev/nvidia1` sees `CUDA_VISIBLE_DEVICES=0`, while the Prolog and Epilog, which run outside the cgroup, see `1`.
- NVML numbers GPUs by PCI bus ID. For CUDA's numbering to match, set **`CUDA_DEVICE_ORDER=PCI_BUS_ID`**.
- Related variables set in the job: `SLURM_JOB_GPUS`, `SLURM_GPUS_ON_NODE`, `SLURM_GPUS_PER_NODE` ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).

## Accounting for GPU use

- With `AccountingStorageTRES=gres/gpu`, Slurm also gathers **`gres/gpumem`** and **`gres/gpuutil`**. This needs `AutoDetect=nvml` (NVIDIA) or `rsmi` (AMD).
- Read them with `sacct -j <job>.<step> --format=TRESUsageInAve,TRESUsageInMax -p`.
- There are **no** gpumem or gpuutil figures for MIG devices, because NVML doesn't report them.
- [TRES](https://slurm.schedmd.com/archive/slurm-25.11.2/tres.html) and [Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html) both recommend tracking the generic and the typed GRES together, e.g. `AccountingStorageTRES=gres/gpu,gres/gpu:tesla`. Otherwise untyped requests aren't counted.

## MIG (Multi-Instance GPU)

- Each MIG instance is treated as an individual GPU, with cgroup isolation and task binding.
- Configure with `AutoDetect=nvml`, and give the MIG profile as a GRES type, e.g. `gpu:a100_3g.20gb:2`.
- MIGs must be partitioned in advance. Slurm "does not support dynamic MIG partitioning".

## MPS (CUDA Multi-Process Service)

- `Gres=gpu:2,mps:200`, for example. The MPS count is treated as a percentage of a GPU.
- A request must fit on one GPU per node, unless the site sets `OPT_MULTIPLE_SHARING_GRES_PJ`. You cannot request `gpu` and `mps` in the same job.
- The job gets `CUDA_MPS_ACTIVE_THREAD_PERCENTAGE`.
- NVIDIA's MPS serialises different **users** on a GPU, so they are time-sliced, not truly concurrent.

## Sharding

- `Gres=gpu:2,shard:64`, for example. Several jobs can share a GPU, but sharding "does not fence the processes running on the GPU". It "works best with homogeneous workflows".
- A GPU allocated as a `gpu` can't also be handed out as shards, and the reverse is also true.
- The job gets `SLURM_SHARDS_ON_NODE` ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html)).

## Limits on typed GPUs (why sites force a type or feature)

- "If one requests `--gres=gpu:2` having a limit set of `MaxTRESPerUser=gres/gpu:tesla=1`, the limit won't be enforced". Slurm calls this a design limitation.
- SchedMD's suggested fix is a **job_submit/lua** plugin that rejects GPU requests without a type ([Resource Limits](https://slurm.schedmd.com/archive/slurm-25.11.2/resource_limits.html)).

## Constraints / features vs GRES type

- `--constraint` selects **nodes** by feature tags that the admin defines in `NodeName … Features=`. List them with `sinfo -o "%N %f"` or see them in `scontrol show node` ([sbatch(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sbatch.html); [sinfo(1)](https://slurm.schedmd.com/archive/slurm-25.11.2/sinfo.html)).
- The GRES **type** in `--gpus=type:n` selects the GPU model directly.
- Constraint syntax (`&`, `|`, matching-OR `[a|b]`, counts, left-to-right parsing) and `--prefer`: see [job-scripts.md](job-scripts.md#resource-requests). `|` lets different nodes match different options; `[a|b]` requires all nodes to share one. "Brackets are only reserved for Multiple Counts and Matching OR syntax."

**At VACC** ([vacc/slurm-and-jobs.md](../vacc/slurm-and-jobs.md#node-constraints---constraint---c)):
- VACC selects GPU models with **node features** (`GPU_SKU:H200`, `GPU_MEM:80GB`, …) rather than GRES types. That is why its examples use `--gpus=N --constraint=…`.
- Its `[A|B]` advice is Slurm's matching OR. Its "at least 80 GB" recipe has to OR the feature tags together, because features are plain strings.
- If VACC's nodes also define GRES types, `--gpus=<type>:N` would work too. `sinfo -p nvgpu -o "%N %G"` shows the GRES strings. **Unverified.**
- A multi-node `--gpus=N` still needs at least one GPU per node.
