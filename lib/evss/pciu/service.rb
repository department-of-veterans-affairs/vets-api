# frozen_string_literal: true

require 'common/client/base'
require 'evss/pciu/configuration'
require 'evss/pciu/email_address_response'
require 'evss/pciu/phone_number_response'
require 'evss/pciu/request_body'
require 'evss/service'
require 'evss/pciu/email_address'

module EVSS
  module PCIU
    # EVSS::PCIU endpoints for a user's mailing address, email address,
    # primary/secondary phone numbers, and countries
    #
    # @param [User] Initialized with a user through the EVSS::Service parent
    #
    class Service < EVSS::Service
      configuration EVSS::PCIU::Configuration

      # Returns a response object containing the user's email address and
      # its effective date
      #
      # @return [EVSS::PCIU::EmailAddressResponse] Sample response.email_address:
      #   {
      #     "effective_date" => "2018-02-27T14:41:32.283Z",
      #     "value" => "test2@test1.net"
      #   }
      #
      def get_email_address
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'emailAddress')

          EVSS::PCIU::EmailAddressResponse.new(raw_response.status, raw_response)
        end
      end

      # Returns a response object containing the user's primary phone number,
      # extension, and country code
      #
      # @return [EVSS::PCIU::PhoneNumberResponse] Sample response.phone:
      #   {
      #     "country_code" => "1",
      #     "extension" => "",
      #     "number" => "4445551212",
      #     "effective_date" => "2018-02-27T14:41:32.283Z"
      #   }
      #
      def get_primary_phone
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'primaryPhoneNumber')

          EVSS::PCIU::PhoneNumberResponse.new(raw_response.status, raw_response)
        end
      end

      # Returns a response object containing the user's alternate phone number,
      # extension, and country code
      #
      # @return [EVSS::PCIU::PhoneNumberResponse] Sample response.phone:
      #   {
      #     "country_code" => "1",
      #     "extension" => "",
      #     "number" => "4445551212",
      #     "effective_date" => "2018-02-27T14:41:32.283Z"
      #   }
      #
      def get_alternate_phone
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'secondaryPhoneNumber')

          EVSS::PCIU::PhoneNumberResponse.new(raw_response.status, raw_response)
        end
      end

      # POST's the passed phone attributes to the EVSS::PCIU service.
      # Returns a response object containing the user's primary phone number,
      # extension, and country code
      #
      # @param phone_attrs [EVSS::PCIU::PhoneNumber] A EVSS::PCIU::PhoneNumber instance
      # @return [EVSS::PCIU::PhoneNumberResponse] Sample response.phone:
      #   {
      #     "country_code" => "1",
      #     "extension" => "",
      #     "number" => "4445551212"
      #     "effective_date" => "2018-02-27T14:41:32.283Z"
      #   }
      #
      def post_primary_phone(phone_attrs)
        with_monitoring_and_error_handling do
          raw_response = perform(
            :post,
            'primaryPhoneNumber',
            RequestBody.new(phone_attrs, pciu_key: 'cnpPhone').set,
            headers
          )

          EVSS::PCIU::PhoneNumberResponse.new(raw_response.status, raw_response)
        end
      end

      # POST's the passed phone attributes to the EVSS::PCIU service.
      # Returns a response object containing the user's alternate phone number,
      # extension, and country code
      #
      # @param phone_attrs [EVSS::PCIU::PhoneNumber] A EVSS::PCIU::PhoneNumber instance
      # @return [EVSS::PCIU::PhoneNumberResponse] Sample response.phone:
      #   {
      #     "country_code" => "1",
      #     "extension" => "",
      #     "number" => "4445551212"
      #     "effective_date" => "2018-02-27T14:41:32.283Z"
      #   }
      #
      def post_alternate_phone(phone_attrs)
        with_monitoring_and_error_handling do
          raw_response = perform(
            :post,
            'secondaryPhoneNumber',
            RequestBody.new(phone_attrs, pciu_key: 'cnpPhone').set,
            headers
          )

          EVSS::PCIU::PhoneNumberResponse.new(raw_response.status, raw_response)
        end
      end

      # POST's the passed email attributes to the EVSS::PCIU service.
      # Returns a response object containing the user's email and effective date.
      #
      # @param email_attrs [EVSS::PCIU::EmailAddress] A EVSS::PCIU::EmailAddress instance
      # @return [EVSS::PCIU::EmailAddressResponse] Sample response.email_address:
      #   {
      #     "effective_date" => "2018-02-27T14:41:32.283Z",
      #     "value" => "test2@test1.net"
      #   }
      #
      def post_email_address(email_attrs)
        with_monitoring_and_error_handling do
          raw_response = perform(
            :post,
            'emailAddress',
            { value: email_attrs.email }.to_json,
            headers
          )

          EVSS::PCIU::EmailAddressResponse.new(raw_response.status, raw_response)
        end
      end
    end
  end
end
