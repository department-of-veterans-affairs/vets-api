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
      # @params email [Vet360::Models::Email] the email to create
      # @returns [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around an transaction object
      def post_email(email)
        post_or_put_email(:post, email)
      end

      # PUTs a new address to the vet360 API
      # @params email [Vet360::Models::Email] the email to update
      # @returns [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def put_email(email)
        post_or_put_email(:put, email)
      end

      # POSTs a new address to the vet360 API
      # @params address [Vet360::Models::Address] the address to send
      # @returns [Vet360::ContactInformation::AddressTransactionResponse] response wrapper around an transaction object
      def post_address(address)
        post_or_put_address(:post, address)
      end

      # PUTs a new address to the vet360 API
      # @params address [Vet360::Models::Address] the address to update
      # @returns [Vet360::ContactInformation::AddressTransactionResponse] response wrapper around a transaction object
      def put_address(address)
        post_or_put_address(:put, address)
      end

      # GET's the status of a transaction id from the Vet360 api
      # @params transaction [Vet360::Models::Transaction] the transaction check
      # @returns [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def get_email_transaction_status(transaction)
        route = "#{@user.vet360_id}/emails/status/#{transaction.id}"
        get_transaction_status(route, EmailTransactionResponse)
      end

      # GET's the status of a transaction id from the Vet360 api
      # @params transaction [Vet360::Models::Transaction] the transaction to check
      # @returns [Vet360::ContactInformation::TelephoneTransactionResponse] response wrapper around a transaction object
      def get_telephone_transaction_status(transaction)
        route = "#{@user.vet360_id}/telephones/status/#{transaction.id}"
        get_transaction_status(route, TelephoneTransactionResponse)
      end

      private

      def get_transaction_status(route, klass)
        with_monitoring do
          raw_response = perform(:get, route)

          klass.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def post_or_put_email(method, email)
        with_monitoring do
          raw = perform(method, 'emails', email.in_json)
          EmailTransactionResponse.new(raw.status, raw)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def post_or_put_address(method, address)
        with_monitoring do
          raw = perform(method, 'addresses', address.in_json)
          AddressTransactionResponse.new(raw.status, raw)
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
