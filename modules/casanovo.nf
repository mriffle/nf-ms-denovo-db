process CASANOVO {
    publishDir "${params.result_dir}/casanovo", failOnError: true, mode: 'copy'
    label 'process_high_constant'
    container params.images.casanovo

    containerOptions = { 

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

    // don't melt the GPU
    if (params.use_gpus) {
        maxForks = 1
    }
    
    input:
        path mzml_file
        path model_weights_file
        path casanovo_config_file

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
        --config ${casanovo_config_file} \
        ${mzml_file} \
        > >(tee "${mzml_file.baseName}.casanovo.stdout") 2> >(tee "${mzml_file.baseName}.casanovo.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}
