Using this endpoint will decrease the likelihood of errors associated with individual documents during
the submission process. Validations performed:
* Document is a valid PDF (Note: `Content-Type` header value must be "application/pdf")
* Document does not have a user password (an owner password is acceptable)
* File size does not exceed 100 MB
* Page size does not exceed 78" x 101"

Each PDF document is sent as a direct file upload. The request body should contain nothing other than the document in
binary format. Binary multipart/form-data encoding is not supported. This endpoint does NOT validate metadata in JSON
format.

This endpoint does NOT initiate the claims intake process or submit data to that process. After using this endpoint,
individual PDF documents can be combined and submitted as a payload using PUT `/path`.

A `200` response confirms that the individual document provided passes the system requirements.

A `422` response indicates one or more problems with the document that should be resolved before submitting it in the
full document submission payload.
