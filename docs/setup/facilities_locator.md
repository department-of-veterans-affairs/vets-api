### Facilities Locator Setup

For the current maps.va.gov endpoint, you will need to add the VA internal root
CA certificate to your trusted certificates. With `homebrew` this is typically
done by appending the exported/downloaded certificate to
`<HOMEBREW_DIR>/etc/openssl/cert.pem`.

#### SQL52

When running facilities sidekiq jobs, mental health phone numbers depend on
a database called SQL52 that is behind the VA network. To get around this
locally you can run your own dockerized SQL52 container locally. The following
instructions will help you run SQL52 locally:

1. `docker pull dsva/vets-api-sql52-stubbed:latest`
1. `docker run -e ACCEPT_EULA=Y -e SA_PASSWORD=password1! -p 1433:1433 -d dsva/vets-api-sql52-stubbed:latest`
1. In `config/settings.local.yml`, you will also need to set these variables

```yaml
oit_lighthouse2:
  sql52:
    hostname: localhost
    username: sql52user
    password: sql52password!
    port: 1433
    facilities_mental_health:
      database_name: SQL52
      table_name: OMHSP_PERC_Share__DOEx__FieldDataEntry_MHPhone
```

If you would like to know more about how this image was put together, please
go here: https://github.com/department-of-veterans-affairs/vets-api-sql52-stubbed-docker

