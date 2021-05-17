# Benefits Intake

Are you a Veteran? [Check your benefits or appeals claim status](https://www.va.gov/claim-or-appeal-status/).

https://api.va.gov/services/vba_documents/docs/v1/api

The Benefits Intake API allows authorized third-party systems used by Veteran Service Organizations, agencies, and Veterans to digitally submit claim documents directly to the Veterans Benefits Administration's (VBA) claims intake process.

Visit our VA Lighthouse [Contact Us page](https://developer.va.gov/support) for further assistance.


## Background 
This API provides a secure, efficient, and tracked alternative to paper or fax for Veteran benefit claim document submissions. The VBA can begin processing documents submitted through this API immediately, which ultimately provides Veterans with claim decisions more quickly. All successfully submitted documents are routed to the correct office(s) for processing, including documents related to the following benefit claim types:

* Compensation
* Pension/Survivors Benefits
* Education 
* Fiduciary
* Insurance
* Veteran Readiness & Employment (VRE)
* Board of Veteran Appeals (BVA)

The API provides submission status updates until the document(s) are successfully established for VBA claim processing, eliminating the need for users to switch between systems to manually check whether documents have been successfully uploaded.

## Technical overview
The Benefits Intake API first provides an upload location and unique submissino identifier, and then accepts a payload consisting of a document in PDF format, zero or more optional attachments in PDF format, and some JSON metadata. 

The metadata describes the document and attachments, and identifies the person for whom it is being submitted. This payload is encoded as binary multipart/form-data (not base64). The unique identifier supplied with the payload can subsequently be used to request the processing status of the uploaded document package.

API Consumers are encouraged to validate the `zipcode`,`fileNumber`, `veteranFirstName`, and 'veteranLastName' fields before submission according to their description in the DocumentUploadMetadata model and provide the use selected 'businessLine' attribute for the most efficient processing. Additionally, please ensure no PDF user or owner passwords are used in submitted PDFs. 

### Attachment & file size limits
There is not a limit on the number of documents that can be submitted at once, but file sizes can impact the number of documents accepted.

* The file size limit for each document is 100 MB.
* The entire package, which is all PDFs combined into one payload, is limited to 5 GB.
* The maximum page size for each image (i.e. within a PDF) is 21 in x 21 in. Open source tools can be used to check the size of an image.  

### Date of receipt
The date and time documents are submitted to the Benefits Intake API is used as the official VA date of receipt. However, note that until a document status of `received`, `processing`, `success`, or `vbms` is returned, a client cannot consider the document received by VA. 

A status of `received` means that the document package has been transmitted, but possibly not validated. Any errors with the document package (unreadable PDF, Veteran not found, etc) will cause the status to change to `error`.

If the document status is `error`, VA has not received the submission and cannot honor the submission date as the date of receipt.

### Authorization
API requests are authorized through a symmetric API token, provided in an HTTP header with name 'apikey'. [Get a sandbox API Key](https://developer.va.gov/apply)

### Testing in the sandbox environment
In the sandbox environment, the final status of a submission is `received` and submissions do not actually progress to Central Mail / VBMS. Progress beyond the `received` status can be simulated for testing.

In sandbox, we allow passing in a `Status-Override` header on the `/uploads/{id}` endpoint so that you can change the status of your submission to simulate the various scenarios. 

The available statuses are `pending`, `uploaded`, `received`, `processing`, `success`, `vbms`, and `error`. The meaning of the various statuses is listed below in Models under DocumentUploadStatusAttributes.

Use mock test data in the sandbox environment, data is not sent downstream and it is not necessary to align with any other systems' data. 

### Upload operation
Allows a client to upload a multi-part document package (form + attachments + metadata).

1. Client Request: POST https://sandbox-api.va.gov/services/vba_documents/v1/
    * No request body or parameters required

2. Service Response: A JSON API object with the following attributes:
    * `guid`: An identifier used for subsequent status requests
    * `location`: A URL to which the actual document package payload can be submitted in the next step. The URL is specific to this upload request, and should not be re-used for subsequent uploads. The URL is valid for 900 seconds (15 minutes) from the time of this response. If the location is not used within 15 minutes, the GUID will expire. Once expired, status checks on the GUID will return a status of `expired`.
        * Note: If, after you've submitted a document, the status hasn't changed to `uploaded` before 15 minutes has elapsed, we recommend retrying the upload in order to make sure the document properly reaches our servers. If the upload continues to fail, try encoding the payload as Base64 (See below).

 3. Client Request: PUT to the location URL returned in Step 2.
    * Request body should be encoded as binary multipart/form-data (base64 also available - see details below), equivalent to that generated by an HTML form submission or using “curl -F…”. The format is described in more detail below.
    * No `apikey` authorization header is required for this request, as authorization is embedded in the signed location URL.

4. Service Response: The HTTP status indicates whether the upload was successful.
    * Additionally, the response includes an ETag header containing an MD5 hash of the submitted payload. This can be compared to the submitted payload to ensure data integrity of the upload.

### Status caching
Due to current system limitations, data for the `/uploads/report` endpoint is cached for one hour.

A request to the `/uploads/{id}` endpoint will return a real-time status for that GUID, and update its status in `/uploads/report`.

The `updated_at` field indicates the last time the status for a given GUID was updated.

### Optional Base64 encoding

Base64 is an encoding scheme that converts binary data into text format, so that encoded textual data can be easily transported over networks uncorrupted and without data loss. 

Base64 can be used to encode binary multipart/form-data it in its entirety.  Note that the whole payload must be encoded, not individual parts/attachments.

After encoding your payload, you'll be required to preface your base64 string with `data:multipart/form-data;base64,` in order to allow our system to distinguish the file type. Your final string payload would look something like `data:multipart/form-data;base64,(encryption string)==` and close with the standard == marker.  Note that the multipart boundaries i.e. -----WebKitFormBoundaryVfOwzCyvug0JmWYo and ending ------WebKitFormBoundaryVfOwzCyvug0JmWYo- must also be included.

### Consumer onboarding process
When you're ready to move to production, [request a production API key.](https://developer.va.gov/go-live)
