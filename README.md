# Vets.gov API [![Build Status](https://dev.vets.gov/jenkins/buildStatus/icon?job=testing/vets-api/master)](http://jenkins.vetsgov-internal/job/department-of-veterans-affairs/job/vets-api/job/master/)

This project provides common APIs for applications that live on vets.gov.

## Developer Setup

Vets API requires:
- PostgreSQL
- Redis
- Ruby 2.3

### Base Setup

To start, fetch this code:

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`

#### Automated (OSX)

If you are developing on OSX, you can run the automated setup script. From
the `vets-api` directory, run `./bin/setup-osx && source ~/.bash_profile && cd .`

#### Alternative (OSX)

1. Install Ruby 2.3.
  - It is suggested that you use a Ruby version manager such as
    [rbenv](https://github.com/rbenv/rbenv#installation) and
    [install Ruby 2.3](https://github.com/rbenv/rbenv#installing-ruby-versions).
  - *NOTE*: rbenv will also provide additional installation instructions in the
    console output. Make sure to follow those too.
1. Install Bundler to manage dependencies
  - `gem install bundler`
1. Install Postgres and enable on startup
  - `brew install postgres`
  - `brew services start postgres`
1. Install Redis
  - `brew install redis`
  - Follow post-install instructions to enable Redis on startup. Otherwise,
    launch it manually with `brew services start redis`.
1. Install gem dependencies: `cd vets-api; bundle install`
1. Install overcommit `overcommit --install --sign`
1. Setup localhost certificates / keys
  - Create a hidden folder in your home directory:  `mkdir ~/.certs`
  - Copy the [certificate][certificate] to `~/.certs/vetsgov-localhost.crt`
  - Copy the [key][key] to `~/.certs/vetsgov-localhost.key`
  - *NOTE*: If you don't have access to these keys, running the following
    commands will provide basic functionality, such as for running unit tests:
  - `touch ~/.certs/vetsgov-localhost.crt`
  - `touch ~/.certs/vetsgov-localhost.key`
1. Create dev database: `bundle exec rake db:setup`


[certificate]: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Identity%20Discovery%202016/certificates/vetsgov-localhost.crt
[key]: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Identity%20Discovery%202016/certificates/vetsgov-localhost.key

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

Vets API will still run in a limited capacity without configuring any of these
features, and will run the unit tests successfully.

## Running the App

From within the cloned repo directory, you can run this command to run
`vets-api`:

```
bundle exec rails server
```

You can also run `vets-api` with Foreman:

```
bundle exec foreman start
```

You should then be able to navigate to http://localhost:3000/v0/status in your
browser and start interacting with the API.

### Testing Commands

- `bundle exec rake lint` - Run the full suite of linters on the codebase.
- `bundle exec guard` - Runs the guard test server that reruns your tests after
  files are saved. Useful for TDD!
- `bundle exec rake security` - Run the suite of security scanners on the codebase.
- `bundle exec rake ci` - Run all build steps performed in CI.

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
