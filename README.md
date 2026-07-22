# nf-ms-denovo-db

A [Nextflow](https://www.nextflow.io/) pipeline implementing the **"denovo-db"**
metaproteomics protocol: it identifies peptides that may lie *outside* a searched
database by combining a database search with *de novo* sequencing, then mapping
the merged peptide list onto a well-annotated protein database by homology and
controlling the false discovery rate (FDR) with RESET.

The original design is described in
[`resources/denovo-db.pdf`](resources/denovo-db.pdf) — *Detecting peptides outside
the database using de novo sequencing and database search* (Noble & Keich).
**Note:** that document predates the current implementation and is out of date in
places (for example, homology search now uses DIAMOND rather than glsearch, and
Casanovo is a newer version). Treat the code as the source of truth.

> In metaproteomics the question is usually not "is peptide *x* present?" but
> "is the observed spectrum from a peptide **identical or homologous** to something
> known?" This pipeline answers that by running Comet (database search) **and**
> Casanovo (de novo) over the same spectra, merging the peptides, aligning them to
> an annotated database, and using RESET to assign rigorous FDR.

---

## How it works

```mermaid
flowchart TD
    spectra[".raw / .mzML spectra"] -->|MSCONVERT<br/>(only if .raw)| mzml["mzML"]
    subset["subset protein FASTA"] --> cdec["GENERATE_COMET_DECOYS"]

    mzml --> comet["COMET<br/>database search"]
    cdec --> comet
    mzml --> casa["CASANOVO<br/>de novo sequencing"]

    comet --> cpf["CREATE_PEPTIDE_FASTA<br/>(collapse + merge peptides)"]
    casa --> cpf

    ann["annotated FASTA<br/>(e.g. Swiss-Prot)"] --> ldec["GENERATE_LIBRARY_DECOYS"]
    ldec --> ddb["CREATE_DIAMOND_DB"]

    cpf -->|combined peptide FASTA| diamond["DIAMOND<br/>homology search"]
    ddb --> diamond

    cpf --> bri["BUILD_RESET_INPUT"]
    diamond --> bri
    ldec --> bri

    bri --> reset["RESET<br/>(FDR control)"]
    reset --> out["FDR_percolator.peptides.txt"]
```

1. **MSCONVERT** – converts vendor `.raw` files to `.mzML` (skipped if the input
   directory already contains `.mzML`).
2. **COMET** – database search of each spectrum file against the subset FASTA
   (concatenated with reverse-sequence decoys).
3. **CASANOVO** – *de novo* sequencing of each spectrum file.
4. **CREATE_PEPTIDE_FASTA** – collapses Comet and Casanovo PSMs to distinct
   peptides and writes a combined query FASTA.
5. **DIAMOND** – homology search of the combined peptides against the annotated
   database (plus decoys).
6. **BUILD_RESET_INPUT / RESET** – assembles the feature table and runs
   `percolator_RESET` to produce an FDR-controlled peptide list.

## Requirements

- [Nextflow](https://www.nextflow.io/) **≥ 26.04.0** (enforced by the manifest)
- Java **17+** (Nextflow requirement)
- **Docker** (or Singularity/Apptainer) for the tool containers — see
  [`container_images.config`](container_images.config)
- Optional: NVIDIA GPU(s) for faster Casanovo (`--use_gpus true`)

## Quick start

```bash
# 1. (optional) install Nextflow 26 locally, into this directory
curl -s https://get.nextflow.io | bash

# 2. run the pipeline
./nextflow run mriffle/nf-ms-denovo-db \
    -profile standard \
    --spectra_dir     /path/to/spectra \
    --fasta           /path/to/subset.fasta \
    --annotated_fasta /path/to/swissprot.fasta \
    --comet_params        ./comet.params \
    --casanovo_config_file ./casanovo.yaml
```

Or put your settings in a config file and pass it with `-c` (see
[`resources/pipeline.config`](resources/pipeline.config) for a complete example):

```bash
./nextflow run mriffle/nf-ms-denovo-db -profile standard -c pipeline.config
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| `spectra_dir` | ✅ | – | Directory of input `.mzML` or `.raw` files. `.mzML` is used if present; otherwise `.raw` files are converted with msconvert. |
| `fasta` | ✅ | – | Subset protein FASTA searched by Comet. |
| `annotated_fasta` | ✅ | `./swissprot.fasta` | Well-annotated protein FASTA for the homology search (may be gzipped). |
| `comet_params` | | `comet.params` | Comet parameters file. See [`resources/comet.params`](resources/comet.params). |
| `casanovo_config_file` | | `casanovo.yaml` | Casanovo config file. |
| `casanovo_weights` | | Casanovo v4.2.0 URL | Casanovo model weights (local path or URL). |
| `comet_decoy_prefix` | | `COMET_DECOY_` | Prefix for Comet decoy sequences. |
| `library_decoy_prefix` | | `LIBRARY_DECOY_` | Prefix for annotated-database decoy sequences. |
| `homology_search_engine` | | `diamond` | Homology search engine (currently only `diamond`). |
| `homology_search.gap_initiation_penalty` | | `6` | DIAMOND gap-open penalty. |
| `homology_search.gap_extension_penalty` | | `2` | DIAMOND gap-extend penalty. |
| `use_gpus` | | `false` | Use GPUs for Casanovo (limits Casanovo to one task at a time). |
| `cuda_launch_blocking` | | `false` | Set `CUDA_LAUNCH_BLOCKING=1` (older GPUs only; may slow things down). |
| `result_dir` | | `results/nf-ms-denovo-db` | Where published results are written. |
| `report_dir` | | `reports/nf-ms-denovo-db` | Where execution reports are written. |
| `email` | | `null` | If set, a completion email is sent (requires a `mail { }` block). |
| `max_cpus` / `max_memory` / `max_time` | | `16` / `128.GB` / `240.h` | Resource ceilings; requests above these are capped (`process.resourceLimits`). |
| `mzml_cache_directory` / `fasta_cache_directory` / `diamond_cache_directory` | | `./mzml_cache` / `./fasta_cache` / `./diamond_db_cache` | Cache locations for expensive, reusable outputs (msconvert, decoy FASTAs, DIAMOND DB). |

## Outputs

Under `result_dir` (default `results/nf-ms-denovo-db/`):

| Path | Contents |
|------|----------|
| `comet/` | Comet results (`*.txt`) and logs |
| `casanovo/` | Casanovo results (`*.mztab`) and logs |
| `peptide_fasta/` | `combined_results.fasta`, `comet_peptides.txt`, `casanovo_peptides.txt` |
| `diamond/` | DIAMOND homology hits (`*.dmnd.txt`) and logs |
| `fasta/` | decoy-generation logs |
| `reset/` | `reset_input.txt`, **`FDR_percolator.peptides.txt`**, `FDR_percolator.decoy_peptides.txt`, `FDR_percolator.log.txt` |

Execution reports (timeline, report, trace) are written to `report_dir`.

## Profiles

- **`standard`** (default) – runs locally, one task at a time, with modest
  resource ceilings.
- **`test`** – a lightweight stub profile (no containers, tiny fixtures) used by
  the test harness and CI; see below.

## GPU support

Set `--use_gpus true` to run Casanovo on GPU. The pipeline passes the correct
container flags (`--gpus all` for Docker, `--nv` for Singularity/Apptainer) and
limits Casanovo to a single concurrent task to avoid GPU contention. Use
`--cuda_launch_blocking true` only if you hit CUDA errors on older hardware.

## Caching

`msconvert` output, decoy FASTAs, and the DIAMOND database are cached (via
`storeDir`) in the `*_cache_directory` locations so they are not regenerated on
re-runs. The two decoy processes cache into separate `comet/` and `library/`
sub-directories to avoid collisions when the two input FASTAs share a filename.

## Testing (stub harness) & CI

The repository ships a **stub test harness** that runs the whole DAG in Nextflow's
`-stub` mode: every process executes a tiny `stub:` block (a few `touch`es)
instead of the real tool, with **no containers required**. It validates DSL
syntax, config parsing, channel wiring, and each process' declared outputs in a
few seconds.

Run it locally:

```bash
# uses ./nextflow if present, otherwise `nextflow` on your PATH
bash tests/stub_test.sh
```

The same harness runs automatically on every push and pull request via
[GitHub Actions](.github/workflows/ci.yml), pinned to Nextflow 26. Test fixtures
live in [`tests/data/`](tests/data).

**Coverage note:** the stub harness validates DSL/config parsing, DAG wiring, and
each process' declared outputs — it does **not** run the real tools, so it cannot
catch mistakes in the actual tool command lines. The direct-mzML input branch
(input already `.mzML`) and the GPU path (`use_gpus=true`) are also not exercised.
A real integration smoke test on tiny inputs is a known gap (see `SPECIFICATION.md`).

## Containers

All tool versions are pinned in
[`container_images.config`](container_images.config) (Comet, Casanovo, DIAMOND,
ProteoWizard, RESET, and the `ms-denovo-db-utils` helper scripts).
