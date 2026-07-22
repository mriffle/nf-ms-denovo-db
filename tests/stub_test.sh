#!/usr/bin/env bash
#
# Stub test harness for nf-ms-denovo-db.
#
# Runs the whole pipeline with the `test` profile in `-stub` mode: every process
# executes its `stub:` block (a few `touch`es) instead of the real tool, with no
# containers required. This verifies that the DAG wiring, channel plumbing, and
# every process' declared outputs are consistent end-to-end.
#
# Usage:
#   tests/stub_test.sh              # uses ./nextflow (local install) if present, else `nextflow` on PATH
#   NF=/path/to/nextflow tests/stub_test.sh
#
set -euo pipefail

# Resolve repo root (this script lives in <repo>/tests)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Keep the Nextflow distribution local to the repo (gitignored)
export NXF_HOME="${NXF_HOME:-$REPO_ROOT/.nxf_home}"

# Prefer the repo-local launcher, fall back to PATH
if [[ -n "${NF:-}" ]]; then
    NEXTFLOW="$NF"
elif [[ -x "$REPO_ROOT/nextflow" ]]; then
    NEXTFLOW="$REPO_ROOT/nextflow"
else
    NEXTFLOW="nextflow"
fi

echo "== Using launcher: $NEXTFLOW =="
"$NEXTFLOW" -version

# Start from a clean slate so the test never passes on stale outputs
rm -rf "$REPO_ROOT/.test" "$REPO_ROOT/work" "$REPO_ROOT/.nextflow"

echo "== Running stub pipeline (-profile test -stub) =="
"$NEXTFLOW" run "$REPO_ROOT" -profile test -stub -ansi-log false

echo "== Verifying published outputs =="
expected=(
    ".test/results/reset/FDR_percolator.peptides.txt"
    ".test/results/reset/FDR_percolator.decoy_peptides.txt"
    ".test/results/reset/reset_input.txt"
    ".test/results/diamond"
    ".test/results/casanovo"
    ".test/results/comet"
    ".test/results/peptide_fasta/combined_results.fasta"
)
missing=0
for f in "${expected[@]}"; do
    if [[ -e "$REPO_ROOT/$f" ]]; then
        echo "  ok   $f"
    else
        echo "  MISS $f"
        missing=1
    fi
done

if [[ "$missing" -ne 0 ]]; then
    echo "STUB TEST FAILED: expected outputs missing" >&2
    exit 1
fi

echo "STUB TEST PASSED"
