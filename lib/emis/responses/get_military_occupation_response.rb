# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetMilitaryOccupationResponse < EMIS::Responses::Response
      def item_tag_name
        'militaryOccupationData'
      end

      def item_schema
        {
          'occupationSegmentIdentifier' => { rename: 'segment_identifier' },
          'dodOccupationType' => {},
          'occupationType' => {},
          'serviceSpecificOccupationType' => {},
          'serviceOccupationDate' => { date: true }
        }
      end
    end
  end
end
