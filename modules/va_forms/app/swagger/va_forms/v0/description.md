Use the VA Forms API to search for VA forms, get the PDF link and form metadata, and check for new versions.

Visit our VA Lighthouse [support portal](https://developer.va.gov/support) for further assistance.

## Background
This API offers an efficient way to stay up-to-date with the latest VA forms and information. The forms information listed on VA.gov matches the information returned by this API.
- Search by form number, keyword, or title
- Get a link to the form in PDF format
- Get detailed form metadata including the number of pages, related forms, benefit categories, language, and more
- Retrieve the latest date of PDF changes and the SHA256 checksum
- Identify when a form is deleted by the VA

## Technical summary
Please note that not all
VA forms follow the same format and that the exact form name must passed, including proper placement of prefix and/or hyphens.
### Authentication and authorization
The form information shared by this API is publicly available.  API requests are authorized through a symmetric API token, provided in an HTTP header with name apikey. [Get a sandbox API Key](https://developer.va.gov/apply).

### Testing in sandbox environment
Form data in the sandbox environment is not guaranteed to be up to date and also the environment has a reduced API rate limit. When ready to move to production, be sure
to [request a production API key.](https://developer.va.gov/go-live)

### SHA256 revision history
Every night, each form is checked for recent file changes and a corresponding SHA256 checksum calculated. This provides a record of when the PDF changed and
the SHA256 hash that was calculated. This allows end users to know that they have the most recent version and can verify the integrity of a previously 
downloaded PDF.

### Valid PDF link
Additionally, during the nightly refresh process, the link to the form PDF is verified and the `valid_pdf` metadata is updated accordingly. If marked `true`, the link 
is valid and a current form. Is marked `false` the link is either broken or the form has been removed.

### Deleted forms
If the `deleted_at` metadata is set, that means the VA has removed this form from the repository and it is no longer to be used.
