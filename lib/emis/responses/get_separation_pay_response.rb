# frozen_string_literal: true

require 'emis/models/separation_pay'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetSeparationPayResponse < EMIS::Responses::Response
      def item_tag_name
        'separationPayData'
      end

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

      def model_class
        EMIS::Models::SeparationPay
      end
    end
  end
end
