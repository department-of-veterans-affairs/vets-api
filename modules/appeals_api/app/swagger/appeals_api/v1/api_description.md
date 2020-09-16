The Decision Reviews API allows you to interact with a Veteran’s decision reviews, also known as benefit appeals. This API provides a secure and efficient alternative to paper or fax submissions and follows the AMA process. To view the status of all decision reviews and benefits appeals submitted according to the legacy benefits appeals process, use the [Appeals Status API](/explore/appeals/docs/appeals?version=current).

Information about the decision reviews process and types of decision reviews is available on the [VA decision reviews and appeals page](https://www.va.gov/decision-reviews/#request-a-decision-review-or-appeal).

### Background
The Decision Reviews API passes data through to Caseflow, a case management system. The API converts decision review data into structured data that can be used for processing and reporting. 

Because this application is designed to allow third-parties to request information on behalf of a Veteran, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).

### Authorization and Access
To gain access to the decision reviews API you must [request an API Key](/apply). API requests are authorized through a symmetric API token which is provided in an HTTP header named `apikey`.

