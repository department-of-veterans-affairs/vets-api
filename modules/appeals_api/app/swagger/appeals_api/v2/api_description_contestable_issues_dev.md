The Contestable Issues API lets internal VA teams retrieve a list of a claimant’s contestable issues and any chains of preceding issues. Contestable issues are issues from claims about which VA has made a decision that may be eligible for appeal. Not all contestable issues are guaranteed to be eligible for appeal; for example, claimants may have another appeal in progress for an issue.

To check the status of all decision reviews and appeals for a specified individual, use the [Appeals Status API](https://developer.va.gov/explore/appeals/docs/appeals?version=current).

To file an appeal or decision review, use one of these APIs: 
* `Higher-Level Reviews API`
* `Notice of Disagreements API`
* `Supplemental Claims API`

## Technical overview
The Contestable Issues API pulls data from Caseflow, a case management system. It provides decision review and appeal data that can be used for submitting a Higher Level Review, Notice of Disagreement, or Supplemental Claim.

### Authorization and Access
To gain access to the Higher-Level Reviews API you must [request an API Key](https://developer.va.gov/apply). API requests are authorized through a symmetric API token which is provided in an HTTP header named `apikey`.

Because this application is designed to let third-parties request information on behalf of a claimant, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).