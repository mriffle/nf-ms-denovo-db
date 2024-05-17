process DIAMOND {
    publishDir "${params.result_dir}/diamond", failOnError: true, mode: 'copy'
    label 'process_high'
    label 'process_long'
    container params.images.diamond

    input:
        path query_fasta
        path library_db
        val gap_initiation_penalty
        val gap_extension_penalty

    output:
        path("*.dmnd.txt"), emit: diamond_results
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout

    script:
    """
    echo "Running diamond..."
    blastp \
        --matrix BLOSUM62 \
        --gapopen ${gap_initiation_penalty} \
        --gapextend ${gap_extension_penalty} \
        --outfmt 6 \
        --max-target-seqs 1
        --threads ${task.cpus} \
        --query ${query_fasta}
        --db ${library_db} \
        --out ${query_fasta.baseName}.dmnd.txt
        > >(tee "${query_fasta.baseName}.stdout") 2> >(tee "${query_fasta.baseName}.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}

process CREATE_DIAMOND_DB {
    //storeDir "${params.diamond_cache_directory}"
    publishDir "${params.result_dir}/diamond", pattern: "*.stderr", failOnError: true, mode: 'copy'
    publishDir "${params.result_dir}/diamond", pattern: "*.stdout", failOnError: true, mode: 'copy'
    label 'process_high'
    label 'process_long'
    container params.images.diamond

    input:
        path library_fasta

    output:
        path("${library_fasta.baseName}.dmnd"), emit: diamond_db
        path("*.stderr"), emit: stderr
        path("*.stdout"), emit: stdout

    script:
    """
    echo "Making diamond db..."
    makedb \
        --threads ${task.cpus} \
        --in ${library_fasta} \
        -d ${library_fasta.baseName} \
        > >(tee "${library_fasta.baseName}.makedb.stdout") 2> >(tee "${library_fasta.baseName}.makedb.stderr" >&2)

    echo "DONE!" # Needed for proper exit
    """
}