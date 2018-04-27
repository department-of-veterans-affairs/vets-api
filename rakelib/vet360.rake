# frozen_string_literal: true

namespace :vet360 do
  ###########
  ## TASKS ##
  ###########

  ## GETs

  desc 'Request Vet360 person contact information'
  task :get_person, [:vet360_id] => [:environment] do |_, args|
    abort 'No vet360_id provided' if args[:vet360_id].blank?

    user = OpenStruct.new(vet360_id: args[:vet360_id])

    person = Vet360::ContactInformation::Service.new(user).get_person
    pp person.to_h
  end

  desc 'GET Vet360 email transaction status'
  task :get_email_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    abort 'No vet360_id provided' if args[:vet360_id].blank?
    abort 'No tx_audit_id provided' if args[:tx_audit_id].blank?

    user = OpenStruct.new(vet360_id: args[:vet360_id])
    transaction = Vet360::Models::Transaction.new(id: args[:tx_audit_id])

    trx = Vet360::ContactInformation::Service.new(user).get_email_transaction_status(transaction)
    pp trx.to_h
  end

  desc 'GET Vet360 address transaction status'
  task :get_address_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    abort 'No vet360_id provided' if args[:vet360_id].blank?
    abort 'No tx_audit_id provided' if args[:tx_audit_id].blank?

    user = OpenStruct.new(vet360_id: args[:vet360_id])
    transaction = Vet360::Models::Transaction.new(id: args[:tx_audit_id])

    trx = Vet360::ContactInformation::Service.new(user).get_address_transaction_status(transaction)
    pp trx.to_h
  end

  desc 'GET Vet360 telephone transaction status'
  task :get_telephone_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    abort 'No vet360_id provided' if args[:vet360_id].blank?
    abort 'No tx_audit_id provided' if args[:tx_audit_id].blank?

    user = OpenStruct.new(vet360_id: args[:vet360_id])
    transaction = Vet360::Models::Transaction(id: args[:tx_audit_id])

    trx = Vet360::ContactInformation::Service.new(user).get_telephone_transaction_status(transaction)
    pp trx.to_h
  end

  desc 'Update Vet360 email'
  task :put_email, [:body] => [:environment] do |_, args|
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
    abort 'No body provided' if args[:body].blank?

    body = JSON.parse(body)
    vet360_id = body.dig('bio', 'vet360_id')
    abort 'No vet360_id provided in body' if vet360_id.blank?

    user = OpenStruct.new(vet360_id: vet360_id)
    email = Vet360::Models::Email.build_from(body)
    trx = Vet360::ContactInformation::Service.new(user).put_email(email)
    pp trx.to_h
  end

  desc 'Update Vet360 telephone'
  task :put_telephone, [:body] => [:environment] do |_, args|
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
    abort 'No body provided' if args[:body].blank?

    body = JSON.parse(body)
    vet360_id = body.dig('bio', 'vet360_id')
    abort 'No vet360_id provided in body' if vet360_id.blank?

    user = OpenStruct.new(vet360_id: vet360_id)
    telephone = Vet360::Models::Telephone.build_from(body)
    trx = Vet360::ContactInformation::Service.new(user).put_telephone(telephone)
    pp trx.to_h
  end

  desc 'Update Vet360 address'
  task :put_address, [:body] => [:environment] do |_, args|
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
    abort 'No body provided' if args[:body].blank?

    body = JSON.parse(body)
    vet360_id = body.dig('bio', 'vet360_id')
    abort 'No vet360_id provided in body' if vet360_id.blank?

    user = OpenStruct.new(vet360_id: vet360_id)
    address = Vet360::Models::Address.build_from(body)
    trx = Vet360::ContactInformation::Service.new(user).put_address(address)
    pp trx.to_h
  end

  desc 'Create Vet360 email'
  task :post_email, [:body] => [:environment] do |_, args|
    # EXPECTED FORMAT OF BODY:
    # {
    #   "bio": {
    #     "confirmationDate": "2018-04-06T17:42:47.655Z",
    #     "effectiveEndDate": "2018-04-06T17:42:47.655Z",
    #     "effectiveStartDate": "2018-04-06T17:42:47.655Z",
    #     "emailAddressText": "string",
    #     "emailPermInd": true,
    #     "emailStatusCode": "NO_KNOWN_PROBLEM",
    #     "originatingSourceSystem": "string",
    #     "sourceDate": "2018-04-06T17:42:47.655Z",
    #     "sourceSystemUser": "string",
    #     "vet360Id": 0
    #   }
    # }
    abort 'No body provided' if args[:body].blank?

    body = JSON.parse(body)
    vet360_id = body.dig('bio', 'vet360_id')
    abort 'No vet360_id provided in body' if vet360_id.blank?

    user = OpenStruct.new(vet360_id: vet360_id)
    email = Vet360::Models::Email.build_from(body)
    trx = Vet360::ContactInformation::Service.new(user).post_email(email)
    pp trx.to_h
  end

  desc 'Create Vet360 telephone'
  task :post_telephone, [:body] => [:environment] do |_, args|
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
    #     "textMessageCapableInd": true,
    #     "textMessagePermInd": true,
    #     "ttyInd": true,
    #     "vet360Id": 0,
    #     "voiceMailAcceptableInd": true
    #   }
    # }
    abort 'No body provided' if args[:body].blank?

    body = JSON.parse(body)
    vet360_id = body.dig('bio', 'vet360_id')
    abort 'No vet360_id provided in body' if vet360_id.blank?

    user = OpenStruct.new(vet360_id: vet360_id)
    telephone = Vet360::Models::Telephone.build_from(body)
    trx = Vet360::ContactInformation::Service.new(user).post_telephone(telephone)
    pp trx.to_h
  end

  desc 'Create Vet360 address'
  task :post_address, [:body] => [:environment] do |_, args|
    # EXPECTED FORMAT OF BODY:
    # {
    #   "bio": {
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
    abort 'No body provided' if args[:body].blank?

    body = JSON.parse(body)
    vet360_id = body.dig('bio', 'vet360_id')
    abort 'No vet360_id provided in body' if vet360_id.blank?

    user = OpenStruct.new(vet360_id: vet360_id)
    address = Vet360::Models::Address.build_from(body)
    trx = Vet360::ContactInformation::Service.new(user).post_address(address)
    pp trx.to_h
  end
end
