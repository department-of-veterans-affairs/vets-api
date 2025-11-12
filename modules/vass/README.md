# VASS Module

## Overview

The VASS (Veterans Affairs Scheduling System) module enables non-authenticated, first-time users to schedule appointments with the VA, including suicide awareness and health appointments.

## Features

- **One-Time Code (OTC) Authentication**: Secure verification for non-authenticated users
- **VANotify Integration**: OTP delivery via email and SMS
- **VASS API Integration**: External service integration for appointment scheduling
- **Redis Storage**: Session and OTC management
- **RESTful API**: JSON API endpoints following vets-api patterns

## Architecture

This module follows the Rails Engine pattern used throughout vets-api. It provides:

- Isolated namespace (`Vass`)
- API-only configuration
- Integration with existing vets-api infrastructure (Redis, VANotify, StatsD)
- Forward proxy support for external VASS API calls

## API Endpoints

### v0 API

- `POST /vass/v0/sessions` - Create session and send OTP
- `GET /vass/v0/sessions/:id` - Validate OTP
- `GET /vass/v0/appointments` - List available appointment slots
- `POST /vass/v0/appointments` - Book an appointment
- `GET /vass/v0/appointments/:id` - Get appointment details

## Development

### Running Tests

```bash
cd modules/vass
bundle exec rspec
```

### Local Configuration

The module requires the following settings in `config/settings.yml`:

```yaml
vass:
  url: 'https://vass-api.va.gov'
  timeout: 30
  forward_proxy_url: 'your-proxy-url'
```

## Documentation

- [OpenAPI/Swagger Documentation](/vass/v0/apidocs)
- [Implementation Tickets](../../vass_implementation_tickets.md)

## Dependencies

- **Redis**: For OTC and session storage
- **VANotify**: For OTP delivery
- **VASS API**: External appointment scheduling service

## Monitoring

All endpoints and service calls are instrumented with StatsD. Metrics are available in Datadog under the `vass` namespace.

## Support

For questions or issues, contact the VASS team.

