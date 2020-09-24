# frozen_string_literal: true

require 'emis/models/guard_reserve_service_period'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS guard reserve service periods response
    class GetGuardReserveServicePeriodsResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'guardReserveServicePeriodsData'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
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

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::GuardReserveServicePeriod
      end
    end
  end
end
