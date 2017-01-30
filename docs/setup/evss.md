## EVSS S3 Uploads
Uploaded disability claim documents are handled by CarrierWave and either sent to Amazon S3 or saved to disk.
To enable S3 uploads, set the following ENV variables:
```
EVSS_S3_UPLOADS
EVSS_AWS_S3_REGION
EVSS_AWS_S3_BUCKET
EVSS_AWS_ACCESS_KEY_ID
EVSS_AWS_SECRET_ACCESS_KEY
```

Note: `EVSS_S3_UPLOADS` needs to be set to the string 'true' to enable S3 uploads


## EVSS Disability Claims Setup
For this app to be properly configured, you will need to specify the following environment variables:
```
EVSS_BASE_URL
EVSS_SAMPLE_CLAIMANT_USER
```

For an example, see `application.yml.example` - these are just mock endpoints.
For actual backend testing you will need to reference the appropriate private repository.
