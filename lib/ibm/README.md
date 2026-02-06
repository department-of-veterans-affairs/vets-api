# IBM MMS Intake

Allows a programmatic submission of a form via JSON to the IBM MMS API.

- [IBM MMS Intake](#ibm-mms-intake)
  - [Prerequisites](#prerequisites)
  - [Configuration](#configuration)
  - [Usage Examples](#usage-examples)
  - [Testing](#testing)

## Prerequisites

For local development you need to acquire a firewall exception and signed mTLS keys from GCIO.

## Configuration

Within `config/settings.yml` there is an entry for `ibm`.
The values are stored in AWS Parameter store, and can be overridden for local development.

```yaml
ibm:
  breakers_error_threshold: 80
  host: <%= ENV['bio__ibm_mms__host'] %>
  path: <%= ENV['bio__ibm_mms__path'] %>
  use_mocks: <%= ENV['bio__ibm_mms__use_mocks'] %>
  version: <%= ENV['bio__ibm_mms__version'] %>
```

If you want to record VCR cassettes, add these settings to config/settings/test.local.yml
```yaml
ibm:
  breakers_error_threshold: 80
  host: api-dev.digitization.gcio.com
  path: "/api/validated-forms"
  use_mocks: false
  version: v1
  client_cert_path: config/certs/IBM.crt
  client_key_path: config/certs/IBM.key

```
## Usage Examples

To perform an upload of a form:

```ruby
service = Ibm::Service.new
claim = MedicalExpenseReports::SavedClaim.last
service.upload_form(claim.to_ibm.to_json.to_s, claim.guid)
```

- [medical_expense_reports/benefits_intake/submit_claim_job](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/medical_expense_reports/lib/medical_expense_reports/benefits_intake/submit_claim_job.rb)

## Testing

```bash
# Run module tests
bundle exec rspec spec/lib/ibm
```

Create a claim, submit the claim to IBM MMS using the service
