# frozen_string_literal: true
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
          'combatPayBeginDate' => { date: true, rename: 'begin_date' },
          'combatPayEndDate' => { date: true, rename: 'end_date' },
          'combatPayTypeCode' => { rename: 'type_code' },
          'combatZoneCountryCode' => {}
        }
      end
    end
  end
end
