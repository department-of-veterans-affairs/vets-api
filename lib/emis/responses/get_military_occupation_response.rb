# frozen_string_literal: true

require 'emis/models/military_occupation'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS military occupation data
    class GetMilitaryOccupationResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'militaryOccupationData'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'occupationSegmentIdentifier' => { rename: 'segment_identifier' },
          'dodOccupationType' => {},
          'occupationType' => {},
          'serviceSpecificOccupationType' => {},
          'serviceOccupationDate' => {}
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::MilitaryOccupation
      end
    end
  end
end
