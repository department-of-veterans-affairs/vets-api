## Education Benefits Year to Date Report
The year to date report uses GovDelivery to send the email and S3 to upload a link to the generated csv file.
To test sending the report, set the following ENV variables within `application.yml` (see application.yml.example):
```
GOV_DELIVERY_TOKEN
REPORTS_AWS_ACCESS_KEY_ID
REPORTS_AWS_SECRET_ACCESS_KEY
REPORTS_AWS_S3_REGION
REPORTS_AWS_S3_BUCKET
```