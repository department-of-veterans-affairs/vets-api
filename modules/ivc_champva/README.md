# IVC ChampVa
This module allows you to generate form_mappings based on a PDF file.
With this in place, you can submit a form payload from the vets-website
and have this module map that payload to the associated PDF and submit it
to PEGA via S3.

PEGA has the ability to hit an endpoint to update the database table `ivc_champva_forms`
with their `case_id` and `status` in the payload.

# Uploads_Controller
The uploads_controller.rb file in the IVC Champva module is a key component of the application, responsible for handling file uploads. It contains several private methods that perform various tasks related to file uploads. The get_attachment_ids_and_form method generates attachment IDs based on the parsed form data and also instantiates a new form object. It uses the generate_attachment_ids method to create an array of attachment IDs.

The supporting_document_ids method retrieves the IDs of any supporting documents included in the parsed form data. The get_file_paths_and_metadata method generates file paths and metadata for the uploaded files, and also handles any attachments associated with the form. The get_form_id method retrieves the ID of the form being processed. Overall, this controller is crucial for managing the upload and processing of files in the application.

## Helpful Links
- [Swagger API UI](https://department-of-veterans-affairs.github.io/va-digital-services-platform-docs/api-reference/) then search "https://dev-api.va.gov/v1/apidocs" to see the ivc_champva endpoint
- [Project MarkDowns](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/health-care/champva)
- [DataDog Dashboard](https://vagov.ddog-gov.com/dashboard/zsa-453-at7/ivc-champva-forms)
- [Pega Callback API ADR](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/ADR-callback-api-to-receive-status-from-pega.md)
- [Pega Callback API Implementation Plan](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/callback-api-technical-spec.md)

## Endpoints
- `/ivc_champva/v1/forms`
- `/ivc_champva/v1/forms/submit_supporting_documents`
- `/ivc_champva/v1/forms/status_updates`


### Generate files for new forms
`rails ivc_champva:generate\['path to PDF file'\]`

### Installation
Ensure the following line is in the root project's Gemfile:

  `gem 'ivcchampva', path: 'modules/ivcchampva'`

### License
This module is open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
