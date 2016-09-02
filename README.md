# Vets.gov API [![Build Status](https://travis-ci.org/department-of-veterans-affairs/vets-api.svg?branch=master)](https://travis-ci.org/department-of-veterans-affairs/vets-api)

This project provides common APIs for applications that live on vets.gov. This repo is in its infancy - more information coming soon!

## Developer Setup

### Base Setup

1. Install Ruby 2.3. (It is suggested to use a Ruby version manager such as [rbenv](https://github.com/rbenv/rbenv#installation) and then to [install Ruby 2.3](https://github.com/rbenv/rbenv#installing-ruby-versions)).
1. Install Bundler to manage dependencies: `gem install bundler`
1. Install Postgres (on Mac): `brew install postgres`
1. Install gem dependencies: `cd vets-api; bundle install`

### Database Setup
1. Start Postgres: `postgres -D /usr/local/var/postgres`
1. Create dev database: `bundle exec rake db:setup`

### ID.me Certificate Setup
For the ID.me SAML auth integration to work, you will need the following environment variables set:
```
CERTIFICATE_FILE
KEY_FILE
```

For an example, see `application.yml.example`
For local development, ID.me has configured their sandbox with a cert that developers can share.

1. Download the [key and certificate files](https://github.com/department-of-veterans-affairs/platform-team/tree/master/identity/certificates)
1. Set the environment variables above to point to your local copies of the files

### Redis Setup
For this app to be properly configured, you will need to specify the following environment variables:
```
REDIS_HOST
REDIS_PORT
```

For an example, see `application.yml.example`

1. Install Redis (on mac): `brew install redis`
1. Follow post install instructions
  - always have Redis running as service
  - manually launch Redis `redis-server /usr/local/etc/redis.conf`
1. Set the environment variables above according to your Redis configuration

Note: If you encounter `Redis::CannotConnectError: Error connecting to Redis on localhost:6379 (Errno::ECONNREFUSED)`
this is a sign that redis is not currently running or `config/redis.yml` is not using correct host and port.

### Running the App
1. Start the application: `bundle exec rails s`
1. Navigate to <http://localhost:3000/v0/status> in your browser.

## Testing Commands
- `bundle exec rake lint` - Run the full suite of linters on the codebase.
- `bundle exec guard` - Runs the guard test server that reruns your tests after files are saved. Useful for TDD!
- `bundle exec rake security` - Run the suite of security scanners on the codebase.
- `bundle exec rake ci` - Run all build steps performed in Travis CI.

### Manually Testing Auth Flow
The first endpoint, below, doesn't require authentication while the second does:
```
curl localhost:3000/v0/status
curl localhost:3000/v0/welcome
```
It is easiest to go through the auth flow in your browser. Curl or browse to `http://localhost:3000/v0/sessions/new`; copy and paste the ID.me URL into your browser and log in on ID.me. The token returned in the json response at the end of the login flow can be used as follows (You may wish to use Postman instead of curl to test within the browser):

```
curl --header "Authorization: Token token=GvmkAW231VxGHkYxyppr2QQsi1D7PStqeiJXyyja" localhost:3000/v0/welcome
curl --header "Authorization: Token token=GvmkAW231VxGHkYxyppr2QQsi1D7PStqeiJXyyja" localhost:3000/v0/sessions/profile
```

## Deployment Instructions

Currently, this API is only deployed to the `dev` environment. Ansible templates and instructions for deploying are in the [devops repo](https://github.com/department-of-veterans-affairs/devops/tree/master/ansible). The `app_name` for this project is `platform-api`. After deploying, you can check that the right version was deployed with:
```
https://dev.vets.gov/api/v0/status
```

## API Request key formatting

When sending HTTP requests use the `X-Key-Inflection` request header to specify which case your client wants to use. Valid cases are `camel`, `dash`, and `snake`. For example if you set `X-Key-Inflection: camel` then you can use camelCase keys in your JSON request body and you will get back data with camelCase keys in the response body. If the header is not provided then the server will expect snake_case keys in the request body and output snake_case in the response.

## How to Contribute

There are many ways to contribute to this project:

**Bugs**

If you spot a bug, let us know! File a GitHub Issue for this project. When filing an issue add the following:

- Title: Sentence that summarizes the bug concisely
- Comment:
    - The environment you experienced the bug (browser, browser version, kind of account any extensions enabled)
    - The exact steps you took that triggered the bug. Steps 1, 2, 3, etc.
    - The expected outcome
    - The actual outcome (include screen shot or error logs)
- Label: Apply the label `bug`

**Code Submissions**

This project logs all work needed and work being actively worked on via GitHub Issues. Submissions related to these are especially appreciated, but patches and additions outside of these are also great.

If you are working on something related to an existing GitHub Issue that already has an assignee, talk with them first (we don't want to waste your time). If there is no assignee, assign yourself (if you have permissions) or post a comment stating that you're working on it.

To work on your code submission, follow [GitHub Flow](https://guides.github.com/introduction/flow/):

1. Branch or Fork
1. Commit changes
1. Submit Pull Request
1. Discuss via Pull Request
1. Pull Request gets approved or denied by core team member

If you're from the community, it may take one to two weeks to review your pull request. Teams work in one to two week sprints, so they need time to need add it to their time line.

## Contact

If you have a question or comment about this project, file a GitHub Issue with your question in the Title, any context in the Comment, and add the `question` Label.
