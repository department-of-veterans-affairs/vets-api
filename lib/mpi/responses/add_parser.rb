# frozen_string_literal: true

require 'sentry_logging'
require_relative 'parser_base'

module MPI
  module Responses
    # Parses a MVI response and returns a MviProfile
    class AddParser < ParserBase
      include SentryLogging

      ACKNOWLEDGEMENT_DETAIL_CODE_XPATH = 'acknowledgement/acknowledgementDetail/code'
      BODY_XPATH = 'env:Envelope/env:Body/idm:MCCI_IN000002UV01'
      CODE_XPATH = 'acknowledgement/typeCode/@code'

      # Creates a new parser instance.
      #
      # @param response [struct Faraday::Env] the Faraday response
      # @return [ProfileParser] an instance of this class
      def initialize(response)
        @original_body = locate_element(response.body, BODY_XPATH)
        @code = locate_element(@original_body, CODE_XPATH)

        if failed_or_invalid?
          PersonalInformationLog.create(
            error_class: 'MPI::Errors',
            data: {
              payload: response.body
            }
          )
        end
      end

      # Parse the response.
      #
      # @return [Array] Possible list of codes associated with request
      def parse
        raw_codes = locate_elements(@original_body, ACKNOWLEDGEMENT_DETAIL_CODE_XPATH)
        return [] unless raw_codes

        attributes = raw_codes.map(&:attributes)
        parse_ids(attributes)
      end

      private

      def parse_ids(attributes)
        codes = { other: [] }
        attributes.each do |attribute|
          case attribute[:code]
          when /BRLS/
            codes[:birls_id] = sanitize_id(attribute[:code])
          when /CORP/
            codes[:participant_id] = sanitize_id(attribute[:code])
          else
            codes[:other].append(attribute)
          end
        end
        codes.delete(:other) if codes[:other].empty?
        codes
      end
    end
  end
end
