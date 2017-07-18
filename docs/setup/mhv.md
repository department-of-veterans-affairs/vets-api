## MHV Prescriptions and MHV Secure Messaging Setup

Prescription refill and secure-messaging require a working MHV (MyHealthEVet)
config.  You will need to copy the following configuration into
`config/settings.local.yml` with the appropriate values filled in.

```yaml
mhv:
  rx:
    host: ...
    app_token: ...
  sm:
    host: ...
    app_token: ...
```

The `config/settings.yml` file contains example mock endpoints. For actual
backend testing, you will need to reference the appropriate private repository.
