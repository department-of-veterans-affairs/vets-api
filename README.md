# Vets.gov API [![Build Status](https://dev.vets.gov/jenkins/buildStatus/icon?job=testing/vets-api/master)](http://jenkins.vetsgov-internal/job/department-of-veterans-affairs/job/vets-api/job/master/)

This project provides common APIs for applications that live on vets.gov.

### Base Setup

**See the [native setup instructions](docs/setup/native.md) if you can't use docker**

To start, fetch this code:

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`

1. Install [Docker for Mac](https://docs.docker.com/docker-for-mac/install/). This will configure both `docker` and `docker-compose`.
1. Setup localhost certificates / keys:
   - Create a folder in your vets-api directory:  `mkdir config/certs`
   - Copy the [certificate][certificate] to `config/certs/vetsgov-localhost.crt`
   - Copy the [key][key] to `config/certs/vetsgov-localhost.key`
   - *NOTE:* If you don't have access to these keys, running the following
     commands will provide basic functionality:
   - `touch config/certs/vetsgov-localhost.crt`
   - `touch config/certs/vetsgov-localhost.key`
1. Set Sidekiq environment variables
   - `export BUNDLE_ENTERPRISE__CONTRIBSYS__COM=***`, where `***` is the Sidekiq Enterprise [license key](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Vets-API/Sidekiq%20Enterprise%20Setup.md).
   - *NOTE:* If you don't have access to Sidekiq Enterprise (not necessary for 99% of things), you can instead set: `export EXCLUDE_SIDEKIQ_ENTERPRISE=true`.
1. Run the vets-api dependencies and application
    - `make up`

The API will then be available on port 3000 of the docker host.

[certificate]: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Files_From_IDme/development-certificates/vetsgov-localhost.crt
[key]: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Files_From_IDme/development-certificates/vetsgov-localhost.key

### Configuration

Vets API is configured with [Config](https://github.com/railsconfig/config). The
default configuration is contained in [settings.yml](config/settings.yml). To
customize your setup, you can create a `config/settings.local.yml` file with
configuration specific to your needs. For example, to configure Redis and
PostgreSQL, place something like this in that file:

```yaml
database_url: postgres://pg_host:9999/custom_db

redis:
  host: redis_host
  port: 9999
```

This is also where you will place any other customizations, such as API tokens
or certificate paths.

### Optional Application Configuration

The following features require additional configuration, click for details.
- [Authentication with ID.me](/docs/setup/authentication_with_idme.md)
- [EVSS](/docs/setup/evss.md)
- [Facilities Locator](/docs/setup/facilities_locator.md)
- [My HealtheVet (MHV)](/docs/setup/mhv.md)
- [Education Benefits](/docs/setup/edu_benefits.md)
- [Master Veteran Index (MVI)](/docs/setup/mvi.md)
- [Sidekiq Enterprise](/docs/setup/sidekiq_enterprise.md)

To mock one or more of the above services see [Betamocks](/docs/setup/betamocks.md)

Vets API will still run in a limited capacity without configuring any of these
features, and will run the unit tests successfully.

## Running the App

From within the cloned repo directory, you can run this command to run
`vets-api`:

```
make up
```

You should then be able to navigate to http://localhost:3000/v0/status in your
browser and start interacting with the API. Changes to the source in your local
directory will be reflected automatically via a docker volume mount, just as
they would be when running rails directly.

### Testing Commands

- `make lint` - Run the full suite of linters on the codebase.
- `make guard` - Run the guard test server that reruns your tests after files are saved. Useful for TDD!
- `make security` - Run the suite of security scanners on the codebase.
- `make ci` - Run all build steps performed in CI.

### Troubleshooting

#### `make up` fails with a message about missing gems

```
Could not find %SOME_GEM_v0.0.1% in any of the sources
Run `bundle install` to install missing gems.
```

There is no need to run `bundle install` on your system to resolve this.
A rebuild of the `vets_api` image will update the gems. The `vets_api` docker image
installs gems when the image is built, rather than mounting them into a container when
it is run. This means that any time gems are updated in the Gemfile or Gemfile.lock,
it may be necessary to rebuild the `vets_api` image using the
following command:

- `make rebuild` - Rebuild the `vets_api` image.

## Deployment Instructions

Jenkins deploys `vets-api` upon each merge to `master`:

http://jenkins.vetsgov-internal/job/department-of-veterans-affairs/job/vets-api/job/master/

Each deploy is available here:

https://dev-api.vets.gov/v0/status

## API Request key formatting

When sending HTTP requests use the `X-Key-Inflection` request header to specify
which case your client wants to use. Valid cases are `camel`, `dash`, and
`snake`. For example if you set `X-Key-Inflection: camel` then you can use
camelCase keys in your JSON request body and you will get back data with
camelCase keys in the response body. If the header is not provided then the
server will expect snake_case keys in the request body and output snake_case in
the response.

## How to Contribute

There are many ways to contribute to this project:

**Bugs**

If you spot a bug, let us know! File a GitHub Issue for this project. When
filing an issue add the following:

- Title: Sentence that summarizes the bug concisely
- Comment:
    - The environment you experienced the bug (browser, browser version, kind of
      account any extensions enabled)
    - The exact steps you took that triggered the bug. Steps 1, 2, 3, etc.
    - The expected outcome
    - The actual outcome (include screen shot or error logs)
- Label: Apply the label `bug`

For security related bugs unfit for public viewing, email us feedback@va.gov

**Code Submissions**

This project logs all work needed and work being actively worked on via GitHub
Issues. Submissions related to these are especially appreciated, but patches and
additions outside of these are also great.

If you are working on something related to an existing GitHub Issue that already
has an assignee, talk with them first (we don't want to waste your time). If
there is no assignee, assign yourself (if you have permissions) or post a
comment stating that you're working on it.

To work on your code submission, follow [GitHub Flow](https://guides.github.com/introduction/flow/):

1. Branch or Fork
1. Commit changes
1. Submit Pull Request
1. Discuss via Pull Request
1. Pull Request gets approved or denied by core team member

If you're from the community, it may take one to two weeks to review your pull
request. Teams work in one to two week sprints, so they need time to need add it
to their time line.

## Contact

If you have a question or comment about this project, file a GitHub Issue with
your question in the Title, any context in the Comment, and add the `question`
Label.
