# Betamocks

## Setup
1. `cd` to parent directory of `vets-api` and clone `vets-api-mockdata`,
e.g. if you checked out `vets-api` to `~/Documents` then:
```bash
cd ~/Documents
git clone git@github.com:department-of-veterans-affairs/vets-api-mockdata.git
```

2. If you're using Docker there is no step 2 run `make up` to start vets-api. If you're 
not on Docker set the cache dir to the relative path of the mock data repo in 
config/development.yml file, you may need to run `bin/spring stop` for the change to take effect.
```yaml
betamocks:
  enabled: true
  recording: false
  # the cache dir depends on how you run the api, run `bin/spring stop` after switching this setting
  cache_dir: ../vets-api-mockdata # via rails; e.g. bundle exec rails s or bundle exec rails c
  #cache_dir: /cache # via docker; e.g. make up or make console
  services_config: config/betamocks/services_config.yml
```

You can now login with one of the [test users](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/MVI%20Integration/reference_documents/mvi_users_s1a.csv)
without being connect to the VA VPN. By default all users have been mocked for MVI but
only M. Webb (vets.gov.user+228@gmail.com) will work for the other services unless their mock data has been added.

## Mocking a Service
1. Add the Betamocks middleware to the service to be mocked. It should
be the first response middleware listed in the connection block.
```ruby
def connection
  @conn ||= Faraday.new(base_path, ssl: ssl_options) do |faraday|
    faraday.options.timeout = DEFAULT_TIMEOUT
    faraday.use      :breakers
    faraday.use      EVSS::ErrorMiddleware
    faraday.use      Faraday::Response::RaiseError
    faraday.response :betamocks if Settings.my_service.mock # e.g. Settings.mvi.mock
    faraday.response :snakecase, symbolize: false
    faraday.response :json
  end
end
```

2. Add endpoints to be mocked to the services config file.
Each service description has a `base_uri` (pulled from Settings)
`endpoints` is an array of hashes with:
- `method:` a symbol of the http verb `:get`, `:post`, `:put`...
- `path:` the path that combined with the base_uri makes a full URI
- `file_path:` where to save the file (relative to betamocks' cache dir)
```yaml
:services:

# EVSS::PCIUAddress
- :base_uri: <%= URI(Settings.evss.url).host %>
  :endpoints:
  - :method: :get
    :path: "/wss-pciu-services-web/rest/pciuServices/v1/states"
    :file_path: "evss/pciu_address"
```

3. In config/settings.yml set betamocks recording to true:
```yaml
betamocks:
  enabled: true
  recording: true
```

4. Make a request. If a cache file does not exist one will be recorded (turn on your VA VPNs),
all subsequent requests will use the cache (feel free to turn off your VA VPNs).

## Mocking error responses
You can record an error response or edit one manually to return an error status, or you can turn errors on and off
by adding an error key to the config with an optional body. Restart rails after updating the service config:
```yaml
- :method: :get
  :path: "/wss-pciu-services-web/rest/pciuServices/v1/states"
  :file_path: "evss/pciu_address"
  :error: 400
```
```yaml
- :method: :get
  :path: "/wss-pciu-services-web/rest/pciuServices/v1/states"
  :file_path: "evss/pciu_address"
  :error: 420
  :body: '{"key": "letter.generator.error", "message": "the letter generator hamsters have fallen asleep"}'
```

## Caching mulitple responses
To record multiple responses for a URI you can add a wildcard in place of the identifier
and add a matching locator or in the case of endpoints that use header or body values for identifiers you can write
a locator that will be appended to the cache file name. `query` and `header` uid_location types
use named locators, `url` and `body` types use regular expression matchers to extract locators:

#### For query string identifiers
The below will record `/users?uuid=abc123` and `/users?uuid=efg456` to the same directory:
```yaml
:endpoints:
  - :method: :get
    :path: "/users"
    :file_path: "users/list"
    :cache_multiple_responses:
      :uid_location: query
      :uid_locator: 'uuid'
```

#### For header identifiers
The below will record all `/evss/address` responses with different identifiers in the
request headers to the same directory:
```yaml
:endpoints:
  - :method: :get
    :path: "/evss/address"
    :file_path: "evss/address"
    :cache_multiple_responses:
      :uid_location: header
      :uid_locator: 'va_eauth_pnid'
```

#### For URL identifiers
The below will record `/users/42/forms` and `/users/101/forms` to the same directory:
```yaml
:endpoints:
  - :method: :get
    :path: "/users/*/forms"
    :file_path: "users/form"
    :cache_multiple_responses:
      :uid_location: url
      :uid_locator: '\/users\/(.+)\/forms' # matches anything '(.+)' between /users and /forms
```

#### For request body identifiers
The below will record all `/mvi/find_profile` responses with different identifiers in the
XML request bodies to the same directory:
```yaml
:endpoints:
  - :method: :post
    :path: "/mvi/find_profile"
    :file_path: "mvi/profiles"
    :cache_multiple_responses:
      :uid_location: body
      :uid_locator: '(?:root="2.16.840.1.113883.4.1" )?extension="(\d{9})"(?: root="2.16.840.1.113883.4.1")?' 
      extension=
```
