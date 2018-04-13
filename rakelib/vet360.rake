namespace :vet360 do

  ###########
  ## SETUP ##
  ###########
  VET360_HOST = Settings.vet360.url
  @headers = {
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  }
  @base_path = "/cuf/person/contact-information/v1"
  @cuf_system_name = Settings.vet360.system_name

  ###########
  ## TASKS ##
  ###########

  ## GETs

  desc "Request Vet360 person contact information"
  task :get_contactinfo, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}"
    response = make_request(:get, path).body
  end

  desc "Request Vet360 person contact information addresses"
  task :get_contactinfo_addresses, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/addresses"
    response = make_request(:get, path).body
  end

  desc "Request Vet360 person contact information emails"
  task :get_contactinfo_emails, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/emails"
    response = make_request(:get, path).body
  end

  desc "Request Vet360 person contact information telephones"
  task :get_contactinfo_telephones, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/telephones"
    response = make_request(:get, path).body
  end

  desc "Request Vet360 email transaction"
  task :get_transaction_emails, [:vet360_id, :tx_audit_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    abort "No tx_audit_id provided" if args[:tx_audit_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/emails/#{:tx_audit_id}"
    response = make_request(:get, path, nil, {cufSystemName: @cuf_system_name}).body
  end

  desc "Request Vet360 addresses transaction"
  task :get_transaction_addresses, [:vet360_id, :tx_audit_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    abort "No tx_audit_id provided" if args[:tx_audit_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/addresses/#{:tx_audit_id}"
    response = make_request(:get, path, nil, {cufSystemName: @cuf_system_name}).body
  end

  desc "Request Vet360 telephones transaction"
  task :get_transaction_telephones, [:vet360_id, :tx_audit_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    abort "No tx_audit_id provided" if args[:tx_audit_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/telephones/#{:tx_audit_id}"
    response = make_request(:get, path, nil, {cufSystemName: @cuf_system_name}).body
  end

  ## PUTs

  desc "Update Vet360 email"
  # EXPECTED FORMAT OF BODY:
  # {
  #   "bio": {
  #     "confirmationDate": "2018-04-06T17:42:47.655Z",
  #     "effectiveEndDate": "2018-04-06T17:42:47.655Z",
  #     "effectiveStartDate": "2018-04-06T17:42:47.655Z",
  #     "emailAddressText": "string",
  #     "emailId": 0,
  #     "emailPermInd": true,
  #     "emailStatusCode": "NO_KNOWN_PROBLEM",
  #     "originatingSourceSystem": "string",
  #     "sourceDate": "2018-04-06T17:42:47.655Z",
  #     "sourceSystemUser": "string",
  #     "vet360Id": 0
  #   }
  # }
  task :put_contactinfo_email, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/emails"
    response = make_request(:put, path, args[:body], {cufSystemName: @cuf_system_name}).body
  end

  desc "Update Vet360 address"
  # EXPECTED FORMAT OF BODY:
  # {
  #   "bio": {
  #     "addressId": 0,
  #     "addressLine1": "string",
  #     "addressLine2": "string",
  #     "addressLine3": "string",
  #     "addressPOU": "RESIDENCE/CHOICE",
  #     "addressType": "string",
  #     "badAddressIndicator": "string",
  #     "cityName": "string",
  #     "confidenceScore": "string",
  #     "confirmationDate": "2018-04-06T17:57:08.701Z",
  #     "countryCodeFIPS": "string",
  #     "countryCodeISO2": "string",
  #     "countryCodeISO3": "string",
  #     "countryName": "string",
  #     "county": {
  #       "countyCode": "string",
  #       "countyName": "string"
  #     },
  #     "effectiveEndDate": "2018-04-06T17:57:08.701Z",
  #     "effectiveStartDate": "2018-04-06T17:57:08.701Z",
  #     "geocodeDate": "2018-04-06T17:57:08.701Z",
  #     "geocodePrecision": "string",
  #     "intPostalCode": "string",
  #     "latitude": "string",
  #     "longitude": "string",
  #     "originatingSourceSystem": "string",
  #     "overrideIndicator": false,
  #     "provinceName": "string",
  #     "sourceDate": "2018-04-06T17:57:08.701Z",
  #     "sourceSystemUser": "string",
  #     "stateCode": "string",
  #     "vet360Id": 0,
  #     "zipCode4": "string",
  #     "zipCode5": "string"
  #   }
  # }
  task :put_contactinfo_address, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/addresses"
    response = make_request(:put, path, args[:body], {cufSystemName: @cuf_system_name}).body
  end

  desc "Update Vet360 telephone"
  # EXPECTED FORMAT OF BODY:
  # {
  #   "bio": {
  #     "areaCode": "string",
  #     "confirmationDate": "2018-04-06T17:59:16.371Z",
  #     "connectionStatusCode": "NO_KNOWN_PROBLEM",
  #     "countryCode": "string",
  #     "effectiveEndDate": "2018-04-06T17:59:16.371Z",
  #     "effectiveStartDate": "2018-04-06T17:59:16.371Z",
  #     "internationalIndicator": true,
  #     "originatingSourceSystem": "string",
  #     "phoneNumber": "string",
  #     "phoneNumberExt": "string",
  #     "phoneType": "MOBILE",
  #     "sourceDate": "2018-04-06T17:59:16.371Z",
  #     "sourceSystemUser": "string",
  #     "telephoneId": 0,
  #     "textMessageCapableInd": true,
  #     "textMessagePermInd": true,
  #     "ttyInd": true,
  #     "vet360Id": 0,
  #     "voiceMailAcceptableInd": true
  #   }
  # }
  task :put_contactinfo_telephone, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/telephones"
    response = make_request(:put, path, args[:body], {cufSystemName: @cuf_system_name}).body
  end

  ## POSTs

  desc "Create Vet360 person contact information addresses"
  task :post_contactinfo_addresses, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/addresses"
    response = make_request(:post, path, args[:body], {cufSystemName: @cuf_system_name}).body
  end

  desc "Create Vet360 person contact information emails"
  task :post_contactinfo_emails, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/emails"
    response = make_request(:post, path, args[:body], {cufSystemName: @cuf_system_name}).body
  end

  desc "Create Vet360 person contact information telephones"
  task :post_contactinfo_telephones, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/telephones"
    response = make_request(:post, path, args[:body], {cufSystemName: @cuf_system_name}).body
  end

  #############
  ## Helpers ##
  #############
  def conn
    conn = Faraday.new(
      VET360_HOST, ssl: { verify: false }
      ) do |faraday|
      faraday.adapter :httpclient
    end
  end

  def make_request method, route, body = nil, headers = {}

    response = conn.send(method) do |req|
      req.url route
      req.headers = @headers.merge(headers)
      req.body = body
    end

    # print results to console
    puts "#{method.upcase}: #{route}"
    puts "Response status: #{response.status}"
    puts "Response body: #{response.body}"
  end

end