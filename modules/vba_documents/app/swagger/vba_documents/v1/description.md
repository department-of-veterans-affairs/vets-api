The Benefits Intake API enables authorized third-party systems, such as those used by Veteran Service Organizations (VSOs), agencies, and Veterans, to digitally submit documents for VA benefits claims directly to the claims intake process of the Veterans Benefits Administration (VBA). This API handles documents related to the following benefit claim types:
* Compensation
* Pension/Survivors Benefits
* Education
* Fiduciary
* Insurance
* Veteran Readiness & Employment (VRE)
* Board of Veteran Appeals (BVA)

Additionally, the API offers real-time status updates on document submissions until they've been successfully accepted by VBA or another VA system for claims processing.

**Important**: This API **may not** be used for Veterans Health Administration (VHA) benefits forms, including the Instructions and Enrollment Application for Health Benefits form (10-10EZ) and the application for CHAMPVA benefits form (10-10d).

## Technical overview
The Benefits Intake API first provides an upload location and unique submission identifier, and then accepts a payload consisting of a PDF document, other optional PDF attachments, and JSON metadata. The metadata describes the PDF attachments and identifies the Veteran who the benefits are related to.

### Authentication and Authorization
API requests are authorized through a symmetric API token, provided in an HTTP header with name `apikey`. [Get access to sandbox](https://developer.va.gov/explore/api/benefits-intake/sandbox-access).

### Test data
Since the primary purpose of this API is to accept user submissions, it doesn't have mock test data available. In the sandbox environment, data submitted to the API is not sent downstream. This API can return data that has been previously submitted by a consumer.

### Document Submission Statuses

After a successful upload, a submission status can be tracked using the GET /uploads/{id} endpoint. If multiple uploads have been made, the POST /uploads/report endpoint can be used to track the status of multiple submissions. For more information, please see steps 5 and 6 in the **How to Upload** section of this documentation or check out the example curl and response sections for these endpoints.

Detailed descriptions of what each status means are found in this table.
| Status        | What it means |
| ---           |     ---     |
| **Pending**   | - This is the initial status. Indicates no document submission has been uploaded yet.<br /><br />- Date of Receipt is not yet established with this status. |
| **Uploaded**  | - Indicates document submission has been successfully uploaded (PUT) to the API server.<br /><br />- Submission has not yet been validated.<br /><br />- Date of Receipt is not yet established with this status.<br /><br />- Any errors with the document submission, such as having an unreadable PDF, may cause an Error status. |
| **Received**  | - Indicates document submission has been received downstream of the API and is awaiting processing.<br /><br />- The VA Date of Receipt is set when this status is achieved.<br /><br />- Any errors with the document submission, such as having an unreadable PDF, may cause an Error status.<br /><br />- This is the final status in the sandbox environment unless further progress is simulated by the user. |
| **Processing**| - Indicates the document package is being validated, processed, and made ready to route and work.<br /><br />- Any errors with the document submission, such as having an unreadable PDF, may cause an Error status.|
| **Success**   | - Indicates the document submission has been successfully received within VA's mail handling system.<br /><br />- Success is the final status for a small percentage of submissions with claim types, Veteran types, or exception processes that are not worked in VBMS. A true value in the final_status attribute will indicate this.<br /><br />- Most submissions reach a Success status within 1 business day.<br /><br />- A small portion will take longer. However, some submissions may take up to 2 weeks to reach a Success status.|
| **VBMS**      | - Indicates the document submission was successfully uploaded into a Veteran's eFolder within VBMS.<br /><br />- On average, submissions reach VBMS status within 3 business days. However, processing times vary and some submissions may remain in a Success status for several weeks before reaching a VBMS status.<br /><br />- Some document packages are worked in VA systems other than VBMS. For these submissions, Success is the final status. |
| **Error**     | - Indicates that there was an error. Refer to the error code and detail for further information. |
| **Expired**   | - After a POST request, there is a 15-minute window during which documents must be uploaded via a PUT request.<br /><br />- An Expired status means the documents were not successfully uploaded within this 15-minute window.<br /><br />- We recommend coding to retry unsuccessful uploads within 15 minutes using the same submission in case of connection issues. |

In the sandbox environment:
* The final status of a submission is `received` since submissions do not actually progress to the Central Mail repository or VBMS.
* Progress beyond the `received` status can be simulated for testing. A `Status-Override` header can be passed on the `/uploads/{id}` endpoint to change the status of a submission to simulate the various status scenarios.

In the production environment:
* The date that the Benefits Intake API submits the documents downstream (indicated by the `received` status)  is used as the official VA date of receipt. This is usually the same day as when the documents are submitted by users, but not always.
* If the document's final destination is VBMS, it can fall into an `error` state until the status of VBMS is returned.
* If the document's final destination is another VA system besides VBMS, it can fall into an `error` state until the status of `success` is returned.


### How to avoid submission errors
The Benefits Intake API returns three different categories of errors:
* HTTP errors relating to the client request. These errors will be immediate.
* Metadata and PDF validation errors run by the system before passing the submission downstream to subsequent services. These errors will be asynchronous but generally come within minutes of submission.
* Downstream errors returned by subsequent services, usually relating to the content of the PDFs or metadata. These errors will be asynchronous and can take minutes to hours or longer to receive.

To prevent submission delays and errors:
* Ensure that submitted PDFs are not locked by user passwords and that they are within the file and page size limits before submitting your payload.
* Be sure to validate all metadata fields against their data requirements as defined in the DocumentUploadMetadata schema before submitting your payload.
* The businessLine field is optional, but when included, it will ensure the fastest possible processing. If not specified, businessLine will default to CMP, the business line for Compensation requests.
* The POST /uploads/validate_document endpoint can be used to ensure individual PDF documents meet system requirements prior to submission.

For information on how to monitor the status of submissions, please see Steps 5 and 6 of the **How to Upload** section of this documentation.

### Attachment & file size limits
There is no limit on the number of files a payload can contain, but file size and page dimension limits do apply.
* Uploaded PDFs can't be larger than 78" x 101".
* Uploaded PDFs can't exceed 100 MB.
* The entire payload can't exceed 5 GB.

### How to Upload
The Upload operation lets a client upload a multi-part document submission, specifically PDFs and metadata. Uploading is detailed below.
1. Client Request: POST https://sandbox-api.va.gov/services/vba_documents/v1/
    * No request body or parameters required.
2. Service Response: A JSON API object with the following attributes:
    * `guid`: An identifier used for subsequent status requests.
    * `location`: A URL to which the actual document submission payload can be submitted in the next step. The URL is specific to this upload request, and should not be re-used for subsequent uploads. The URL is valid for 15 minutes (900 seconds) from the time of this response. If the location is not used within 15 minutes, the GUID will expire. Once expired, status checks on the GUID will return a status of `expired`.
        * **Note**: If the status hasn't changed to uploaded within 15 minutes of submission, retry the POST request in step 1 to generate a new location URL.
3. Client Request: PUT to the location URL returned in step 2.
    * The request body should use the binary multipart/form-data format . The body can optionally be encoded as Base64.
    * No `apikey` authorization header is required for this request, as authorization is embedded in the signed location URL.
4. Service Response: The HTTP status indicates whether the upload was submitted.
    * Additionally, the response includes an ETag header containing an MD5 hash of the submitted payload. This can be compared to the submitted payload to ensure data integrity of the upload.
    * **Note**: A successful document submission **_does not_** mean it was successfully received by VA. Successful document submissions can fail later, as discussed above in the "How to avoid submission errors" section.
5. Client Request: GET https://sandbox-api.va.gov/services/vba_documents/v2/uploads/{id}
    * `id`: An identifier (`guid`) returned in step 2 by the previous submission.
6. Service Response: A JSON API object with the following attributes:
    * `guid`: The identifier of the submission for which a status was requested.
    * `status`: The current status of the submission. See the previous "Document Submission Statuses" section for more information about the specific statuses.
    * `code`: Only present if `status` is `error`. An error code specifying why the submission is in an error state. For a list of the error codes, see the schema for the GET /uploads/{id} 200 response.
    * `detail`: Only present if `status` is `error`. Plain language detailing of the error corresponding to the error code and the specific submission.
    * `final_status`: Indicates whether the status of the submission is final. Submissions with a `final_status` of `true` will no longer update to a new status.
    * `updated_at`: The last time the submission status was updated.


If submissions to the API are made frequently, the bulk status endpoint should be used in place of the above Step 5 to request updates for multiple submissions:

5. Client Request: POST https://sandbox-api.va.gov/services/vba_documents/v1/uploads/report
    * `ids`: A list of identifiers ( guid) returned in step 2 by the previous submissions.
6. Service Response: A JSON API object with the following attributes for each `id`:
    * `guid`: The identifier of the submission for which a status was requested.
    * `status`: The current status of the submission. See the previous "Document Submission Statuses" section for more information about the specific statuses.
    * `code`: Only present if `status` is `error`. An error code specifying why the submission is in an error state. For a list of the error codes, see the schema for the GET /uploads/{id} 200 response.
    * `detail`: Only present if `status` is `error`. Plain language detailing of the error corresponding to the error code and the specific submission.
    * `final_status`: Indicates whether the status of the submission is final. Submissions with a `final_status` of `true` will no longer update to a new status.
    * `updated_at`: The last time the submission status was updated.
    * Due to current system limitations, data for the /uploads/report endpoint is cached for one hour. The /uploads/{id} endpoint isn't cached.


### Optional Base64 encoding
Base64 is an encoding scheme that converts binary data into text format, so that encoded textual data can be easily transported over networks uncorrupted and without data loss.

Base64 can be used to encode binary multipart/form-data in its entirety. Note that the whole payload must be encoded, not individual parts/attachments.

After encoding the payload, the base64 string must be prefaced with `data:multipart/form-data;base64` in order to allow the system to distinguish the file type.

The final string payload will look something like this: `data:multipart/form-data;base64,(encryption string)==`, and close with the standard == marker. Note that the multipart boundaries, that is,\
-----WebKitFormBoundaryVfOwzCyvug0JmWYo and ending in\
------WebKitFormBoundaryVfOwzCyvug0JmWYo- must also be included.
