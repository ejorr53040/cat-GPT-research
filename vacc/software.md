# Software environment

Back to [README](README.md). Compiled 2026-11-11.

## Base system

- **OS:** RHEL 9.6 (upgraded from 9.4 on 2026-01-07/08) ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications); [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)).
- **Modules:** Lmod, with compiler and MPI hierarchies. Module tree at `/gpfs1/sw/rh9/modules/Core`; Spack 0.22.2 packages under `/gpfs1/sw/spack/0.22.2/modules/linux-rhel9-x86_64/gcc/13.3.0`. Spack-built modules carry a 7-character hash suffix (e.g. `samtools/1.19.2-pfmpoam`) ([Installed Software Modules](https://www.uvm.edu/vacc/docs/start_guide/modules/)).
- Commands: `module avail`, `module spider <name>[/<ver>]`, `module keyword <word>`, `module load` / `unload` / `purge` / `list` ([Modules](https://www.uvm.edu/vacc/docs/start_guide/modules/)).
- Module collections: `module save <name>`, `module restore <name>`, `module savelist`, `module describe`. Stored in `~/.config/lmod`. A collection saved with no name becomes the default and loads at login ([Module Collections](https://www.uvm.edu/vacc/docs/start_guide/module_collections/)).
- The [Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/) lists every module (212 entries, my count).

## Compilers, MPI, maths libraries

From the [Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/) and [Modules](https://www.uvm.edu/vacc/docs/start_guide/modules/):
- **GCC:** `gcc/13.3.0-xp3epyt`.
- **Intel oneAPI:** `oneapi/2024.2.1` (compilers, libraries, MPI), plus `mkl/2024.2` and `tbb/2021.13`.
- **CUDA:** 11.8.0, 12.2.2, 12.3.2, 12.4.1, 12.6.2, 12.8.2, 12.9.1, 13.0.2. **cuDNN:** 8.9.7-cuda12, 9.4.0-cuda12, 9.12.0-cuda12, 9.17.1-cuda13.
- **Open MPI:** `4.1.6-67ovor6` (Spack), `5.0.5-ib` (InfiniBand-enabled), `5.0.7`. Plain `openmpi` "does not support Infiniband" ([Using MPI](https://www.uvm.edu/vacc/docs/beyond_basics/use_mpi/)).
- **Conflict (MPICH-compatible MPI):** [Slurm Examples](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_examples/) says Intel MPI is not supported; [MPI on VACC](https://www.uvm.edu/vacc/docs/beyond_basics/mpi/) says to use Intel MPI from the oneapi module; [Using MPI](https://www.uvm.edu/vacc/docs/beyond_basics/use_mpi/) says "please send us mail".
- MPI transports: TCP everywhere, InfiniBand on `ib*` nodes ([MPI on VACC](https://www.uvm.edu/vacc/docs/beyond_basics/mpi/)).
- Libraries: fftw 3.3.10, openblas 0.3.28, lapack 3.12.0, hdf5 1.12.1 / 1.14.4-3, phdf5, netcdf-c / cxx / fortran, gsl 2.8, boost (1.85 to 1.89), eigen, cgal, magma 2.28-cuda11, gdal, geos, proj, vtk, itk. No PETSc module.
- Build tools: cmake 3.31.8 / 4.0.3, maven, ant, openjdk 1.8.0 / 23.0.0, julia (1.10.5, 1.12.2, 1.13.2), valgrind, dmtcp (checkpointing).

## Python, conda and R

- **Anaconda has been removed** (Anaconda terms of service). VACC uses **Miniforge** (conda-forge only). `python3.xx-anaconda` modules redirect to miniforge, and OOD Jupyter apps use only Miniforge. venvs built on Anaconda Python had to be rebuilt by 2026-05-20 ([Conda transition](https://www.uvm.edu/vacc/docs/beyond_basics/conda_transition/); [Miniforge technical details](https://www.uvm.edu/vacc/docs/beyond_basics/miniforge/)).
- Miniforge modules: `25.11.0-py3.12`, `26.7.2-py3.14`, `26.9.4-py3.14` ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)). `module load miniforge/25.11.0-py3.12` gives Python 3.12.12 with pip, venv, conda and mamba ([Python](https://www.uvm.edu/vacc/docs/beyond_basics/python/)).
- The `defaults` (Anaconda) channel may not be used for research without your own licence ([Conda transition](https://www.uvm.edu/vacc/docs/beyond_basics/conda_transition/)).
- Jupyter kernels from venvs or conda environments: [ipykernel guide](https://www.uvm.edu/vacc/docs/beyond_basics/ipykernel/), [JupyterLab](https://www.uvm.edu/vacc/docs/beyond_basics/jupyter_lab/).
- **R:** 4.4.1, 4.5.1, 4.6.0, plus `Rtidyverse`, `Rgeospatial` and `rstudio` (2024.09.0 to 2026.08.2). Guides cover R batch, interactive R, R libraries and an R Jupyter kernel ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/); [R batch](https://www.uvm.edu/vacc/docs/beyond_basics/Rbatch/)).
- **PyTorch / TensorFlow:** no modules in the catalogue; install in a Miniforge environment [INFERENCE].

## Containers

- **Apptainer 1.3.4** ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)); runs Singularity images ([Using Containers](https://www.uvm.edu/vacc/docs/beyond_basics/use_apptainer/)).
- Use `apptainer run|exec|shell -e` (clean environment). Move the cache off home with `export APPTAINER_CACHEDIR=$HOME/scratch/apptainer-cache`. Example image: `/gpfs1/sw/examples/containers/example.sif` ([Using Containers](https://www.uvm.edu/vacc/docs/beyond_basics/use_apptainer/)).
- `apptainer build` works on the cluster, including `--sandbox` / `--writable`. Builds needing `--fakeroot` must be cleared with vacchelp@uvm.edu first ([Building Containers](https://www.uvm.edu/vacc/docs/beyond_basics/build_apptainer/)).
- Docker or Podman: **not found**.

## AI / LLM resources

- **Central model library** at `/gpfs1/llm`: Llama 2, 3, 3.1 (up to 405B), 3.2, 3.3 and 4 (Scout, Maverick, including FP8) in Meta, HF safetensors and GGUF formats, plus Code Llama and Snowflake `arctic-embed-l` ([LLM Central Library](https://www.uvm.edu/vacc/docs/start_guide/llm_library/)). Users can request new models; approval weighs resource efficiency, security and demand, and models unused for a year are removed ([Sharing LLMs](https://www.uvm.edu/vacc/docs/start_guide/sharing_llms/)).
- Modules: `ollama/0.9.0`, `llama.cpp/b9077-cuda`, `alphafold/3.0.1`, `noscribe/0.6.2c` (Whisper-based transcription GUI for an OOD single-GPU Desktop, any GPU except RTX 6000) ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/); [Language tools](https://www.uvm.edu/vacc/docs/beyond_basics/llm/)).
- Llama-4 setup scripts: "llama-4-setup" repo in the VACC Tools group on UVM GitLab ([Language tools](https://www.uvm.edu/vacc/docs/beyond_basics/llm/)).

## Notable applications

From the [Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/):
- **Chemistry / materials:** amber 24, gaussian 16_C.02, orca 6.x, namd 3.0.1-cuda, gromacs 2025.2, lammps 29Aug2024 (cpu, gpu, kokkos), quantum-espresso, abinit, berkeleygw, openmolcas, turbomole 7.9, pyscf, xtb, phonopy, hoomd-blue, quantumatk, vmd, maestro 2025-3 (Schrodinger).
- **Bio / genomics:** samtools, bcftools, bwa / bwa-mem2, bowtie2, hisat2, star, salmon, gatk 4.6.1.0, fastqc, fastp, kraken2, qiime2 2024.10, nextflow 24.10 / 25.04, dorado, flye, canu, hifiasm, cactus, iqtree2, raxml-ng, vep, snpeff, plink.
- **Neuroimaging:** afni, fsl 6.0.7.14, freesurfer 7.4.1, fmriprep 25.2.6, mriqc, ants, dcm2niix, hcp-workbench.
- **Engineering / EDA:** ansys 24.2, ADS, cadence, design_compiler, primetime, vcs, verdi, hspice, ic_compiler_ii, sentaurus, matlab R2023b to R2026b, mathematica 14.1, paraview, gurobi 12 / 13, mosek, ipopt, spss 27, dedalus.
- Licence-gated software needs a Qualtrics acknowledgement form: **Amber, Gaussian, NAMD, ORCA, VMD** ([Restricted Software](https://www.uvm.edu/vacc/docs/start_guide/restricted_sw/)). **Schrodinger** is limited to Cancer Center-approved users, with token caps (16 shared for ConfGen/Epik/Glide/LigPrep/MacroMode/Prime; 1 each for Maestro/OPLS Access/KNIME) ([Maestro](https://www.uvm.edu/vacc/docs/beyond_basics/maestro/)).

## Software requests

Request software by emailing vacchelp@uvm.edu; no formal process is documented. The `use.own` module is available (in standard Lmod it adds `~/privatemodules` to the module path) ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)).
