### Download operation
An endpoint that will allow you to see exactly what the server sees. We split apart all submitted docs and metadata and zip the file to make it available to you to help with debugging purposes. Files are deleted after 10 days. Only available in testing environments, not production.

1. Client Request: GET https://dev-api.va.gov/services/vba_documents/v2/uploads/{id}/download
    Pass the ID as returned by a previous create upload request.

2. Client Response (200): A binary zip file of "what the server sees".
    

