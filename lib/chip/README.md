# CHIP
Chip stands for Check-in Integration Point

## Description
Provide Veterans with a unified front door experience for preparing for and checking into their clinical appointments. Including, changing the process for outpatient clinical workflow that improves efficiency and decrease devices requiring publicly accessible shared surfaces that may increase the transmissions of communicable diseases

## Design

### CHIP settings and setup
CHIP settings are stored at `config/settings.local.yml` under `chip_api_v2`. Initialize your setup using a client (or custom built) session key

```
check_in_session = CheckIn::V2::Session.build(data: { uuid: params[:id] }, jwt: low_auth_token)
```

## Usage

If using the pre-created CHIP service, which is highly suggested unless you have special use cases, calling the service is straightforward:

```
::V2::Chip::Service.build(check_in: check_in_session, params: permitted_params).create_check_in
```

This calls the service, using a passed in session key (always required), and params for this particular method, `create_check_in`