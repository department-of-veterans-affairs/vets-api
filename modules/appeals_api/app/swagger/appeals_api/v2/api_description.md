The Decision Reviews API allows you to interact with a Veteran’s decision reviews, also known as benefit appeals. This API provides a secure and efficient alternative to paper or fax submissions and follows the AMA process. To view the status of all decision reviews and benefits appeals submitted according to the legacy benefits appeals process, use the [Appeals Status API](/explore/appeals/docs/appeals?version=current).

Information about the decision reviews process and types of decision reviews is available on the [VA decision reviews and appeals page](https://www.va.gov/decision-reviews/#request-a-decision-review-or-appeal).

### Background
The Decision Reviews API passes data through to Caseflow, a case management system. The API converts decision review data into structured data that can be used for processing and reporting.

Because this application is designed to allow third-parties to request information on behalf of a Veteran, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).

### Authorization and Access
To gain access to the decision reviews API you must [request an API Key](/apply). API requests are authorized through a symmetric API token which is provided in an HTTP header named `apikey`.

### Submission Statuses

Use the correct GET endpoint to check the appeal’s submission status. The endpoint returns the current status of the submission to VA but not the status of the appeal in the AMA process.

### Higher Level Review (HLR) Submission Statuses

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

#### Status Simulation

Sandbox test submissions do not progress through the same statuses as in the Production environment.  In the lower environments (i.e. Sandbox or Staging), the final status of a submission is either `submitted` (for NOD) or `received` (for HLR). In the lower environments, we allow passing a `Status-Simulation` header on the show endpoints so that you can simulate the other statuses.

Statuses can be simulated for both HLR/NOD submissions as well as evidence document uploads.

The **submission statuses** available for simulation are the statuses listed in the NOD or HLR Submission Statuses table above (for either the NOD or HLR respectively).

The **evidence upload** statuses available for simulation are the statuses listed in the Evidence Upload Statuses table below (for simulating the status of uploaded evidence documents).

### Status Caching

Due to current system limitations, data for the status attribute for the following endpoints is cached for one hour.

- GET `/higher_level_reviews/{uuid}`

The updated_at field indicates the last time the status for a given GUID was updated.
