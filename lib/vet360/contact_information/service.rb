# frozen_string_literal: true

require 'common/client/base'
require 'vet360/contact_information/transaction_response'

module Vet360
  module ContactInformation
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ContactInformation::Configuration

      # GET's a Person bio from the Vet360 API
      # @returns [Vet360::ContactInformation::PersonResponse] response wrapper around an person object
      def get_person
        with_monitoring do
          # TODO: guard clause in case there is no vet360_id
          raw_response = perform(:get, @user.vet360_id)

          PersonResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      # POSTs a new address to the vet360 API
      # @params address [Vet360::Models::Address] the address to send
      # @returns [Vet360::ContactInformation::AddressTransactionResponse] response wrapper around an transaction object
      def post_address(address)
        post_or_put_data(:post, address, 'addresses', AddressTransactionResponse)
      end

      # PUTs an updated address to the vet360 API
      # @params address [Vet360::Models::Address] the address to update
      # @returns [Vet360::ContactInformation::AddressTransactionResponse] response wrapper around a transaction object
      def put_address(address)
        post_or_put_data(:put, address, 'addresses', AddressTransactionResponse)
      end

      # GET's the status of an address transaction from the Vet360 api
      # @params transaction [Vet360::Models::Transaction] the transaction to check
      # @returns [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def get_address_transaction_status(transaction)
        route = "#{@user.vet360_id}/addresses/status/#{transaction.id}"
        get_transaction_status(route, AddressTransactionResponse)
      end

      # POSTs a new address to the vet360 API
      # @params email [Vet360::Models::Email] the email to create
      # @returns [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around an transaction object
      def post_email(email)
        post_or_put_data(:post, email, 'emails', EmailTransactionResponse)
      end

      # PUTs an updated address to the vet360 API
      # @params email [Vet360::Models::Email] the email to update
      # @returns [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def put_email(email)
        post_or_put_data(:put, email, 'emails', EmailTransactionResponse)
      end

      # GET's the status of an email transaction from the Vet360 api
      # @params transaction [Vet360::Models::Transaction] the transaction to check
      # @returns [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def get_email_transaction_status(transaction)
        route = "#{@user.vet360_id}/emails/status/#{transaction.id}"
        get_transaction_status(route, EmailTransactionResponse)
      end

      # POSTs a new telephone to the vet360 API
      # @params telephone [Vet360::Models::Telephone] the telephone to send
      # @returns [Vet360::ContactInformation::TelephoneUpdateResponse] response wrapper around a transaction object
      def post_telephone(telephone)
        post_or_put_data(:post, telephone, 'telephones', TelephoneTransactionResponse)
      end

      # PUTs an updated telephone to the vet360 API
      # @params telephone [Vet360::Models::Telephone] the telephone to update
      # @returns [Vet360::ContactInformation::TelephoneUpdateResponse] response wrapper around a transaction object
      def put_telephone(telephone)
        post_or_put_data(:put, telephone, 'telephones', TelephoneTransactionResponse)
      end

      # GET's the status of a telephone transaction from the Vet360 api
      # @params transaction [Vet360::Models::Transaction] the transaction to check
      # @returns [Vet360::ContactInformation::TelephoneTransactionResponse] response wrapper around a transaction object
      def get_telephone_transaction_status(transaction)
        route = "#{@user.vet360_id}/telephones/status/#{transaction.id}"
        get_transaction_status(route, TelephoneTransactionResponse)
      end

      private

      def post_or_put_data(method, model, path, response_class)
        with_monitoring do
          raw = perform(method, path, model.in_json)
          response_class.new(raw.status, raw)
        end
      end

      def post_or_put_data(method, model, path, response_class)
        with_monitoring do
          raw = perform(method, path, model.in_json)
          response_class.new(raw.status, raw)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def get_transaction_status(path, response_class)
        with_monitoring do
          raw_response = perform(:get, path)

          response_class.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
