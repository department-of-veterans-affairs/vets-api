The Appeals Status API allows you to request the statuses of all decision reviews for a Veteran, including decision reviews following the AMA process and legacy benefit appeals. The statuses are returned as read only.

To retrieve a list of a claimant’s active contestable issues or legacy appeals, use one of these APIs:
* [Appealable Issues API](https://dev-developer.va.gov/explore/api/appealable-issues/docs)
* [Legacy Appeals API](https://dev-developer.va.gov/explore/api/legacy-appeals/docs)

To file an appeal or decision review, use one of these APIs:
* [Higher-Level Reviews API](https://dev-developer.va.gov/explore/api/higher-level-reviews/docs)
* [Notice of Disagreements API](https://dev-developer.va.gov/explore/api/notice-of-disagreements/docs)
* [Supplemental Claims API](https://dev-developer.va.gov/explore/api/supplemental-claims/docs)

## Background

The Appeals API passes data through to Caseflow, a case management system. Caseflow accepts a header with the Veteran’s SSN and returns the current status of their decision reviews and/or benefits appeals.

Because this application is designed to allow third-parties to request information on behalf of a Veteran, we are not using VA Authentication Federation Infrastructure (VAAFI) headers or Single Sign On External (SSOe).

## Technical overview

### Authentication and Authorization

The authentication model for the Appeals Status API uses OAuth 2.0/OpenID Connect. The following authorization models are supported:
* [Authorization code flow](https://dev-developer.va.gov/explore/api/appeals-status/authorization-code)
* [Client Credentials Grant (CCG)](https://dev-developer.va.gov/explore/api/appeals-status/client-credentials)

**Important:** To get production access using client credentials grant, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](https://dev-developer.va.gov/support/contact-us).

### Test data

The database powering our sandbox environment is populated with [Veteran test data](https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts/benefits_test_accounts.md). This sandbox data contains no PII or PHI, but mimics real Veteran account information.
