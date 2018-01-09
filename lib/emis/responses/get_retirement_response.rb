# frozen_string_literal: true

require 'emis/models/retirement'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetRetirementResponse < EMIS::Responses::Response
      def item_tag_name
        'retirementData'
      end

      def item_schema
        {
          'retirementServiceCode' => { rename: 'service_code' },
          'retirementBeginDate' => { rename: 'begin_date' },
          'retirementTermDate' => { rename: 'end_date' },
          'retirementTerminationReasonCode' => { rename: 'termination_reason_code' }
        }
      end

      def model_class
        EMIS::Models::Retirement
      end
    end
  end
end
