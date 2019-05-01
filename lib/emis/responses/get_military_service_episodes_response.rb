# frozen_string_literal: true

require 'emis/models/military_service_episode'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS military service episodes response
    class GetMilitaryServiceEpisodesResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'militaryServiceEpisode'
      end

      # rubocop:disable Metrics/MethodLength

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'personnelCategoryTypeCode' => {},
          'serviceEpisodeStartDate' => { rename: 'begin_date' },
          'serviceEpisodeEndDate' => { rename: 'end_date' },
          'serviceEpisodeTerminationReason' => { rename: 'termination_reason' },
          'branchOfServiceCode' => {},
          'retirementTypeCode' => {},
          'personnelProjectedEndDate' => {},
          'personnelProjectedEndDateCertaintyCode' => {},
          'dischargeCharacterOfServiceCode' => {},
          'honorableDischargeForVaPurposeCode' => {},
          'personnelStatusChangeTransactionTypeCode' => {},
          'narrativeReasonForSeparationCode' => {},
          'post911GIBillLossCategoryCode' => {},
          'mgadLossCategoryCode' => {},
          'activeDutyServiceAgreementQuantity' => {},
          'initialEntryTrainingEndDate' => {},
          'uniformServiceInitialEntryDate' => {},
          'militaryAccessionSourceCode' => {},
          'personnelBeginDateSource' => {},
          'personnelTerminationDateSourceCode' => {},
          'activeFederalMilitaryServiceBaseDate' => {},
          'mgsrServiceAgreementDurationYearQuantityCode' => {},
          'dodBeneficiaryTypeCode' => {},
          'reserveUnderAge60Code' => {}
        }
      end
      # rubocop:enable Metrics/MethodLength

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::MilitaryServiceEpisode
      end
    end
  end
end
