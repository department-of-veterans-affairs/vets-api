The Decision Reviews API allows you to interact with a Veteran’s decision reviews, also known as benefit appeals. This API provides a secure and efficient alternative to paper or fax submissions and follows the AMA process. To view the status of all decision reviews and benefits appeals submitted according to the legacy benefits appeals process, use the [Appeals Status API](/explore/appeals/docs/appeals?version=current).

Information about the decision reviews process and types of decision reviews is available on the [VA decision reviews and appeals page](https://www.va.gov/decision-reviews/#request-a-decision-review-or-appeal).

### Background
The Decision Reviews API passes data through to Caseflow, a case management system. The API converts decision review data into structured data that can be used for processing and reporting.

Because this application is designed to allow third-parties to request information on behalf of a Veteran, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).

### Authorization and Access
To gain access to the decision reviews API you must [request an API Key](/apply). API requests are authorized through a symmetric API token which is provided in an HTTP header named `apikey`.

### Submission Statuses

In order to understand where your appeal submission is in the process, the Show endpoint (ex: GET /higher_level_reviews/{uuid}) can be called which will return the status for that appeal submission.  Please note this is the status of the appeal submission to VA, NOT the status of the appeal within the AMA process.
The statuses returned for an appeal submission (HLR, NOD, or SC) follow this pattern:

1. **pending** - Initial status, indicates no document package has been uploaded yet
1. **submitting** - Indicates that the transfer of data has begun but not yet completed
1. **submitted** - Indicates that the data has been sent to upstream systems
1. **received** - Indicates document package has been received upstream of the API, but is not yet in processing. Date of Receipt is set when this status is achieved. (This is also the final status in the sandbox environment.)
1. **processing** - Indicates intake has begun, Conversion and Mail Handling Services (ICMHS) is processing the document package.
1. **success** - Indicates document package has been received by Digital Mail Handling System (DHMS, aka the Centralized Mail portal).
1. **caseflow** - Final status. Indicates document package has been entered into the Caseflow system. Once the appeal has entered this status, the Appeals Status API can be used to check the status of the appeal within the AMA process.

If there is a problem during the process,

- **error** - Indicates that there was an error. See the code and message for further information.
