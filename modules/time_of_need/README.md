# Time of Need (40-4962)

## Overview

The Time of Need module handles burial scheduling requests submitted through VA.gov. It processes form data from the frontend, persists claims in the vets-api database, and submits them asynchronously to NCA's systems via MuleSoft.

### Data Flow

```
va.gov (vets-website) → vets-api → MuleSoft API → MDW (Memorials Data Warehouse) → CaMEO (Salesforce)
```

### Key Systems

| System | Description |
|--------|-------------|
| **MuleSoft** | API gateway / middleware that authenticates and routes requests |
| **MDW** | Memorials Data Warehouse — NCA's data storage layer |
| **CaMEO** | NCA's Salesforce instance for case management |

## Architecture

### Module Structure

```
modules/time_of_need/
├── app/
│   ├── controllers/time_of_need/v0/claims_controller.rb  # API endpoints
│   └── models/time_of_need/saved_claim.rb                # Claim persistence
├── config/
│   └── routes.rb                                         # Route definitions
├── lib/time_of_need/
│   ├── engine.rb                                         # Rails engine
│   ├── monitor.rb                                        # StatsD + logging
│   └── mule_soft/
│       ├── client.rb                                     # MuleSoft HTTP client
│       ├── configuration.rb                              # Client configuration
│       ├── auth_token_client.rb                          # OAuth2 token fetch
│       └── submit_job.rb                                 # Sidekiq async job
└── spec/
```

### Authentication

- **Users**: Both authenticated and unauthenticated users can submit (skip_before_action :authenticate)
- **MuleSoft**: OAuth2 client credentials flow (client_id + client_secret → bearer token)

## Configuration

Add to `config/settings.yml` (or environment-specific):

```yaml
time_of_need:
  mulesoft:
    host: <MuleSoft endpoint URL - TBD>
    timeout: 600
    auth:
      host: <OAuth2 token endpoint - TBD>
      token_path: /oauth/token
      client_id: <%= ENV['time_of_need__mulesoft__client_id'] %>
      client_secret: <%= ENV['time_of_need__mulesoft__client_secret'] %>
```

## Feature Flags

| Flag | Description |
|------|-------------|
| `time_of_need_mulesoft_enabled` | Enables async submission to MuleSoft API |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/time_of_need/v0/claims` | Create a new Time of Need claim |
| GET | `/time_of_need/v0/claims/:id` | Retrieve a claim by GUID |

## Testing

```bash
bundle exec rspec modules/time_of_need
```

## Status

- [x] Module scaffolding
- [x] Controller (save claim to DB)
- [x] SavedClaim model
- [x] Monitor (StatsD + logging)
- [x] Sidekiq job skeleton
- [x] MuleSoft client skeleton
- [ ] MuleSoft endpoint URL + payload schema (blocked on MuleSoft team)
- [ ] OAuth2 credentials (blocked on MuleSoft team)
- [ ] File attachment format (base64 vs multipart — blocked on MuleSoft team)
- [ ] Frontend wiring (submitUrl update)
- [ ] Zero silent failure alerts configuration
