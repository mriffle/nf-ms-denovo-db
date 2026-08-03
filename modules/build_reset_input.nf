process BUILD_RESET_INPUT {
    publishDir "${params.result_dir}/reset", failOnError: true, mode: 'copy'
    label 'process_low'
    container params.images.ms_denovo_db_utils

    input:
        path comet_peptides
        path casanovo_peptides
        path homology_search_results
        path fasta_file
        val library_decoy_prefix
        val comet_decoy_prefix
        val entrapment_prefix

    output:
        path("reset_input.txt"), emit: reset_input
        path("*.stderr"), emit: stderr

    script:
    // An option, and passed BEFORE the positionals: the sixth positional is optional in
    // the tool, so a seventh could never be told apart from that one being omitted.
    // Omitted entirely when empty, because images predating the option reject it.
    def entrapment_arg = entrapment_prefix?.toString()?.trim() \
        ? "--entrapment_prefix ${entrapment_prefix} " : ''
    """
    echo "Collecting comet peptides..."
    python3 /usr/local/bin/build_reset_input.py \
        ${entrapment_arg}\
        ${comet_peptides} \
        ${casanovo_peptides} \
        ${homology_search_results} \
        ${fasta_file} \
        ${library_decoy_prefix} \
        ${comet_decoy_prefix} \
        > >(tee "reset_input.txt") 2> >(tee "build_reset_input.stderr" >&2)


    echo "DONE!" # Needed for proper exit
    """

    stub:
    """
    touch reset_input.txt
    touch build_reset_input.stderr
    """
}
