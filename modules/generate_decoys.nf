
process GENERATE_DECOYS {
    publishDir "${params.result_dir}/fasta", failOnError: true, mode: 'copy'
    label 'process_low'
    container 'spctools/tpp:version6.2.0'

    input:
        val decoy_prefix
        path fasta_file

    output:
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout
        path("${fasta_file.baseName}.plusdecoys.fasta"), emit: decoys_fasta

    script:
    """
    echo "Generating decoys using TPP..."
        decoyFastaGenerator.pl -c KR -n P ${fasta_file} ${decoy_prefix} ${fasta_file.baseName}.plusdecoys.fasta \
        >${fasta_file.baseName}.plusdecoys.fasta.stdout \
        2>${fasta_file.baseName}.plusdecoys.fasta.stderr

    echo "Done!" # Needed for proper exit
    """

    stub:
    """
    touch "${fasta_file.baseName}.plusdecoys.fasta"
    """
}
