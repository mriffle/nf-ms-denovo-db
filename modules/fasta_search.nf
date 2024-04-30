process GLSEARCH {
    publishDir "${params.result_dir}/glsearch", failOnError: true, mode: 'copy'
    label 'process_mid_constant'
    label 'process_low_memory'
    label 'process_long'
    container 'quay.io/protio/fasta:36.3.8i'

    input:
        path query_fasta
        path library_fasta

    output:
        path("*.gl.txt"), emit: glsearch_results
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
        > >(tee "${query_fasta.baseName}.gl.txt") 2> >(tee "${query_fasta.baseName}.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}

process SPLIT_QUERY_FASTA {
    publishDir "${params.result_dir}/glsearch", failOnError: true, mode: 'copy'
    label 'process_low_constant'
    container 'quay.io/protio/ms-denovo-db-utils:latest'

    input:
        path query_fasta
        val requested_parts

    output:
        path("query_part*.fasta"), emit: query_fasta_part
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout

    script:
    """
    echo "Splitting query fasta..."
    /usr/local/bin/split_fasta.sh \
        ${query_fasta} \
        ${requested_parts} \
        > >(tee "query_fasta_split.stdout") 2> >(tee "query_fasta_split.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}