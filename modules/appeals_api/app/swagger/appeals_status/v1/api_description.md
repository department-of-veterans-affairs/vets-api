The Appeals Status API allows you to request the statuses of all decision reviews for a Veteran, including decision reviews following the AMA process and legacy benefit appeals. The statuses are returned as read only.

To retrieve a list of a claimant’s active contestable issues or legacy appeals, use one of these APIs:
* [Appealable Issues API](https://developer.va.gov/explore/appeals/docs/appealable_issues)
* [Legacy Appeals API](https://developer.va.gov/explore/appeals/docs/legacy_appeals)

To file an appeal or decision review, use one of these APIs:
* [Higher-Level Reviews API](https://developer.va.gov/explore/appeals/docs/higher_level_reviews)
* [Notice of Disagreements API](https://developer.va.gov/explore/appeals/docs/notice_of_disagreements)
* [Supplemental Claims API](https://developer.va.gov/explore/appeals/docs/supplemental_claims)

## Background

The Appeals API passes data through to Caseflow, a case management system. Caseflow accepts a header with the Veteran’s SSN and returns the current status of their decision reviews and/or benefits appeals.

Because this application is designed to allow third-parties to request information on behalf of a Veteran, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).

## Technical overview

### Authentication and Authorization

The authentication model for the Appeals Status API uses OAuth 2.0/OpenID Connect. The following authorization models are supported:
* [Authorization code flow](https://developer.va.gov/explore/authorization/docs/authorization-code?api=appeals)
* [Client credentials grant](https://developer.va.gov/explore/authorization/docs/client-credentials?api=appeals) (restricted access)

**Important:** To get production access using client credentials grant, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](https://developer.va.gov/support/contact-us).

### Test data

The database powering our sandbox environment is populated with [Veteran test data](https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts/benefits_test_accounts.md). This sandbox data contains no PII or PHI, but mimics real Veteran account information.
