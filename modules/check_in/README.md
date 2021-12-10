## What is vets-api Check-in?

The CheckIn module is a pass through API to the CHIP API. The CHIP API is a specialized service that orchestrates the Check-in process by coordinating with the vets-api, LoROTA, VEText, and VistA services.

## Installation
Ensure the following line is in the root project's Gemfile:

`gem 'check_in', path: 'modules/check_in'`

## Documentation
Swagger documentation can be viewed by booting up the vets-api server locally and visiting
`http://localhost:3000/check_in/v0/apidocs` in your browser.

Yardoc can be viewed by running `yard doc` from within the `modules/check_in` folder and then visiting
`file:///<path_to_vets-api>/modules/check_in/doc/` in your browser.

## Development and Testing

### Conversion of params from snakeCase to camel_case
vets-api uses a middleware component [olive_branch](https://github.com/vigetlabs/olive_branch) which converts the case of incoming parameters based on the value of a HTTP header X-Key-Inflection. See here: https://github.com/department-of-veterans-affairs/vets-api#api-request-key-formatting. The middleware is configured here: https://github.com/department-of-veterans-affairs/vets-api/blob/d16d87536bf898fc750067749eb9c8ffc7737a39/config/application.rb#L74

Note that OliveBranch only transforms parameters when Content-type is application/json (https://github.com/vigetlabs/olive_branch#troubleshooting). This means that if the front-end library doesn't include that header for GET requests with no body, the query parameters will not be transformed.


## Monitoring and Error reporting
StatsD monitoring of end points is setup in the `config/initializers/statsd.rb` file. All configured metrics
for the Check-in project can be viewed in Grafana by selecting the appropriate filters.

Sentry reporting is setup in the main vets-api application and as a result the Check-in engine will report
errors to Sentry by default. If additional or custom Sentry errors and warning messages need to be reported you can
include the `SentryLogging` module in your class and call the appropriate methods.

## Configuration
Check-in is configured with Config. The default configuration is contained in the settings.yml file. To customize your setup, you can create a `config/settings.local.yml` file with configuration specific to your needs.

```
check_in:
  chip_api:
    url: CHIP API URL
    host: CHIP API host
    tmp_api_user: CHIP API user
    tmp_api_id: CHIP API ID
    mock: false
    key_path: path
    redis_session_prefix: <prefix>
    timeout: Timeout in seconds
```

## Minimal authentication

## The CheckIn module exposes two endpoints: 

- The `GET /v0/patient_check_ins/:id` route accepts a LoROTA `uuid` and returns the data which is relevant to a patient's Check-in at a given location and time.

- The `POST /v0/patient_check_ins` route accepts POST data from an upstream client with the LoROTA uuid in the request body and submits it to the relevant CHIP API endpoint. A success or fail message will be sent back to the client depending on the downstream servers response.

## Sequence and Architecture Diagrams
### Happy path sequence flow between the UI/vets-api/CHIP:
![Diagram](https://raw.githubusercontent.com/department-of-veterans-affairs/va.gov-team/master/products/health-care/checkin/engineering/Check-In-Sequence.png)

## License
This module is open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
