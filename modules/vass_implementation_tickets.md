# VASS Module Implementation Tickets

## Overview
This document contains all tickets for implementing the VASS (Veterans Affairs Scheduling System) module in vets-api. The VASS module enables non-authenticated, first-time users to schedule appointments with the VA, including suicide awareness and health appointments.

**Total Tickets:** 13 (9 Small, 4 Medium)

---

## Ticket 1: Create VASS Module Base Scaffolding

**Size: S**

### Summary
Create the foundational Rails Engine structure for the VASS module including gemspec, engine configuration, version file, and base module files.

### Context / Background
Following the architectural patterns from `check_in` and `travel_pay` modules, we need to establish the basic Rails Engine structure that will house all VASS functionality. This provides the isolated namespace and foundation for the module.

---

### Acceptance Criteria

* [ ] Create `modules/vass/vass.gemspec` with appropriate metadata
* [ ] Create `modules/vass/lib/vass.rb` main module file
* [ ] Create `modules/vass/lib/vass/engine.rb` with Engine configuration
* [ ] Create `modules/vass/lib/vass/version.rb` (start at 0.0.1)
* [ ] Create `modules/vass/Rakefile` with standard tasks
* [ ] Create `modules/vass/Gemfile` 
* [ ] Create `modules/vass/bin/rails` executable
* [ ] Create `modules/vass/README.md` with basic module description
* [ ] Engine configured with `isolate_namespace Vass` and `api_only = true`
* [ ] FactoryBot paths configured in engine initializer
* [ ] Documentation updated (technical + feature reference)
* [ ] Tests added/updated

---

### Technical Details

**Area(s) of Work:** Backend / Infrastructure

**Primary Files / Modules:**
* `/modules/vass/vass.gemspec`
* `/modules/vass/lib/vass/engine.rb`
* `/modules/vass/lib/vass/version.rb`
* `/modules/vass/lib/vass.rb`

**Dependencies:**
* None - foundational ticket

**Design / Assets:**
* [Check-In Module Structure](modules/check_in) - reference implementation
* [Travel Pay Module Structure](modules/travel_pay) - reference implementation

---

## Ticket 2: Create VASS Routes and Application Controller

**Size: S**

### Summary
Set up the routing structure for VASS v0 API and create the base ApplicationController with CORS support.

### Context / Background
Establish the routing foundation and base controller that all VASS controllers will inherit from. This includes CORS preflight handling for frontend integration.

---

### Acceptance Criteria

