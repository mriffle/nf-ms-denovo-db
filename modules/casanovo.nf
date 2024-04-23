process CASANOVO {
    publishDir "${params.result_dir}/casanovo", failOnError: true, mode: 'copy'
    label 'process_high_constant'
    container 'quay.io/protio/casanovo:4.1.0'
    containerOptions '--shm-size=1g'

    input:
        path mzml_file
        path model_weights_file

    output:
        path("*.mztab"), emit: mztab
        path("*.log"), emit: log
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    """
    echo "Running casanovo..."
    casanovo \
        sequence \
        --model ${model_weights_file} \
        --output ${mzml_file.baseName}.mztab \
        ${mzml_file} \
        > >(tee "${mzml_file.baseName}.casanovo.stdout") 2> >(tee "${mzml_file.baseName}.casanovo.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}
