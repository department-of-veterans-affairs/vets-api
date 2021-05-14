Use the VA Forms API to search for VA forms, get the form's PDF link and metadata, and check for new versions.

Visit our VA Lighthouse [Contact Us page](https://developer.va.gov/support) for further assistance.

## Background
This API offers an efficient way to stay up-to-date with the latest VA forms and information. The forms information listed on VA.gov matches the information returned by this API.
- Search by form number, keyword, or title
- Get a link to the form in PDF format
- Get detailed form metadata including the number of pages, related forms, benefit categories, language, and more
- Retrieve the latest date of PDF changes and the SHA256 checksum
- Identify when a form is deleted by the VA

## Technical summary
The VA Forms API collects form data from the official VA Form Repository on a nightly basis.  The Index endpoint can return all available forms or, if an optional query parameter is passed, will return only forms that may relate to the query value. When a valid form name is passed to the Show endpoint, it will return a single form with additional metadata and full revision history. A JSON response is given with the PDF link (if published) and the corresponding form metadata.

### Authentication and authorization
The form information shared by this API is publicly available.  API requests are authorized through a symmetric API token, provided in an HTTP header with name apikey. [Get a sandbox API Key](https://developer.va.gov/apply).

### Testing in sandbox environment
Form data in the sandbox environment is for testing your API only, and is not guaranteed to be up-to-date. This API also has a reduced API rate limit. When you're ready to move to production, be sure to [request a production API key.](https://developer.va.gov/go-live)

### SHA256 revision history
Each form is checked nightly for recent file changes. A corresponding SHA256 checksum is calculated, which provides a record of when the PDF changed and the SHA256 hash that was calculated. This allows end users to know that they have the most recent version and can verify the integrity of a previously downloaded PDF.

### Valid PDF link
Additionally, during the nightly refresh process, the link to the form PDF is verified and the `valid_pdf` metadata is updated accordingly. If marked `true`, the link is valid and is a current form. If marked `false`, the link is either broken or the form has been removed.

### Deleted forms
If the `deleted_at` metadata is set, that means the VA has removed this form from the repository and it is no longer to be used.
