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
