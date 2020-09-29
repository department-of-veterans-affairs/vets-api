# frozen_string_literal: true

require_relative 'id_parser'
require_relative 'profile_parser'

module MVI
  module Responses
    class HistoricalIcnParser
      HISTORICAL_ICN_XPATH = [
        'controlActProcess/subject', # matches ProfileParser::SUBJECT_XPATH
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
          IdParser::VA_ROOT_OID
        ) || []
      end
    end
  end
end
