#!/bin/bash

# Script to start a SSM port forwarding session to the 'forward-proxy' on an app environment

# based on a combination of devops scripts:
# https://github.com/department-of-veterans-affairs/devops/blob/master/utilities/issue_mfa.sh
# https://github.com/department-of-veterans-affairs/devops/blob/master/utilities/ssm-portforwarding.sh

USAGE=$(cat <<-END
./forward-proxy-tunnel.sh [APP_ENV] [REMOTE_PORT_ON_APP] [LOCAL_PORT]
  Establish AWS credentials, prompts for AWS_USERNAME and MFA token.
  Selects a random instance and starts an SSM port forwarding session.

  Example Usage: ./forward-proxy-tunnel.sh dev 5303 4443
END
)

if [[ $# -lt 3 ]] ; then
  echo "$USAGE"
  exit 0
fi

if [[ $1 == "-h" ]]; then
  echo "$USAGE"
  exit 0
fi

# VARIABLES

region="aws-us-gov"
mfa_device_number="008577686731"
deployment_name='forward-proxy'
instance_ids=()

app_env=$1
remote_port=$(($2 + 0))
local_port=$(($3 + 0))

read -p "AWS User name (default: ${AWS_USERNAME}): " user_name
read -p 'MFA token code: ' token_code

user_name="${user_name:-$AWS_USERNAME}"

echo "${user_name} ${token_code} ${app_env} ${remote_port} ${local_port}"

###########

unset AWS_USERNAME
unset AWS_EXPIRATION_TIME
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN

echo "Acquiring AWS session credentials ..."
aws_out="$(aws sts get-session-token --output json --serial-number arn:$region:iam::$mfa_device_number:mfa/$user_name --token-code $token_code)"
aws_expiration_time=$(($(date +%s) + (12 * 60 * 60)))
aws_id=$(echo $aws_out | jq -r .Credentials.AccessKeyId)
aws_secret=$(echo $aws_out | jq -r .Credentials.SecretAccessKey)
aws_session=$(echo $aws_out | jq -r .Credentials.SessionToken)

export AWS_USERNAME=$user_name
export AWS_EXPIRATION_TIME=$aws_expiration_time
export AWS_ACCESS_KEY_ID=$aws_id
export AWS_SECRET_ACCESS_KEY=$aws_secret
export AWS_SECURITY_TOKEN=$aws_session
export AWS_SESSION_TOKEN=$aws_session

echo
echo "AWS Session credentials saved. Will expire in 12 hours"
echo "AWS_EXPIRATION_TIME=$aws_expiration_time"
echo "AWS_ACCESS_KEY_ID=$aws_id"
echo "AWS_SECRET_ACCESS_KEY=$aws_secret"
echo "AWS_SECURITY_TOKEN=$aws_session"
echo "AWS_SESSION_TOKEN=$aws_session"
echo

# Check for valid credentials
AWS_VALID_RC=$(aws sts get-caller-identity > /dev/null 2>&1)
if [[ $AWS_VALID_RC -eq 255 ]]; then
  echo "Credentials are invalid or expired. Please run issue_mfa.sh." >&2
  exit 1
fi

# display the current instances
echo "Finding apps for $deployment_name $app_env ..."
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" "Name=tag:deployment_name,Values=${deployment_name}" "Name=tag:environment,Values=${app_env}" \
  --query 'Reservations[*].Instances[*].[[InstanceId,PrivateIpAddress,Tags[?Key == `Name`].Value][]]' \
  --output text
echo

# select a random instance automatically
lines=$(aws ec2 describe-instances \
          --filters "Name=instance-state-name,Values=running" "Name=tag:deployment_name,Values=${deployment_name}" "Name=tag:environment,Values=${app_env}" \
          --query 'Reservations[*].Instances[*].[InstanceId]' \
          --output text)
for instance in $lines; do
  instance_ids+=($(echo -n ${instance} | tr -d '\r'))
done
picked=$(($RANDOM % ${#instance_ids[@]}))

instance_id=${instance_ids[$picked]}
echo "Picked instance: ${instance_ids[$picked]}"
echo

echo "Starting port forwarding session to: ${instance_id} from local port ${local_port} to remote port ${remote_port}"

# outputs parameters as JSON
parameters="portNumber=${remote_port},localPortNumber=${local_port}"
# arguments for the start-session command
arguments="--target $instance_id --document-name AWS-StartPortForwardingSession --parameters ${parameters}"
# use eval so output is printed to stdout, also when stopping the execution of this script, will stop the session
eval "aws ssm start-session $arguments"
