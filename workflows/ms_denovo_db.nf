// Modules
include { MSCONVERT } from "../modules/msconvert"
include { COMET } from "../modules/comet"
include { CASANOVO } from "../modules/casanovo"
include { CREATE_PEPTIDE_FASTA } from "../modules/create_peptide_fasta"
include { DIAMOND } from "../modules/diamond"
include { CREATE_DIAMOND_DB } from "../modules/diamond"
include { BUILD_RESET_INPUT } from "../modules/build_reset_input"
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
        comet_decoy_prefix
        library_decoy_prefix
    
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
            comet_decoy_prefix
        )
        GENERATE_LIBRARY_DECOYS(
            library_fasta,
            library_decoy_prefix
        )

        COMET(
            mzml_file_ch,
            comet_params,
            GENERATE_COMET_DECOYS.out.decoys_fasta,
        )
        
        CASANOVO(
            mzml_file_ch,
            casanovo_weights,
            casanovo_config_file
        )

        CREATE_PEPTIDE_FASTA(
            COMET.out.comet_txt.collect(),
            CASANOVO.out.mztab.collect(),
            comet_decoy_prefix
        )

        homology_search_results = null
        if(params.homology_search_engine.toLowerCase() == 'diamond') {
            CREATE_DIAMOND_DB(
                GENERATE_LIBRARY_DECOYS.out.decoys_fasta
            )

            DIAMOND(
                CREATE_PEPTIDE_FASTA.out.peptide_query_fasta,
                CREATE_DIAMOND_DB.out.diamond_db,
                params.homology_search.gap_initiation_penalty,
                params.homology_search.gap_extension_penalty
            )
            homology_search_results = DIAMOND.out.diamond_results

        } else {
            error "'${params.homology_search_engine}' is an invalid argument for params.search_engine!"
        }

        BUILD_RESET_INPUT(
            CREATE_PEPTIDE_FASTA.out.comet_peptides,
            CREATE_PEPTIDE_FASTA.out.casanovo_peptides,
            homology_search_results.collect(),
            GENERATE_LIBRARY_DECOYS.out.decoys_fasta,
            library_decoy_prefix,
            comet_decoy_prefix
        )

        RESET(
            BUILD_RESET_INPUT.out.reset_input
        )
}
