process RESET {
    publishDir "${params.result_dir}/reset", failOnError: true, mode: 'copy'
    label 'process_medium'
    container params.images.reset

    input:
        path reset_input

    output:
        path("FDR_percolator.peptides.txt"), emit: reset_peptides
        path("FDR_percolator.log.txt"), emit: reset_log
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    """
    echo "Running RESET-Percolator..."
    python3 -m percolator_RESET \
        --initial_dir diamond_bitscore \
        --dynamic_competition F \
        ${reset_input} \
        > >(tee "reset.stdout") 2> >(tee "reset.comet.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}
