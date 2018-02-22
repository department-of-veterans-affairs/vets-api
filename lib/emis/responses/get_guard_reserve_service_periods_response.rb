# frozen_string_literal: true

require 'emis/models/guard_reserve_service_period'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetGuardReserveServicePeriodsResponse < EMIS::Responses::Response
      def item_tag_name
        'guardReserveServicePeriodsData'
      end

      def item_schema
        {
          'guardReserveSegmentIdentifier' => { rename: 'segment_identifier' },
          'guardReservePeriodStartDate' => { rename: 'begin_date' },
          'guardReservePeriodEndDate' => { rename: 'end_date' },
          'guardReservePeriodTerminationReason' => { rename: 'termination_reason' },
          'guardReservePeriodCharacterOfServiceCode' => { rename: 'character_of_service_code' },
          'narrativeReasonForSeparationCode' => {},
          'guardReservePeriodStatuteCode' => { rename: 'statute_code' },
          'guardReservePeriodProjectCode' => { rename: 'project_code' },
          'post911GIBilLossCategoryCode' => { rename: 'post_911_gibill_loss_category_code' },
          'trainingIndicatorCode' => {}
        }
      end

      def model_class
        EMIS::Models::GuardReserveServicePeriod
      end
    end
  end
end
