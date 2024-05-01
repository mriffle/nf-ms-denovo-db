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
    casanovo_weights = file(params.casanovo_weights, checkIfExists: true)
    library_fasta = file(params.library_fasta, checkIfExists: true)

    spectra_dir = file(params.spectra_dir, checkIfExists: true)

    // get our mzML files
    mzml_files = file("$spectra_dir/*.mzML")

    // get our raw files
    raw_files = file("$spectra_dir/*.raw")

    if(mzml_files.size() < 1 && raw_files.size() < 1) {
        error "No raw or mzML files found in: $spectra_dir"
    }

    if(mzml_files.size() > 0) {
        spectra_files_ch = Channel.fromList(mzml_files)
        from_raw_files = false;
    } else {
        spectra_files_ch = Channel.fromList(raw_files)
        from_raw_files = true;
    }

    wf_ms_denovo_db(
        spectra_files_ch, 
        fasta, 
        comet_params,
        casanovo_config,
        casanovo_weights, 
        library_fasta,
        from_raw_files
    )

}

//
// Used for email notifications
//
def email() {
    // Create the email text:
    def (subject, msg) = EmailTemplate.email(workflow, params)
    // Send the email:
    if (params.email) {
        sendMail(
            to: "$params.email",
            subject: subject,
            body: msg
        )
    }
}

//
// This is a dummy workflow for testing
//
workflow dummy {
    println "This is a workflow that doesn't do anything."
}

// Email notifications:
workflow.onComplete {
    try {
        email()
    } catch (Exception e) {
        println "Warning: Error sending completion email."
    }
}
