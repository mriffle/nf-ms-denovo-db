# nf-ms-denovo-db — Project Specification

Onboarding document for engineers and coding agents picking up this project. It
describes what the pipeline is, how it is built and developed, how to test it, and
its current status, TODOs, and footguns. For end-user run instructions see
[`README.md`](README.md); this file is the "pick up where work left off" reference.

> **Source of truth:** the code on `main`. `resources/denovo-db.pdf` is the
> *original design doc* and is now out of date (see §9).

---

## 1. What this is and what it does

nf-ms-denovo-db is a [Nextflow](https://www.nextflow.io/) (DSL2) pipeline for
**metaproteomics** peptide identification. It detects peptides that may lie
*outside* a searched protein database by running two identification strategies over
the same MS/MS spectra and reconciling them:

1. **Database search** — Comet, against a user-supplied "subset" protein FASTA.
2. **De novo sequencing** — Casanovo.

The peptides from both are merged into one query list, aligned to a well-annotated
protein database (e.g. Swiss-Prot) by **homology search** (DIAMOND `blastp`), and
the resulting matches are passed through **RESET** (`percolator_RESET`) for
semi-supervised FDR control. Reversed-sequence decoys in both databases enable the
FDR estimate.

Rationale: in metaproteomics the useful question is whether an observed spectrum is
from a peptide *identical or homologous* to something known, so a novel de-novo
peptide can inherit functional/taxonomic annotation from its closest known homolog.

---

## 2. Pipeline architecture

**Entry:** `main.nf` validates the input files, discovers `.mzML` (preferred) or
`.raw` spectra in `params.spectra_dir`, and calls the sub-workflow
`wf_ms_denovo_db` in `workflows/ms_denovo_db.nf`, which wires the processes below.

**Data flow:**

```
spectra (.raw ─MSCONVERT→ / .mzML)
        ├──────────────► COMET ───────────┐
        └──────────────► CASANOVO ────────┤
                                           ▼
subset.fasta ─GENERATE_COMET_DECOYS─► (Comet DB)      CREATE_PEPTIDE_FASTA
                                                       (merge → combined FASTA)
                                                           │        │
annotated.fasta ─GENERATE_LIBRARY_DECOYS─┬─CREATE_DIAMOND_DB─┐      │
                                         │                   ▼      ▼
                                         │                 DIAMOND  │
                                         │                   │      │
                                         └───────────────► BUILD_RESET_INPUT
                                                                 │
                                                               RESET → FDR_percolator.peptides.txt
```

**Processes** (each pinned to a container in `container_images.config`):

| Process | File | Container key | Role |
|---|---|---|---|
| `MSCONVERT` | `modules/msconvert.nf` | `proteowizard` | `.raw` → `.mzML` (peak picking). Skipped when input is already `.mzML`. `storeDir`-cached. |
| `GENERATE_COMET_DECOYS` | `modules/generate_decoys.nf` | `ms_denovo_db_utils` | Reverse-decoy the subset FASTA. Cache: `fasta_cache/comet`. |
| `GENERATE_LIBRARY_DECOYS` | `modules/generate_decoys.nf` | `ms_denovo_db_utils` | Reverse-decoy the annotated FASTA (handles gzip). Cache: `fasta_cache/library`. |
| `COMET` | `modules/comet.nf` | `comet` | Database search (`-P` params, `-D` target+decoy FASTA). |
| `CASANOVO` | `modules/casanovo.nf` | `casanovo` | De novo sequencing (`casanovo sequence`). GPU-aware. |
| `CREATE_PEPTIDE_FASTA` | `modules/create_peptide_fasta.nf` | `ms_denovo_db_utils` | Collapse Comet+Casanovo PSMs to distinct peptides; emit combined query FASTA. |
| `CREATE_DIAMOND_DB` | `modules/diamond.nf` | `diamond` | `diamond makedb` from annotated+decoys. `storeDir`-cached. |
| `DIAMOND` | `modules/diamond.nf` | `diamond` | `diamond blastp` homology search of combined peptides. |
| `BUILD_RESET_INPUT` | `modules/build_reset_input.nf` | `ms_denovo_db_utils` | Assemble the RESET feature table. |
| `RESET` | `modules/reset.nf` | `reset` | `python -m percolator_RESET` → FDR-controlled peptide lists. |

**RESET invocation** (in `modules/reset.nf`) currently uses
`--initial_dir combined_rank_score --train_FDR_threshold 0.05
--dynamic_competition F --FDR_threshold 1 --report_decoys T`. These have been
actively tuned (see git history) and are a likely place for future iteration.

---

## 3. Repository layout

```
main.nf                      # entry workflow: input discovery + wf call
workflows/ms_denovo_db.nf    # wf_ms_denovo_db — the DAG
modules/*.nf                 # one file per process (see table above)
nextflow.config              # params, profiles (standard/test), reports, notification, includes
conf/base.config             # process resource model (resourceLimits + labels)
container_images.config      # pinned container image tags
resources/
  comet.params               # EXAMPLE Comet params (not necessarily what users run — see §9)
  pipeline.config            # EXAMPLE user config (-c), incl. mail{} SMTP block
  denovo-db.pdf              # ORIGINAL design doc — OUT OF DATE (see §9)
tests/
  stub_test.sh               # local stub harness runner
  data/                      # tiny fixtures for the `test` profile
.github/workflows/ci.yml     # CI: lint + stub harness on Nextflow 26
README.md                    # end-user docs
SPECIFICATION.md             # this file
```

Gitignored (not in the repo): the local `nextflow` launcher, `.nxf_home/`, `work/`,
`.nextflow*`, and pipeline outputs/caches (`.test/`, `results/`, `reports/`,
`*_cache/`).

---

## 4. Configuration & resource model

- **Params** are declared in `nextflow.config`. Required: `fasta`, `spectra_dir`,
  `annotated_fasta`. See the README parameter table for the full list and defaults.
- **Profiles:**
  - `standard` (default): local executor, `queueSize = 1`, modest ceilings.
  - `test`: stub profile — local executor, **docker disabled**, tiny fixtures wired
    via `${projectDir}/tests/data`, outputs to `${launchDir}/.test`.
- **Resource model** (`conf/base.config`): per-process requests come from
  `withLabel:` selectors (`process_low`, `process_high`, `process_high_constant`,
  `process_very_long`, …). Every request is capped by
  `process.resourceLimits = [cpus, memory, time]`, sourced from
  `params.max_cpus/max_memory/max_time`. **This replaced the old nf-core
  `check_max()` helper**, which the Nextflow 26 parser rejects (see §5).
- **Caching:** `msconvert` output, decoy FASTAs, and the DIAMOND DB use `storeDir`
  (`mzml_cache_directory`, `fasta_cache_directory`, `diamond_cache_directory`) so
  they are not regenerated across runs.
- **Containers:** all tool versions pinned in `container_images.config`. The
  `ms_denovo_db_utils` image bundles the Python helper scripts (see §11).

---

## 5. Development environment — Nextflow 26 (READ THIS BEFORE EDITING CONFIG/DSL)

The pipeline targets **Nextflow ≥ 26.04.0** (enforced by the manifest) and is clean
under the **new strict language parser**, which is the default in NF26. Install
Nextflow locally (gitignored) and always lint before committing:

```bash
curl -s https://get.nextflow.io | bash      # creates ./nextflow (uses NXF_HOME=$PWD/.nxf_home in the test harness)
./nextflow -version                          # expect 26.x
./nextflow lint .                            # must report: all files had no errors
```

**Strict-parser gotchas that already bit this project** (avoid re-introducing):

- **Config files:** no top-level `def` variable declarations and no top-level `if`
  statements. Conditional directives must be expressed as values, e.g.
  `maxForks = params.use_gpus ? 1 : null`.
- **No `check_max()`** — use `process.resourceLimits` instead.
- **Reports** can't use a top-level `def timestamp`; they use `overwrite = true`
  (so each run overwrites the previous report — no per-run history).
- **Scripts:** no top-level `workflow.onComplete { }`. Completion email is handled
  by the native `notification` scope in `nextflow.config` instead.
- Use `files(glob)` not `file(glob)`; use `channel.` not `Channel.`.
- Cross-file references break the parser: config cannot see `lib/` classes at parse
  time (this is why the custom `EmailTemplate` was removed in favor of
  `notification`).

---

## 6. Testing

**Stub harness** — the primary automated test. Runs the whole DAG in Nextflow's
`-stub` mode: every process runs its `stub:` block (a few `touch`es) instead of the
real tool, with **no containers**. Validates DSL/config parsing, channel wiring, and
each process' declared outputs in seconds.

```bash
bash tests/stub_test.sh          # uses ./nextflow if present, else `nextflow` on PATH
```

It uses the `test` profile and a `.raw` fixture (so the `MSCONVERT` branch is
exercised), then asserts key published outputs exist under `.test/results`.

**CI:** `.github/workflows/ci.yml` runs `nextflow lint` (informational) + the stub
harness on **Nextflow 26.04.6** for every push and PR.

**What testing does NOT cover** (see §9): real tool command lines, the direct-mzML
input branch, the GPU path, and the completion-email path.

---

## 7. Conventions

- **Every process has a `stub:` block** producing its declared outputs — keep this
  invariant when adding processes, or the stub harness/CI breaks.
- Real scripts end with `echo "DONE!"` and tee stdout/stderr to `*.stdout`/`*.stderr`
  via process substitution: `> >(tee f.stdout) 2> >(tee f.stderr >&2)`.
  `process.shell` is `bash -euo pipefail`.
- Results are published with `publishDir … mode: 'copy'` under `params.result_dir`;
  cacheable/reusable artifacts additionally use `storeDir`.
- Decoy prefixes are parameters (`comet_decoy_prefix`, `library_decoy_prefix`) and
  are threaded to the helper scripts that classify targets vs decoys.
- The Python helpers live in the sibling `ms-denovo-db-utils` repo and are consumed
  via the pinned container, not vendored here (see §11).

---

## 8. How to run (real data)

```bash
./nextflow run . -profile standard \
    --spectra_dir     /path/to/spectra \
    --fasta           /path/to/subset.fasta \
    --annotated_fasta /path/to/swissprot.fasta \
    --comet_params        ./comet.params \
    --casanovo_config_file ./casanovo.yaml
```

Or supply a `-c` config (copy `resources/pipeline.config`). Requires Docker (or
Singularity/Apptainer) for the tool containers. Set `--use_gpus true` for GPU
Casanovo.

---

## 9. Known issues / footguns

- **`resources/denovo-db.pdf` is outdated.** It is the original plan, not the spec.
  Confirmed stale: homology search is DIAMOND (not glsearch); Casanovo is newer than
  the PDF's 4.1.0. Do not treat PDF/code divergences as bugs.
- **`resources/comet.params` is still only an EXAMPLE** — `params.comet_params`
  resolves to `./comet.params` in the launch directory, so users supply their own.
  It is now configured to match the method as described in the manuscript:
  **high-resolution** fragment matching (`fragment_bin_tol = 0.02`, `offset 0.0`,
  `theoretical_fragment_ions = 0`), semi-tryptic digestion (`num_enzyme_termini = 1`)
  with Trypsin/P (`search_enzyme_number = 2`, no proline suppression), 3 missed
  cleavages, 10 ppm precursor tolerance, and one match per spectrum
  (`num_output_lines = 1`). Tune per instrument before running real data.
- **Stub test validates wiring, not tool behavior.** It cannot catch a bad Comet /
  Casanovo / DIAMOND / RESET command line. No real integration smoke test exists yet.
- **Untested paths:** direct-mzML input (input already `.mzML`) and the GPU path
  (`use_gpus=true`, which sets `maxForks=1`).
- **Completion email is untested.** It uses Nextflow's native `notification` scope
  with the default template and needs a real `mail { }` SMTP block to work; there is
  no CI coverage for it.
- **Reports overwrite each run** (no timestamp/history) — a consequence of the NF26
  migration. Accepted for now.
- **`tee` + process-substitution logging** can truncate `.stdout`/`.stderr` on
  fast-exiting processes (bash doesn't wait on the substitution). Cosmetic; affects
  captured logs only.
- **Decoy `storeDir` caches are separated** into `fasta_cache/comet` and
  `fasta_cache/library` precisely because both processes emit
  `<basename>.plusdecoys.fasta`; do not merge them back into one directory.
- **`CREATE_PEPTIDE_FASTA` passes explicit staged inputs** (`${comet_results_files}`,
  `${casanovo_results_files}`) rather than `*.txt`/`*.mztab` globs — the globs could
  match the process's own tee output files. Keep it explicit.
- **`nextflowVersion` floor is `!>=26.04.0`** — collaborators on older Nextflow are
  blocked until they upgrade.
- **`diamond` image is `mriffle/diamond:2.1.10` on Docker Hub**, unlike the other
  images on `quay.io/protio`.

---

## 10. TODOs / roadmap

- ~~Decide the intended default instrument for `resources/comet.params`~~ — done
  2026-07-30: high-res Orbitrap (`0.02 / 0.0 / 0`), aligned with the manuscript's
  Methods §Step 1.
- **Move Casanovo to 5.2.0.** Decided 2026-07-30; the manuscript now says 5.2.0.
  The reason for the move is that the precursor-mass penalty survived until 5.2.0
  removed it from de novo mode (PR #575), so 5.0.0 is not sufficient.

  **The code changes are done (2026-07-31); only the image publish remains.**
  `modules/casanovo.nf`, `main.nf` and `params.casanovo_weights` have all been
  updated and run end to end against a locally built `casanovo:local-5.2.0`
  (see the working directory's `CLAUDE.md` §"Local unpublished images"). What is
  left is to publish that image and bump `container_images.config`.

  Note the weights decision changed: rather than the released
  `casanovo_orbitrap_v5-2-0.ckpt`, the image **bakes in the custom checkpoint**
  `casa-bigger2.best_20260427.ckpt`, and `params.casanovo_weights` is a path
  *inside the container* (`/opt/casanovo/weights/...`) rather than a URL. Set it to
  `''` to omit `--model` and let Casanovo download a released checkpoint instead.

  Two CLI/config breakages this required, worth knowing before touching it again:
  - **`--output` no longer exists.** It is `--output_dir` + `--output_root`, and the
    root keeps its suffix (`--output_root foo` → `foo.mztab`, `foo.log`).
  - **A partial config file is rejected** with `Missing expected config option(s)`.
    A Casanovo config must be the complete 5.2.0 default with edits applied on top.

  Pre-flight checks:
  - ~~`process_casanovo_results` requires the mzTab columns `sequence`, `charge`,
    `search_engine_score[1]`, `calc_mass_to_charge`, `exp_mass_to_charge`.~~
    **Verified 2026-07-31: 5.2.0 emits all five.**
  - 5.0.0 changed the peptide score from the mean to the **product** of per-residue
    scores, so `casanovo_best_score` — a RESET feature — changes meaning and
    distribution. Expect the ranking to shift; this is not a regression.

- **`process_comet_results` does not filter on Comet's per-spectrum rank column
  (`num`).** It is correct now only because `resources/comet.params` sets
  `num_output_lines = 1`; a user whose own params file keeps more matches per
  spectrum silently inflates `num_spectra` and `num_peptidoforms`. Fix belongs in
  `ms-denovo-db-utils`, not here.
- Add a real integration smoke test (tiny real inputs + containers) to catch
  tool-argument regressions the stub test can't.
- (Optional) Restore a branded HTML completion email via `notification.template`.
- (Optional) Mirror the `diamond` image to `quay.io/protio` for registry
  consistency.
- Housekeeping: prune stale remote branches (see §11).
- Ongoing: RESET feature/threshold tuning (`modules/reset.nf`) and DIAMOND scoring
  as it feeds RESET — an active area per git history.

---

## 11. Status & external dependencies

- **Current `main`:** commit `cfa79cc` — "Migrate to Nextflow 26, add stub test
  harness + CI, fix engineering issues." This introduced the NF26 migration, stubs
  for every process, the stub harness + CI, and a batch of engineering fixes.
- **Sibling repo `ms-denovo-db-utils`** (at `../ms-denovo-db-utils`) holds the
  Python helpers (`process_comet_results.py`, `process_casanovo_results.py`,
  `collate_into_fasta.py`, `generate_reverse_decoys.py`, `build_reset_input.py`).
  They are shipped via the `ms_denovo_db_utils` container, pinned in
  `container_images.config`. Frequent "update ms_denovo_db_utils version" commits
  mean the two repos evolve together — when changing helper behavior, bump the image
  tag here.
- **Stale remote branches** (candidates for pruning, unmerged/abandoned):
  `add-reset`, `casanovo5`, `centralize-images`, `comet-fasta`, `diamond`,
  `glsearch`, `reset-input`, `user-decoy-prefix`.
