#!/bin/bash

# Upstream Service Connection Wizard for vets-api
# Connects local vets-api instance to upstream staging services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/upstream_service_config.rb"
DEVOPS_PATH="$(cd "$SCRIPT_DIR/../../../devops" 2>/dev/null && pwd)" || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions for clean output
extract_username_from_arn() {
  local arn="$1"
  # Extract username from ARN like 'arn:aws-us-gov:iam::123456789:user/First.Last'
  echo "$arn" | sed -n 's/.*user\/\([^/]*\)$/\1/p'
}

mask_instance_id() {
  local instance_id="$1"
  # Hash all but last 8 characters: i-########12341234
  if [[ ${#instance_id} -gt 10 ]]; then
    local prefix="${instance_id:0:2}"  # 'i-'
    local last8="${instance_id: -8}"   # last 8 chars
    local middle_count=$((${#instance_id} - 10))
    local hashes=$(printf '#%.0s' $(seq 1 $middle_count))
    echo "${prefix}${hashes}${last8}"
  else
    echo "$instance_id"  # too short to mask
  fi
}

get_process_pid() {
  local port="$1"
  # Extract just the PID from lsof output
  lsof -i :$port | tail -n +2 | awk '{print $2}' | head -1
}

USAGE=$(cat <<-END
upstream-connect.sh [OPTIONS] [SERVICE]

Connect local vets-api to upstream staging services.
Handles AWS authentication, settings sync, and port forwarding.

ARGUMENTS:
  SERVICE       Optional service name (e.g., 'appeals', 'letters')
                If not provided, will show interactive menu

OPTIONS:
  --list        List all available services
  --status      Check connection status and AWS session info
  --cleanup     Stop all background port forwarding sessions
  --dry-run     Show what would be done without making changes
  --force       Skip confirmation prompts
  -h, --help    Show this help message

EXAMPLES:
  upstream-connect.sh                    # Interactive menu
  upstream-connect.sh appeals            # Connect to Appeals service
  upstream-connect.sh letters --force    # Connect to Letters service without prompts
  upstream-connect.sh --list             # List available services
  upstream-connect.sh --status           # Check connection status
  upstream-connect.sh --cleanup          # Stop all port forwarding sessions

REQUIREMENTS:
  - devops repository cloned as sibling to vets-api
  - AWS CLI configured with appropriate credentials
  - Ruby environment for vets-api

The script will:
1. Check AWS authentication status
2. Authenticate with MFA if needed
3. Sync required settings from Parameter Store
4. Set up port forwarding tunnels to staging services
5. Display connection instructions and test URLs
END
)

# Parse command line arguments
SERVICE=""
DRY_RUN=""
FORCE=""
LIST_SERVICES=""
CHECK_STATUS=""
CLEANUP=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --list)
      LIST_SERVICES=1
      shift
      ;;
    --dry-run)
      DRY_RUN="--dry-run"
      shift
      ;;
    --force)
      FORCE="--force"
      shift
      ;;
    --status)
      CHECK_STATUS=1
      shift
      ;;
    --cleanup)
      CLEANUP=1
      shift
      ;;
    -h|--help)
      echo "$USAGE"
      exit 0
      ;;
    *)
      if [[ -z "$SERVICE" ]]; then
        SERVICE="$1"
      else
        echo -e "${RED}Error: Too many arguments${NC}"
        echo "$USAGE"
        exit 1
      fi
      shift
      ;;
  esac
done

# Helper functions
log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
  echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
  echo -e "${RED}❌${NC} $1"
}

