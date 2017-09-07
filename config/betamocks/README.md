# Betamocks 

## Setup
1. Add and enable the Betamocks settings in your settings.local.yml file:
```yaml
betamocks_enabled: true
betamocks_cache_path: /config/betamocks/local_cache
```

2. Copy over the example services config YAML file 
```bash
cp config/services_config.yml.example config/services_config.yml
```

3. _Skip this step if a friendly neighborhood back-end dev has created a service description for you_...
Add endpoints to be mocked to the services config file. 
Each service description has
an array of `base_uris` for each environment to be mocked (e.g. local/CI, dev/INT, staging/PINT).
`endpoints` is an array of hashes with:
- `method:` a symbol of the http verb :get, :post, :put...
- `path:` the path that combined with the base_uri makes a full URI
- `file_path:` where to save the file (relative to betamocks' cache dir)
```yaml
:services:

# EVSS::PCIUAddress
- :base_uris:
  - csraciapp6.evss.srarad.com
  :endpoints:
  - :method: :get
    :path: "/wss-pciu-services-web/rest/pciuServices/v1/states"
    :file_path: "evss/pciu_address"
```

4. Make a request. If a pre-recorded cache file exists then Betamocks will return a response
without hitting the real service. If a cache file does not exist one will be recorded (turn on your VA VPNs),
all subsequent requests will use the cache (feel free to turn off your VA VPNs).

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
    :file_path: "users"
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
    :file_path: "address"
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
    :file_path: "forms"
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
