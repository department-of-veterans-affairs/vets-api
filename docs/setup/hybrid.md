# Developer Setup

In hybrid mode, you'll run vets-api natively, but run Postgres and Redis in Docker. By doing so, you avoid the challenges of installing these two software packages and having to keep them upgraded to the appropriate version.

## Base Setup

Follow these steps, or alternatively use [binstubs](binstubs.md).

1. Install Docker as referenced in the [Docker setup instructions](docker.md).

1. Follow the [Native setup instructions](native.md), but skip any steps related to installing Postgres, Postgis, Redis or ClamAV. You *will* need to install the other dependencies such as pdftk.

1. Configure vets-api to point to the Docker-ized dependencies. Add the following to `config/settings.local.yml`:

```
database_url: postgis://postgres:password@localhost:54320/vets_api_development?pool=4
test_database_url: postgis://postgres:password@localhost:54320/vets_api_test?pool=4

redis:
  host: localhost
  port: 63790
  app_data:
    url: redis://localhost:63790
  sidekiq:
    url: redis://localhost:63790
```

*Note: If you have local instances of Postgres or Redis that were only for use by vets-api, you can stop them to save system resources.*

## Running Deps

1. To start Postgres and Redis: run `docker-compose -f docker-compose-deps.yml up` in one terminal window.
2. In another terminal window, start `vets-api` as per the [native running instructions](running_natively.md).
  * Run `bin/setup` first to create the needed database tables.
3. Confirm the API is successfully running by seeing if you can visit [the local Flipper page.](http://localhost:3000/flipper/features)

### Mock ClamAV

If you wish to mock ClamAV, please set the clamav mock setting to true in settings.local.yml. This will mock the clamav response in the [virus_scan code](https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/common/virus_scan.rb#L14-L23).

```
clamav:
  mock: true
```
