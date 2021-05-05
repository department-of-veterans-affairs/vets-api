The Decision Reviews API allows you to interact with a Veteran’s decision reviews, also known as benefit appeals. This API provides a secure and efficient alternative to paper or fax submissions and follows the AMA process. To view the status of all decision reviews and benefits appeals submitted according to the legacy benefits appeals process, use the [Appeals Status API](/explore/appeals/docs/appeals?version=current).

Information about the decision reviews process and types of decision reviews is available on the [VA decision reviews and appeals page](https://www.va.gov/decision-reviews/#request-a-decision-review-or-appeal).

### Background
The Decision Reviews API passes data through to Caseflow, a case management system. The API converts decision review data into structured data that can be used for processing and reporting.

Because this application is designed to allow third-parties to request information on behalf of a Veteran, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).

### Authorization and Access
To gain access to the decision reviews API you must [request an API Key](/apply). API requests are authorized through a symmetric API token which is provided in an HTTP header named `apikey`.

### Submission Statuses

Use the correct GET endpoint to check the appeal’s submission status. The endpoint returns the current status of the submission to VA but not the status of the appeal in the AMA process.

### Notice of Disagreement (NOD) Submission Statuses

The submission statuses begin with pending and end with caseflow.

| Status      | What it means |
| ---        |     ---     |
| pending      | Initial status of the submission when no supporting documents have been uploaded. |
| submitting   | Data is transferring to upstream systems but is not yet complete. |
| submitted   | A submitted status means the data was successfully transferred to the central mail portal.<br /><br />A submitted status is confirmation from the central mail portal that they have received the PDF, but the data is not yet being processed. The Date of Receipt is set when this status is achieved.<br /><br />Submitted is the final status in the sandbox environment.<p> |
| processing   | Indicates intake has begun, the Intake, Conversion and Mail Handling Services (ICMHS) group is processing the appeal data. |
| success   | The centralized mail portal, Digital Mail Handling System (DHMS), has received the data. |
| caseflow   | Final status. The data is in the caseflow system and the Appeals Status API can be used to check the status of the appeal in the AMA process. |
| error   | An error occurred. See the error code and message for further information. |

### Higher Level Review (HLR) Submission Statuses

The submission statuses begin with pending and end with success.

| Status      | What it means |
| ---        |     ---     |
| pending      | Initial status of the submission when no supporting documents have been uploaded. |
| submitting   | Data is transferring to upstream systems but is not yet complete. |
| submitted   | A submitted status means the data was successfully transferred to the central mail portal. A submitted status is confirmation from the central mail portal that they have received the PDF, but the data is not yet being processed. The Date of Receipt is set when this status is achieved.Submitted is the final status in the sandbox environment. |
| uploaded   | This status has been deprecated and is no longer in use. |
| received   | A received status is confirmation from the Central Mail Portal that they have received the PDF, but the data is not yet being processed. The Date of Receipt is set when this status is achieved.<br /><br />Received is the final status in the sandbox environment. |
| processing   | Indicates intake has begun, the Intake, Conversion and Mail Handling Services (ICMHS) group is processing the appeal data. |
| success   | The centralized mail portal, Digital Mail Handling System (DHMS), has received the data. |
| error   | An error occurred. See the error code and message for further information. |

#### Status Simulation

Sandbox test submissions do not progress through the same statuses as in the Production environment.  In the lower environments (i.e. Sandbox or Staging), the final status of a submission is either `submitted` (for NOD) or `received` (for HLR). In the lower environments, we allow passing a `Status-Simulation` header on the show endpoints so that you can simulate the other statuses.

Statuses can be simulated for both HLR/NOD submissions as well as evidence document uploads.

The **submission statuses** available for simulation are the statuses listed in the NOD or HLR Submission Statuses table above (for either the NOD or HLR respectively).

The **evidence upload** statuses available for simulation are the statuses listed in the Evidence Upload Statuses table below (for simulating the status of uploaded evidence documents).

### Evidence Uploads

Our NOD evidence submission endpoints allow a client to upload a document package (documents and metadata) of supporting evidence for their submitted NOD by following these steps.

1. Use the POST endpoint [`/notice_of_disagreements/evidence_submissions`] to return a JSON service response with the attributes listed below.
    - `guid`: An identifier used for subsequent evidence upload status requests (not to be confused with the NOD submission GUID)
    - `location`: A URL to which the actual document package payload can be submitted in the next step. The URL is specific to this upload request, and should not be re-used for subsequent uploads. The URL is valid for 900 seconds (15 minutes) from the time of this response. If the location is not used within 15 minutes, the GUID will expire. Once expired, status checks on the GUID will return a status of `expired`.

1. Client Request: PUT to the location URL returned in step 1.
    - Request body should be encoded as binary multipart/form-data, equivalent to that generated by an HTML form submission or using “curl -F…”.
    - No `apikey` authorization header is required for this request, as authorization is embedded in the signed location URL.
    - The metadata.json file uploaded to the location URL with the evidence documents MUST set the `businessLine` to “BVA” to ensure your supporting  documents route to the Board of Veterans Appeals (BVA).
    - The JSON key for the metadata.json file is "metadata", the initial file is "content".  Any subsequent file will be "attachment1", "attachment2", and so forth.

1. The service response will include:
    - HTTP status to indicate whether the evidence document upload was successful.
    - ETag header containing an MD5 hash of the submitted payload. This can be compared to the submitted payload to ensure data integrity of the upload.

Example `metadata.json` file:

```
{
  "veteranFirstName": "Jane",
  "veteranLastName": "Doe",
  "fileNumber": "012345678",
  "zipCode": "94402",
  "source": "Vets.gov",
  "docType": "316",
  "businessLine": "BVA"
}
```

You may check the status of your evidence document upload by using GET `/notice_of_disagreements/evidence_submissions/{uuid}`. If, after you've uploaded a document, the status hasn't changed to `uploaded` before 15 minutes has elapsed, we recommend retrying the submission to make sure the document properly reaches our servers.

### Evidence Upload Statuses

The evidence document upload statuses begin with pending and end with vbms.

Note that until a document status of “received”, “processing”, “success”, or "vbms" is returned, a client cannot consider the document as received by VA. In particular a status of “uploaded” means that the document package has been transmitted, but possibly not validated. Any errors with the document package (unreadable PDF, etc) may cause the status to change to “error”.

| Status      | What it means |
| ---        |     ---     |
| pending      | Initial status of the submission when no supporting documents have been uploaded. |
| uploaded   | Indicates document package has been successfully uploaded (PUT) from the vendor's application system to the API server but has not yet been validated. Date of Receipt is not yet established with this status. |
| received   | Indicates document package has been received upstream of the API, but is not yet in processing. Date of Receipt is set when this status is achieved. (This is also the final status in the sandbox environment unless further progress is simulated.) |
| processing   | Indicates intake has begun, the Intake, Conversion and Mail Handling Services (ICMHS) group is processing the appeal data. |
| success   | The centralized mail portal, Digital Mail Handling System (DHMS), has received the data. |
| vbms   | Final status. Indicates document package has been received by Veterans Benefits Management System (VBMS). |
| error   | An error occurred. See the error code and message for further information. |

### Status Caching

Due to current system limitations, data for the status attribute for the following endpoints is cached for one hour.

- GET `/higher_level_reviews/{uuid}`
- GET `/notice_of_disagreements/{uuid}`
- GET `/notice_of_disagreements/evidence_submission/{uuid}`

The updated_at field indicates the last time the status for a given GUID was updated.
