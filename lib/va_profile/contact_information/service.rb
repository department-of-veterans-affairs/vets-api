# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require_relative 'configuration'
require_relative 'transaction_response'

module VAProfile
  module ContactInformation
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::ContactInformation::Configuration

      # GET's a Person bio from the VAProfile API
      # If a user is not found in VAProfile, an empty PersonResponse with a 404 status will be returned
      # @return [VAProfile::ContactInformation::PersonResponse] response wrapper around an person object
      def get_person
        with_monitoring do
          vet360_id_present!
          raw_response = perform(:get, @user.vet360_id)

          PersonResponse.from(raw_response)
        end
      rescue Common::Client::Errors::ClientError => e
        if e.status == 404
          log_exception_to_sentry(
            e,
            { vet360_id: @user.vet360_id },
            { va_profile: :person_not_found },
            :warning
          )

          return PersonResponse.new(404, person: nil)
        end

        handle_error(e)
      rescue => e
        handle_error(e)
      end

      # POSTs a new address to the VAProfile API
      # @param address [VAProfile::Models::Address] the address to create
      # @return [VAProfile::ContactInformation::AddressTransactionResponse] response wrapper around
      #   an transaction object
      def post_address(address)
        post_or_put_data(:post, address, 'addresses', AddressTransactionResponse)
      end

      # PUTs an updated address to the VAProfile API
      # @param address [VAProfile::Models::Address] the address to update
      # @return [VAProfile::ContactInformation::AddressTransactionResponse] response wrapper around a transaction object
      def put_address(address)
        post_or_put_data(:put, address, 'addresses', AddressTransactionResponse)
      end

      # GET's the status of an address transaction from the VAProfile api
      # @param transaction_id [int] the transaction_id to check
      # @return [VAProfile::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def get_address_transaction_status(transaction_id)
        route = "#{@user.vet360_id}/addresses/status/#{transaction_id}"
        get_transaction_status(route, AddressTransactionResponse)
      end

      # POSTs a new address to the VAProfile API
      # @param email [VAProfile::Models::Email] the email to create
      # @return [VAProfile::ContactInformation::EmailTransactionResponse] response wrapper around an transaction object
      def post_email(email)
        post_or_put_data(:post, email, 'emails', EmailTransactionResponse)
      end

      # PUTs an updated address to the VAProfile API
      # @param email [VAProfile::Models::Email] the email to update
      # @return [VAProfile::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def put_email(email)
        post_or_put_data(:put, email, 'emails', EmailTransactionResponse)
      end

      # GET's the status of an email transaction from the VAProfile api
      # @param transaction_id [int] the transaction_id to check
      # @return [VAProfile::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def get_email_transaction_status(transaction_id)
        route = "#{@user.vet360_id}/emails/status/#{transaction_id}"
        get_transaction_status(route, EmailTransactionResponse)
      end

      # POSTs a new telephone to the VAProfile API
      # @param telephone [VAProfile::Models::Telephone] the telephone to create
      # @return [VAProfile::ContactInformation::TelephoneUpdateResponse] response wrapper around a transaction object
      def post_telephone(telephone)
        post_or_put_data(:post, telephone, 'telephones', TelephoneTransactionResponse)
      end

      # PUTs an updated telephone to the VAProfile API
      # @param telephone [VAProfile::Models::Telephone] the telephone to update
      # @return [VAProfile::ContactInformation::TelephoneUpdateResponse] response wrapper around a transaction object
      def put_telephone(telephone)
        post_or_put_data(:put, telephone, 'telephones', TelephoneTransactionResponse)
      end

      # GET's the status of a telephone transaction from the VAProfile api
      # @param transaction_id [int] the transaction_id to check
      # @return [VAProfile::ContactInformation::TelephoneTransactionResponse] response wrapper around
      #   a transaction object
      def get_telephone_transaction_status(transaction_id)
        route = "#{@user.vet360_id}/telephones/status/#{transaction_id}"
        get_transaction_status(route, TelephoneTransactionResponse)
      end

      # POSTs a new permission to the VAProfile API
      # @param permission [VAProfile::Models::Permission] the permission to create
      # @return [VAProfile::ContactInformation::PermissionUpdateResponse] response wrapper around a transaction object
      def post_permission(permission)
        post_or_put_data(:post, permission, 'permissions', PermissionTransactionResponse)
      end

      # PUTs an updated permission to the VAProfile API
      # @param permission [VAProfile::Models::Permission] the permission to update
      # @return [VAProfile::ContactInformation::PermissionUpdateResponse] response wrapper around a transaction object
      def put_permission(permission)
        post_or_put_data(:put, permission, 'permissions', PermissionTransactionResponse)
      end

      # GET's the status of a permission transaction from the VAProfile api
      # @param transaction_id [int] the transaction_id to check
      # @return [VAProfile::ContactInformation::PermissionTransactionResponse] response wrapper around
      #   a transaction object
      def get_permission_transaction_status(transaction_id)
        route = "#{@user.vet360_id}/permissions/status/#{transaction_id}"
        get_transaction_status(route, PermissionTransactionResponse)
      end

      # GET's the status of a person transaction from the VAProfile api. Does not validate the presence of
      # a vet360_id before making the service call, as POSTing a person initializes a vet360_id.
      #
      # @param transaction_id [String] the transaction_id to check
      # @return [VAProfile::ContactInformation::PersonTransactionResponse] response wrapper around a transaction object
      #
      def get_person_transaction_status(transaction_id)
        with_monitoring do
          raw_response = perform(:get, "status/#{transaction_id}")
          VAProfile::Stats.increment_transaction_results(raw_response, 'init_vet360_id')

          VAProfile::ContactInformation::PersonTransactionResponse.from(raw_response, @user)
        end
      rescue => e
        handle_error(e)
      end

      private

      def vet360_id_present!
        raise 'User does not have a vet360_id' if @user&.vet360_id.blank?
      end

      def post_or_put_data(method, model, path, response_class)
        with_monitoring do
          vet360_id_present!
          raw_response = perform(method, path, model.in_json)

          response_class.from(raw_response)
        end
      rescue => e
        handle_error(e)
      end

      def get_transaction_status(path, response_class)
        with_monitoring do
          vet360_id_present!
          raw_response = perform(:get, path)
          VAProfile::Stats.increment_transaction_results(raw_response)

          response_class.from(raw_response)
        end
      rescue => e
        handle_error(e)
      end
    end
  end
end
