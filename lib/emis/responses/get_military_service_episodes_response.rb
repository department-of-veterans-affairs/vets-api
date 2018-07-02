# frozen_string_literal: true

require 'emis/models/military_service_episode'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetMilitaryServiceEpisodesResponse < EMIS::Responses::Response
      def item_tag_name
        'militaryServiceEpisode'
      end

      # rubocop:disable Metrics/MethodLength
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

      def model_class
        EMIS::Models::MilitaryServiceEpisode
      end
    end
  end
end
