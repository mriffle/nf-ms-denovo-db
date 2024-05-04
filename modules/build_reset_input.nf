process BUILD_RESET_INPUT {
    publishDir "${params.result_dir}/peptide_fasta", failOnError: true, mode: 'copy'
    label 'process_low_constant'
    container 'quay.io/protio/ms-denovo-db-utils:latest'

    input:
        path comet_peptides
        path casanovo_peptides
        path glsearch_results

    output:
        path("combined_results.fasta"), emit: peptide_query_fasta
        path("*.stderr"), emit: stderr

    script:
    """
    echo "Collecting comet peptides..."
    python3 /usr/local/bin/process_comet_results.py *.txt \
        > >(tee "comet_peptides.txt") 2> >(tee "collect_comet_peptides.stderr" >&2)

    echo "Collecting casanovo peptides..."
    python3 /usr/local/bin/process_casanovo_results.py *.mztab \
        > >(tee "casanovo_peptides.txt") 2> >(tee "collect_casanovo_peptides.stderr" >&2)

    echo "Create FASTA from combined results..."
    python3 /usr/local/bin/collate_into_fasta.py comet_peptides.txt casanovo_peptides.txt \
        > >(tee "combined_results.fasta") 2> >(tee "combine_into_fasta.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}
