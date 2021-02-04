# frozen_string_literal: true

module MPI
  module Responses
    class ParserBase
      # MVI response code options.
      EXTERNAL_RESPONSE_CODES = {
        success: 'AA',
        failure: 'AR',
        invalid_request: 'AE'
      }.freeze

      def initialize(code = nil)
        @code = code
      end

      # MVI returns failed or invalid codes if the request is malformed or MVI throws an internal error.
      #
      # @return [Boolean] has failed or invalid code?
      def failed_or_invalid?
        invalid_request? || failed_request?
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

      def sanitize_edipi(edipi)
        return unless edipi.present? && edipi.is_a?(String)

        # Remove non-digit characters from input, and match the first contiguous 10 digits found
        edipi.match(/\d{10}/)&.to_s
      end

      def sanitize_id(id)
        return unless id.present? && id.is_a?(String)

        # Remove non-digit characters from input
        id.match(/\d+/)&.to_s
      end

      def locate_element(el, path)
        locate_elements(el, path)&.first
      end

      def locate_elements(el, path)
        return nil unless el.present? && el.is_a?(Ox::Element)

        el.locate(path)
      end
    end
  end
end
