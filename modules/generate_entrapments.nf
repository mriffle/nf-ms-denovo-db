// Entrapment injection, for validating the FDR estimate.
//
// Entrapment proteins are shuffled sequences that cannot be in the sample. Any accepted
// hit on one is false by construction, so counting them estimates the false discoveries
// hiding among the real targets.
//
// These processes run *upstream* of GENERATE_*_DECOYS, and that order is load-bearing:
// the decoy step then covers the expanded database, so every entrapment gets its own
// decoy and target:decoy stays 1:1. Injecting after decoy generation would leave targets
// outnumbering decoys and bias the FDR estimate low -- the one direction that would make
// the experiment useless, because it biases toward concluding control is fine.
//
// Both processes are skipped entirely when their ratio is empty, so a run without
// entrapment produces exactly the DAG it did before these existed.

// The entrapment parameters go in the FILENAME, not just the file. Both decoy processes
// and CREATE_DIAMOND_DB use `storeDir`, which caches on filename alone -- so a database
// built at one ratio would be served unchanged for a run at another, silently, and the
// run would report FDP against a database it never searched. `1.0` becomes `1p0` because
// a dot in the stem would be eaten by Nextflow's `baseName`.
def entrapmentTag(ratio, seed) {
    def r = ratio.toString().trim().replace('.', 'p')
    def s = seed?.toString()?.trim() ? seed.toString().trim() : '0'
    return "ent${r}-s${s}"
}

process GENERATE_COMET_ENTRAPMENTS {
    storeDir "${params.fasta_cache_directory}/comet"
    publishDir "${params.result_dir}/fasta", failOnError: true, mode: 'copy', pattern: '*.stderr'
    label 'process_low'
    container params.images.ms_denovo_db_utils

    input:
        path fasta_file
        val entrapment_prefix
        val ratio
        val seed

    output:
        path("${fasta_file.baseName}.${entrapmentTag(ratio, seed)}.fasta"), emit: entrapment_fasta
        path("*.stderr"), emit: stderr

    script:
    def tag = entrapmentTag(ratio, seed)
    def output_file = "${fasta_file.baseName}.${tag}.fasta"
    // Tested as a trimmed string, not for Groovy truth: `seed` arrives as a number when
    // set in a params file, and 0 is a legitimate seed that plain truthiness would
    // silently discard. Same reasoning as reset.nf's seed_arg.
    def seed_arg = seed?.toString()?.trim() ? "--seed ${seed} " : ''
    """
    echo "Generating entrapment sequences..."
    python3 /usr/local/bin/generate_entrapments.py ${fasta_file} \
        --entrapment_prefix ${entrapment_prefix} \
        --ratio ${ratio} \
        ${seed_arg}\
        >${output_file} \
        2>${output_file}.stderr

    echo "Done!" # Needed for proper exit
    """

    stub:
    """
    touch ${fasta_file.baseName}.${entrapmentTag(ratio, seed)}.fasta
    touch ${fasta_file.baseName}.${entrapmentTag(ratio, seed)}.fasta.stderr
    """
}

process GENERATE_LIBRARY_ENTRAPMENTS {
    storeDir "${params.fasta_cache_directory}/library"
    publishDir "${params.result_dir}/fasta", failOnError: true, mode: 'copy', pattern: '*.stderr'
    label 'process_low'
    label 'process_long'
    container params.images.ms_denovo_db_utils

    input:
        path fasta_file
        val entrapment_prefix
        val ratio
        val seed

    output:
        path("${fasta_file.baseName}.${entrapmentTag(ratio, seed)}.${fasta_file.name.endsWith('.gz') ? 'fasta.gz' : 'fasta'}"), emit: entrapment_fasta
        path("*.stderr"), emit: stderr

    script:
    // Gzipped in, gzipped out -- generate_entrapments detects gzip by magic number, and
    // GENERATE_LIBRARY_DECOYS downstream names its own output on the same assumption.
    def output_extension = fasta_file.name.endsWith('.gz') ? 'fasta.gz' : 'fasta'
    def tag = entrapmentTag(ratio, seed)
    def output_file = "${fasta_file.baseName}.${tag}.${output_extension}"
    def seed_arg = seed?.toString()?.trim() ? "--seed ${seed} " : ''
    """
    echo "Generating entrapment sequences..."
    python3 /usr/local/bin/generate_entrapments.py ${fasta_file} \
        --entrapment_prefix ${entrapment_prefix} \
        --ratio ${ratio} \
        ${seed_arg}\
        >${output_file} \
        2>${fasta_file.baseName}.${tag}.fasta.stderr

    echo "Done!" # Needed for proper exit
    """

    stub:
    def output_extension = fasta_file.name.endsWith('.gz') ? 'fasta.gz' : 'fasta'
    def tag = entrapmentTag(ratio, seed)
    """
    touch ${fasta_file.baseName}.${tag}.${output_extension}
    touch ${fasta_file.baseName}.${tag}.fasta.stderr
    """
}
