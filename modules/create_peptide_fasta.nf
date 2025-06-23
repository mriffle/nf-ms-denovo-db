process CREATE_PEPTIDE_FASTA {
    publishDir "${params.result_dir}/peptide_fasta", failOnError: true, mode: 'copy'
    label 'process_low_constant'
    container params.images.ms_denovo_db_utils

    input:
        path comet_results_files
        path casanovo_results_files
        val comet_decoy_prefix

    output:
        path("combined_results.fasta"), emit: peptide_query_fasta
        path("comet_peptides.txt"), emit: comet_peptides
        path("casanovo_peptides.txt"), emit: casanovo_peptides
        path("*.stderr"), emit: stderr

    script:
    """
    echo "Collecting comet peptides..."
    python3 /usr/local/bin/process_comet_results.py --decoy_prefix ${comet_decoy_prefix} *.txt \
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