check_requirements() {
  log_info "Checking requirements..."

  # Check Ruby script exists
  if [[ ! -f "$CONFIG_SCRIPT" ]]; then
    log_error "Configuration script not found: $CONFIG_SCRIPT"
    exit 1
  fi

  # Check devops repo exists
  if [[ ! -d "$DEVOPS_PATH" ]]; then
    log_error "devops repository not found as sibling to vets-api"
    echo "Expected location: $(dirname "$SCRIPT_DIR")/devops"
    echo ""
    echo "Please clone the devops repository:"
    echo "  cd $(dirname "$SCRIPT_DIR")"
    echo "  git clone [devops-repo-url] devops"
    exit 1
  fi

  # Check for required devops scripts
  local issue_mfa_script="$DEVOPS_PATH/utilities/issue_mfa.sh"

  if [[ ! -f "$issue_mfa_script" ]]; then
    log_error "MFA script not found: $issue_mfa_script"
    exit 1
  fi

  # Check for required tools
  if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Try: brew install jq"
    exit 1
  fi

  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install and configure AWS CLI."
    exit 1
  fi

  log_success "All requirements met"
}

get_service_list() {
  # Use Ruby script to get list of available services
  ruby "$CONFIG_SCRIPT" --list
}

show_service_menu() {
  echo ""
  echo -e "${BLUE}Available Services:${NC}"
  echo ""
  
  local services
  services=$(get_service_list)
  
  if [[ -z "$services" ]]; then
    log_error "No services configured"
    exit 1
  fi

  echo "$services"
  echo ""
  
  read -p "Select a service: " SERVICE
  
  if [[ -z "$SERVICE" ]]; then
    log_error "No service selected"
    exit 1
  fi
}

validate_service() {
  local service="$1"
  
  # Check if service exists using Ruby script
  if ! ruby "$CONFIG_SCRIPT" --validate "$service" > /dev/null 2>&1; then
    log_error "Unknown service: $service"
    echo ""
    echo "Available services:"
    get_service_list
    exit 1
  fi
}

check_aws_auth() {
  log_info "Checking AWS authentication..."
  
  # Check if session credentials exist and source them
  if [[ -f ~/.aws/session_credentials.sh ]]; then
    source ~/.aws/session_credentials.sh
  fi
  
  # Try to run a simple AWS command to check auth
  local aws_check_result
  aws_check_result=$(aws sts get-caller-identity 2>&1)
  if [[ $? -ne 0 ]]; then
    if [[ "$aws_check_result" =~ "ExpiredToken" ]] || [[ "$aws_check_result" =~ "RequestExpired" ]]; then
      log_warning "AWS session expired, need to re-authenticate"
    else
      log_warning "AWS authentication required"
    fi
    return 1
  fi
  
  # Check if session is close to expiring (within 1 hour)
  if [[ -n "$AWS_EXPIRATION_TIME" ]]; then
    current_time=$(date +%s)
    remaining_time=$((AWS_EXPIRATION_TIME - current_time))
    
    if [[ $remaining_time -lt 3600 ]]; then
      remaining_minutes=$((remaining_time / 60))
      log_warning "AWS session expires in ${remaining_minutes} minutes"
      return 1
    fi
    
    remaining_hours=$((remaining_time / 3600))
    log_success "AWS authentication valid (expires in ${remaining_hours}h)"
  else
    log_success "AWS authentication valid"
  fi
  
  return 0
}

