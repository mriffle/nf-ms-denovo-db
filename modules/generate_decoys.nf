process GENERATE_COMET_DECOYS {
    publishDir "${params.result_dir}/fasta", failOnError: true, mode: 'copy'
    label 'process_low'
    container 'quay.io/protio/ms-denovo-db-utils:1.0.4'

    input:
        path fasta_file
        val decoy_prefix

    output:
        path("*.stderr"), emit: stderr
        path("${fasta_file.baseName}.plusdecoys.fasta"), emit: decoys_fasta

    script:
    """
    echo "Generating decoys..."
        python3 /usr/local/bin/generate_reverse_decoys.py ${fasta_file} \
        --decoy_prefix ${decoy_prefix} \
        >${fasta_file.baseName}.plusdecoys.fasta \
        2>${fasta_file.baseName}.plusdecoys.fasta.stderr

    echo "Done!" # Needed for proper exit
    """
}

process GENERATE_LIBRARY_DECOYS {
    publishDir "${params.result_dir}/fasta", failOnError: true, mode: 'copy'
    label 'process_low'
    container 'quay.io/protio/ms-denovo-db-utils:1.0.4'

    input:
        path fasta_file
        val decoy_prefix

    output:
        path("*.stderr"), emit: stderr
        path("${fasta_file.baseName}.plusdecoys.fasta"), emit: decoys_fasta

    script:
    """
    echo "Generating decoys..."
        python3 /usr/local/bin/generate_reverse_decoys.py ${fasta_file} \
        --decoy_prefix ${decoy_prefix} \
        >${fasta_file.baseName}.plusdecoys.fasta \
        2>${fasta_file.baseName}.plusdecoys.fasta.stderr

    echo "Done!" # Needed for proper exit
    """
}
