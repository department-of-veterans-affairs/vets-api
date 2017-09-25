# Betamocks 

## Setup
1. `cd` to parent directory of `vets-api` and clone `vets-api-mockdata`, 
e.g. if you checked out `vets-api` to `~/Documents` then:
```bash
cd ~/Documents
git clone git@github.com:department-of-veterans-affairs/vets-api-mockdata.git
```

2. _If using Docker skip to step #3_. Add and enable the Betamocks settings in your settings.local.yml file,
and change `cache_dir` to path of `vets-api-mockdata`.
```yaml
betamocks:
  enabled: true
  cache_dir: /path/to/vets-api-mockdata/repo
  services_config: config/betamocks/services_config.yml
```

3. Copy over the example services config YAML file 
```bash
cp config/services_config.yml.example config/services_config.yml
```



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
    faraday.response :betamocks if Betamocks.configuration.enabled
    faraday.response :snakecase, symbolize: false
    faraday.response :json
    faraday.adapter  :httpclient
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

3. Make a request. If a pre-recorded cache file exists then Betamocks will return a response
without hitting the real service. If a cache file does not exist one will be recorded (turn on your VA VPNs),
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
      :uid_locator: 'root="2.16.840.1.113883.4.1" extension="(\d{9})"' # matches 9 digits '(\d{9})' after extension=
```
