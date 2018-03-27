require 'faraday'
require 'date'
require 'json'

headers = {
	"Content-Type" => "application/json", 
	"Accept" => "application/json", 
	"va_eauth_csid" => "DSLogon", 
	"va_eauth_authenticationmethod" => "DSLogon", 
	"va_eauth_pnidtype" => "SSN", 
	"va_eauth_assurancelevel" => "3", 
	"va_eauth_firstName" => "Mark", 
	"va_eauth_lastName" => "Webb", 
	"va_eauth_issueinstant" => DateTime.now.iso8601, 
	"va_eauth_dodedipnid" => "1013590059", 
	"va_eauth_pid" => "13367440", 
	"va_eauth_pnid" => "796104437", 
	"va_eauth_birthdate" => "1950-10-04T00:00:00+00:00", 
	"va_eauth_authorization" => "{\"authorizationResponse\":{\"status\":\"VETERAN\",\"idType\":\"SSN\",\"id\":\"796104437\",\"edi\":\"1013590059\",\"firstName\":\"Mark\",\"lastName\":\"Webb\",\"birthDate\":\"1950-10-04T00:00:00+00:00\"}}"
}

conn = Faraday.new(
	"https://csraciapp6.evss.srarad.com/wss-form526-services-web/rest/form526/v1", ssl: { verify: false }
) do |faraday|
	faraday.adapter :httpclient
end

response = conn.get do |req|
	req.url 'ratedDisabilities'
	req.headers = headers
	req.body = {}.to_json
end

p response
puts response.status
puts response.body

