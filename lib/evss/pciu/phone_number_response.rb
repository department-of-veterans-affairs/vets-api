# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIU
    ##
    # Model for PCIU phone number response
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute country_code
    #   @return [String] The country code at the beginning of the phone number
    # @!attribute number
    #   @return [String] The main phone number
    # @!attribute extension
    #   @return [String] The extension at the end of the phone number
    # @!attribute effective_date
    #   @return [String] Date at which the number was known to be valid
    #
    class PhoneNumberResponse < EVSS::Response
      attribute :country_code, String
      attribute :number, String
      attribute :extension, String
      attribute :effective_date, String

      def initialize(status, response = nil)
        attributes = {
          country_code: response&.body&.dig('cnp_phone', 'country_code'),
          number: response&.body&.dig('cnp_phone', 'number'),
          extension: response&.body&.dig('cnp_phone', 'extension'),
          effective_date: response&.body&.dig('cnp_phone', 'effective_date')
        }

        super(status, attributes)
      end

      def to_s
        "#{country_code}#{number}#{extension}".gsub(/[^\d]/, '')
      end
    end
  end
end
