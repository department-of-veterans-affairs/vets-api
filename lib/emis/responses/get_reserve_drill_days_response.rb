# frozen_string_literal: true

require 'emis/models/reserve_drill_days'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS reserve drill days response
    class GetReserveDrillDaysResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'reserveDrillDaysData'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'reserveDrillSegmentIdentifier' => { rename: 'segment_identifier' },
          'reserveActiveDutyMonthlyCurrentPaidDays' => {},
          'reserveDrillMonthlyCurrentPaidDays' => {},
          'reserveDrillCurrentMonthlyPaidDate' => {}
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::ReserveDrillDays
      end
    end
  end
end
