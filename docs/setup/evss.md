## EVSS S3 Uploads

Uploaded disability claim documents are handled by CarrierWave and either sent
to Amazon S3 or saved to disk. To enable S3 uploads, copy the following
configuration into `config/settings.local.yml` with the appropriate values:

```yaml
evss:
  s3:
    uploads_enabled: true
    bucket: ...
    region: ...
```

## EVSS Disability Claims Setup

For this app to be properly configured, you will need to copy the following
configuration into `config/settings.local.yml` with the appropriate URL:

```yaml
evss:
  url: ...
```

The `config/settings.yml` file contains an example mock endpoint. For actual
backend testing, you will need to reference the appropriate private repository.

## EVSS Service via Open VPN

To develop locally against the EVSS CI environment you must connect through the 'EVSS Open' VPN.
Contact your product/project manager for access.

## EVSS Letters/GIBS Mock Services

If you don't have VPN access, or would like to override the responses from EVSS for testing, you can enable the mock services for the GI Bill Status and Letters endpoints.

- In `config/settings.local.yml` set `mock_letters` and/or `mock_gi_bill_status` to `true`:
``` yaml
evss:
  mock_letters: true
  mock_gi_bill_status: true
```

- Copy the contents of `config/evss/` of `mock_letters_response.yml.example` and/or `mock_gi_bill_status_response.yml.example`
to new files without the `.example` extension:
```
cp config/evss/mock_letters_response.yml.example config/evss/mock_letters_response.yml
cp config/evss/mock_gi_bill_status_response.yml.example mock_gi_bill_status_response.yml
```
- Restart the vets-api service `bundle exec rails s`, the related evss endpoints will now use the mock data from the files above.
