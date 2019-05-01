# frozen_string_literal: true

require 'emis/models/retirement_pay'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS retirement pay response
    class GetRetirementPayResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'retirementPayData'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'retirementPaySegmentIdentifier' => { rename: 'segment_identifier' },
          'retirementPaymentMonthlyGrossAmount' => { rename: 'monthly_gross_amount' },
          'retirementPayBeginDate' => { rename: 'begin_date' },
          'retirementPayEndDate' => { rename: 'end_date' },
          'retirementPayTerminationReason' => { rename: 'termination_reason' },
          'retirementPayStopPaymentReason' => { rename: 'stop_payment_reason' },
          'dodDisabilityPercentageCode' => {},
          'retirementPaymentStatus' => { rename: 'payment_status' },
          'chapter61ServiceGrossPayAmount' => {},
          'chapter61EffectiveDate' => {},
          'retirementDateDifferencCode' => {},
          'survivorBenefitPlanPremiumMonthlyCostAmount' => {},
          'directRemitterSurvivorBenefitPlanAmount' => {},
          'directRemitterSurvivorBenefitPlanEffectiveDate' => {},
          'projectedSurvivorBenefitPlanAnnuityAmount' => {},
          'survivorBenefitPlanBeneficiaryTypeCode' => {},
          'originalRetirementPayDate' => {},
          'functionalAccountNumberCode' => {}
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::RetirementPay
      end
    end
  end
end
