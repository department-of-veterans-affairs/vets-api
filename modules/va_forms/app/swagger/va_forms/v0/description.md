The VA Forms API provides a means to reference the VA Forms library and retrieve Form information such as, link to the PDF, revision history, related Forms, page numbers and other relevant metadata.

Visit our VA Lighthouse [support portal](https://developer.va.gov/support) for further assistance.

## Background
The VA Forms API o ers an e icient way to look up VA Forms and their relevant metadata. Using this API provides many benefits, such as:
- A link to the Form in PDF format.
- Complete history on when the PDF changed and the SHA256 checksum.
- Detailed metadata including: number of pages, related forms, benefit categories and more.
- Search by Form number, keyword or title.

## Technical Summary
The VA Forms API collects Form data from the o icial VA Form Repository on a nightly basis. The Index endpoint can return all available forms or, optionally, passed a query parameter to filter on. The Show endpoint will return a single Form with additional metadata and full revision history. A JSON response is given with the PDF link (if published) and the corresponding Form metadata.

Making a GET call to `/forms` will return an index of all available VA forms. Optionally, pass a `?query` parameter to filter forms by form number or title.

Making a GET call with a specific `form_name` to `/forms/{form_name}` will return a specific Form, including full version history. Please note that not all 
VA Forms follow the same format and that the exact Form name must passed, including proper placement of prefix and/or hyphens.  

### Testing in sandbox environment
Form data in the sandbox environment is not guaranteed to be up to date and also has a reduced API rate limit applied. When ready to move to production, be sure
to request a production API key [here](https://developer.va.gov/go-live).

### SHA256 Revision History
Every night, each Form is checked for recent file changes and a corresponding SHA256 checksum calculated. This provides a record of when the PDF changed and
the SHA256 hash that was calculated. This allows end users to know that they have the most recent version and can verify the integrity of a previously 
downloaded PDF.

### Valid PDF Link
Additionally, during the nightly refresh process, the link to the Form PDF is verified and the `valid_pdf` metadata is updated accordingly. If marked `true`, the link 
is valid and a current Form. Is marked `false` the link is either broken or the Form has been removed.

### Deleted Forms
If the `deleted_at` metadata is set, that means the VA has removed this Form from the repository and it is no longer to be used.
