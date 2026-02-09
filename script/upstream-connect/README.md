# Upstream Service Connection Wizard

The `upstream-connect.sh` script is a wizard that simplifies connecting a local vets-api instance to upstream staging services. It handles AWS authentication, settings synchronization, and port forwarding setup.

## Overview

This wizard automates the complex process of:
1. Authenticating with AWS (including MFA)
2. Pulling required staging secrets from AWS Parameter Store
3. Setting up port forwarding tunnels to staging services through forward proxy
4. Providing connection instructions and test endpoints

## Usage

### Interactive Mode
```bash
./script/upstream-connect/upstream-connect.sh
```
Shows a menu of available services to connect to.

### Direct Service Connection
```bash
./script/upstream-connect/upstream-connect.sh appeals
```

### List Available Services
```bash
./script/upstream-connect/upstream-connect.sh --list
```

### Dry Run (See what would be done)
```bash
./script/upstream-connect/upstream-connect.sh appeals --dry-run
```

### Force Mode (Skip confirmations)
```bash
./script/upstream-connect/upstream-connect.sh letters --force
```

### Check Connection Status
```bash
./script/upstream-connect/upstream-connect.sh --status
```

### Cleanup Port Forwarding Sessions
```bash
./script/upstream-connect/upstream-connect.sh --cleanup
```

## Available Services

### Appeals (Caseflow)
- **Service Key**: `appeals`
- **Aliases**: None
- **Settings**: `caseflow`
- **Port**: `4437`
- **Description**: Connect to Caseflow appeals system

### Benefits Eligibility Platform (BEP/BGS)
- **Service Key**: `awards`
- **Aliases**: `payment_history`, `bep`, `bgs`, `dependents`
- **Settings**: `bgs`
- **Port**: `4447`
- **Description**: Connect to Benefits Eligibility Platform for awards and payment history data

### Benefits Intake API (Lighthouse)
- **Service Key**: `benefits_intake`
- **Aliases**: None
- **Settings**: `lighthouse.benefits_intake`
- **Port**: `4492`
- **Description**: Connect to VA Benefits Intake API for backup 686c submissions

### Benefits Claims API (Lighthouse)
- **Service Key**: `claims`
- **Aliases**: None
- **Settings**: `lighthouse.benefits_claims`
- **Port**: `4492`
- **Description**: Connect to VA Benefits Claims API for claims data

### Benefits Documents API (Lighthouse)
- **Service Key**: `decision_letters`
- **Aliases**: `benefits_documents`
- **Settings**: `lighthouse.benefits_documents`
- **Port**: `4492`
- **Description**: Connect to VA Benefits Documents API for decision letters and doc uploads

### Direct Deposit Management API (Lighthouse)
- **Service Key**: `direct_deposit`
- **Aliases**: None
- **Settings**: `lighthouse.direct_deposit`
- **Port**: `4492`
- **Description**: Connect to VA Direct Deposit Management API for direct deposit banking data

### Immunizations/Locations - Patient Health API (FHIR) (Lighthouse)
- **Service Key**: `immunizations`
- **Aliases**: `locations`
- **Settings**: `lighthouse_health_immunization`
- **Port**: `4492`
- **Description**: Search for an individual patients immunizations and Location information

### Patient Health API (FHIR) (Lighthouse)
- **Service Key**: `labs_and_tests`
- **Aliases**: `allergies_v0`
- **Settings**: `lighthouse.veterans_health`
- **Port**: `4492`
- **Description**: Search for an individual patients appointments, conditions, medications, observations including vital signs and lab tests, and more

### Letter Generator API (Lighthouse)
- **Service Key**: `letters`
- **Aliases**: None
- **Settings**: `lighthouse.letters_generator`
- **Port**: `4492`
- **Description**: Connect to VA Letter Generator API for official VA letters

### MPI
- **Service Key**: `user`
- **Aliases**: `mpi`
- **Settings**: `lighthouse.facilities`
- **Port**: `4492`
- **Description**: Connect to Benefits Eligibility Platform for awards and payment history data

