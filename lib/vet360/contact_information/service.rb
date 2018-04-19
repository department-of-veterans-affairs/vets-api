# frozen_string_literal: true

require 'common/client/base'
require 'vet360/contact_information/transaction_response'

module Vet360
  module ContactInformation
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ContactInformation::Configuration

      def get_person
        with_monitoring do
          # TODO: guard clause in case there is no vet360_id
          raw_response = perform(:get, @user.vet360_id)

          Vet360::ContactInformation::PersonResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      # POSTs a new address to the vet360 API
      # @params address [Vet360::Models::Email] the email to create
      # @returns [Vet360::ContactInformation::EmailUpdateResponse] response wrapper around an transaction object
      def post_email(email)
        post_or_put_email(:post, email)
      end

      # PUTs a new address to the vet360 API
      # @params address [Vet360::Models::Email] the email to update
      # @returns [Vet360::ContactInformation::EmailUpdateResponse] response wrapper around a transaction object
      def put_email(email)
        post_or_put_email(:put, email)
      end

      def get_email_transaction_status(transaction)
        with_monitoring do
          route = "#{@user.vet360_id}/emails/status/#{transaction.id}"
          raw_response = perform(:get, route)

          Vet360::ContactInformation::EmailTransactionResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      # POSTs a new address to the vet360 API
      # @params address [Vet360::Models::Address] the address to send
      # @returns [Vet360::ContactInformation::AddressUpdateResponse] response wrapper around an transaction object
      def post_address(address)
        post_or_put_address(:post, address)
      end

      # PUTs a new address to the vet360 API
      # @params address [Vet360::Models::Address] the address to update
      # @returns [Vet360::ContactInformation::AddressUpdateResponse] response wrapper around a transaction object
      def put_address(address)
        post_or_put_address(:put, address)
      end

      private

      def post_or_put_email(method, vet360_email)
        with_monitoring do
          raw = perform(method, 'emails', vet360_email.in_json)
          Vet360::ContactInformation::EmailTransactionResponse.new(raw.status, raw)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def post_or_put_address(method, address)
        with_monitoring do
          raw = perform(method, 'addresses', address.in_json)
          Vet360::ContactInformation::AddressTransactionResponse.new(raw.status, raw)
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
