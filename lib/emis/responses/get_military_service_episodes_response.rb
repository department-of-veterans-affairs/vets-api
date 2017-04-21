# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetMilitaryServiceEpisodesResponse < EMIS::Responses::Response
      def item_tag_name
        'militaryServiceEpisodeData'
      end

      # rubocop:disable Metrics/MethodLength
      def item_schema
        {
          'serviceEpisodeStartDate' => { date: true, rename: 'begin_date' },
          'serviceEpisodeEndDate' => { date: true, rename: 'end_date' },
          'serviceEpisodeTerminationReason' => { rename: 'termination_reason' },
          'branchOfServiceCode' => {},
          'retirementTypeCode' => {},
          'personnelProjectedEndDate' => { date: true },
          'personnelProjectedEndDateCertaintyCode' => {},
          'dischargeCharacterOfServiceCode' => {},
          'honorableDischargeForVaPurposeCode' => {},
          'personnelStatusChangeTransactionTypeCode' => {},
          'narrativeReasonForSeparationCode' => {},
          'post911GIBillLossCategoryCode' => {},
          'mgadLossCategoryCode' => {},
          'activeDutyServiceAgreementQuantity' => {},
          'initialEntryTrainingEndDate' => { date: true },
          'uniformServiceInitialEntryDate' => { date: true },
          'militaryAccessionSourceCode' => {},
          'personnelBeginDateSource' => {},
          'personnelTerminationDateSourceCode' => {},
          'activeFederalMilitaryServiceBaseDate' => { date: true },
          'mgsrServiceAgreementDurationYearQuantityCode' => {},
          'dodBeneficiaryTypeCode' => {},
          'reserveUnderAge60Code' => {}
        }
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