### VA Profile
- **Service Key**: `va_profile`
- **Aliases**: `demographics`, `contact_info`, `military_personnel`, `military_service`, `phones`, `addresses`, `emails`, `preferred_name`
- **Settings**: `va_profile`
- **Port**: `4433`
- **Description**: Connect to VA Profile for user profile, contact info, and military service history data

### Vet Service History and Eligibility API (Lighthouse)
- **Service Key**: `vet_verification`
- **Aliases**: `disability_rating`
- **Settings**: `lighthouse.veteran_verification`
- **Port**: `4492`
- **Description**: Connect to Vet Service History and Eligibility API for the service history, certain enrolled benefits, and disability rating information of a veteran

## Requirements

1. **devops repository**: Must be cloned as a sibling to vets-api (only needed for MFA script)
   ```bash
   cd /path/to/vets-api
   git clone https://github.com/department-of-veterans-affairs/devops
   ```

2. **AWS CLI**: Installed and configured with appropriate credentials
   ```bash
   brew install awscli
   aws configure
   ```

3. **Ruby environment**: Working Ruby environment for vets-api

## Architecture

The wizard consists of three main files:

### 1. `upstream-connect.sh` (Main Script)
- Bash script that orchestrates the connection process
- Handles command-line arguments and user interaction
- Calls upstream_settings_sync.rb for settings synchronization
- Provides colored output and progress indicators

### 2. `upstream_service_config.rb` (Service Configuration)
- Ruby module defining available services in a static SERVICES hash
- Provides service metadata including ports, settings, and instructions
- Single source of truth for all service configurations

### 3. `upstream_settings_sync.rb` (Settings Synchronization)
- Ruby script that handles AWS Parameter Store synchronization
- Manages port forwarding setup and tunnel configuration
- Processes service-specific settings and creates localhost mappings

## Adding New Services

To add a new service, edit `script/upstream-connect/upstream_service_config.rb` and add an entry to the `SERVICES` hash:

```ruby
'service_key' => {
  name: 'Human Readable Name',
  description: 'Brief description of the service',
  ports: [4438, 4439],                          # Ports to forward
  settings_namespaces: ['namespace1', 'namespace2'],  # Settings.yml/Parameter Store namespaces
  skipped_settings: [['namespace1_key1', 'namespace1_key2'], ['namespace2_key1']],     # Settings/namespaces to skip (array per namespace)
  tunnel_setting: ['url', 'host'],          # Settings to map to localhost (one per port)
  instructions: <<~TEXT
    Service-specific instructions connecting to service and a user + endpoint to test connection
  TEXT
}
```

### Service Configuration Fields

- **`name`**: Human-readable display name for the service
  - Used in menus and output messages

- **`description`**: Brief description of what the service does
  - Displayed in service listings

- **`ports`**: Array of port numbers for port forwarding
  - Local and remote ports will use the same numbers
  - Each port creates a tunnel from `localhost:PORT` to `staging:PORT`

- **`settings_namespaces`**: Array of AWS Parameter Store namespaces to sync
  - Each namespace corresponds to a dotted path like `lighthouse.letters_generator`
  - Settings will be pulled from `/dsva-vagov/vets-api/staging/env_vars/{namespace}`

- **`skipped_settings`**: Array of arrays containing settings to exclude from sync
  - One array per namespace in `settings_namespaces`
  - Settings are specified as dot-notation paths relative to the namespace
  - For example: `[['access_token.client_id', 'access_token.path']]` will skip `namespace.access_token.client_id` and `namespace.access_token.path`

- **`tunnel_setting`**: Array of setting keys that should be mapped to localhost URLs
  - Must have one entry per port in the `ports` array
  - For example: `['url']` with port `[4492]` will set `namespace.url` to `https://localhost:4492`
  - Use empty string `['']` if no tunnel mapping needed for a port

