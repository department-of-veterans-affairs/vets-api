The Legacy Appeals API returns a list of a claimant's active legacy appeals, which are not part of the Appeals Modernization Act (AMA) process. This list can be used to determine whether to opt in to the new decision review process. [Learn more about managing a legacy appeal](https://www.va.gov/decision-reviews/legacy-appeals/).

To check the status of all decision reviews and appeals for a specified individual, use the [Appeals Status API](/explore/api/appeals-status/docs).

To file an appeal or decision review, use one of these APIs:
* [Higher-Level Reviews API](/explore/api/higher-level-reviews/docs)
* [Notice of Disagreements API](/explore/api/notice-of-disagreements/docs)
* [Supplemental Claims API](/explore/api/supplemental-claims/docs)

## Technical overview
The Legacy Appeals API pulls data from Caseflow, a case management system. It provides decision review and appeal data that can be used for submitting a Higher Level Review, Notice of Disagreement, or Supplemental Claim.

### Authorization and Access
The authentication model for the Legacy Appeals API uses OAuth 2.0/OpenID Connect. The following authorization models are supported:
* [Authorization code flow](/explore/api/legacy-appeals/authorization-code)
* [Client Credentials Grant (CCG)](/explore/api/legacy-appeals/client-credentials)

**Important:** To get production access using client credentials grant, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](/support/contact-us).

### Test data

Our sandbox environment is populated with [Veteran test data](https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts/legacy_appeals_test_accounts.md) that can be used to test various response scenarios. This sandbox data contains no PII or PHI, but mimics real Veteran account information.
