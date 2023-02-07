# Product Outline: Check-In

### Slack Channels

- [#check-in-experience](https://dsva.slack.com/archives/C022AC2STBM)
- [#check-in-experience-engineering](https://dsva.slack.com/archives/C02G6AB3ZRS)
- [#check-in-experience-ux](https://dsva.slack.com/archives/C02GXKL8WM6)

### Team Members - HCE

|Name|Role|Email|
|----|----|-----|
|Patrick Bateman|Product Owner/Office of the CTO|patrick.bateman@va.gov|
|Stephen Barrs|Architect/Lead|stephen.barrs@va.gov|
|Lori Pusey|Product Manager|lori.pusey@agile6.com|
|Gaurav Gupta|Senior Engineer HCE|ggupta@kindsys.us|
|Kanchana Suriyamoorthy|Senior Engineer HCE|ksuriyamoorthy@kindsys.us|

## Related Documents
* [Sketch - Editing wireframes](https://www.sketch.com/s/5331b114-280d-4ff5-8d36-ec49b1696b9e)
* [Sketch - Overall pre-check-in MVP wireframes](https://www.sketch.com/s/e79a827e-42cf-4a82-b554-874c75b5c70e)
* [Check-In Test Data Setup](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/checkin/engineering/qa/test-data-setup.md)
* [Check-In Architecture](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/checkin/engineering/README.md)
* [Research Documents](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/health-care/checkin/research)
* [Engineering Documents](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/health-care/checkin/engineering)
* [VA.gov Profile](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/identity-personalization/profile/README.md)

## Table of Contents
- [Overview](#overview)
- [Vets-API](#vets-api)
  - [Code Documentation](#code-documentation)
  - [Application Performance Monitoring](#application-performance-monitoring)
  - [Local Configuration](#local-configuration)
  - [Miscellaneous](#miscellaneous)
  - [The Check-In Module Endpoints](#the-check--in-module-endpoints)
- [Architecture and Sequence Diagrams](#architecture-and-sequence-diagrams)
- [Other Applications and Services](#other-applications-and-services)
    - [Vets Website](#vets-website)
    - [CHIP](#chip)
    - [LoROTA](#lorota)
    - [Profile Service](#profile-service)
    - [Vista](#vista)
    - [VEText](#vetext)
    - [VA.gov Profile](#vagov-profile)
    - [VA Profile](#va-profile)

## Overview
- Please [click here](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/checkin/product/product-outline.md) for a comprehensive explanation.

## Vets-API

* The Check-In module Rails engine inside the `vets-api` umbrella serves as a general purpose API, and as a service bus to the downstream LoROTA and CHIP APIs for the `vets-website`, the UI for the va.gov site
* Built with the Ruby on Rails framework
* Is the main backend service for the `vets-website`
* [Vets-API Readme](https://github.com/department-of-veterans-affairs/vets-api/#readme)

### Code Documentation
- Swagger documentation can be viewed as JSON locally by running the vets-api application server, and then visiting http://localhost:3000/check_in/v2/apidocs in a browser window. Swagger UI can be accessed via https://department-of-veterans-affairs.github.io/va-digital-services-platform-docs/api-reference/#/ and then searching for https://dev-api.va.gov/check_in/v2/apidocs in the search bar at the top of the page.

- Yardoc can be viewed by running the `yard doc` command in a terminal window from within the `modules/check_in` directory, and then visiting `file:///<path_to_vets-api>/modules/check_in/doc/` in a browser window.

### Application Performance Monitoring
- StatsD monitoring of end points is setup in the `config/initializers/statsd.rb` file. All configured metrics
for the Check-in project can be viewed in Datadog at: https://app.datadoghq.com/dashboard/tmn-f5f-e9r/check-in-vets-api?from_ts=1641496780112&to_ts=1642101580112&live=true

- Sentry reporting is setup in the main vets-api application and as a result, the Check-in engine will report
errors to Sentry automatically. If custom Sentry errors and warning messages need to be reported, you can
include the `SentryLogging` module located within the `vets-api` codebase in your relevant class and call the appropriate methods provided by the module.

- The `vets-api` logs are shipped to Grafana Loki and can be viewed at: http://grafana.vfs.va.gov/explore?orgId=1&left=%5B%22now-1h%22,%22now%22,%22Loki%20(Prod)%22,%7B%22expr%22:%22%7Bapp%3D~%5C%22vets-api-.%2B%5C%22%7D%22%7D%5D

### Local Configuration
- The Check-in module is configured using the config gem in the `vets-api` repository. The default configuration is contained in the settings.yml file under the `check_in` key. To customize your setup locally, you can create a `config/settings.local.yml` file, ignored in `.gitignore`, and override the `check_in` key/values to facilitate local development.

### Miscellaneous
- vets-api uses a middleware component [olive_branch](https://github.com/vigetlabs/olive_branch) which converts the case of incoming parameters based on the value of a HTTP header X-Key-Inflection. See here: https://github.com/department-of-veterans-affairs/vets-api#api-request-key-formatting. The middleware is configured here: https://github.com/department-of-veterans-affairs/vets-api/blob/d16d87536bf898fc750067749eb9c8ffc7737a39/config/application.rb#L74
Note that OliveBranch only transforms parameters when Content-type is application/json (https://github.com/vigetlabs/olive_branch#troubleshooting). This means that if the front-end library doesn't include that header for GET requests with no body, the query parameters will not be transformed.

### The Check-In Module Endpoints
- /check_in/application#cors_preflight
- /check_in/v0/patient_check_ins#create {:format=>:json} - deprecated
- /check_in/v0/patient_check_ins#show {:format=>:json} - deprecated
- /check_in/v1/patient_check_ins#create {:format=>:json} - deprecated
- /check_in/v1/patient_check_ins#show {:format=>:json} - deprecated
- /check_in/v1/sessions#create {:format=>:json} - deprecated
- /check_in/v1/sessions#show {:format=>:json} - deprecated
- /check_in/v2/patient_check_ins#create {:format=>:json}
- /check_in/v2/patient_check_ins#show {:format=>:json}
- /check_in/v2/sessions#create {:format=>:json}
- /check_in/v2/sessions#show {:format=>:json}
- /check_in/v2/pre_check_ins#create {:format=>:json}
- /check_in/v2/pre_check_ins#show {:format=>:json}
- /check_in/v2/apidocs#index {:format=>:json}

## Architecture and Sequence Diagrams

## Other Applications and Services

### Vets Website

* This is the application that powers the main va.gov website.
* Day of Check-In: This application is for veterans to check into their health appointments on the day of care.
* Pre-Check-In: This application is going to be filled out by veterans days before the appointment. The veteran will be able to confirm various aspects of their appointment and information.
* Built with reactJS
* Uses Vets-API as the main backend API and service bus
* [Day of Check-In Readme](https://github.com/department-of-veterans-affairs/vets-website/tree/main/src/applications/check-in/day-of#readme)
* [Pre-Check-In Readme](https://github.com/department-of-veterans-affairs/vets-website/tree/main/src/applications/check-in/pre-check-in#readme)

### CHIP

* Check-In Integration Point API.
* Provides Veterans with a unified front door experience for preparing for and checking into their clinical appointments.
* Includes, changing the process for outpatient clinical workflow that improves efficiency and decrease devices requiring publicly accessible shared surfaces that may increase the transmissions of communicable diseases like COVID-19.
* [CHIP Readme](https://github.com/department-of-veterans-affairs/chip#readme)

### LoROTA

* Low Risk One Time Authentication, or LoROTA, is a simple service that uses a unique key (UUID)passed between a user and various services to authenticate that user for certain low risk activities, like form submission.
* [LoROTA Readme](https://github.com/department-of-veterans-affairs/lorota#readme)

### Profile Service

* Provides functionality related to grouping of clinics

### VISTA

* Stands for Veterans Health Information Systems and Technology Architecture, and it's one of the VA's systems for managing veterans electronic health records.

### VEText

* VEText is an interactive mobile solution to send notifications through text messages to veterans about and around their upcoming and scheduled appointments.
* [VEText Information](https://www.va.gov/health/VEText.asp)

### VA.gov Profile

* The VA.gov profile provides a centralized place where users can see what information the VA knows about them, and where they can update that information as needed.
* Currently, the VA.gov profile supports the following information:
    * Personal information
    * Contact information
    * Military information
    * Direct deposit information
    * Notification preferences
    * Account security
    * Connected apps (managed by the Lighthouse team)
* References:
  - [VA.gov Profile](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/identity-personalization/profile/README.md)

### VA Profile
* This is a backend system that was formerly known as Vet360.
* It came about in 2018 to act as a connector between a bunch of VA backends and frontends, so that veterans could update their info in one place and it would save everywhere (or almost everywhere).
* The VA Profile team is not part of the OCTO/DEPO contracts. They are an entirely separate team that we work with, and they work with a lot of other teams.
* References:
  - [VA.gov Profile](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/identity-personalization/profile/README.md)

## License
This module is open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
