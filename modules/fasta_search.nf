process GLSEARCH {
    publishDir "${params.result_dir}/glsearch", failOnError: true, mode: 'copy'
    label 'process_high'
    label 'process_long'
    container 'quay.io/protio/fasta:36.3.8i'

    input:
        path query_fasta
        path library_fasta

    output:
        path("glsearch36_results.txt"), emit: glsearch_results
        path("*.stderr"), emit: stderr

    script:
    """
    echo "Running glsearch36..."
    /usr/local/bin/glsearch36 \
        -p \
        -s BP62 \
        -f 0 \
        -g -33 \
        -b 1 \
        -m 8 \
        -T ${task.cpus} \
        ${query_fasta} ${library_fasta} \
        > >(tee "glsearch36_results.txt") 2> >(tee "glsearch36.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}
