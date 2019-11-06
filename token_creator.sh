#!/usr/bin/env bash

#
# JWT Encoder Bash Script
#

secret='L1ghth0us3B1p'

# Static header fields.
header='{
	"typ": "JWT",
	"alg": "HS256",
	"kid": "0001",
	"iss": "Bash JWT Generator"

}'

# Use jq to set the dynamic `iat` and `exp`
# fields on the header using the current time.
# `iat` is set to now, and `exp` is now + 1 second.
header=$(
	echo "${header}" | jq --arg time_str "$(date +%s)" \
	'
	($time_str | tonumber) as $time_num
	| .iat=$time_num
	| .exp=($time_num + 1)
	'
)
payload='{
  "iss": "va.gov",
  "jti": "d3cf8355-7263-4c86-b413-1f476f54253b",
  "assuranceLevel": 2,
  "birthDate": "1978-05-20",
  "correlationIds": [
    "77779102^NI^200M^USVHA^P",
    "912444689^PI^200BRLS^USVBA^A",
    "6666345^PI^200CORP^USVBA^A",
    "1105051936^NI^200DOD^USDOD^A",
    "912444689^SS"
  ],
  "email": "jane.doe@va.gov",
  "firstName": "JANE",
  "gender": "FEMALE",
  "lastName": "DOE",
  "middleName": "M",
  "prefix": "Ms",
  "suffix": "S",
  "user": "string"
}'

base64_encode()
{
	declare input=${1:-$(</dev/stdin)}
	# Use `tr` to URL encode the output from base64.
	printf '%s' "${input}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

json() {
	declare input=${1:-$(</dev/stdin)}
	printf '%s' "${input}" | jq -c .
}

hmacsha256_sign()
{
	declare input=${1:-$(</dev/stdin)}
	printf '%s' "${input}" | openssl dgst -binary -sha256 -hmac "${secret}"
}

header_base64=$(echo "${header}" | json | base64_encode)
payload_base64=$(echo "${payload}" | json | base64_encode)

header_payload=$(echo "${header_base64}.${payload_base64}")
signature=$(echo "${header_payload}" | hmacsha256_sign | base64_encode)

echo "${header_payload}.${signature}"
