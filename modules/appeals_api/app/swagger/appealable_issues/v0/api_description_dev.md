The Appealable Issues API lets you retrieve a list of a claimant’s appealable issues and any chains of preceding issues. Appealable issues are issues from claims about which VA has made a decision that may be eligible for appeal. Not all appealable issues are guaranteed to be eligible for appeal; for example, claimants may have another appeal in progress for an issue.

To check the status of all decision reviews and appeals for a specified individual, use the [Appeals Status API](https://dev-developer.va.gov/explore/appeals/docs/appeals?version=current).

To file an appeal or decision review, use one of these APIs:
* [Higher-Level Reviews API](https://dev-developer.va.gov/explore/appeals/docs/higher_level_reviews)
* [Notice of Disagreements API](https://dev-developer.va.gov/explore/appeals/docs/notice_of_disagreements)
* [Supplemental Claims API](https://dev-developer.va.gov/explore/appeals/docs/supplemental_claims)

## Technical overview
The Appealable Issues API pulls data from Caseflow, a case management system. It provides decision review and appeal data that can be used for submitting a Higher Level Review, Notice of Disagreement, or Supplemental Claim.

### Authorization and Access
The authentication model for the Appealable Issues API uses OAuth 2.0/OpenID Connect. The following authorization models are supported:
* [Authorization code flow](https://dev-developer.va.gov/explore/authorization/docs/authorization-code)
* [Client Credentials Grant (CCG)](https://dev-developer.va.gov/explore/authorization/docs/client-credentials)

**Important:** To get production access using client credentials grant, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](https://dev-developer.va.gov/support/contact-us).
