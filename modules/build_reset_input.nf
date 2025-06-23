process BUILD_RESET_INPUT {
    publishDir "${params.result_dir}/reset", failOnError: true, mode: 'copy'
    label 'process_low'
    container params.images.ms_denovo_db_utils

    input:
        path comet_peptides
        path casanovo_peptides
        path glsearch_results
        path fasta_file
        val library_decoy_prefix

    output:
        path("reset_input.txt"), emit: reset_input
        path("*.stderr"), emit: stderr

    script:
    """
    echo "Collecting comet peptides..."
    python3 /usr/local/bin/build_reset_input.py \
        ${comet_peptides} \
        ${casanovo_peptides} \
        . \
        ${fasta_file} \
        ${library_decoy_prefix} \
        > >(tee "reset_input.txt") 2> >(tee "build_reset_input.stderr" >&2)


    echo "DONE!" # Needed for proper exit
    """
}
