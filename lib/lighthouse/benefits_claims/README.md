# Lighthouse Benefits Claims

Standardized client for accessing the Lighthouse Benefits Claims API, providing secure access to veteran claims data, power of attorney management, and intent to file submissions.

## Overview

The Benefits Claims service provides a unified interface for:
- **Claims retrieval** with filtering and status management
- **Power of Attorney** submission and status tracking
- **Intent to File** management for disability compensation
- **5103 evidence waiver** submissions
- **JWT authentication** with client credentials flow

**External Service:** Lighthouse Benefits Claims API v2

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Testing](#testing)

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Lighthouse API Access | - | Client credentials required |
| RSA Key Pair | - | For JWT token generation |
| Veteran ICN | - | Required for all operations |

## Configuration

Configure through main application settings:

```yaml
# config/settings.yml
lighthouse:
  benefits_claims:
    host: 'https://sandbox-api.va.gov'
    timeout: 30
    use_mocks: false
    access_token:
      client_id: <%= ENV['LIGHTHOUSE_CLAIMS_CLIENT_ID'] %>
      rsa_key: <%= ENV['LIGHTHOUSE_CLAIMS_RSA_KEY_PATH'] %>
      aud_claim_url: 'https://api.va.gov'
```

**Required Environment Variables:**
- `LIGHTHOUSE_CLAIMS_CLIENT_ID` - OAuth client identifier
- `LIGHTHOUSE_CLAIMS_RSA_KEY_PATH` - Path to RSA private key

## Usage Examples

### Basic Service Usage

```ruby
# Initialize service with veteran ICN
service = BenefitsClaims::Service.new('1008596379V859838')

# Get all claims for veteran
claims = service.get_claims
claims['data'].each { |claim| puts claim['attributes']['claimType'] }

# Get specific claim
claim = service.get_claim('600442049')
puts claim['data']['attributes']['status']
```

### Power of Attorney Management

```ruby
# Check current power of attorney
poa = service.get_power_of_attorney
puts poa['data']['attributes']['representative']['name'] if poa['data'].present?

# Submit new 21-22 form
attributes = {
  serviceOrganization: {
    organizationName: 'Veterans Legal Services',
    poaCode: 'A1B'
  },
  recordConsent: true,
  consentLimits: []
}
response = service.submit2122(attributes)
```

### Intent to File

```ruby
# Get intent to file for compensation claims
itf = service.get_intent_to_file('compensation')
puts "ITF expires: #{itf['data']['attributes']['expirationDate']}"
```

### With Custom Client Credentials

```ruby
service = BenefitsClaims::Service.new('1008596379V859838')
claims = service.get_claims(
  'my-lighthouse-client-id',
  '/path/to/my/rsa-key.pem'
)
```

## API Reference

### BenefitsClaims::Service

| Method | Parameters | Description |
|--------|------------|-------------|
| `get_claims` | `lighthouse_client_id`, `lighthouse_rsa_key_path`, `options` | Retrieve all claims |
| `get_claim` | `id`, `lighthouse_client_id`, `lighthouse_rsa_key_path`, `options` | Get single claim |
| `get_power_of_attorney` | `lighthouse_client_id`, `lighthouse_rsa_key_path`, `options` | Get POA status |
| `submit2122` | `attributes`, `lighthouse_client_id`, `lighthouse_rsa_key_path`, `options` | Submit POA form |
| `get_intent_to_file` | `type`, `lighthouse_client_id`, `lighthouse_rsa_key_path`, `options` | Get ITF status |
| `submit5103` | `id`, `tracked_item_id`, `options` | Submit evidence waiver |

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `options[:params]` | Hash | Query parameters for requests |
| `options[:aud_claim_url]` | String | Override audience claim URL |
| `options[:auth_params]` | Hash | Additional auth parameters |
| `options[:generate_pdf]` | Boolean | Request PDF generation |
| `options[:asynchronous]` | Boolean | Use async submission |

## Testing

```bash
# Run service tests
bundle exec rspec spec/lib/lighthouse/benefits_claims/
```

### Test Authentication

```ruby
# Mock authentication in tests
allow_any_instance_of(Auth::ClientCredentials::Service)
  .to receive(:get_token)
  .and_return('fake_access_token')
```

### Filtering Features

The service automatically filters claims by:
- **Status filtering**: Excludes CANCELED, ERRORED, and PENDING claims
- **EP code filtering**: Configurable filtering for specific establishment codes
- **Evidence request suppression**: Hides certain tracked item types

Provides reliable access to Lighthouse Benefits Claims API with built-in authentication, filtering, and error handling for VA.gov applications.