* [ ] Create `modules/vass/config/routes.rb` with namespace structure
* [ ] Create `modules/vass/app/controllers/vass/application_controller.rb`
* [ ] Configure CORS preflight handling for `/vass/v0/*` paths
* [ ] Set up v0 namespace with `defaults: { format: :json }`
* [ ] Add error handling patterns to ApplicationController
* [ ] Documentation updated
* [ ] Tests added for ApplicationController

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/config/routes.rb`
* `/modules/vass/app/controllers/vass/application_controller.rb`

**Dependencies:**
* Ticket 1 (Base scaffolding)

**Design / Assets:**
* Reference: `modules/check_in/config/routes.rb`
* Reference: `modules/check_in/app/controllers/check_in/application_controller.rb`

---

## Ticket 3: Implement Redis Client for OTC Storage

**Size: M**

### Summary
Create a Redis client service for storing and retrieving one-time codes (OTC) with TTL management for VASS authentication flow.

### Context / Background
Non-authenticated users need a secure way to verify their identity for appointment scheduling. The OTC system will generate unique codes, store them in Redis with expiration, and validate them during the appointment flow.

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/services/vass/redis_client.rb`
* [ ] Implement OTC generation (secure random tokens)
* [ ] Implement Redis storage with configurable TTL (suggest 15 minutes)
* [ ] Implement OTC retrieval and validation
* [ ] Implement OTC deletion after use
* [ ] Add namespace prefixing for Redis keys (e.g., `vass:otc:{token}`)
* [ ] Handle Redis connection errors gracefully
* [ ] Documentation updated
* [ ] Monitoring/logging added (if relevant)
* [ ] Tests added with Redis mock/stub
* [ ] Test TTL expiration behavior

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/app/services/vass/redis_client.rb`
* `/modules/vass/spec/services/vass/redis_client_spec.rb`

**Dependencies:**
* Redis service (existing infrastructure)
* Ticket 1 (Base scaffolding)

**Design / Assets:**
* Reference: `modules/check_in/app/services/check_in/map/redis_client.rb`
* Reference: `modules/check_in/app/services/v2/lorota/redis_client.rb`

---

## Ticket 4: Build VASS API Base Client and Configuration

**Size: M**

### Summary
Create the base HTTP client and configuration service for communicating with the external VASS API, including authentication handling and forward proxy support.

### Context / Background
The VASS module needs to communicate with external VASS services through a forward proxy. This ticket establishes the foundation for all VASS API calls with proper authentication, error handling, and configuration management.

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/services/vass/configuration.rb` with Settings integration
* [ ] Create `modules/vass/app/services/vass/base_client.rb` using Faraday
* [ ] Configure forward proxy URL from Settings
* [ ] Implement connection timeout and retry logic
* [ ] Create `modules/vass/app/services/vass/auth_manager.rb` for token management
* [ ] Create `modules/vass/app/services/vass/response.rb` for response handling
* [ ] Add error classes in `modules/vass/lib/vass/errors.rb`
* [ ] Documentation updated
* [ ] Monitoring/logging added (if relevant)
* [ ] Tests added with VCR or WebMock

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/app/services/vass/configuration.rb`
* `/modules/vass/app/services/vass/base_client.rb`
* `/modules/vass/app/services/vass/auth_manager.rb`
* `/modules/vass/app/services/vass/response.rb`
* `/modules/vass/lib/vass/errors.rb`

**Dependencies:**
* Service dependency: `vass_api` (external)
* Forward proxy configuration in Settings
* Ticket 1 (Base scaffolding)

**Design / Assets:**
* Reference: `modules/check_in/app/services/travel_claim/base_client.rb`
* Reference: `modules/travel_pay/app/services/travel_pay/base_client.rb`

---

## Ticket 5: Implement VASS API Client Service

**Size: M**

### Summary
Build the main VASS API client that implements specific endpoint calls for appointment scheduling, building on the base client infrastructure.

### Context / Background
With the base client established, we need to implement the specific VASS API endpoints for the appointment scheduling workflow (e.g., availability check, appointment creation, appointment retrieval).

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/services/vass/client.rb` extending BaseClient
* [ ] Implement endpoint methods based on VASS API spec (TBD with team)
* [ ] Add request/response logging with PII scrubbing
* [ ] Implement error handling and retry logic for specific error codes
* [ ] Add circuit breaker pattern if needed
* [ ] Documentation updated (technical + feature reference)
* [ ] Monitoring/logging added (if relevant)
* [ ] Tests added/updated with request/response fixtures

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/app/services/vass/client.rb`
* `/modules/vass/spec/services/vass/client_spec.rb`
* `/modules/vass/spec/fixtures/vass/` (request/response fixtures)

**Dependencies:**
* Service dependency: `vass_api`
* Ticket 4 (Base Client)

**Design / Assets:**
* [VASS API Documentation]() - TBD
* [Swagger File / API Doc]() - TBD

---

## Ticket 6: Create OTP Session Controller and Model

**Size: M**

### Summary
Implement the session creation endpoint that generates and sends OTP codes to users via VANotify, and creates a session validation endpoint.

### Context / Background
Non-authenticated users need to verify their contact information (email/SMS) before scheduling. This controller handles OTP generation, sending via VANotify, and validation.

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/controllers/vass/v0/sessions_controller.rb`
* [ ] Implement `create` action (generate OTP, send via VANotify, store in Redis)
* [ ] Implement `show` action (validate OTP code)
* [ ] Create `modules/vass/app/models/vass/session.rb` model
* [ ] Add request parameter validation and sanitization
* [ ] Rate limiting consideration for OTP generation
* [ ] Add routes to `config/routes.rb`
* [ ] Documentation updated
* [ ] Monitoring/logging added (if relevant)
* [ ] Tests added/updated

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/app/controllers/vass/v0/sessions_controller.rb`
* `/modules/vass/app/models/vass/session.rb`
* `/modules/vass/config/routes.rb`

**Dependencies:**
* Service dependency: `va_notify`
* Ticket 3 (Redis Client)
* Ticket 2 (Routes and Application Controller)

**Design / Assets:**
* Reference: `modules/check_in/app/controllers/check_in/v2/sessions_controller.rb`
* Reference: `modules/check_in/app/models/check_in/v2/session.rb`

---

## Ticket 7: Integrate VANotify Service for OTP Delivery

**Size: S**

### Summary
Create service wrapper for VANotify integration to send OTP codes via email and SMS.

### Context / Background
Users need to receive OTP codes to verify their identity. VANotify is the VA's notification service that handles email and SMS delivery. This service will format and send OTP messages.

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/services/vass/notification_service.rb`
* [ ] Implement email OTP delivery method
* [ ] Implement SMS OTP delivery method
* [ ] Use existing VANotify module/client from vets-api
* [ ] Add OTP message templates (coordinate with VANotify team)
* [ ] Handle VANotify errors gracefully
* [ ] Documentation updated
* [ ] Monitoring/logging added (if relevant)
* [ ] Tests added/updated with VANotify mocks

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/app/services/vass/notification_service.rb`
* `/modules/vass/spec/services/vass/notification_service_spec.rb`

**Dependencies:**
* Service dependency: `va_notify`
* Feature toggle: TBD (may need `vass_enabled` toggle)

**Design / Assets:**
* Reference: Existing VANotify integration in vets-api
* OTP message templates - coordinate with VANotify team

---

## Ticket 8: Create Appointments Controller and Endpoints

**Size: M**

### Summary
Implement the appointments controller with endpoints for checking availability, creating appointments, and retrieving appointment details.

### Context / Background
After OTP verification, users need to search for available appointment slots and book appointments. This controller handles the appointment workflow using the VASS API client.

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/controllers/vass/v0/appointments_controller.rb`
* [ ] Implement `index` action (list available slots)
* [ ] Implement `create` action (book appointment)
* [ ] Implement `show` action (get appointment details)
* [ ] Add session validation (verify OTP was completed)
* [ ] Add request parameter validation
* [ ] Add routes to `config/routes.rb`
* [ ] Documentation updated
* [ ] Monitoring/logging added (if relevant)
* [ ] Tests added/updated

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/app/controllers/vass/v0/appointments_controller.rb`
* `/modules/vass/config/routes.rb`

**Dependencies:**
* Ticket 5 (VASS API Client)
* Ticket 6 (Sessions Controller for auth)

**Design / Assets:**
* [VASS API Documentation]() - TBD
* [Frontend Requirements]() - TBD

---

## Ticket 9: Create Appointment Models and Serializers

**Size: S**

### Summary
Build data models and JSON serializers for appointment resources following JSON:API specification.

### Context / Background
API responses need consistent formatting. Models provide business logic and validation, while serializers transform data into the JSON:API format used by vets-api.

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/models/vass/appointment.rb`
* [ ] Create `modules/vass/app/serializers/vass/appointment_serializer.rb`
* [ ] Implement data validation in models
* [ ] Follow JSON:API specification for serializers
* [ ] Handle nested appointment data structures
* [ ] Documentation updated
* [ ] Tests added/updated

