# Developer Setup

In hybrid mode, you will run vets-api natively, but run Postgres and Redis in Docker. By doing so you avoid any challenges of installing these two software packages and keeping them upgraded to the appropriate version.



## Base Setup

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

## Running

Prior to EKS, ClamAV (the virus scanner) was deployed in the same process as Vets API. With EKS, ClamAV has been extracted out into it’s own service. Locally you can see the docker-compose.yml config for clamav.

**Note**: Running clamav natively, as we did in Vets API master still needs to be configured. For the time being, please run via docker:

Please set the [clamav intitalizer](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/config/initializers/clamav.rb) initializers/clamav.rb file to the following:

``` 
# ## If running hybrid
if Rails.env.development?
   ENV["CLAMD_TCP_HOST"] = "0.0.0.0"
   ENV["CLAMD_TCP_PORT"] = "33100"
 end
```

### Options
#### Option 1: Run ONLY clamav via Docker

You can either run:
`docker-compose -f docker-compose-clamav.yml up` - this will run ONLY clamav via docker

After that, follow the native instructions and run `foreman start -m all=1`

#### Option 2: Run ALL dependencies via docker (Clamav, Redis, Postgres)
`docker-compose -f docker-compose-deps.yml up` - this will run all dependencies via docker

After that, follow the native instructions and run `foreman start -m web=1 all=0`

You should then be able to navigate to http://localhost:3000/v0/status in your browser and start interacting with the API. Changes to the source in your local directory will be reflected automatically via a docker volume mount, just as they would be when running rails directly.

1. Start vets-api as per the [native running instructions](running_natively.md).

#### Option 3: Mock ClamAV
There is a third choice to "mock" a successful clamav response. If you choose this path, please set the clamav mock setting to true in [the local settings.yml](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/config/settings.yml). This will mock the clamav response in the [virus_scan code](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/lib/common/virus_scan.rb#L14-L23). 

```
clamav:
  mock: true
```

1. To start Postgres and Redis: run `docker-compose -f docker-compose-deps.yml up` in one terminal window.
2. In another terminal window, start `vets-api` as per the [native running instructions](running_natively.md).
  * Run `bin/setup` first to create the needed database tables.
3. Confirm the API is successfully running by seeing if you can visit [the local Flipper page.](http://localhost:3000/flipper/features)

