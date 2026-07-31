process RESET {
    publishDir "${params.result_dir}/reset", failOnError: true, mode: 'copy'
    label 'process_medium'
    container params.images.reset

    input:
        path reset_input
        val model
        val seed

    output:
        path("FDR_percolator.peptides.txt"), emit: reset_peptides
        path("FDR_percolator.decoy_peptides.txt"), emit: reset_decoy_peptides
        path("FDR_percolator.log.txt"), emit: reset_log
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    // Omitted entirely when unset, rather than defaulting to '--model svm':
    // images predating the option reject the argument, so always passing it
    // would break every run against an older pin.
    def model_arg = model ? "--model ${model} " : ''
    // Omitted when unset so RESET keeps seeding from the clock, which its
    // author considers part of the method: error control holds in expectation
    // over the random decoy split, not for any one draw. Set this only to make
    // a run reproducible for debugging or comparison.
    //
    // Tested as a trimmed string, not for Groovy truth: `seed` arrives as a
    // number when set in a params file, and 0 is a legitimate seed that plain
    // truthiness would silently discard.
    def seed_arg = seed?.toString()?.trim() ? "--seed ${seed} " : ''
    """
    echo "Running RESET-Percolator..."
    python3 -m percolator_RESET \
        --initial_dir combined_rank_score \
        --train_FDR_threshold 0.05 \
        --dynamic_competition F \
        --FDR_threshold 1 \
        --report_decoys T \
        ${model_arg}${seed_arg}${reset_input} \
        > >(tee "reset.stdout") 2> >(tee "reset.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """

    stub:
    """
    touch FDR_percolator.peptides.txt
    touch FDR_percolator.decoy_peptides.txt
    touch FDR_percolator.log.txt
    touch reset.stdout
    touch reset.stderr
    """
}