---

### Technical Details

**Area(s) of Work:** Backend

**Primary Files / Modules:**
* `/modules/vass/app/models/vass/appointment.rb`
* `/modules/vass/app/serializers/vass/appointment_serializer.rb`

**Dependencies:**
* Ticket 8 (Appointments Controller)

**Design / Assets:**
* Reference: `modules/check_in/app/serializers/check_in/v2/appointment_data_serializer.rb`
* JSON:API specification

---

## Ticket 10: Add StatsD Monitoring and Logging Configuration

**Size: S**

### Summary
Configure StatsD instrumentation for all VASS controllers and services to enable monitoring in Datadog.

### Context / Background
Following vets-api patterns, all API endpoints and external service calls need monitoring for performance tracking, error rates, and operational visibility. StatsD metrics feed into Datadog dashboards.

---

### Acceptance Criteria

* [ ] Create `modules/vass/config/initializers/statsd.rb`
* [ ] Add StatsD instrumentation to all controllers (show, create, index actions)
* [ ] Add StatsD instrumentation to VASS API client methods
* [ ] Add StatsD instrumentation to VANotify calls
* [ ] Use snake_case for service tag values (e.g., `service:vass`)
* [ ] Use key:value format for tags
* [ ] Create logger utility if needed
* [ ] Documentation updated (include Datadog dashboard link once created)
* [ ] Monitoring/logging added (if relevant)
* [ ] Tests verify StatsD calls are made