authenticate_aws() {
  log_info "Authenticating with AWS..."
  
  local issue_mfa_script="$DEVOPS_PATH/utilities/issue_mfa.sh"
  
  if [[ -n "$DRY_RUN" ]]; then
    log_info "[DRY RUN] Would prompt for AWS username and MFA token"
    log_info "[DRY RUN] Would run: source $issue_mfa_script USERNAME MFA_TOKEN"
    return 0
  fi
  
  # Check if session credentials already exist and are still valid
  if [[ -f ~/.aws/session_credentials.sh ]]; then
    source ~/.aws/session_credentials.sh
    current_time=$(date +%s)
    
    if [[ -n "$AWS_EXPIRATION_TIME" ]] && [[ $current_time -lt $AWS_EXPIRATION_TIME ]]; then
      local remaining_hours=$(( (AWS_EXPIRATION_TIME - current_time) / 3600 ))
      log_success "Existing AWS session found (expires in ${remaining_hours}h)"
      return 0
    else
      log_warning "AWS session expired, need to re-authenticate"
    fi
  fi
  
  # Prompt for AWS username and MFA token
  echo ""
  echo -e "${BLUE}AWS MFA Authentication Required${NC}"
  echo ""
  
  read -p "AWS Username (case-sensitive): " aws_username
  if [[ -z "$aws_username" ]]; then
    log_error "AWS username is required"
    return 1
  fi
  
  read -p "MFA Token (6 digits): " mfa_token
  if [[ -z "$mfa_token" ]]; then
    log_error "MFA token is required"
    return 1
  fi
  
  # Validate MFA token format (should be 6 digits)
  if ! [[ "$mfa_token" =~ ^[0-9]{6}$ ]]; then
    log_error "MFA token must be 6 digits"
    return 1
  fi
  
  # Default to gov-cloud account (staging environment)
  local account_flag=""
  
  echo ""
  log_info "Authenticating with AWS (gov-cloud account)..."
  
  # Source the MFA script with the provided credentials
  # Note: We need to source it in the current shell to get the environment variables
  if source "$issue_mfa_script" "$aws_username" "$mfa_token" $account_flag; then
    log_success "AWS authentication successful"
    return 0
  else
    log_error "AWS authentication failed"
    echo ""
    echo "Common issues:"
    echo "- Incorrect username (case-sensitive)"
    echo "- Expired or incorrect MFA token"
    echo "- Network connectivity issues"
    echo ""
    return 1
  fi
}

sync_service_settings() {
  local service="$1"
  
  log_info "Syncing settings for service: $service"
  
  if [[ -n "$DRY_RUN" ]]; then
    log_info "[DRY RUN] Would sync settings for service: $service"
    "$SCRIPT_DIR/upstream_settings_sync.rb" --service "$service" --dry-run
  else
    # Run the dedicated Ruby script with service parameter
    # It will handle all namespaces, exclusions, and tunnel settings
    local sync_args=("--service" "$service")
    
    # Add force flag if present
    if [[ -n "$FORCE" ]]; then
      sync_args+=("--force")
    fi
    
    "$SCRIPT_DIR/upstream_settings_sync.rb" "${sync_args[@]}"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
      log_success "Settings sync complete"
    else
      log_error "Settings sync failed with exit code $exit_code"
      return 1
    fi
  fi
}

setup_mpi_identity_settings() {
  local service="$1"
  local mock_mode="$2"  # true or false
  
  log_info "Setting up MPI identity settings for service: $service (mock: $mock_mode)"
  
  local identity_settings_file="config/identity_settings/settings.local.yml"
  
  if [[ -n "$DRY_RUN" ]]; then
    log_info "[DRY RUN] Would update identity settings file: $identity_settings_file"
    if [[ "$mock_mode" == "true" ]]; then
      log_info "[DRY RUN] Would set mvi.mock = true"
    else
      log_info "[DRY RUN] Would set mvi.mock = false and mvi.url = https://localhost:4434/psim_webservice/IdMWebService"
    fi
    return 0
  fi
  
  # Create the directory if it doesn't exist
  local identity_settings_dir="config/identity_settings"
  if [[ ! -d "$identity_settings_dir" ]]; then
    log_info "Creating identity settings directory: $identity_settings_dir"
    mkdir -p "$identity_settings_dir"
  fi
  
  # Check if file exists and has mvi section
  if [[ -f "$identity_settings_file" ]] && grep -q "^mvi:" "$identity_settings_file"; then
    log_info "Updating existing MVI configuration in place"
    
    # Update mock value in place
    if grep -q "mock:" "$identity_settings_file"; then
      sed -i '' "s/mock: .*/mock: $mock_mode/" "$identity_settings_file"
    else
      # Add mock line after mvi: line
      sed -i '' "/^mvi:/a\\
  mock: $mock_mode" "$identity_settings_file"
    fi
    
    # Handle URL based on mock mode
    if [[ "$mock_mode" == "false" ]]; then
      # Add or update URL for real connection
      if grep -q "url:" "$identity_settings_file"; then
        sed -i '' "s|url: .*|url: https://localhost:4434/psim_webservice/IdMWebService|" "$identity_settings_file"
      else
        # Add URL line after mock line
        sed -i '' "/mock: $mock_mode/a\\
  url: https://localhost:4434/psim_webservice/IdMWebService" "$identity_settings_file"
      fi
    fi
    # Note: We don't remove URL when mock=true, just leave it as is
    
  else
    log_info "Creating new MVI configuration"
    # Create new file or add mvi section
    if [[ "$mock_mode" == "true" ]]; then
      cat >> "$identity_settings_file" << EOF

mvi:
  mock: true
EOF
    else
      cat >> "$identity_settings_file" << EOF

mvi:
  mock: false
  url: https://localhost:4434/psim_webservice/IdMWebService
EOF
    fi
  fi
  
  log_success "MPI identity settings configured (mock: $mock_mode)"
}

