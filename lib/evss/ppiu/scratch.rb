require 'faraday'
require 'date'
require 'json'

headers = {
	"Content-Type" => "application/json",
	"Accept" => "application/json",
	"va_eauth_csid" => "DSLogon",
	"va_eauth_authenticationmethod" => "DSLogon",
  "va_eauth_authenticationauthority" => "eauth",
	"va_eauth_assurancelevel" => "2",
	"va_eauth_firstName" => "Jane",
	"va_eauth_lastName" => "Doe",
	"va_eauth_issueinstant" => "2015-04-17T14:52:48Z",
	"va_eauth_dodedipnid" => "1026070453",
	"va_eauth_pnidtype" => "SSN",
	"va_eauth_pnid" => "123456789",
  "va_eauth_authorization" =>  '{"authorizationResponse":{"id":"123001002","idType":"SSN","edi":"1026070453","firstName":"JANE","lastName":"DOE","gender":"MALE","status":"VETERAN"}}'
}



conn = Faraday.new(
	"https://csraciapp6.evss.srarad.com/wss-ppiu-services-web/rest/ppiuServices/v1", ssl: { verify: false }
) do |faraday|
	faraday.adapter :httpclient
end

response = conn.get do |req|
	req.url 'paymentInformation'
	req.headers = headers
	req.body = { 'paymentType' => 'CNP' }.to_json
end

puts response.status
puts response.body
