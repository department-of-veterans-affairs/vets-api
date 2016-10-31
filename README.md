# Vets.gov API [![Build Status](https://travis-ci.org/department-of-veterans-affairs/vets-api.svg?branch=master)](https://travis-ci.org/department-of-veterans-affairs/vets-api)

This project provides common APIs for applications that live on vets.gov. This repo is in its infancy - more information coming soon!

## Developer Setup

### Base Setup

1. Install Ruby 2.3. (It is suggested to use a Ruby version manager such as [rbenv](https://github.com/rbenv/rbenv#installation) and then to [install Ruby 2.3](https://github.com/rbenv/rbenv#installing-ruby-versions)).
*Note*: rbenv will also provide additional installation instructions in the console output. Make sure to follow those too.
1. Install Bundler to manage dependencies: `gem install bundler`
1. Install Postgres (on Mac): `brew install postgres`
1. Get the code: `git clone https://github.com/department-of-veterans-affairs/vets-api.git; git submodule init; git submodule update`
1. Install gem dependencies: `cd vets-api; bundle install`

### Database Setup
1. Start Postgres: `postgres -D /usr/local/var/postgres`
1. Create dev database: `bundle exec rake db:setup`
*Note*: This will not work until you set up the environment variables (see below).

## Application Configuration
Various ENV variables are required for the application to run. See application.yml.example

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

*Note*: If you encounter `Redis::CannotConnectError: Error connecting to Redis on localhost:6379 (Errno::ECONNREFUSED)`
this is a sign that redis is not currently running or `config/redis.yml` is not using correct host and port.

### MHV Prescriptions and MHV Secure Messaging Setup
For this app to be properly configured, you will need to specify the following environment variables:
```
MHV_HOST
MHV_APP_TOKEN
MHV_SM_HOST
MHV_SM_APP_TOKEN
```

For an example, see `application.yml.example` - these are just mock endpoints.
For actual backend testing you will need to reference the appropriate private repository.

### EVSS S3 Uploads
Uploaded disability claim documents are handled by CarrierWave and either sent to Amazon S3 or saved to disk.
To enable S3 uploads, set the following ENV variables:
```
EVSS_S3_UPLOADS
EVSS_AWS_S3_REGION
EVSS_AWS_S3_BUCKET
EVSS_AWS_ACCESS_KEY_ID
EVSS_AWS_SECRET_ACCESS_KEY
```

Note: `EVSS_S3_UPLOADS` needs to be set to the string 'true' to enable S3 uploads

### Education Benefits Year to Date Report
The year to date report uses GovDelivery to send the email and S3 to upload a link to the generated csv file.
To test sending the report, set the following ENV variables:
```
GOV_DELIVERY_TOKEN
REPORTS_AWS_ACCESS_KEY_ID
REPORTS_AWS_SECRET_ACCESS_KEY
REPORTS_AWS_S3_REGION
REPORTS_AWS_S3_BUCKET
```

### EVSS Disability Claims Setup
For this app to be properly configured, you will need to specify the following environment variables:
```
EVSS_BASE_URL
EVSS_SAMPLE_CLAIMANT_USER
```

For an example, see `application.yml.example` - these are just mock endpoints.
For actual backend testing you will need to reference the appropriate private repository.

### Facilities Locator Setup
For this app to be properly configured, you need the following environment variables:
```
VHA_MAPSERVER_URL
VHA_MAPSERVER_LAYER
```

For an example, see `application.yml.example`.

For the current maps.va.gov endpoint, you will need to add the VA internal root CA
certificate to your trusted certificates. With homebrew this is typically done by
appending the exported/downloaded certificate to `<HOMEBREW_DIR>/etc/openssl/cert.pem`.

### MVI Service
The Master Veteran Index Service retreives and updates a veterans 'golden record'.
Update the `MVI_URL` env var in config/application.yml with the value given to you
by devops or your team.
```
# config/application.yml
MVI_URL = '...'
```
Since that URL is only accessible over the VA VPN a mock service is included in the project.
To enable it set MOCK_MVI_SERVICE in config/application.yml to 'true'
```
# config/application.yml
MOCK_MVI_SERVICE = true
```
Endpoint response values can be set by copying mock_mvi_responses.yml.example to
mock_mvi_responses.yml. For the find_candidate
endpoint you can return different responses based on SSN:
```
find_candidate:
  555443333:
    birth_date: '19800101'
    edipi: '1234^NI^200DOD^USDOD^A'
    family_name: 'Smith'
    gender: 'M'
    given_names: ['John', 'William']
    icn: '1000123456V123456^NI^200M^USVHA^P'
    mhv_id: '123456^PI^200MHV^USVHA^A'
    ssn: '555443333'
    status: 'active'
  111223333:
    # another mock response hash here...
```

### Running the App
1. Start the application: `foreman start`
1. Navigate to <http://localhost:3000/v0/status> in your browser.

## Testing Commands
- `bundle exec rake lint` - Run the full suite of linters on the codebase.
- `bundle exec guard` - Runs the guard test server that reruns your tests after files are saved. Useful for TDD!
- `bundle exec rake security` - Run the suite of security scanners on the codebase.
- `bundle exec rake ci` - Run all build steps performed in Travis CI.

### Manually Testing ID.me Authentication Flow
The first endpoint, below, doesn't require authentication while the second does:
```
curl localhost:3000/v0/status
curl localhost:3000/v0/welcome
```

The callback from ID.me is configured to go to `http://localhost:3001/auth/login/callback`, which is a front-end route in production. To test just the API locally, without running the vets-website server, start the vets-api server on port 3001:
```
bundle exec rails s -p 3001
```
Curl or browse to `http://localhost:3001/v0/sessions/new`; copy and paste the ID.me URL into your browser. Create your ID.me account if you have not already done so (**Note**: creating your account on the ID.me site is separate from the api.idmelabs.com sandbox) or sign in with your username and password.

The token returned in the json response at the end of the login flow can be used as follows (You may wish to use Postman instead of curl to test within the browser):

```
curl --header "Authorization: Token token=GvmkAW231VxGHkYxyppr2QQsi1D7PStqeiJXyyja" localhost:3001/v0/sessions/current
curl --header "Authorization: Token token=GvmkAW231VxGHkYxyppr2QQsi1D7PStqeiJXyyja" localhost:3001/v0/profile
```

## Deployment Instructions

Currently, this API is not yet in production. Ansible templates and instructions for deploying are in the [devops repo](https://github.com/department-of-veterans-affairs/devops/tree/master/ansible). The `app_name` for this project is `platform-api`. After deploying, you can check that the right version was deployed with:
```
https://dev-api.vets.gov/v0/status
```

There is also a [jenkins build](https://dev.vets.gov/jenkins/job/vets_gov_deploy_all/) that will deploy all the apps in a certain environment.

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
