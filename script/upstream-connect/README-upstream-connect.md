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
- **Settings**: `caseflow`
- **Port**: `4437`
- **Description**: Connect to Caseflow appeals system

### Benefits Claims API (Lighthouse)
- **Service Key**: `claims`
- **Settings**: `lighthouse.benefits_claims`
- **Port**: `4492`
- **Description**: Connect to VA Benefits Claims API for claims data

### Letter Generator API (Lighthouse)
- **Service Key**: `letters`
- **Settings**: `lighthouse.letters_generator`
- **Port**: `4492`
- **Description**: Connect to VA Letter Generator API for official VA letters

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

The wizard consists of two main files:

### 1. `upstream-connect.sh` (Main Script)
- Bash script that orchestrates the connection process
- Handles command-line arguments and user interaction
- Calls existing devops utilities for AWS operations
- Provides colored output and progress indicators

### 2. `upstream_service_config.rb` (Service Configuration)
- Ruby script that manages service definitions
- Returns service configuration in JSON format
- Easy to extend with new services

## Adding New Services

To add a new service, edit `script/upstream_service_config.rb` and add an entry to the `SERVICES` hash:

```ruby
'service_key' => {
  name: 'Human Readable Name',
  description: 'Brief description of the service',
  ports: [4438, 4439],                          # Ports to forward
  settings_keys: ['namespace1', 'namespace2'],  # Parameter Store namespaces
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

- **`settings_keys`**: Array of AWS Parameter Store namespaces to sync
  - Each namespace corresponds to a dotted path like `lighthouse.letters_generator`
  - Settings will be pulled from `/dsva-vagov/vets-api/staging/env_vars/{namespace}`

- **`skipped_settings`**: Array of arrays containing settings to exclude from sync
  - One array per namespace in `settings_keys`
  - Settings are specified as dot-notation paths relative to the namespace
  - For example: `[['access_token.client_id', 'access_token.path']]` will skip `namespace.access_token.client_id` and `namespace.access_token.path`

- **`tunnel_setting`**: Array of setting keys that should be mapped to localhost URLs
  - Must have one entry per port in the `ports` array
  - For example: `['url']` with port `[4492]` will set `namespace.url` to `https://localhost:4492`
  - Use empty string `['']` if no tunnel mapping needed for a port

- **`instructions`**: Multi-line text with service-specific setup and testing instructions
  - Displayed after successful connection setup
  - Should include test user and endpoint for which user has data

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
./script/upstream-connect.sh --cleanup
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