The Legacy Appeals API returns a list of a claimant's active legacy appeals, which are not part of the Appeals Modernization Act (AMA) process. This list can be used to determine whether to opt in to the new decision review process. [Learn more about managing a legacy appeal.](https://www.va.gov/decision-reviews/legacy-appeals/).

To check the status of all decision reviews and appeals for a specified individual, use the [Appeals Status API](https://dev-developer.va.gov/explore/appeals/docs/appeals?version=current).

To file an appeal or decision review, use one of these APIs:
* [Higher-Level Reviews API](https://dev-developer.va.gov/explore/appeals/docs/higher_level_reviews)
* [Notice of Disagreements API](https://dev-developer.va.gov/explore/appeals/docs/notice_of_disagreements)
* [Supplemental Claims API](https://dev-developer.va.gov/explore/appeals/docs/supplemental_claims)

## Technical overview
The Legacy Appeals API pulls data from Caseflow, a case management system. It provides decision review and appeal data that can be used for submitting a Higher Level Review, Notice of Disagreement, or Supplemental Claim.

### Authorization and Access
The authentication model for the Legacy Appeals API uses OAuth 2.0/OpenID Connect. The following authorization models are supported:
* [Authorization code flow](https://dev-developer.va.gov/explore/authorization/docs/authorization-code)
* [Client Credentials Grant (CCG)](https://dev-developer.va.gov/explore/authorization/docs/client-credentials)

To use this API, you must first [request sandbox access](https://dev-developer.va.gov/onboarding/request-sandbox-access). Then, follow our authentication process for [authorization code flow](https://dev-developer.va.gov/explore/authorization/docs/authorization-code) or [client credentials grant](https://dev-developer.va.gov/explore/authorization/docs/client-credentials).

**Important:** To get production access using client credentials grant, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](https://dev-developer.va.gov/support/contact-us).
