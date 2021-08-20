# frozen_string_literal: true

require 'emis/models/guard_reserve_service_period_v2'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS guard reserve service periods response
    class GetGuardReserveServicePeriodsResponseV2 < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'guardReserveServicePeriods'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'personnelCategoryTypeCode' => {},
          'personnelOrganizationCode' => {},
          'personnelSegmentIdentifier' => {},
          'narrativeReasonForSeparationTxt' => {},
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
        EMIS::Models::GuardReserveServicePeriodV2
      end
    end
  end
end
