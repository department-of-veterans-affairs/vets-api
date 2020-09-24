# frozen_string_literal: true

require 'emis/models/retirement'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS retirement data response
    class GetRetirementResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'retirementData'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'retirementServiceCode' => { rename: 'service_code' },
          'retirementBeginDate' => { rename: 'begin_date' },
          'retirementTermDate' => { rename: 'end_date' },
          'retirementTerminationReasonCode' => { rename: 'termination_reason_code' }
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::Retirement
      end
    end
  end
end
