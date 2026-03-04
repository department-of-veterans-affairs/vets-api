# BIO HEART Module
*Benefits Intake Optimization - Helping Ensure Accrued & Relationship Transitions*

## What

This is a module used to facilitate submitting forms 21P-0537 and 21P-601 to 
both the Benefits Intake API and the Mail Management System (MMS) Form Validation
Service (FVS) structured data endpoint.

This module relies on the `simple_forms_api` module for submitting to Benefits 
Intake API and the `lib/ibm` service for submitting to MMS. It acts as a 
coordinator for sending a single submission to both services.

## Why

Forms submitted to the Benefits Intake API via the Simple Forms API (see 
`simple_forms_api` in vets-api/modules) are only represented as generated PDF
documents. In order to complement this submission path, MMS was extended to
accept structured data of forms submitted to the Benefits Intake API. This allows
for automated checking of form content without the need for OCR (as well as other
upsides).

Forms 21P-0537 and 21P-601 are currently handled by the Simple Forms API. Rather
than modify the Simple Forms API to account for this new MMS functionality, this
small module was created to extend the Simple Forms functionality. This ensures
zero disruption of existing Simple Forms workflows (most of which do not need 
to go to MMS), while also allowing new forms
to be submitted to Benefits Intake *and* MMS in a single (from the user's 
perspective) action.

## How

This module includes a controller, `BioHeartApi::V1::UploadsController`, that directly inherits from
the corresponding uploads controller in the Simple Forms API. By first calling the inherited 
`submit` method, and then using an `after_action` to trigger a submission of the 
form data to MMS via the `lib/ibm` service, the PDF is submitted to Benefits 
Intake *and* structured data is submitted to MMS. 

The submissions both use the UUID provided from Benefits Intake, so 
they are able to be connected between the two systems.

## Can more forms be added to this module?

Yes. To add more forms, you must 
1. Add the new form to the Simple Forms API as you would if you had no intention of sending data to MMS. (For more information on this process, refer to the Simple Forms API documentation contained in the module in vets-api)
2. In the BIO HEART module, add a new mapper class in `modules/bio_heart/lib/bio_heart_api/form_mappers` that handles transforming the submitted form data into the format expected by MMS (varies for each form, accepted data structure is specified by MMS)
3. Update the mapper registry `modules/bio_heart/lib/bio_heart_api/form_mapper_registry.rb` with a reference to the newly created mapper
4. Add test data and specs for the new form
5. Set up the form frontend to submit to the BIO HEART API endpoint (see existing examples in vets-website for forms 21P-0537 and 21P-601)

## Miscellaneous

The actual transmission of data to MMS happens via the main service in `lib/ibm`.
This service handles setting up the encrypted connection between vets-api and 
the MMS endpoint (through the fwd proxy). 
The BIO HEART API merely uses this connection without making any modifications.
