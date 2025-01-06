# Vets API
This project provides common APIs for applications that live on VA.gov (formerly vets.gov APIs).


[![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](https://www.rubydoc.info/github/department-of-veterans-affairs/vets-api)
[![License: CC0-1.0](https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg)](LICENSE.md)

[Build Status](http://jenkins.vfs.va.gov/job/builds/job/vets-api/)


[VA.gov Platform Documentation](https://depo-platform-documentation.scrollhelp.site/index.html)

[API Docs](https://department-of-veterans-affairs.github.io/va-digital-services-platform-docs/api-reference/#/)

For frontend, see [vets-website](https://github.com/department-of-veterans-affairs/vets-website) and [vets-content](https://github.com/department-of-veterans-affairs/vagov-content) repos.

## Base setup

1. Clone the `vets-api` repo:

   ```bash
   git clone https://github.com/department-of-veterans-affairs/vets-api.git
   ```

1. Setup key & cert for localhost authentication to ID.me:

   - Create a folder in your vets-api directory:

     ```bash
     mkdir config/certs
     touch config/certs/vetsgov-localhost.crt
     touch config/certs/vetsgov-localhost.key
     ```

   - Copy example configuration file:

     ```bash
     cp config/settings.local.yml.example config/settings.local.yml
     ```

   - Edit `config/settings.local.yml` to disable signed authentication requests:

     ```yaml
     # settings.local.yml
     saml:
       authn_requests_signed: false
     ```

1. If you are developing features that need Sidekiq Enterprise, you must have access to the va.gov-team-sensitive repo and [install the sidekiq enterprise license](https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/engineering/sidekiq-enterprise-setup.md)

   Sidekiq Enterprise is used for worker rate limiting and additional reliability in production and requires a license be configured on your development machine. If you do not have a license configured, the open source version of Sidekiq will be installed instead. This is not an issue unless you are specifically developing features that need Sidekiq Enterprise.

   **DO NOT commit local Gemfile modifications that remove the `sidekiq-ent` and `sidekiq-pro` gems.**

1. Developers who work with vets-api daily tend to prefer the native setup because they don't have to deal with the abstraction of docker-compose while those who would to spend less time on getting started prefer the docker setup. Docker is also useful when it's necessary to have a setup as close to production as possible. Finally, it's possible to use a hybrid setup where you run vets-api natively, but run the Postgres and Redis dependencies in docker.

   - [Native setup](docs/setup/native.md) (OSX/Ubuntu)
   - [Docker setup](docs/setup/docker.md)
   - [Hybrid setup](docs/setup/hybrid.md)
   - [Codespaces setup](docs/setup/codespaces.md)

## Running the app

- [Running natively](docs/setup/running_natively.md)
- [Running with Docker](docs/setup/running_docker.md)

## Configuration

Vets API is configured with [Config](https://github.com/railsconfig/config). The
default configuration is contained in [settings.yml](config/settings.yml). To
customize your setup, you can create a `config/settings.local.yml` file with
configuration specific to your needs. For example, to configure Redis and
PostgreSQL (PostGIS is required), place something like this in that file:

```yaml
database_url: postgis://pg_host:9999/custom_db

redis:
  host: redis_host
  port: 9999
```

This is also where you will place any other customizations, such as API tokens
or certificate paths.

Config settings that vary in value depending on the deployment environment will also need
to be set appropriately for each environment in the relevant
[devops (Private Repo)](https://github.com/department-of-veterans-affairs/devops/blob/master/ansible/deployment/config/vets-api) configurations (dev-, staging-, and prod-settings.local.yml.j2).

Some examples of configuration that will need to be added to these files are:

- API keys/tokens
- 3rd party service hostnames, ports, and certificates/keys.
- Betamocks settings

### Optional application configuration

The following features require additional configuration, click for details.

- [Education Benefits](/docs/setup/edu_benefits.md)
- [EVSS](/docs/setup/evss.md)
- [Facilities Locator](/docs/setup/facilities_locator.md)
- [Local Network Access](/docs/setup/local_network_access.md)
- [Mailers](/docs/setup/mailer.md)
- [Master Person Index (MPI)](/docs/setup/mpi.md)
- [My HealtheVet (MHV)](/docs/setup/mhv.md)
- [Virtual Machine Access](/docs/setup/virtual_machine_access.md)
- [Test User Dashboard](https://github.com/department-of-veterans-affairs/vsp-test-user-dashboard/blob/main/README.md#back-end)

To mock one or more of the above services see [Betamocks](/docs/setup/betamocks.md)

Vets API will still run in a limited capacity without configuring any of these
features, and will run the unit tests successfully.

## Deployment instructions

Jenkins deploys `vets-api` upon each merge to `master`:

http://jenkins.vfs.va.gov/job/testing/job/vets-api/job/master/

Each deploy is available here:

https://dev-api.va.gov/v0/status

Additional deployment details can be found here:

[additional deployment details](docs/deployment/information.md)

## API request key formatting

When sending HTTP requests use the `X-Key-Inflection` request header to specify
which case your client wants to use. Valid cases are `camel`, `dash`, and
`snake`. For example if you set `X-Key-Inflection: camel` then you can use
camelCase keys in your JSON request body and you will get back data with
camelCase keys in the response body. If the header is not provided then the
server will expect snake_case keys in the request body and output snake_case in
the response.

## Versions

The version of Ruby and gem dependencies (including Rails) used are defined in the included [Gemfile](https://github.com/department-of-veterans-affairs/vets-api/blob/master/Gemfile). The currently used versions of gems are maintained with Bundler and stored in the [Gemfile.lock](https://github.com/department-of-veterans-affairs/vets-api/blob/master/Gemfile.lock).

#### Version Policy

The goal is to have vets-api use supported versions of gems and Ruby, which is often the latest. However the versions are generally updated as need or availability arise. If you need a newer version of a gem, please submit a pull-request marked as `draft` with just the gem updated and passing tests.

## Not a member of the repository and want to be added?
- If you're on a VA.gov Platform team, contact your Program Manager.
- If you're on a VFS team, you must complete [Platform Orientation](https://depo-platform-documentation.scrollhelp.site/getting-started/platform-orientation) to be added to this repository. This includes completing your Platform Orientation ticket(s) in GitHub.
