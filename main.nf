#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { wf_ms_denovo_db } from "./workflows/ms_denovo_db"

//
// The main workflow
//
workflow {

    fasta = file(params.fasta, checkIfExists: true)
    comet_params = file(params.comet_params, checkIfExists: true)
    casanovo_config = file(params.casanovo_config_file, checkIfExists: true)
    // NOT file() -- the checkpoint is baked into the Casanovo image, so this is a
    // path inside the container that does not exist on the host. See
    // params.casanovo_weights in nextflow.config.
    casanovo_weights = params.casanovo_weights
    annotated_fasta = file(params.annotated_fasta, checkIfExists: true)

    spectra_dir = file(params.spectra_dir, checkIfExists: true)

    // get our mzML files
    mzml_files = files("$spectra_dir/*.mzML")

    // get our raw files
    raw_files = files("$spectra_dir/*.raw")

    if(mzml_files.size() < 1 && raw_files.size() < 1) {
        error "No raw or mzML files found in: $spectra_dir"
    }

    if(mzml_files.size() > 0) {
        spectra_files_ch = channel.fromList(mzml_files)
        from_raw_files = false
    } else {
        spectra_files_ch = channel.fromList(raw_files)
        from_raw_files = true
    }

    wf_ms_denovo_db(
        spectra_files_ch,
        fasta,
        comet_params,
        casanovo_config,
        casanovo_weights,
        annotated_fasta,
        from_raw_files,
        params.comet_decoy_prefix,
        params.library_decoy_prefix
    )

}

//
// This is a dummy workflow for testing
//
workflow dummy {
    println "This is a workflow that doesn't do anything."
}

// NOTE: completion-email handling lives in nextflow.config as
// `workflow.onComplete`. Under the Nextflow 26 script parser, top-level event
// handlers can no longer be declared in main.nf.
