# IVC ChampVa
This module allows you to generate form_mappings based on a PDF file.
With this in place, you can submit a form payload from the vets-website
and have this module map that payload to the associated PDF and submit it
to PEGA via S3.

PEGA has the ability to hit an endpoint to update the database `ivc_champva_forms`

## Helpful Links
[Swagger API Docs](TBD)
[Project MarkDowns](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/health-care/champva)
[DataDog Dashboard](https://vagov.ddog-gov.com/dashboard/zsa-453-at7/ivc-champva-forms)
[Pega Callback API ADR](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/ADR-callback-api-to-receive-status-from-pega.md)
[Pega Callback API Implementation Plan](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/callback-api-technical-spec.md)

## Endpoints
/ivc_champva/v1/forms
/ivc_champva/v1/forms/submit_supporting_documents
/ivc_champva/v1/forms/status_updates


### Generate files for new forms
rails ivc_champva:generate\['path to PDF file'\]

### Installation
Ensure the following line is in the root project's Gemfile:

  `gem 'ivcchampva', path: 'modules/ivcchampva'`

### License
This module is open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).