---

### Technical Details

**Area(s) of Work:** Backend / Infrastructure

**Primary Files / Modules:**
* `/modules/vass/config/initializers/statsd.rb`
* `/modules/vass/lib/vass/utils/logger.rb` (if needed)

**Dependencies:**
* All previous controller/service tickets
* StatsD infrastructure (existing)

**Design / Assets:**
* Reference: `modules/check_in/config/initializers/statsd.rb`
* [Datadog Dashboard]() - to be created

---

## Ticket 11: Create OpenAPI/Swagger Documentation

**Size: S**

### Summary
Create OpenAPI 3.0 specification documenting all VASS v0 API endpoints for developer reference and API documentation site.

### Context / Background
All vets-api modules provide OpenAPI documentation for internal and external developers. This enables auto-generated documentation and API testing tools.

---

### Acceptance Criteria

* [ ] Create `modules/vass/app/docs/vass/v0/vass.yaml` OpenAPI spec
* [ ] Document all endpoints (sessions, appointments)
* [ ] Include request/response schemas
* [ ] Include authentication flow documentation
* [ ] Add example requests and responses
* [ ] Create apidocs controller at `/vass/v0/apidocs`
* [ ] Verify documentation renders at `https://dev-api.va.gov/vass/v0/apidocs`
* [ ] Documentation updated

---

### Technical Details

**Area(s) of Work:** Backend / Documentation

**Primary Files / Modules:**
* `/modules/vass/app/docs/vass/v0/vass.yaml`
* `/modules/vass/app/controllers/vass/v0/apidocs_controller.rb`

**Dependencies:**
* All controller tickets (6, 8)

