# frozen_string_literal: true

require 'emis/models/unit_information'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetUnitInformationResponse < EMIS::Responses::Response
      def item_tag_name
        'unitInformation'
      end

      def item_schema
        {
          'unitSegmentIdentifier' => { rename: 'segment_identifier' },
          'unitIdentificationCode' => { rename: 'identification_code' },
          'unitUicTypeCode' => { rename: 'uic_type_code' },
          'unitAssignedDate' => { rename: 'assigned_date' }
        }
      end

      def model_class
        EMIS::Models::UnitInformation
      end
    end
  end
end
