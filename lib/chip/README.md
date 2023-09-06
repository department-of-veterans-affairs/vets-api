# CHIP
Chip stands for Check-in Integration Point

## Description
Provide Veterans with a unified front door experience for preparing for and checking into their clinical appointments.

## Design

Configuration and code for the CHIP service are located under `/lib/chip`. The design docs can found here: https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/checkin/engineering/full-auth-check-in/chip-design-doc.md

### CHIP service setup

Accessing CHIP endpoints requires a tenant to be setup. Reach out to [patient-check-in](https://github.com/orgs/department-of-veterans-affairs/teams/patient-check-in) team and they'll provide a tenant-id, username and password that can be used to call these endpoints. These parameters should be secured, and are tenant specific and should not be shared with other teams. You should follow best practices to store these parameters for different environments in config and/or AWS param store.

## Usage

1. Instantiate a client with authentication params:

```
def chip_service
    settings = Settings.chip.tenant_name
    
    chip_creds = {
      tenant_id: settings.tenant_id,
      tenant_name: 'my_tenant_name',
      username: settings.username,
      password: settings.password
    }.freeze
    
    ::Chip::Service.new(chip_creds)
end
```

2. Use methods to call appropriate endpoints:

```
begin
  response = chip_service.get_demographics(patient_dfn:, station_no:)
rescue Chip::ServiceException
  raise Common::Exceptions::BackendServiceException, 'MY_400_upstream_error'
end
```

Please reach out to [patient-check-in](https://github.com/orgs/department-of-veterans-affairs/teams/patient-check-in) or slack @check-in-be team for any questions.
