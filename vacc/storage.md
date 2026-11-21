# Storage, data transfer and data policy

Back to [README](README.md). Compiled 2026-11-11.

Hardware behind the filesystems: [hardware.md](hardware.md#storage-hardware) (IBM Spectrum Scale/GPFS, 2.8 PB, about 25% flash).

## Filesystems

| Path | What it is | Backup | Purge |
| --- | --- | --- | --- |
| `/gpfs1/home/<a>/<b>/<netid>`, shown as `/users/<a>/<b>/<netid>` | Home directories | Yes | No. **Deleted when sponsorship ends** |
| `/gpfs1/pi/<PI netid>` | PI-group shared directory, writable by the group | Yes | No |
| `/gpfs2/scratch/<netid>`, linked as `~/scratch` | Personal scratch | **No** | "VACC reserves the right to delete any or all data ... without notice, if needed" |
| `/gpfs2/scratch/pi/<PI netid>` | Group scratch | **No** | As above |
| `/gpfs3tmp/pi/<PI netid>` | Temporary files for active computations | **No** | **Files not accessed for 60 days are deleted.** Warning email at about day 40; no notice on deletion |
| `/netfiles/<share>` | ETS Research Storage (Netfiles) shares, mounted on the cluster | ETS (see below) | No |
| `/gpfs1/llm` | Central library of LLM models (read-only for users) | — | Models unused for 1 year are deleted |
| `/gpfs1/sw` | Software tree (`/gpfs1/sw/rh9/modules/Core`, Spack under `/gpfs1/sw/spack/0.22.2`, examples under `/gpfs1/sw/examples`) | — | — |
| Job `/tmp`, `/var/tmp`, `/dev/shm` | Per-job private namespace (since 2026-06-10) | No | Deleted at job end |

Sources: [Cluster Data Storage](https://www.uvm.edu/vacc/docs/pi-info/gpfs/), [Data and Storage](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/), [Netfiles](https://www.uvm.edu/vacc/docs/pi-info/netfiles/), [LLM Central Library](https://www.uvm.edu/vacc/docs/start_guide/llm_library/), [Sharing LLMs](https://www.uvm.edu/vacc/docs/start_guide/sharing_llms/), [Modules](https://www.uvm.edu/vacc/docs/start_guide/modules/), [Maintenance](https://www.uvm.edu/vacc/docs/maintenance/).

- Compute nodes have **no local storage for computational work**; everything uses the central pool ([Intro](https://www.uvm.edu/vacc/docs/start_guide/intro/)). Backing (RAM or disk) and size of the per-job `/tmp` are **not documented**.
- `/gpfs3tmp` has only per-PI directories ([Maintenance](https://www.uvm.edu/vacc/docs/maintenance/)).

## Backups

- **gpfs1:** "daily backups, copied to a data recovery location, and are generally able to retain the last 7 days, 4 weeks of weekly backups, and 3 months of monthly backups", varying with usage. Request restores through vacchelp@uvm.edu ([Data and Storage](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/)).
- **Conflict:** [Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment) says "gpfs1 is backed up approximately 3 times a week"; the user docs say daily.
- gpfs2 and gpfs3tmp: no backups.

## Quotas

Quotas are **per PI group**, summed over the PI and every sponsored user, separately for each filesystem ([Cluster Data Storage](https://www.uvm.edu/vacc/docs/pi-info/gpfs/); [Cost and Payment](https://www.uvm.edu/vacc/cost-and-payment); [Data and Storage](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/)).

| Tier | FS | Space soft / hard | Files soft / hard |
| --- | --- | --- | --- |
| 1 | gpfs1 | 2 TB / 4 TB | 1M / 1.5M |
| 1 | gpfs2 | 4 TB / 8 TB | 1.5M / 3M |
| 2 | gpfs1 | 8 TB / 13 TB | 3M / 6M |
| 2 | gpfs2 | 15 TB / 25 TB | 4M / 8M |
| 3 | gpfs1 | 20 TB / 25 TB | 6M / 12M |
| 3 | gpfs2 | 35 TB / 45 TB | 8M / 16M |
| any | gpfs3tmp | 10 TB / 10 TB | 1M / 1M |

The gpfs3tmp row is from the [user docs](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/) only.

**Grace period:** 7 days over the soft limit. After that, "your work will be terminated and files will be deleted to the soft limit" ([Data and Storage](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/)). Check usage with `my_gpfs_quota` or `groupquota`.

Extra GPFS space: gpfs2 rate plus a fee, 4-year life ([Data Management](https://www.uvm.edu/vacc/data-management)). Price not published.

## Netfiles (ETS Research Storage)

- UVM faculty get **10 TB of Netfiles at no cost**. Suited to rarely accessed data; not for heavy parallel I/O ([Netfiles](https://www.uvm.edu/vacc/docs/pi-info/netfiles/)).
- Shares appear at `/netfiles/<share_name>`. Netfiles groups and permissions are managed separately from VACC sponsorship ([Netfiles](https://www.uvm.edu/vacc/docs/pi-info/netfiles/)).
- ETS Bulk File Storage: "nightly snapshots for up to 90 days", off-site replica in ETS' secondary data centre ([Data Management](https://www.uvm.edu/vacc/data-management)). Whether this is the same service as Netfiles is **unconfirmed**.
- Policy: "Do NOT use the VACC for general file storage" ([Data and Storage](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/)).

## Data transfer

- **scp/sftp** to `login.vacc.uvm.edu`, port 22; examples for scp and FileZilla ([Data and Storage](https://www.uvm.edu/vacc/docs/start_guide/data_and_storage/)). No dedicated data-transfer node found. rsync is not mentioned.
- **Globus:** managed collection **"UVM VACC"** (alongside UVM Netfiles, UVM OneDrive, UVM SE Files). Log in at app.globus.org with "University of Vermont" SSO. Intended for multi-terabyte transfers ([UVM KB: Globus](https://www.uvm.edu/it/kb/article/globus-data-transfer-service/)).
  - Guest collections (sharing with external collaborators) are available on the UVM Netfiles and UVM VACC collections. On the VACC you can only create guest collections on folders you own; for group-owned folders the PI must create it ([UVM KB: Globus](https://www.uvm.edu/it/kb/article/globus-data-transfer-service/)).
  - Free for students, faculty and staff with a NetID ([ETS catalog: Globus](https://catalog.etsweb.w3.uvm.edu/it/catalog/service/globus)).
- **Other tools in modules:** `rclone/1.71.1`, `aspera`, `sratoolkit` ([Software Catalog](https://www.uvm.edu/vacc/docs/start_guide/sw_catalog/)).

## Data organisation and sharing

- Put shared and raw data in `/gpfs1/pi/<PI>`, not in home directories. Home directories are readable by the PI group by default ([Managing Data Access](https://www.uvm.edu/vacc/docs/pi-info/access/)).
- New files default to owner rw and other r-x. Use `umask 0002` (group write) or `umask 0007` (group write, no access for others) in `~/.bashrc` ([Managing Data Access](https://www.uvm.edu/vacc/docs/pi-info/access/)).
- Cross-group sharing: POSIX ACLs with `setfacl` (example in [Sharing LLMs](https://www.uvm.edu/vacc/docs/start_guide/sharing_llms/)).
- The PI is responsible for data integrity and preservation, and for complying with data use agreements ([Request Allocation](https://www.uvm.edu/vacc/request-allocation); [PI info: general](https://www.uvm.edu/vacc/docs/pi-info/general/)).

## Security and compliance

- **HIPAA / PHI / CUI:** no VACC page says the main cluster is approved for regulated data (no mention of HIPAA, PHI, CUI or NIST 800-171). Treat it as **not approved** unless VACC confirms otherwise [INFERENCE].
- **ETS Secure Enclave** (separate service): "designed to protect sensitive data that may be subject to a variety of regulatory or policy security requirements". Contact the Office of the VP for Research or the Information Security Office ([ETS Secure Enclave](https://www.uvm.edu/it/secure-enclave)). Access via VPN plus the Omnissa Horizon client at `vdi.se.uvm.edu`; data enters via Globus ("UVM SE Files") ([Secure Enclave quick start](https://www.uvm.edu/it/kb/article/secure-enclave-instance-quick-start-guide/)).
- **VACC "Secure Cluster":** announced for summer 2026 on the [spec page](https://www.uvm.edu/vacc/cluster-specifications). Compliance scope and launch status **not found**.
- **Export control:** PIs must screen sponsored users; see [access.md](access.md#who-is-eligible) ([Request Allocation](https://www.uvm.edu/vacc/request-allocation)).
- Schrodinger's EULA requires public disclosure of results, with no commercial or confidential use ([Maestro](https://www.uvm.edu/vacc/docs/beyond_basics/maestro/)).
