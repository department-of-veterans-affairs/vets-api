Accepts document metadata, document binary, and attachment binaries.Full URL, including
query parameters, provided from POST `/document_uploads`.

## Example Payload

The following demonstrates a (redacted) multipart payload suitable for submitting to the PUT
endpoint. Most programming languages should have provisions for assembling a multipart
payload like this without having to do so manually.

```
--17de1ed8f01442b2a2d7a93506314b76
Content-Disposition: form-data; name="metadata"
Content-Type: application/json

{"veteranFirstName": "Jane",
"veteranLastName": "Doe",
"fileNumber": "012345678",
"zipCode": "97202",
"source": "MyVSO",
"docType": "21-22"}
--17de1ed8f01442b2a2d7a93506314b76
Content-Disposition: form-data; name="content"
Content-Type: application/pdf

<Binary PDF contents>
--17de1ed8f01442b2a2d7a93506314b76
Content-Disposition: form-data; name="attachment1"
Content-Type: application/pdf

<Binary PDF attachment contents>
--17de1ed8f01442b2a2d7a93506314b76--
```

This PUT request would have an overall HTTP Content-Type header:

```
Content-Type: multipart/form-data; boundary=17de1ed8f01442b2a2d7a93506314b76
```

Note that the Content-Disposition parameter "name" in each part must be the expected values
"metadata", "content", "attachment1"..."attachmentN"