setup_port_forwarding() {
  local service="$1"
  
  log_info "Setting up port forwarding for service: $service"
  
  # Get service configuration
  local service_config
  service_config=$(ruby "$CONFIG_SCRIPT" --config "$service")
  
  # Check if service has mock_mpi flag
  local mock_mpi
  mock_mpi=$(echo "$service_config" | ruby -rjson -e '
    config = JSON.parse(STDIN.read)
    # Default to true if not specified
    puts config.has_key?("mock_mpi") ? (config["mock_mpi"] == true ? "true" : "false") : "true"
  ')
  
  # Extract ports array
  local ports
  ports=$(echo "$service_config" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["ports"].join(" ")')
  
  # Add port 4434 if mock_mpi is false (real MPI connection)
  if [[ "$mock_mpi" == "false" ]]; then
    ports="$ports 4434"
    log_info "Adding MPI port 4434 for real connection (mock_mpi: false)"
  fi
  
  if [[ -z "$ports" ]]; then
    log_warning "No ports configured for service: $service"
    return 0
  fi
  
  # Set up port forwarding for each port
  for port in $ports; do
    # Handle MPI port (4434) with special messaging
    if [[ "$port" == "4434" ]]; then
      log_info "Setting up MPI port forwarding (real connection): localhost:$port → staging:$port"
    else
      log_info "Setting up port forwarding: localhost:$port → staging:$port"
    fi
    
    if [[ -n "$DRY_RUN" ]]; then
      log_info "[DRY RUN] Would start SSM port forwarding: forward-proxy staging $port $port"
    else
      start_ssm_port_forwarding "forward-proxy" "staging" "$port" "$port"
    fi
  done
  
  # Handle MPI identity settings if mock_mpi is set (either true or false)
  if echo "$service_config" | ruby -rjson -e 'config = JSON.parse(STDIN.read); exit(config.has_key?("mock_mpi") ? 0 : 1)' 2>/dev/null; then
    if [[ "$mock_mpi" == "false" ]]; then
      setup_mpi_identity_settings "$service" "false"
    else
      setup_mpi_identity_settings "$service" "true"
    fi
  fi
  
  log_success "Port forwarding setup complete"
}

# Integrated SSM port forwarding function (based on ssm-portforwarding.sh)
start_ssm_port_forwarding() {
  local deployment_name="$1"
  local app_env="$2" 
  local local_port="$3"
  local remote_port="$4"
  local instance_id="$5"  # optional
  
  # Validate ports
  if ! [[ "${local_port}" =~ ^[0-9]+$ ]]; then
    log_error "Local port must be a number"
    return 1
  fi

  if ! [[ "${remote_port}" =~ ^[0-9]+$ ]]; then
    log_error "Remote port must be a number"
    return 1
  fi
  
  # Source AWS credentials and check authentication
  if [[ -f ~/.aws/session_credentials.sh ]]; then
    source ~/.aws/session_credentials.sh
    log_info "AWS credentials sourced (token: ${AWS_SESSION_TOKEN:0:20}...)"
  fi
  
  # Simple authentication check - just verify we can call AWS STS
  if ! aws sts get-caller-identity &>/dev/null; then
    log_error "AWS authentication invalid for SSM operations"
    log_info "Please ensure you have valid AWS session credentials"
    return 1
  fi
  
  log_info "AWS authentication verified for SSM operations"
  
  local instance_ids=()
  
  if [[ -z "${instance_id}" ]]; then
    log_info "Finding instances for deployment_name=$deployment_name app_env=$app_env"
    
    # Get instances matching the deployment and environment
    local lines
    log_info "Running AWS EC2 describe-instances query..."
    lines=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:deployment_name,Values=${deployment_name}" "Name=tag:environment,Values=${app_env}" --query 'Reservations[*].Instances[*].[InstanceId]' --output text 2>&1)
    
    if [[ $? -ne 0 ]]; then
      log_error "Failed to query EC2 instances: $lines"
      return 1
    fi
    
    # Build array of instance IDs
    for id in $lines; do
      if [[ -n "$id" && "$id" != "None" ]]; then
        instance_ids+=($(echo -n ${id} | tr -d '\r'))
      fi
    done
    
    # Create masked version for display
    local masked_instances=()
    for id in "${instance_ids[@]}"; do
      masked_instances+=("$(mask_instance_id "$id")")
    done
    log_info "Found instances: ${masked_instances[@]}"
    
    if [[ ${#instance_ids[@]} -eq 0 ]]; then
      log_error "No instances found for deployment_name=$deployment_name app_env=$app_env"
      log_info "Double-checking with detailed query..."
      aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:deployment_name,Values=${deployment_name}" "Name=tag:environment,Values=${app_env}" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`deployment_name`].Value|[0],Tags[?Key==`environment`].Value|[0]]' --output table
      return 1
    fi
    
    # Pick a random instance
    local picked=$(($RANDOM % ${#instance_ids[@]}))
    instance_id=${instance_ids[$picked]}
    local masked_selected
    masked_selected=$(mask_instance_id "$instance_id")
    log_info "Selected instance: $masked_selected"
  fi
  
  # Prepare SSM parameters
  local parameters="portNumber=${remote_port},localPortNumber=${local_port}"
  
  log_info "Starting SSM port forwarding session..."
  local masked_instance
  masked_instance=$(mask_instance_id "$instance_id")
  log_info "Instance: $masked_instance"
  log_info "Local port ${local_port} → Remote port ${remote_port}"
  
  # Check if port is already in use
  if lsof -i :$local_port > /dev/null 2>&1; then
    log_warning "Port $local_port is already in use. Attempting to continue..."
  fi
  
  # Start the SSM session in background
  log_info "Starting AWS SSM session (this will run in background)..."
  
  # Create a unique log file for this session
  local log_file="/tmp/ssm-port-forward-${local_port}-${remote_port}.log"
  
  # Start SSM session in background and capture PID
  log_info "Running: aws ssm start-session --target $masked_instance --document-name AWS-StartPortForwardingSession --parameters \"$parameters\""
  aws ssm start-session \
    --target "$instance_id" \
    --document-name AWS-StartPortForwardingSession \
    --parameters "$parameters" \
    > "$log_file" 2>&1 &
  
  local ssm_pid=$!
  
  # Give the session a moment to establish
  sleep 2
  
  # Check if the process is still running
  if ! kill -0 $ssm_pid 2>/dev/null; then
    log_error "SSM session failed to start"
    if [[ -f "$log_file" ]]; then
      echo "Error details:"
      cat "$log_file"
    fi
    return 1
  fi
  
  # Save PID for potential cleanup later
  echo "$ssm_pid" >> /tmp/upstream-connect-pids.txt
  
  log_success "SSM port forwarding started (PID: $ssm_pid)"
  log_info "Log file: $log_file"
  
  # Brief verification that port is responding
  sleep 1
  if lsof -i :$local_port > /dev/null 2>&1; then
    log_success "Port $local_port is now active"
  else
    log_warning "Port $local_port may not be ready yet (this can take a few moments)"
  fi
  
  return 0
}

show_connection_info() {
  local service="$1"
  
  log_success "Connection setup complete for service: $service"
  echo ""
  
  # Get service configuration for instructions
  local service_config
  service_config=$(ruby "$CONFIG_SCRIPT" --config "$service")
  
  # Extract and display instructions if available
  local instructions
  instructions=$(echo "$service_config" | ruby -rjson -e 'config = JSON.parse(STDIN.read); puts config["instructions"] if config["instructions"]')
  
  if [[ -n "$instructions" ]]; then
    echo -e "${BLUE}Instructions:${NC}"
    echo "$instructions"
    echo ""
  fi
  
  # Check if service has mock_mpi flag and show MPI instructions
  local mock_mpi
  mock_mpi=$(echo "$service_config" | ruby -rjson -e '
    config = JSON.parse(STDIN.read)
    # Default to true if not specified
    puts config.has_key?("mock_mpi") ? (config["mock_mpi"] == true ? "true" : "false") : "true"
  ')
  
  # Show MPI instructions if service has mock_mpi configured
  if echo "$service_config" | ruby -rjson -e 'config = JSON.parse(STDIN.read); exit(config.has_key?("mock_mpi") ? 0 : 1)' 2>/dev/null; then
    # Get MPI-specific instructions from the MPI_SERVICE configuration
    local mpi_instructions
    mpi_instructions=$(ruby "$CONFIG_SCRIPT" --mpi-instructions)
    
    if [[ -n "$mpi_instructions" ]]; then
      if [[ "$mock_mpi" == "false" ]]; then
        echo -e "${BLUE}MPI Setup Instructions (mock_mpi disabled - real connection):${NC}"
        echo "$mpi_instructions"
        echo ""
        echo -e "${YELLOW}Identity Settings:${NC}"
        echo "  MPI configuration added to: config/identity_settings/settings.local.yml"
        echo "  URL: https://localhost:4434/psim_webservice/IdMWebService"
        echo "  Mock mode: false"
      else
        echo -e "${BLUE}MPI Setup Instructions (mock_mpi enabled - mock mode):${NC}"
        echo "MPI is running in mock mode - no tunnel connection required."
        echo ""
        echo -e "${YELLOW}Identity Settings:${NC}"
        echo "  MPI configuration added to: config/identity_settings/settings.local.yml"
        echo "  Mock mode: true"
      fi
      echo ""
    fi
  fi
  
  # Show port mappings
  local ports
  ports=$(echo "$service_config" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["ports"].join(" ")')
  
  # Add port 4434 to display if mock_mpi is false (real MPI connection)
  if [[ "$mock_mpi" == "false" ]]; then
    ports="$ports 4434"
  fi
  
  if [[ -n "$ports" ]]; then
    echo -e "${BLUE}Port Mappings:${NC}"
    for port in $ports; do
      if [[ "$port" == "4434" ]]; then
        echo "  localhost:$port → staging:$port (MPI Service)"
      else
        echo "  localhost:$port → staging:$port"
      fi
    done
    echo ""
  fi
  
  # Show settings that were synced
  local settings_namespaces
  settings_namespaces=$(echo "$service_config" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["settings_namespaces"].join(" ")')
  
  if [[ -n "$settings_namespaces" ]]; then
    echo -e "${BLUE}Settings Synced:${NC}"
    for namespace in $settings_namespaces; do
      echo "  $namespace"
    done
    echo ""
  fi
  
  echo -e "${GREEN}Your vets-api instance is now connected to upstream $service services!${NC}"
  
  # Show cleanup instructions
  if [[ -f /tmp/upstream-connect-pids.txt ]] && [[ -z "$DRY_RUN" ]]; then
    echo ""
    echo -e "${YELLOW}Background Processes:${NC}"
    echo "  Port forwarding sessions are running in the background"
    echo "  To stop all sessions: $SCRIPT_DIR/upstream-connect.sh --cleanup"
    echo "  PID file: /tmp/upstream-connect-pids.txt"
  fi
}

show_status() {
  echo ""
  echo -e "${BLUE}🔍 Connection Status${NC}"
  echo ""
  
  # Check AWS session
  if [[ -f ~/.aws/session_credentials.sh ]]; then
    source ~/.aws/session_credentials.sh
    
    if [[ -n "$AWS_EXPIRATION_TIME" ]]; then
      current_time=$(date +%s)
      remaining_time=$((AWS_EXPIRATION_TIME - current_time))
      
      if [[ $remaining_time -gt 0 ]]; then
        remaining_hours=$((remaining_time / 3600))
        remaining_minutes=$(((remaining_time % 3600) / 60))
        log_success "AWS Session: Active (${remaining_hours}h ${remaining_minutes}m remaining)"
      else
        log_warning "AWS Session: Expired"
      fi
    else
      log_warning "AWS Session: Unknown expiration"
    fi
    
    # Test AWS connectivity
    if aws sts get-caller-identity > /dev/null 2>&1; then
      local aws_identity
      aws_identity=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
      local username
      username=$(extract_username_from_arn "$aws_identity")
      log_success "AWS Connectivity: OK ($username)"
    else
      log_error "AWS Connectivity: Failed"
    fi
  else
    log_warning "AWS Session: No active session found"
  fi
  
  echo ""
  
  # Check port forwarding (look for configured service ports)
  echo -e "${BLUE}Port Forwarding Status:${NC}"
  local found_tunnels=false
  
  # Get all ports used by configured services
  local all_ports=()
  local services
  services=$(ruby "$CONFIG_SCRIPT" --service-keys)
  
  for service in $services; do
    local service_config
    service_config=$(ruby "$CONFIG_SCRIPT" --config "$service" 2>/dev/null)
    if [[ -n "$service_config" ]]; then
      local ports
      ports=$(echo "$service_config" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["ports"].join(" ")' 2>/dev/null)
      for port in $ports; do
        if [[ " ${all_ports[@]} " != *" $port "* ]]; then
          all_ports+=("$port")
        fi
      done
      
      # Add port 4434 if service has mock_mpi: false
      local mock_mpi
      mock_mpi=$(echo "$service_config" | ruby -rjson -e '
        config = JSON.parse(STDIN.read)
        puts config.has_key?("mock_mpi") ? (config["mock_mpi"] == true ? "true" : "false") : "true"
      ' 2>/dev/null)
      
      if [[ "$mock_mpi" == "false" ]] && [[ " ${all_ports[@]} " != *" 4434 "* ]]; then
        all_ports+=("4434")
      fi
    fi
  done
  
  # Check each configured port
  for port in "${all_ports[@]}"; do
    if lsof -i :$port > /dev/null 2>&1; then
      local pid
      pid=$(get_process_pid "$port")
      if [[ "$port" == "4434" ]]; then
        echo "  Port $port: Active (PID $pid) - MPI Service"
      else
        echo "  Port $port: Active (PID $pid)"
      fi
      found_tunnels=true
    fi
  done
  
  if [[ "$found_tunnels" = false ]]; then
    echo "  No active port forwarding detected"
  fi
  
  echo ""
  
  # Check settings.local.yml for upstream configurations
  echo -e "${BLUE}Local Settings:${NC}"
  
  local settings_check
  settings_check=$(ruby "$CONFIG_SCRIPT" --check-settings 2>/dev/null)
  
  if [[ $? -eq 0 ]] && [[ -n "$settings_check" ]]; then
    # Parse the JSON response to show service settings status
    echo "$settings_check" | ruby -rjson -e '
      begin
        data = JSON.parse(STDIN.read)
        
        if data.key?("error")
          puts "  #{data["error"]}"
        else
          # Group by service
          services = {}
          data.each do |namespace, info|
            service = info["service"]
            services[service] ||= []
            services[service] << {
              namespace: namespace,
              present: info["present"],
              has_content: info["has_content"]
            }
          end
          
          services.each do |service, namespaces|
            service_name = service.capitalize
            all_present = namespaces.all? { |ns| ns[:present] && ns[:has_content] }
            
            if all_present
              puts "✅ #{service_name} settings: Present"
            else
              puts "  #{service_name} settings: Not found or incomplete"
            end
          end
        end
      rescue JSON::ParserError
        puts "  Error: Failed to parse settings check"
      end
    '
  else
    log_warning "Local Settings: Unable to check settings"
  fi
}

cleanup_port_forwarding() {
  echo ""
  echo -e "${BLUE}🧹 Cleaning up port forwarding sessions${NC}"
  echo ""
  
  local cleaned_count=0
  
  # Get all ports used by configured services
  local all_ports=()
  local services
  services=$(ruby "$CONFIG_SCRIPT" --service-keys)
  
  for service in $services; do
    local service_config
    service_config=$(ruby "$CONFIG_SCRIPT" --config "$service" 2>/dev/null)
    if [[ -n "$service_config" ]]; then
      local ports
      ports=$(echo "$service_config" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["ports"].join(" ")' 2>/dev/null)
      for port in $ports; do
        if [[ " ${all_ports[@]} " != *" $port "* ]]; then
          all_ports+=("$port")
        fi
      done
    fi
  done
  
  # Find and kill active session-manager processes on service ports
  for port in "${all_ports[@]}"; do
    if lsof -i :$port > /dev/null 2>&1; then
      local pid
      pid=$(lsof -i :$port | tail -n +2 | awk '{print $2}' | head -1)
      local process_name
      process_name=$(lsof -i :$port | tail -n +2 | awk '{print $1}' | head -1)
      
      if [[ -n "$pid" ]]; then
        log_info "Stopping $process_name process $pid on port $port..."
        if kill "$pid" 2>/dev/null; then
          cleaned_count=$((cleaned_count + 1))
          log_success "Process $pid stopped"
        else
          log_warning "Failed to stop process $pid (may already be stopped)"
        fi
      fi
    fi
  done
  
  # Also clean up any PIDs from the tracking file (for completeness)
  local pid_file="/tmp/upstream-connect-pids.txt"
  if [[ -f "$pid_file" ]]; then
    while read -r pid; do
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        # Only kill if it's not already handled above
        local already_handled=false
        for port in "${all_ports[@]}"; do
          if lsof -i :$port -p "$pid" > /dev/null 2>&1; then
            already_handled=true
            break
          fi
        done
        
        if [[ "$already_handled" = false ]]; then
          log_info "Stopping tracked process $pid..."
          if kill "$pid" 2>/dev/null; then
            cleaned_count=$((cleaned_count + 1))
            log_success "Process $pid stopped"
          else
            log_info "Process $pid already stopped"
          fi
        fi
      fi
    done < "$pid_file"
  fi
  
  # Remove the PID file
  rm -f "$pid_file"
  
  # Clean up log files
  local log_files_cleaned=0
  for log_file in /tmp/ssm-port-forward-*.log; do
    if [[ -f "$log_file" ]]; then
      rm -f "$log_file"
      log_files_cleaned=$((log_files_cleaned + 1))
    fi
  done
  
  echo ""
  log_success "Cleanup complete"
  echo "  Processes stopped: $cleaned_count"
  echo "  Log files cleaned: $log_files_cleaned"
  echo ""
}

# Main execution flow
main() {
  echo ""
  echo -e "${BLUE}🚀 Upstream Service Connection Wizard${NC}"
  echo ""

  # Handle list option
  if [[ -n "$LIST_SERVICES" ]]; then
    get_service_list
    exit 0
  fi

  # Handle status check option
  if [[ -n "$CHECK_STATUS" ]]; then
    show_status
    exit 0
  fi

  # Handle cleanup option
  if [[ -n "$CLEANUP" ]]; then
    cleanup_port_forwarding
    exit 0
  fi

  check_requirements

  # Get service selection
  if [[ -z "$SERVICE" ]]; then
    show_service_menu
  fi

  validate_service "$SERVICE"

  # Check AWS authentication
  if ! check_aws_auth; then
    authenticate_aws
  fi

  # Sync settings for the service
  sync_service_settings "$SERVICE"

  # Set up port forwarding
  setup_port_forwarding "$SERVICE"

  # Show connection information
  show_connection_info "$SERVICE"
}

# Run main function
main "$@"