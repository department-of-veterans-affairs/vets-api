# frozen_string_literal: true

require 'emis/models/unit_information'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS unit information response
    class GetUnitInformationResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'unitInformation'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'unitSegmentIdentifier' => { rename: 'segment_identifier' },
          'unitIdentificationCode' => { rename: 'identification_code' },
          'unitUicTypeCode' => { rename: 'uic_type_code' },
          'unitAssignedDate' => { rename: 'assigned_date' }
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::UnitInformation
      end
    end
  end
end
