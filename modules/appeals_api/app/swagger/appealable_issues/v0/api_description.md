The Appealable Issues API lets you retrieve a list of a claimant’s appealable issues and any chains of preceding issues. Appealable issues are issues from claims about which VA has made a decision that may be eligible for appeal. Not all appealable issues are guaranteed to be eligible for appeal; for example, claimants may have another appeal in progress for an issue.

To check the status of all decision reviews and appeals for a specified individual, use the [Appeals Status API](https://developer.va.gov/explore/api/appeals-status/docs).

To file an appeal or decision review, use one of these APIs: 
* [Higher-Level Reviews API](https://developer.va.gov/explore/api/higher-level-reviews/docs)
* [Notice of Disagreements API](https://developer.va.gov/explore/api/notice-of-disagreements/docs)
* [Supplemental Claims API](https://developer.va.gov/explore/api/supplemental-claims/docs)

## Technical overview
The Appealable Issues API pulls data from Caseflow, a case management system. It provides decision review and appeal data that can be used for submitting a Higher Level Review, Notice of Disagreement, or Supplemental Claim.

### Authorization and Access
The authentication model for the Appealable Issues API uses OAuth 2.0/OpenID Connect. The following authorization models are supported:
* [Authorization code flow](https://developer.va.gov/explore/api/appealable-issues/authorization-code)
* [Client Credentials Grant (CCG)](https://developer.va.gov/explore/api/appealable-issues/client-credentials)

**Important:** To get production access using client credentials grant, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](https://developer.va.gov/support/contact-us).
