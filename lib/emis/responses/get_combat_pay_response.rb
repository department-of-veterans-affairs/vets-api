# frozen_string_literal: true

require 'emis/models/combat_pay'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetCombatPayResponse < EMIS::Responses::Response
      def item_tag_name
        'combatPay'
      end

      def item_schema
        {
          'combatPaySegmentIdentifier' => { rename: 'segment_identifier' },
          'combatPayBeginDate' => { rename: 'begin_date' },
          'combatPayEndDate' => { rename: 'end_date' },
          'combatPayTypeCode' => { rename: 'type_code' },
          'combatZoneCountryCode' => {}
        }
      end

      def model_class
        EMIS::Models::CombatPay
      end
    end
  end
end
