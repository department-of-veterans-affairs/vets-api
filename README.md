# Vets API [![Build Status](http://dev.va.gov/jenkins/buildStatus/icon?job=testing/vets-api/master)](http://jenkins.vfs.va.gov/job/builds/job/vets-api/) [![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](https://www.rubydoc.info/github/department-of-veterans-affairs/vets-api) [![Maintainability](https://api.codeclimate.com/v1/badges/8576e1b71f64d9bcd3cb/maintainability)](https://codeclimate.com/github/department-of-veterans-affairs/vets-api/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/8576e1b71f64d9bcd3cb/test_coverage)](https://codeclimate.com/github/department-of-veterans-affairs/vets-api/test_coverage) [![License: CC0-1.0](https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg)](LICENSE.md)

This project provides common APIs for applications that live on VA.gov (formerly vets.gov APIs).

For frontend, see [vets-website](https://github.com/department-of-veterans-affairs/vets-website) and [vets-content](https://github.com/department-of-veterans-affairs/vagov-content) repos.

## Base setup  

**See the [native setup instructions](docs/setup/native.md) if you can't use docker**

To start, fetch this code:

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`

1. Install [Docker for Mac](https://docs.docker.com/docker-for-mac/install/). This will configure both `docker` and `docker-compose`.
1. Setup localhost certificates / keys:
   - Create a folder in your vets-api directory: `mkdir config/certs`
   - Copy the [certificate][certificate] to `config/certs/vetsgov-localhost.crt`
   - Copy the [key][key] to `config/certs/vetsgov-localhost.key`
   - *NOTE:* using `touch` to create blank cert and key files no longer works. 
   If you previously added certs in this manner replace them with the team repo certificate and key listed above.
   
   [certificate]: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Login/IDme/development-certificates/vetsgov-localhost.crt
   [key]: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Login/IDme/development-certificates/vetsgov-localhost.key

## Running the app

A Makefile provides shortcuts for interacting with the docker images. To run vets-api and its redis and postgres 
dependencies run the following command from within the repo you cloned in the above steps.

### Authentication required for enterprise.contribsys.com

```
Authentication is required for enterprise.contribsys.com.
Please supply credentials for this source. You can do this by running:
 bundle config enterprise.contribsys.com username:password
ERROR: Service 'vets-api' failed to build: The command '/bin/bash --login -c bundle install -j4' returned a non-zero code: 17
make: *** [db] Error 1
```

Sidekiq Enterprise is used for worker rate limiting and additional reliability. Most
developers can bypass the installation of Sidekiq Enterprise with

- `$ EXCLUDE_SIDEKIQ_ENTERPRISE=true make rebuild`

VA.gov Team Engineers should follow instructions [here](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Platform/Vets-API/Sidekiq%20Enterprise%20Setup.md) to install the enterprise license on their systems.

**DO NOT commit Gemfile modifications that result from local builds without sidekiq enterprise if you do not have it enabled on your development system**

Once you have the `EXCLUDE_SIDEKIQ_ENTERPRISE` set you can run the application with:
```
make up
```

You should then be able to navigate to [http://localhost:3000/v0/status](http://localhost:3000/v0/status) in your
browser and start interacting with the API. Changes to the source in your local
directory will be reflected automatically via a docker volume mount, just as
they would be when running rails directly.

The [Makefile](https://github.com/department-of-veterans-affairs/vets-api/blob/master/Makefile) has shortcuts for many common development tasks. You can still run manual [docker-compose commands](https://docs.docker.com/compose/),
but the following tasks have been aliased to speed development:

### Running tests
- `make spec` - Run the entire test suite via the docker image (alias for `rspec spec`)
- `make guard` - Run the guard test server that reruns your tests after files are saved. Useful for TDD!

### Running linters

- `make lint` - Run the full suite of linters on the codebase.
- `make security` - Run the suite of security scanners on the codebase.
- `make ci` - Run all build steps performed in CI.

### Running a rails interactive console
- `make console` - Is an alias for `rails console`, which runs an IRB like REPL in which all of the API's classes and 
environmental variables have been loaded.

### Running a bash shell
To emulate a local install's workflow where you can run `rspec`, `rake`, or `rails` commands 
directly within the vets-api docker instance you can use the `make bash` command.

```bash
$ make bash
Creating network "vetsapi_default" with the default driver
Creating vetsapi_postgres_1 ... done
Creating vetsapi_redis_1    ... done
# then run any command as you would locally e.g.
root@63aa89d76c17:/src/vets-api# rspec spec/requests/user_request_spec.rb:26
```

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

* API keys/tokens
* 3rd party service hostnames, ports, and certificates/keys.
* Betamocks settings

### Optional application configuration

The following features require additional configuration, click for details.
- [Authentication with ID.me](/docs/setup/authentication_with_idme.md)
- [EVSS](/docs/setup/evss.md)
- [Facilities Locator](/docs/setup/facilities_locator.md)
- [My HealtheVet (MHV)](/docs/setup/mhv.md)
- [Education Benefits](/docs/setup/edu_benefits.md)
- [Master Veteran Index (MVI)](/docs/setup/mvi.md)

To mock one or more of the above services see [Betamocks](/docs/setup/betamocks.md)

Vets API will still run in a limited capacity without configuring any of these
features, and will run the unit tests successfully.

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

## Deployment instructions

Jenkins deploys `vets-api` upon each merge to `master`:

http://jenkins.vfs.va.gov/job/department-of-veterans-affairs/job/vets-api/job/master/

Each deploy is available here:

https://dev-api.va.gov/v0/status

## API request key formatting

When sending HTTP requests use the `X-Key-Inflection` request header to specify
which case your client wants to use. Valid cases are `camel`, `dash`, and
`snake`. For example if you set `X-Key-Inflection: camel` then you can use
camelCase keys in your JSON request body and you will get back data with
camelCase keys in the response body. If the header is not provided then the
server will expect snake_case keys in the request body and output snake_case in
the response.

## How to contribute

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
