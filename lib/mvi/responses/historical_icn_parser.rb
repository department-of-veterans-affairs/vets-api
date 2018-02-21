# frozen_string_literal: true

module MVI
  module Responses
    class HistoricalIcnParser
      HISTORICAL_ICN_XPATH = [
        ProfileParser::BODY_XPATH,
        ProfileParser::SUBJECT_XPATH,
        'registrationEvent',
        'replacementOf',
        'priorRegistration',
        'id'
      ].join('/').freeze

      def initialize(body)
        @body = body
      end

      def get_icns
        IdParser.new.select_ids_with_extension(
          @body.locate(HISTORICAL_ICN_XPATH),
          IdParser::ICN_REGEX,
          IdParser::CORRELATION_ROOT_ID
        )
      end
    end
  end
end
