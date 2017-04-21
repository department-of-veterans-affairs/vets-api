# frozen_string_literal: true
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
          'retirementBeginDate' => { rename: 'begin_date', date: true },
          'retirementTermDate' => { rename: 'end_date', date: true },
          'retirementTerminationReasonCode' => { rename: 'termination_reason_code' }
        }
      end
    end
  end
end