**Design / Assets:**
* [OpenAPI 3.0 Specification](https://swagger.io/specification/)
* Reference: `modules/check_in/app/docs/check_in/v2/check_in.yaml`
* [VA API Documentation Site](https://department-of-veterans-affairs.github.io/va-digital-services-platform-docs/api-reference/)

---

## Ticket 12: Create RSpec Test Infrastructure

**Size: S**

### Summary
Set up RSpec test configuration, spec_helper, and factory_bot factories for VASS module testing.

### Context / Background
Comprehensive test coverage is required. This ticket establishes the testing infrastructure that all other test specs will use.

---

### Acceptance Criteria

* [ ] Create `modules/vass/spec/spec_helper.rb` with Rails environment config
* [ ] Configure FactoryBot paths in engine
* [ ] Create `modules/vass/spec/factories/` directory
* [ ] Create factories for Session, Appointment models
* [ ] Set up VCR or WebMock for HTTP request stubbing
* [ ] Configure SimpleCov for coverage reporting
* [ ] Documentation updated
* [ ] Tests run successfully with `bundle exec rspec`

---

### Technical Details

**Area(s) of Work:** Backend / Testing

**Primary Files / Modules:**
* `/modules/vass/spec/spec_helper.rb`
* `/modules/vass/spec/factories/*.rb`

**Dependencies:**
* Ticket 1 (Base scaffolding)

**Design / Assets:**
* Reference: `modules/check_in/spec/spec_helper.rb`
* Reference: `modules/travel_pay/spec/factories/`

---

## Ticket 13: Integrate VASS Module into Main Application

**Size: S**

### Summary
Mount the VASS engine in the main vets-api application and verify routing and configuration.

### Context / Background
The VASS module needs to be registered in the main Rails application routes and loaded properly for endpoints to be accessible.

---

### Acceptance Criteria

* [ ] Add `mount Vass::Engine, at: '/vass'` to `config/routes.rb`
* [ ] Verify routes load correctly with `rails routes | grep vass`
* [ ] Add VASS settings to `config/settings.yml` (URLs, timeouts, etc.)
* [ ] Add VASS settings to environment-specific configs as needed
* [ ] Verify module loads in development/test environments
* [ ] Documentation updated (technical + feature reference)
* [ ] Tests added to verify routes are mounted

---

### Technical Details

**Area(s) of Work:** Backend / Infrastructure

**Primary Files / Modules:**
* `/config/routes.rb`
* `/config/settings.yml`
* `/config/settings/development.yml`
* `/config/settings/test.yml`

**Dependencies:**
* All previous tickets
* Feature toggle: May need `vass_enabled` in Flipper

**Design / Assets:**
* Reference: Lines 417, 435 in `config/routes.rb` (CheckIn, TravelPay mounts)

---

## Recommended Implementation Order

The following order minimizes dependencies and enables parallel work where possible:

1. **Ticket 1** - Base Scaffolding (foundational)
2. **Ticket 2** - Routes and Application Controller (foundational)
3. **Ticket 12** - Test Infrastructure (enables TDD for remaining tickets)
4. **Ticket 3** - Redis Client (auth dependency)
5. **Ticket 7** - VANotify Integration (notification dependency)
6. **Ticket 4** - VASS Base Client (API dependency)
7. **Ticket 5** - VASS API Client (builds on base client)
8. **Ticket 6** - Sessions Controller (uses Redis + VANotify)
9. **Ticket 8** - Appointments Controller (uses VASS client + sessions)
10. **Ticket 9** - Models and Serializers (supports controllers)
11. **Ticket 10** - StatsD Monitoring (once endpoints exist)
12. **Ticket 11** - OpenAPI Documentation (once endpoints finalized)
13. **Ticket 13** - Main App Integration (final integration)

---

## Summary Statistics

- **Total Tickets:** 13
- **Small (S):** 9 tickets
- **Medium (M):** 4 tickets
- **Large (L):** 0 tickets

**Estimated Timeline:**
- Small tickets: ~2-4 hours each = ~18-36 hours
- Medium tickets: ~1-3 days each = ~4-12 days
- Total estimated effort: ~2-4 weeks for sequential implementation

**Parallel Work Opportunities:**
After tickets 1-3 are complete, the following can be worked in parallel:
- Ticket 4-5 (VASS API integration)
- Ticket 7 (VANotify)
- Ticket 3 (Redis)

Once tickets 4-7 are complete:
- Ticket 6 and 8 can be worked in parallel with different developers
- Ticket 9-11 can follow once controllers are stable

---

## Additional Considerations

### Feature Toggles
Consider implementing feature toggles for gradual rollout:
- `vass_enabled` - Master toggle for VASS module
- `vass_appointments_enabled` - Toggle for appointment booking
- `vass_otp_sms_enabled` - Toggle for SMS delivery vs email-only

### Security Considerations
- Rate limiting on OTP generation to prevent abuse
- PII scrubbing in logs
- Secure token generation for OTCs
- CORS configuration for approved frontend domains

### Monitoring & Alerts
- Set up Datadog dashboard for VASS metrics
- Configure alerts for error rates, response times
- Monitor OTP delivery success rates
- Track appointment booking funnel metrics

### Documentation
- Internal technical documentation
- API documentation via OpenAPI/Swagger
- Runbook for operations team
- Integration guide for frontend team

