# frozen_string_literal: true

require 'emis/models/separation_pay'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS separation pay data
    class GetSeparationPayResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'separationPayData'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'separationPaySegmentIdentifier' => { rename: 'segment_identifier' },
          'separationPayType' => { rename: 'type' },
          'separationPaymentGrossAmount' => { rename: 'gross_amount' },
          'separationPaymentNetAmount' => { rename: 'net_amount' },
          'separationPaymentBeginDate' => { rename: 'begin_date' },
          'separationPaymentEndDate' => { rename: 'end_date' },
          'separationPaymentTerminationReason' => { rename: 'termination_reason' },
          'disabilitySeverancePayCombatCode' => {},
          'federalIncomeTaxAmount' => {},
          'separationPayStatusCode' => { rename: 'status_code' }
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::SeparationPay
      end
    end
  end
end
