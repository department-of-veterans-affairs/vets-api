# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIU
    ##
    # Model for PCIU email address response
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute email
    #   @return [String] Email address returned by the service
    # @!attribute effective_at
    #   @return [String] Date the email address was known to be valid
    #
    class EmailAddressResponse < EVSS::Response
      attribute :email, String
      attribute :effective_at, String

      def initialize(status, response = nil)
        attributes = {
          email: response&.body&.dig('cnp_email_address', 'value'),
          effective_at: response&.body&.dig('cnp_email_address', 'effective_date')
        }

        super(status, attributes)
      end
    end
  end
end
