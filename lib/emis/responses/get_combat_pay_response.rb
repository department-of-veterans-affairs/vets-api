# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetCombatPayResponse < EMIS::Responses::Response
      def items
        locate('combatPay').map do |el|
          build_item(el)
        end
      end

      private

      def build_item(el)
        OpenStruct.new(
          segment_identifier: locate_one('combatPaySegmentIdentifier', el).nodes[0],
          begin_date: Date.parse(locate_one('combatPayBeginDate', el).nodes[0]),
          end_date: Date.parse(locate_one('combatPayEndDate', el).nodes[0]),
          type_code: locate_one('combatPayTypeCode', el).nodes[0],
          zone_country_code: locate_one('combatZoneCountryCode', el).nodes[0]
        )
      end
    end
  end
end