- **`instructions`**: Multi-line text with service-specific setup and testing instructions
  - Displayed after successful connection setup
  - Should include test user and endpoint for which user has data

- **`aliases`**: Optional array of alternative names for the service
  - All aliases work identically to the main service name
  - Example: `awards` service has aliases `['payment_history', 'bep', 'bgs', 'dependents']`
  - Displayed in service listings as: `awards | payment_history | bep | bgs | dependents`

- **`mock_mpi`**: Boolean flag controlling MVI (Master Veteran Index) connection mode (optional, defaults to `true`)
  - `false`: Sets up port forwarding to the MVI service (port 4434) and configures `config/identity_settings/settings.local.yml` for real MVI connection
  - `true`: Uses mocked MVI data (default behavior)

## MVI Connection Management

Some services include `mock_mvi` configuration to control whether to use real or mock MVI data:

- **Mock Mode** (`mock_mpi: true`, default): Sets `mvi.mock: true` in identity settings
- **Real MVI Mode** (`mock_mpi: false`): 
  - Adds port 4434 forwarding to MVI service
  - Sets `mvi.mock: false` and `mvi.url: https://localhost:4434/psim_webservice/IdMWebService` in `config/identity_settings/settings.local.yml`

## Implementation Notes

### AWS Authentication
The script checks if AWS credentials are valid using `aws sts get-caller-identity`. If authentication fails or the session is expired/expiring, it will prompt for AWS username and MFA token, then use the devops MFA script to establish a new session.

Features:
- Automatic session expiration checking
- Session reuse if still valid (within 1 hour of expiration)
- Interactive prompts for username and MFA token
- Validation of MFA token format (6 digits)
- Session credentials stored in `~/.aws/session_credentials.sh`

### Settings Synchronization
Based on the existing `sync-settings` script to pull configuration from AWS Parameter Store with some modifications. Each service can specify multiple settings namespaces.

Enhanced features:
- **Tunnel Settings**: Automatically maps specified settings to localhost URLs using the configured ports
- **Skipped Settings**: Excludes specified settings from being synced (useful for local-only credentials)
- **Post-sync Processing**: Removes skipped settings and sets up tunnel mappings after initial sync

### Port Forwarding
Integrated SSM port forwarding functionality (based on the devops `ssm-portforwarding.sh` script) to establish tunnels through the forward proxy. Each service can specify multiple ports.

Features:
- Automatic instance discovery for the specified deployment and environment
- Background session management with PID tracking
- Port availability checking and validation
- Session logging for troubleshooting
- Cleanup functionality to stop all sessions

### Error Handling
- Colored output for different message types (info, success, warning, error)
- Comprehensive requirement checking
- Graceful error handling with helpful messages

## Troubleshooting

### "devops repository not found"
Ensure the devops repo is cloned as a sibling directory to vets-api:
```
/your/projects/
├── devops/
└── vets-api/
```

### "AWS authentication required" 
The script will automatically prompt for your AWS username and MFA token. If you prefer to authenticate manually:
```bash
source ../devops/utilities/issue_mfa.sh YOUR_USERNAME MFA_TOKEN
```

### "Port already in use"
Check if another process is using the required port:
```bash
lsof -i :4437
```

### Port forwarding sessions not stopping
Use the cleanup command to stop all background sessions:
```bash
./script/upstream-connect/upstream-connect.sh --cleanup
```

### Multiple port forwarding sessions
The script tracks background processes in `/tmp/upstream-connect-pids.txt` and logs in `/tmp/ssm-port-forward-*.log`

## Future Enhancements

1. **Additional Services**: Mobile endpionts depend on roughly 20 upstream services. Vets API has even more that could be used for use those devs.
2. **Service Dependencies**: Some services may depend on others being connected first

## Security Considerations

- All secrets are pulled from AWS Parameter Store (encrypted)
- Port forwarding uses secure tunnels through approved forward proxy
- Instructions emphasize using test data only (Staging)
- No secrets are stored in the local codebase