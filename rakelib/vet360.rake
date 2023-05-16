# frozen_string_literal: true

require 'va_profile/contact_information/service'
require 'va_profile/exceptions/builder'
require 'va_profile/models/email'
require 'va_profile/models/telephone'
require 'va_profile/person/service'

namespace :vet360 do
  ###########
  ## TASKS ##
  ###########

  ENV_VAR_NAME = 'VET360_RAKE_DATA'

  ## GETs

  desc 'Request Vet360 person contact information'
  task :get_person, [:vet360_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    trx = VAProfile::ContactInformation::Service.new(user_struct(args[:vet360_id])).get_person
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc 'GET Vet360 email transaction status'
  task :get_email_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    ensure_arg(:tx_audit_id, args)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(args[:vet360_id]))
          .get_email_transaction_status(args[:tx_audit_id])
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc 'GET Vet360 address transaction status'
  task :get_address_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    ensure_arg(:tx_audit_id, args)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(args[:vet360_id]))
          .get_address_transaction_status(args[:tx_audit_id])
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc 'GET Vet360 telephone transaction status'
  task :get_telephone_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    ensure_arg(:tx_audit_id, args)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(args[:vet360_id]))
          .get_telephone_transaction_status(args[:tx_audit_id])
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc 'GET Vet360 permission transaction status'
  task :get_permission_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    ensure_arg(:tx_audit_id, args)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(args[:vet360_id]))
          .get_permission_transaction_status(args[:tx_audit_id])
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  ## PUTs

  desc "Update Vet360 email (from #{ENV_VAR_NAME})"
  task put_email: [:environment] do
    # EXPECTED FORMAT OF VET360_RAKE_DATA:
    # {
    #     "email_address": "string",
    #     "email_id": 0,
    #     "email_perm_ind": true,
    #     "vet360_id": 0
    #     ...
    #     [ see lib/vet360/models/email.rb ]
    # }

    ensure_data_var

    data = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = data['vet360_id']
    ensure_var('vet360_id', vet360_id)

    email = VAProfile::Models::Email.build_from(data)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .put_email(email)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc "Update Vet360 telephone (from #{ENV_VAR_NAME})"
  task put_telephone: [:environment] do
    # EXPECTED FORMAT OF VET360_RAKE_DATA:
    # {
    #     "area_code": "string",
    #     "country_code": "string",
    #     "phone_number": "string",
    #     ...
    #     [ see lib/vet360/models/telephone.rb ]
    # }

    ensure_data_var

    body = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = body['vet360_id']
    ensure_var('vet360_id', vet360_id)

    telephone = VAProfile::Models::Telephone.build_from(body)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .put_telephone(telephone)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc "Update Vet360 address (from #{ENV_VAR_NAME})"
  task put_address: [:environment] do
    # EXPECTED FORMAT OF VET360_RAKE_DATA:
    # {
    #     "address_id": 0,
    #     "address_line1": "string",
    #     "address_line2": "string",
    #     "address_line3": "string",
    #     "address_pou": "RESIDENCE/CHOICE",
    #     ...
    #     [ see lib/vet360/models/address.rb ]
    # }

    ensure_data_var

    body = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = body['vet360_id']
    ensure_var('vet360_id', vet360_id)

    address = VAProfile::Models::Address.build_from(body)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .put_address(address)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc "Update Vet360 permission (from #{ENV_VAR_NAME})"
  task put_permission: [:environment] do
    # EXPECTED FORMAT OF VET360_RAKE_DATA:
    # {
    #     "permission_type": "string",
    #     "permission_value": boolean,
    #     ...
    #     [ see lib/vet360/models/permission.rb ]
    # }

    ensure_data_var

    body = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = body['vet360_id']
    ensure_var('vet360_id', vet360_id)

    permission = VAProfile::Models::Permission.build_from(body)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .put_permission(permission)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  ## POSTs

  desc "Create Vet360 email (from #{ENV_VAR_NAME})"
  task post_email: [:environment] do
    # EXPECTED FORMAT OF VET360_RAKE_DATA:
    # {
    #     "email_address_text": "string",
    #     "email_perm_ind": true,
    #     "vet360_id": 0
    #     ...
    #     [ see lib/vet360/models/email.rb ]
    # }

    ensure_data_var

    body = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = body['vet360_id']
    ensure_var('vet360_id', vet360_id)

    email = VAProfile::Models::Email.build_from(body)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .post_email(email)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc "Create Vet360 telephone (from #{ENV_VAR_NAME})"
  task post_telephone: [:environment] do
    # EXPECTED FORMAT OF BODY:
    # {
    #     "area_code": "string",
    #     "phone_number": "string",
    #     "phone_number_ext": "string",
    #     "phone_type": "MOBILE",
    #     "vet360_id": 0,
    #     ...
    #     [ see lib/vet360/models/telephone.rb ]
    # }

    ensure_data_var

    body = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = body['vet360_id']
    ensure_var('vet360_id', vet360_id)

    telephone = VAProfile::Models::Telephone.build_from(body)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .post_telephone(telephone)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc "Create Vet360 address (from #{ENV_VAR_NAME})"
  task post_address: [:environment] do
    # EXPECTED FORMAT OF BODY:
    # {
    #     "address_line1": "string",
    #     "address_line2": "string",
    #     "vet360_id": 0,
    #     ...
    #     [ see lib/vet360/models/address.rb ]
    # }

    ensure_data_var

    body = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = body['vet360_id']
    ensure_var('vet360_id', vet360_id)

    address = VAProfile::Models::Address.build_from(body)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .post_address(address)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc "Create Vet360 permission (from #{ENV_VAR_NAME})"
  task post_permission: [:environment] do
    # EXPECTED FORMAT OF VET360_RAKE_DATA:
    # {
    #     "permission_type": "string",
    #     "permission_value": boolean,
    #     ...
    #     [ see lib/vet360/models/permission.rb ]
    # }

    ensure_data_var

    body = JSON.parse(ENV[ENV_VAR_NAME])
    vet360_id = body['vet360_id']
    ensure_var('vet360_id', vet360_id)

    permission = VAProfile::Models::Permission.build_from(body)
    trx = VAProfile::ContactInformation::Service
          .new(user_struct(vet360_id))
          .post_permission(permission)
    # rubocop:disable Lint/Debugger
    pp trx.to_h
    # rubocop:enable Lint/Debugger
  end

  desc <<~DESCRIPTION
    Initializes a vet360_id for the passed in ICNs.

    Takes a comma-separated list of ICNs as an argument.  Prints an array of hash results.

    Sample way to call this rake task:

    rake vet360:init_vet360_id[123456,1312312,134234234,4234234]'

    Note: There *cannot* be any spaces around the commas (i.e. [123456, 1312312, 134234234, 4234234])
  DESCRIPTION
  task :init_vet360_id, [:icns] => [:environment] do |_, args|
    service = VAProfile::Person::Service.new('rake_user')
    icns    = args.extras.prepend(args[:icns])
    results = []

    puts "#{icns.size} to be initialized"

    icns.each do |icn|
      response  = service.init_vet360_id(icn)
      vet360_id = response&.person&.vet360_id

      results << { icn:, vet360_id: }
    rescue => e
      results << { icn:, vet360_id: e.message }
    end

    puts "Results:\n\n#{results}"
  end

  desc <<~DESCRIPTION
    Prep Vet360 error codes for locales.exceptions.en.yml file.

    This rake task is idempotent.  It takes all of the current error code
    csv data that you import, and converts it into the proper error code
    format for the config/locales/exceptions.en.yml file.

    This requires a developer to follow some manual steps.  Here are the
    instructions:

    1.  The full set of error codes are located at:  https://github.com/department-of-veterans-affairs/mdm-cuf-person/blob/development/mdm-cuf-person-server/src/inttest/resources/mdm/cuf/person/testData/error_codes.csv

    2. Copy and paste this full set of raw error code csv data into
    spec/support/vet360/api_response_error_messages.csv (not just the diff,
    as this rake task is idempotent.)

    3. Make sure these header columns are present in the csv (no spaces after commas):
    Message Code,Sub Code,Message Key,Type,Status,State,Queue,Message Description

    Here is an example that matches up the headers with one row of matching data:

    Message Code,Sub Code,Message Key,Type,Status,State,Queue,Message Description
    EMAIL200,emailId,emailId.Null,ERROR,400,REJECTED,RECEIVED_ERROR_QUEUE,Email ID in email bio must be null for inserts/adds

    4. Run this rake task.

    5. test.yml will now contain all of the formatted error codes.  You will need to make the
    following adjustments
    - Manually reformat each one of these rows to remove the leading : and double quotes
      :<<: "*external_defaults" becomes
      <<: *external_defaults
    - Change all of the "status" values from strings to integers (i.e. '400' => 400)
    - Remove all of the leading dashes (-) before each VET360_ key.
      For example, - VET360_ADDR101: becomes VET360_ADDR101:

    6. The rake task will output any "titles" or "details" that are missing.  If any are
    missing, you will need to come up with them, and type them in.

    7. Delete all of the VET360_ error codes from exceptions.en.yml

    8. Paste in all of the updated VET360_ error codes from test.yml, into exceptions.en.yml

    9. Delete test.yml
  DESCRIPTION
  task prep_error_codes: :environment do
    VAProfile::Exceptions::Builder.new.construct_exceptions_from_csv
  end

  def ensure_data_var
    abort "Env var: #{ENV_VAR_NAME} not set" if ENV[ENV_VAR_NAME].blank?
  end

  def ensure_arg(arg_symbol, args)
    abort "No #{arg_symbol} argument provided" if args[arg_symbol].blank?
  end

  def ensure_var(name, var)
    abort "No #{name} included" if var.blank?
  end

  def user_struct(vet360_id)
    OpenStruct.new(vet360_id:)
  end
end
