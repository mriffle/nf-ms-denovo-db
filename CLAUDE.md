# CLAUDE.md

Nextflow (DSL2) metaproteomics pipeline: Comet (database search) + Casanovo
(de novo) → merge → DIAMOND homology search → RESET FDR control.

**Read [SPECIFICATION.md](SPECIFICATION.md) first.** It is the onboarding doc:
architecture, dev environment, testing, conventions, known issues, TODOs, and
current status. This file only lists the essentials.

## Essentials

- Targets **Nextflow ≥ 26.04.0** with the strict parser. Before finishing any
  change to `*.nf` / `*.config`: `./nextflow lint .` must be clean **and**
  `bash tests/stub_test.sh` must pass.
- **Every process must have a `stub:` block** — the stub harness and CI depend on it.
- Install Nextflow locally with `curl -s https://get.nextflow.io | bash` (gitignored).
- **`resources/denovo-db.pdf` is an outdated design doc, not the spec — trust the code.**
- For strict-parser rules that already bit this project (no top-level `def`/`if` in
  config, `resourceLimits` not `check_max`, etc.), see SPECIFICATION.md §5.
