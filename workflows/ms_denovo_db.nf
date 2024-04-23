// Modules
include { MSCONVERT } from "../modules/msconvert"
include { COMET } from "../modules/comet"
include { CASANOVO } from "../modules/casanovo"
include { CREATE_PEPTIDE_FASTA } from "../modules/create_peptide_fasta"

workflow wf_ms_denovo_db {

    take:
        spectra_file_ch
        fasta
        comet_params
        casanovo_weights
        from_raw_files
    
    main:

        // convert raw files to mzML files if necessary
        if(from_raw_files) {
            mzml_file_ch = MSCONVERT(spectra_file_ch)
        } else {
            mzml_file_ch = spectra_file_ch
        }

        COMET(mzml_file_ch, comet_params, fasta)
        CASANOVO(mzml_file_ch, casanovo_weights)
        CREATE_PEPTIDE_FASTA(
            COMET.out.comet_txt.collect(),
            CASANOVO.out.mztab.collect()
        )
}
