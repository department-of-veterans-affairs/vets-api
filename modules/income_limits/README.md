## Overview
- Income is one aspect that determine's a Veteran's eligibility for benefits from VA. An existing application allows Veterans, their caregivers, family members, and others to look up the financial thresholds based on location and number of dependents.
- Please [click here](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/income-limits-app) for a comprehensive explanation.

### Slack Channels
- [#sitewide-public-websites](https://dsva.slack.com/archives/C52CL1PKQ)

### Code Documentation
- Swagger documentation can be viewed as JSON locally by running the vets-api application server, and then visiting http://localhost:3000/income_limits/v1/apidocs in a browser window. Swagger UI can be accessed via https://department-of-veterans-affairs.github.io/va-digital-services-platform-docs/api-reference/#/ and then searching for https://dev-api.va.gov/income_limits/v1/apidocs in the search bar at the top of the page.

### Local Configuration
- The Income Limits module is configured using the config gem in the `vets-api` repository.

### The Income Limits Module Endpoints
- /income_limits/v1/limitsByZipCode/
- /income_limits/v1/validateZipCode/

### Data
To get data imported into the postgres database, SideKiq jobs have been created, one for each table in the database, for a total of 5 jobs. For more see /app/workers/income_limits. Each job pulls data down from an S3 location in a CSV format, and imports these records to postgres using ActiveRecord APIs. These jobs can be executed anytime to seed or refresh the postgres database with the CSV data.

The jobs are also scheduled to auto-run via cron on the 1st of every 3rd month, at midnight. See /config/sidekiq_scheduler.yml.

[Click here](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/income-limits-app/data) to learn more about where the Income Limits data is ultimately sourced.