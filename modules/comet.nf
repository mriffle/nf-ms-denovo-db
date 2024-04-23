process COMET {
    publishDir "${params.result_dir}/comet", failOnError: true, mode: 'copy'
    label 'process_high_constant'
    container 'quay.io/protio/comet:2023020-prerelease2'

    input:
        path mzml_file
        path comet_params_file
        path fasta_file

    output:
        path("*.txt"), emit: comet_txt
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    """
    echo "Running comet..."
    comet \
        -P${comet_params_file} \
        -D${fasta_file} \
        ${mzml_file} \
        > >(tee "${mzml_file.baseName}.comet.stdout") 2> >(tee "${mzml_file.baseName}.comet.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """

    stub:
    """
    touch "${mzml_file.baseName}.pep.xml"
    touch "${mzml_file.baseName}.pin"
    """
}
