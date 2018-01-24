# frozen_string_literal: true

require 'emis/models/military_occupation'
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
          'serviceOccupationDate' => {}
        }
      end

      def model_class
        EMIS::Models::MilitaryOccupation
      end
    end
  end
end
