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
        return if edipi.nil?

        # Get rid of invalid values like 'UNK'
        sanitized_result = edipi.match(/\d{10}/)&.to_s
        Rails.logger.info "Edipi sanitized was: '#{edipi}' now: '#{sanitized_result}'." unless sanitized_result == edipi
        sanitized_result
      end

      def sanitize_id(id)
        return if id.nil?

        # Get rid of non-digit characters like 'UNK'/'ASKU'
        sanitized_result = id.match(/\d+/)&.to_s
        Rails.logger.info "Id sanitized, was: '#{id}' now: '#{id}'." if sanitized_result != id
        sanitized_result
      end

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
