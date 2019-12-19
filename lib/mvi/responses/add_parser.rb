# frozen_string_literal: true

require 'sentry_logging'

module MVI
  module Responses
    # Parses a MVI response and returns a MviProfile
    class AddParser
      include SentryLogging

      ACKNOWLEDGEMENT_DETAIL_CODE_XPATH = 'acknowledgement/acknowledgementDetail/code'
      BODY_XPATH = 'env:Envelope/env:Body/idm:MCCI_IN000002UV01'
      CODE_XPATH = 'acknowledgement/typeCode/@code'

      # MVI response code options.
      EXTERNAL_RESPONSE_CODES = {
        success: 'AA',
        failure: 'AR',
        invalid_request: 'AE'
      }.freeze

      # Creates a new parser instance.
      #
      # @param response [struct Faraday::Env] the Faraday response
      # @return [ProfileParser] an instance of this class
      def initialize(response)
        @original_body = locate_element(response.body, BODY_XPATH)
        @code = locate_element(@original_body, CODE_XPATH)
      end

      # MVI returns failed if MVI throws an internal error.
      #
      # @return [Boolean] has failed
      def failed_request?
        EXTERNAL_RESPONSE_CODES[:failure] == @code
      end

      # MVI returns invalid request if request is malformed.
      #
      # @return [Boolean] has invalid request
      def invalid_request?
        EXTERNAL_RESPONSE_CODES[:invalid_request] == @code
      end

      # Parse the response.
      #
      # @return [Array] Possible list of codes associated with request
      def parse
        raw_codes = locate_elements(@original_body, ACKNOWLEDGEMENT_DETAIL_CODE_XPATH)
        return [] unless raw_codes

        raw_codes.map(&:attributes)
      end

      private

      def locate_element(el, path)
        locate_elements(el, path)&.first
      end

      def locate_elements(el, path)
        return nil unless el

        el.locate(path)
      end
    end
  end
end
