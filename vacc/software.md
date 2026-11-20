# Software environment

Back to [README](README.md). All pages accessed 2026-11-11.

## Base system

- **OS:** RHEL 9.6, upgraded from 9.4 on 2026-01-07/08 ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications); [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)). The VACC home page labels the docs "VACC Documentation (Red Hat 9)" ([VACC home](https://www.uvm.edu/vacc)).
- **Modules:** Lmod, with a compiler hierarchy and an MPI hierarchy. The module tree is at `/gpfs1/sw/rh9/modules/Core`, and Spack 0.22.2 packages are under `/gpfs1/sw/spack/0.22.2/modules/linux-rhel9-x86_64/gcc/13.3.0`. Spack-built modules carry a 7-character hash suffix (for example `samtools/1.19.2-pfmpoam`), and the old separate Spack commands are no longer used ([Installed Software Modules](https://www.uvm.edu/vacc/docs/start_guide/modules/)).
- Key commands: `module avail`, `module spider <name>[/<ver>]`, `module keyword <word>`, `module load` / `unload` / `purge` / `list` ([Modules](https://www.uvm.edu/vacc/docs/start_guide/modules/)).
- Module collections: `module save <name>`, `module restore <name>`, `module savelist`, `module describe`. They are stored in `~/.config/lmod`, having moved from `~/.lmod.d`. A collection saved with no name becomes the default and loads at login ([Module Collections](https://www.uvm.edu/vacc/docs/start_guide/module_collections/)).
- A browsable [Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/) lists every module. I parsed **212 entries** from it (my count, from the docs search index).

## Compilers, MPI, maths libraries

From the [Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/) and [Modules](https://www.uvm.edu/vacc/docs/start_guide/modules/):
- **GCC:** the catalogue lists `gcc/13.3.0-xp3epyt`. The modules page also shows `gcc/10.5.0` in a `module keyword` example, so that version may be stale.
- **Intel oneAPI:** `oneapi/2024.2.1` (compilers, libraries, MPI), plus `mkl/2024.2` and `tbb/2021.13`.
- **CUDA:** 11.8.0, 12.2.2, 12.3.2, 12.4.1, 12.6.2, 12.8.2, 12.9.1, 13.0.2. **cuDNN:** 8.9.7-cuda12, 9.4.0-cuda12, 9.12.0-cuda12, 9.17.1-cuda13. The spec page summarises this as "CUDA 11, 12, 13" ([cluster-specifications](https://www.uvm.edu/vacc/cluster-specifications)).
- **Open MPI:** `4.1.6-67ovor6` (Spack), `5.0.5-ib` (InfiniBand-enabled), `5.0.7`. Plain `openmpi` "does not support Infiniband" ([Using MPI](https://www.uvm.edu/vacc/docs/beyond_basics/use_mpi/)).
- **MPICH-compatible MPI: the pages conflict.**
  - [Slurm Examples](https://www.uvm.edu/vacc/docs/beyond_basics/slurm_examples/): "OpenMPI (we support), and MPICH (Intel MPI, which we do not support)".
  - [MPI on VACC](https://www.uvm.edu/vacc/docs/beyond_basics/mpi/): "If you have software that requires an MPICH compatible MPI, use the Intel implementation of MPI from the oneapi module."
  - [Using MPI](https://www.uvm.edu/vacc/docs/beyond_basics/use_mpi/): "please send us mail".
  - In short, Intel MPI is available through oneapi, but its support status is inconsistent across pages.
- MPI transports: TCP everywhere, InfiniBand on `ib*` nodes ([MPI on VACC](https://www.uvm.edu/vacc/docs/beyond_basics/mpi/)).
- Libraries: fftw 3.3.10, openblas 0.3.28, lapack 3.12.0, hdf5 1.12.1 / 1.14.4-3, phdf5, netcdf-c / cxx / fortran, gsl 2.8, boost (1.85 to 1.89), eigen, cgal, magma 2.28-cuda11, gdal, geos, proj, vtk, itk. No PETSc module was found.
- Build tools: cmake 3.31.8 / 4.0.3, maven, ant, openjdk 1.8.0 / 23.0.0, julia (1.10.5, 1.12.2, 1.13.2), valgrind, dmtcp (checkpointing).

## Python, conda and R

- **Anaconda has been removed.** Because of Anaconda's terms of service, VACC moved to **Miniforge** (conda-forge only). The `python3.xx-anaconda` modules now redirect to miniforge, and the OOD Jupyter apps use only Miniforge. venv environments built on Anaconda Python had to be rebuilt by 2026-05-20. The timeline on the page reads "March 2026 → May 20th → June 22nd" ([Conda transition](https://www.uvm.edu/vacc/docs/beyond_basics/conda_transition/); [Miniforge technical details](https://www.uvm.edu/vacc/docs/beyond_basics/miniforge/)).
- Miniforge modules: `25.11.0-py3.12`, `26.7.2-py3.14`, `26.9.4-py3.14` ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)). The [Python page](https://www.uvm.edu/vacc/docs/beyond_basics/python/) uses `module load miniforge/25.11.0-py3.12`, which gives Python 3.12.12 with pip, venv, conda and mamba.
- Using the `defaults` (Anaconda) channel for research without your own licence is not allowed ([Conda transition](https://www.uvm.edu/vacc/docs/beyond_basics/conda_transition/)).
- **Stale example:** the [Module Collections page](https://www.uvm.edu/vacc/docs/start_guide/module_collections/) still shows `python3.12-anaconda` in its "nlp" collection.
- Jupyter kernels from venvs or conda environments: [ipykernel guide](https://www.uvm.edu/vacc/docs/beyond_basics/ipykernel/), [JupyterLab](https://www.uvm.edu/vacc/docs/beyond_basics/jupyter_lab/).
- **R:** 4.4.1, 4.5.1, 4.6.0, plus `Rtidyverse` and `Rgeospatial` bundles and `rstudio` (2024.09.0 to 2026.08.2). Guides cover R batch jobs, interactive R, R libraries and an R Jupyter kernel ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/); [R batch](https://www.uvm.edu/vacc/docs/beyond_basics/Rbatch/)).
- **PyTorch / TensorFlow:** **no modules for them appear** in the catalogue. Presumably users install them in Miniforge environments. The GPU Features page discusses PyTorch and TensorFlow workloads without naming a module.

## Containers

- **Apptainer 1.3.4** ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)). It runs Singularity images too ([Using Containers](https://www.uvm.edu/vacc/docs/beyond_basics/use_apptainer/)). The ETS catalogue still says "Container support via Singularity" ([ETS catalog](https://catalog.etsweb.w3.uvm.edu/service/vermont-advanced-computing-core-vacc)).
- VACC recommends `apptainer run|exec|shell -e` (clean environment). Move the cache off home with `export APPTAINER_CACHEDIR=$HOME/scratch/apptainer-cache`. An example image is at `/gpfs1/sw/examples/containers/example.sif` ([Using Containers](https://www.uvm.edu/vacc/docs/beyond_basics/use_apptainer/)).
- Containers can be built on the cluster with `apptainer build`, including `--sandbox` / `--writable`. A build that needs `--fakeroot` has to be cleared with vacchelp@uvm.edu first ([Building Containers](https://www.uvm.edu/vacc/docs/beyond_basics/build_apptainer/)).
- Docker or Podman: not mentioned. **Not found.**

## AI / LLM resources

- **Central model library** at `/gpfs1/llm`. It holds Llama 2, 3, 3.1 (up to 405B), 3.2, 3.3 and 4 (Scout, Maverick, including FP8) in Meta, HF safetensors and GGUF formats, plus Code Llama and Snowflake `arctic-embed-l` ([LLM Central Library](https://www.uvm.edu/vacc/docs/start_guide/llm_library/)). Users can request new models; approval weighs resource efficiency, security and demand, and a model unused for a year is removed ([Sharing LLMs](https://www.uvm.edu/vacc/docs/start_guide/sharing_llms/)).
- Modules: `ollama/0.9.0`, `llama.cpp/b9077-cuda`, `alphafold/3.0.1`, `noscribe/0.6.2c` (a Whisper-based transcription GUI for an OOD single-GPU Desktop, on any GPU except the RTX 6000) ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/); [Language tools](https://www.uvm.edu/vacc/docs/beyond_basics/llm/)).
- Llama-4 setup scripts live in a "llama-4-setup" repo in the VACC Tools group on UVM GitLab. The URL was not captured from the indexed text ([Language tools](https://www.uvm.edu/vacc/docs/beyond_basics/llm/)).

## Notable applications

From the [Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/):
- **Chemistry / materials:** amber 24, gaussian 16_C.02, orca 6.x, namd 3.0.1-cuda, gromacs 2025.2, lammps 29Aug2024 (cpu, gpu, kokkos), quantum-espresso, abinit, berkeleygw, openmolcas, turbomole 7.9, pyscf, xtb, phonopy, hoomd-blue, quantumatk, vmd, maestro 2025-3 (Schrodinger).
- **Bio / genomics:** samtools, bcftools, bwa / bwa-mem2, bowtie2, hisat2, star, salmon, gatk 4.6.1.0, fastqc, fastp, kraken2, qiime2 2024.10, nextflow 24.10 / 25.04, dorado, flye, canu, hifiasm, cactus, iqtree2, raxml-ng, vep, snpeff, plink.
- **Neuroimaging:** afni, fsl 6.0.7.14, freesurfer 7.4.1, fmriprep 25.2.6, mriqc, ants, dcm2niix, hcp-workbench.
- **Engineering / EDA:** ansys 24.2, ADS, cadence, EDA modules named design_compiler, primetime, vcs, verdi, hspice, ic_compiler_ii, sentaurus, etc. (the catalogue does not name the vendor), matlab R2023b to R2026b, mathematica 14.1, paraview, gurobi 12 / 13, mosek, ipopt, spss 27, dedalus.
- Licence-gated software needs a Qualtrics acknowledgement form: **Amber, Gaussian, NAMD, ORCA, VMD** ([Restricted Software](https://www.uvm.edu/vacc/docs/start_guide/restricted_sw/)). **Schrodinger** is limited to Cancer Center-approved users, with a token cap (16 shared tokens for ConfGen/Epik/Glide/LigPrep/MacroMode/Prime, and 1 each for Maestro/OPLS Access/KNIME) ([Maestro](https://www.uvm.edu/vacc/docs/beyond_basics/maestro/)).

## Software requests

The docs do not describe a formal software-request process beyond emailing vacchelp@uvm.edu. The [Mission page](https://www.uvm.edu/vacc/mission-and-history) says VACC "actively maintain[s] an extensive library of scientific packages". The `use.own` module is listed, which in standard Lmod adds `~/privatemodules` to the module path ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)).
