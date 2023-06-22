The Higher-Level Reviews API lets you create and manage Higher-Level Reviews. Higher-Level Reviews can be requested after receiving an initial claim or a Supplemental Claims decision. [Learn more about VA Higher-Level Reviews](https://www.va.gov/decision-reviews/higher-level-review/).

To check the status of all decision reviews and appeals for a specified individual, use the [Appeals Status API](https://dev-developer.va.gov/explore/appeals/docs/appeals?version=current).

## Technical overview
The Higher-Level Reviews API pulls data from Caseflow, a case management system. It provides decision review and appeal data that can be used for submitting a Higher-Level Review.

### Authorization and Access
The authentication model for the Higher-Level Reviews API uses OAuth 2.0/OpenID Connect. The following authorization models are supported:
* [Authorization code flow](https://dev-developer.va.gov/explore/authorization/docs/authorization-code)
* [Client Credentials Grant (CCG)](https://dev-developer.va.gov/explore/authorization/docs/client-credentials)

**Important:** To get production access using client credentials grant, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](https://dev-developer.va.gov/support/contact-us).

### Submission Statuses
Use the correct GET endpoint to check the status of a Higher-Level Review submission.

These endpoints return the status of the submission in Caseflow but not the status of the submission in VBMS, which is the status visible to claimants. Therefore, VBMS statuses are different from the statuses this API returns.

To check the status of an appeal as it will appear to a claimant, use the [Appeals Status API](https://dev-developer.va.gov/explore/appeals/docs/appeals?version=current).

| Status      | What it means |
| ---        |     ---     |
| pending      | Submission successfully received by the API but has not yet started processing. |
| submitting   | Data is transferring to upstream systems but is not yet complete. |
| submitted   | A submitted status means the data was successfully transferred to the central mail portal.<br /><br />A submitted status is confirmation from the central mail portal that they have received the PDF, but the data is not yet being processed. The Date of Receipt is set when this status is achieved.<br /><br />Submitted is the final status in the sandbox environment.<p> |
| processing   | Indicates intake has begun, the Intake, Conversion and Mail Handling Services (ICMHS) group is processing the appeal data. |
| success   | The centralized mail portal, Digital Mail Handling System (DHMS), has received the data. |
| complete   | Final status. Indicates the document package has been successfully associated with the Veteran and has been received in the correct business area for processing. Claim is now established in VBMS. |
| error   | An error occurred. See the error code and message for further information. |

#### Status simulation in sandbox and staging

Test submissions do not progress through the same statuses as the production environment. In sandbox and staging, the final status of a submission is `submitted`; however, we allow passing a `Status-Simulation` header on the show endpoints so that you can simulate all production statuses.

#### Status Caching
Due to system limitations, status attribute data for the GET `/forms/200996/{uuid}` endpoint is cached for 1 hour. The updated_at field indicates the last time the status for a given GUID was updated.
