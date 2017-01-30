## MHV Prescriptions and MHV Secure Messaging Setup
Prescription refill and secure-messaging require a working MHV (MyHealthEVet) config.  You will need to specify the following environment variables:
```
MHV_HOST
MHV_APP_TOKEN
MHV_SM_HOST
MHV_SM_APP_TOKEN
```

For an example, see `application.yml.example` - these are just mock endpoints.
For actual backend testing you will need to reference the appropriate private repository.