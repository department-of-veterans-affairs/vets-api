# CHIP
Chip stands for Check-in Integration Point

## Description
Provide Veterans with a unified front door experience for preparing for and checking into their clinical appointments. Including, changing the process for outpatient clinical workflow that improves efficiency and decrease devices requiring publicly accessible shared surfaces that may increase the transmissions of communicable diseases

## Design

Configuration and files for the CHIP service are located under `/lib/chip`

### CHIP service setup
In order for the CHIP service located here to be initialized, you will need a tenant setup. You can request these from the `vets-api` team

```
def chip_service
    settings = Settings.chip.mobile_app
    
    chip_creds = {
      tenant_id: settings.tenant_id,
      tenant_name: 'mobile_app',
      username: settings.username,
      password: settings.password
    }.freeze
    
    ::Chip::Service.new(chip_creds)
end
```

## Usage

Using the CHIP service is straightforward.

```
begin
  response = chip_service.get_demographics(patient_dfn:, station_no: params[:location_id])
rescue Chip::ServiceException
  raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error'
end
```

This calls the service, using a passed in session key (always required), and params for this particular method, `create_check_in`