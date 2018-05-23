# frozen_string_literal: true

namespace :vet360 do
  ###########
  ## TASKS ##
  ###########

  ENV_VAR_NAME = 'VET360_RAKE_DATA'

  ## GETs

  desc 'Request Vet360 person contact information'
  task :get_person, [:vet360_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    person = Vet360::ContactInformation::Service.new(user_struct(args[:vet360_id])).get_person
    pp person.to_h
  end

  desc 'GET Vet360 email transaction status'
  task :get_email_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    ensure_arg(:tx_audit_id, args)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(args[:vet360_id]))
      .get_email_transaction_status(args[:tx_audit_id])
    pp trx.to_h
  end

  desc 'GET Vet360 address transaction status'
  task :get_address_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    ensure_arg(:tx_audit_id, args)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(args[:vet360_id]))
      .get_address_transaction_status(args[:tx_audit_id])
    pp trx.to_h
  end

  desc 'GET Vet360 telephone transaction status'
  task :get_telephone_transaction_status, %i[vet360_id tx_audit_id] => [:environment] do |_, args|
    ensure_arg(:vet360_id, args)
    ensure_arg(:tx_audit_id, args)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(args[:vet360_id]))
      .get_telephone_transaction_status(args[:tx_audit_id])
    pp trx.to_h
  end

  ## PUTs

  desc "Update Vet360 email (from #{ENV_VAR_NAME})"
  task :put_email do
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
    vet360_id = data.dig('vet360_id')
    ensure_var('vet360_id', vet360_id)

    email = Vet360::Models::Email.build_from(data)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(vet360_id))
      .put_email(email)
    pp trx.to_h
  end

  desc "Update Vet360 telephone (from #{ENV_VAR_NAME})"
  task :put_telephone do 
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
    vet360_id = body.dig('vet360_id')
    ensure_var('vet360_id', vet360_id)

    telephone = Vet360::Models::Telephone.build_from(body)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(vet360_id))
      .put_telephone(telephone)
    pp trx.to_h
  end

  desc "Update Vet360 address (from #{ENV_VAR_NAME})"
  task :put_address do
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
    vet360_id = body.dig('vet360_id')
    ensure_var('vet360_id', vet360_id)

    address = Vet360::Models::Address.build_from(body)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(vet360_id))
      .put_address(address)
    pp trx.to_h
  end

  ## POSTs

  desc "Create Vet360 email (from #{ENV_VAR_NAME})"
  task :post_email do
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
    vet360_id = body.dig('vet360_id')
    ensure_var('vet360_id', vet360_id)

    email = Vet360::Models::Email.build_from(body)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(vet360_id))
      .post_email(email)
    pp trx.to_h
  end

  desc "Create Vet360 telephone (from #{ENV_VAR_NAME})"
  task :post_telephone do
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
    vet360_id = body.dig('vet360_id')
    ensure_var('vet360_id', vet360_id)

    telephone = Vet360::Models::Telephone.build_from(body)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(vet360_id))
      .post_telephone(telephone)
    pp trx.to_h
  end

  desc "Create Vet360 address (from #{ENV_VAR_NAME})"
  task :post_address do
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
    vet360_id = body.dig('vet360_id')
    ensure_var('vet360_id', vet360_id)

    address = Vet360::Models::Address.build_from(body)
    trx = Vet360::ContactInformation::Service
      .new(user_struct(vet360_id))
      .post_address(address)
    pp trx.to_h
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
    OpenStruct.new(vet360_id: vet360_id)
  end
end
