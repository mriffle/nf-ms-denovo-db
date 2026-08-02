process CASANOVO {
    publishDir "${params.result_dir}/casanovo", failOnError: true, mode: 'copy'
    label 'process_high_constant'
    container params.images.casanovo

    containerOptions {

        // When the executor is awsbatch, --shm-size is expecting the number of MiB
        // otherwise it is expecting the number of bytes
        def options = '--shm-size 1g'
        if (params.use_gpus) {
            if (workflow.containerEngine == "singularity" || workflow.containerEngine == "apptainer") {
                options += ' --nv'
            } else if (workflow.containerEngine == "docker") {
                options += ' --gpus all'
            }

            if (params.cuda_launch_blocking) {
                options += ' -e CUDA_LAUNCH_BLOCKING=1'
            }
        }

        return options
    }

    // When running on GPUs, CASANOVO is limited to one concurrent task via
    // `withName: CASANOVO { maxForks = 1 }` in nextflow.config (a process body
    // may not contain `if` statements under the Nextflow 26 parser).

    input:
        path mzml_file
        val model_weights
        path casanovo_config_file

    output:
        path("*.mztab"), emit: mztab
        path("*.log"), emit: log
        path("*.stdout"), emit: stdout
        path("*.stderr"), emit: stderr

    script:
    // Casanovo >= 5.0.0 replaced --output with --output_dir + --output_root, and
    // no longer strips a suffix from the root, so pass the bare basename here:
    // --output_root foo yields foo.mztab and foo.log.
    //
    // Weights are a path *inside the container* (baked into the image), not a
    // file Nextflow staged -- Nextflow cannot stage what only exists in an image.
    // Omitted entirely when unset, in which case Casanovo downloads a released
    // checkpoint matching the instrument.
    def model_arg = model_weights?.toString()?.trim() ? "--model ${model_weights} " : ''
    """
    echo "Running casanovo..."
    casanovo \
        sequence \
        ${model_arg}\
        --output_dir . \
        --output_root ${mzml_file.baseName} \
        --config ${casanovo_config_file} \
        ${mzml_file} \
        > >(tee "${mzml_file.baseName}.casanovo.stdout") 2> >(tee "${mzml_file.baseName}.casanovo.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """

    stub:
    """
    touch "${mzml_file.baseName}.mztab"
    touch "${mzml_file.baseName}.log"
    touch "${mzml_file.baseName}.casanovo.stdout"
    touch "${mzml_file.baseName}.casanovo.stderr"
    """
}
