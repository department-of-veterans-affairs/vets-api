# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetGuardReserveServicePeriodsResponse < EMIS::Responses::Response
      def items
        locate('guardReserveServicePeriodsData').map do |el|
          build_item(el)
        end
      end

      private

      def build_item(el)
        OpenStruct.new(
          segment_identifier: locate_one('guardReserveSegmentIdentifier', el).nodes[0],
          begin_date: Date.parse(locate_one('guardReservePeriodStartDate', el).nodes[0]),
          end_date: Date.parse(locate_one('guardReservePeriodEndDate', el).nodes[0]),
          termination_reason: locate_one('guardReservePeriodTerminationReason', el).nodes[0],
          character_of_service_code: locate_one('guardReservePeriodCharacterOfServiceCode', el).nodes[0],
          narrative_reason_for_separation_code: locate_one('narrativeReasonForSeparationCode', el).nodes[0],
          statute_code: locate_one('guardReservePeriodStatuteCode', el).nodes[0],
          project_code: locate_one('guardReservePeriodProjectCode', el).nodes[0],
          post_911_gibill_loss_category_code: locate_one('post911GIBilLossCategoryCode', el).nodes[0],
          training_indicator_code: locate_one('trainingIndicatorCode', el).nodes[0]
        )
      end
    end
  end
end
