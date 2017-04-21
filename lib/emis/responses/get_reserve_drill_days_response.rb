# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetReserveDrillDaysResponse < EMIS::Responses::Response
      def item_tag_name
        'reserveDrillDaysData'
      end

      def item_schema
        {
          'reserveDrillSegmentIdentifier' => { rename: 'segment_identifier' },
          'reserveActiveDutyMonthlyCurrentPaidDays' => {},
          'reserveDrillMonthlyCurrentPaidDays' => {},
          'reserveDrillCurrentMonthlyPaidDate' => { date: true }
        }
      end
    end
  end
end
