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
│       ├── configuration.rb                              # Client + auth config
│       ├── auth_token_client.rb                          # OAuth2 token fetch
│       ├── payload_builder.rb                            # Form → MuleSoft payload mapper
│       └── submit_job.rb                                 # Sidekiq async job
└── spec/
```

### Authentication

- **Users**: Both authenticated and unauthenticated users can submit (skip_before_action :authenticate)
- **MuleSoft**: OAuth2 client credentials flow (client_id + client_secret → bearer token)

### Payload Mapping

The `PayloadBuilder` transforms flat frontend form fields (camelCase) into the Salesforce object/field
structure expected by MuleSoft/MDW/CaMEO. Key mappings documented in the TON Field Gap Analysis:

- **Applicant** → Personal Representative (Contact)
- **Deceased** → Claimant/Veteran (Contact, MBMS_Case_Details__c)
- **Service Periods** → Military Service (MBMS_Military_Service_Info__c)
- **Interment** → Case Details interment fields
- **Funeral Home** → Account

## Configuration

Settings in `config/settings.yml`:

```yaml
time_of_need:
  mulesoft:
    host: <MuleSoft endpoint URL>
    timeout: 600
    auth:
      token_url: <OAuth2 token endpoint>
      token_path: /oauth/token
      client_id: <from environment>
      client_secret: <from environment>
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

## JSON Schema

The form is validated against the `40-4962` schema in `vets-json-schema`.

## Testing

```bash
bundle exec rspec modules/time_of_need
```

## Status

- [x] Module scaffolding
- [x] Controller (save claim to DB + queue submission)
- [x] SavedClaim model with schema validation
- [x] JSON Schema (40-4962) in vets-json-schema
- [x] Monitor (StatsD + logging) with submission tracking
- [x] PayloadBuilder (form → MuleSoft/CaMEO field mapping)
- [x] Sidekiq SubmitJob (builds payload, calls client)
- [x] MuleSoft client + auth token client
- [x] Settings configuration
- [x] Feature flag (time_of_need_mulesoft_enabled)
- [x] Frontend form ID corrected (FORM_40_4962)
- [ ] MuleSoft endpoint URL confirmed (using placeholder)
- [ ] OAuth2 credentials provisioned
- [ ] Production deployment and testing
- [ ] Zero silent failure alerts configuration
