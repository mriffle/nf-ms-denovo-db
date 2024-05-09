// Modules
include { MSCONVERT } from "../modules/msconvert"
include { COMET } from "../modules/comet"
include { GENERATE_COMET_FASTA } from "../modules/comet"
include { CASANOVO } from "../modules/casanovo"
include { CREATE_PEPTIDE_FASTA } from "../modules/create_peptide_fasta"
include { GLSEARCH } from "../modules/fasta_search"
include { BUILD_RESET_INPUT } from "../modules/build_reset_input"
include { SPLIT_QUERY_FASTA } from "../modules/fasta_search"
include { GENERATE_COMET_DECOYS } from "../modules/generate_decoys"
include { GENERATE_LIBRARY_DECOYS } from "../modules/generate_decoys"
include { RESET } from "../modules/reset"

workflow wf_ms_denovo_db {

    take:
        spectra_file_ch
        fasta
        comet_params
        casanovo_config_file
        casanovo_weights
        library_fasta
        from_raw_files
        decoy_prefix
    
    main:

        // convert raw files to mzML files if necessary
        if(from_raw_files) {
            mzml_file_ch = MSCONVERT(spectra_file_ch)
        } else {
            mzml_file_ch = spectra_file_ch
        }

        // generate reverse protein sequence decoys
        GENERATE_COMET_DECOYS(
            fasta,
            decoy_prefix
        )
        GENERATE_LIBRARY_DECOYS(
            library_fasta,
            decoy_prefix
        )

        // create fasta for comet searches
        GENERATE_COMET_FASTA(
            GENERATE_COMET_DECOYS.out.decoys_fasta,
            GENERATE_LIBRARY_DECOYS.out.decoys_fasta 
        )

        COMET(
            mzml_file_ch,
            comet_params,
            GENERATE_COMET_FASTA.out.comet_fasta,
        )
        
        
        CASANOVO(
            mzml_file_ch,
            casanovo_weights,
            casanovo_config_file
        )

        CREATE_PEPTIDE_FASTA(
            COMET.out.comet_txt.collect(),
            CASANOVO.out.mztab.collect(),
            decoy_prefix
        )
        SPLIT_QUERY_FASTA(
            CREATE_PEPTIDE_FASTA.out.peptide_query_fasta,
            params.requested_fasta_parts
        )

        GLSEARCH(
            SPLIT_QUERY_FASTA.out.query_fasta_part.flatten(),
            GENERATE_LIBRARY_DECOYS.out.decoys_fasta,
            params.glsearch.gap_initiation_penalty,
            params.glsearch.gap_extension_penalty
        )

        BUILD_RESET_INPUT(
            CREATE_PEPTIDE_FASTA.out.comet_peptides,
            CREATE_PEPTIDE_FASTA.out.casanovo_peptides,
            GLSEARCH.out.glsearch_results.collect(),
            GENERATE_LIBRARY_DECOYS.out.decoys_fasta,
            decoy_prefix
        )

        RESET(
            BUILD_RESET_INPUT.out.reset_input
        )

}
