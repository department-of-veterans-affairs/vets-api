The Appeals Status API allows you to request the statuses of all decision reviews for a Veteran, including decision reviews following the AMA process and legacy benefit appeals. The statuses are returned as read only. If you need to manage or submit a Veteran’s decision review request, use the [Decision Reviews API](/explore/appeals/docs/decision_reviews?version=current). 

## Background

The Appeals API passes data through to Caseflow, a case management system. Caseflow accepts a header with the Veteran’s SSN and returns the current status of their decision reviews and/or benefits appeals.

Because this application is designed to allow third-parties to request information on behalf of a Veteran, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).


## Design

### Authorization and Access

To gain access to the Appeals Status API you must [request an API Key](/apply). API requests are authorized through a symmetric API token which is provided in an HTTP header named `apikey`.

1. Client Request: GET https://sandbox-api.va.gov/services/appeals/v1/appeals
    * Provide the Veteran's SSN as the X-VA-SSN header
    * Provide the VA username of the person requesting the appeals status as the X-VA-User header

2. Service Response: A JSON API object with the current status of appeals
