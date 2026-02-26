# IBM MMS Intake

Allows a programmatic submission of a form via JSON to the IBM MMS API.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Testing](#testing)

## Prerequisites

For local development you need to acquire a firewall exception and signed mTLS keys from GCIO.

## Configuration

Within `config/settings.yml` there is an entry for `ibm`.
The values are stored in AWS Parameter store, and can be overriden for local development.

```yaml
ibm:
  breakers_error_threshold: 80
  host: <%= ENV['bio__ibm_mms__host'] %>
  path: <%= ENV['bio__ibm_mms__path'] %>
  use_mocks: <%= ENV['bio__ibm_mms__use_mocks'] %>
  version: <%= ENV['bio__ibm_mms__version'] %>
```

## Usage Examples

To perform an upload of a form:

```ruby
service = Ibm::Service.new
claim = MedicalExpenseReport::SavedClaim.last
service.upload_form(claim.to_ibm.to_json.to_s, claim.guid)
```

- [medical_expense_reports/benefits_intake/submit_claim_job](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/medical_expense_reports/lib/medical_expense_reports/benefits_intake/submit_claim_job.rb)

## Testing

```bash
# Run module tests
bundle exec rspec spec/lib/ibm
```

Create a claim, submit the claim to IBM MMS using the service
