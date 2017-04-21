# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetRetirementPayResponse < EMIS::Responses::Response
      def item_tag_name
        'retirementPayData'
      end

      def item_schema
        {
          'retirementPaySegmentIdentifier' => { rename: 'segment_identifier' },
          'retirementPaymentMonthlyGrossAmount' => { rename: 'monthly_gross_amount', float: true },
          'retirementPayBeginDate' => { rename: 'begin_date', date: true },
          'retirementPayEndDate' => { rename: 'end_date', date: true },
          'retirementPayTerminationReason' => { rename: 'termination_reason' },
          'retirementPayStopPaymentReason' => { rename: 'stop_payment_reason' },
          'dodDisabilityPercentageCode' => {},
          'retirementPaymentStatus' => { rename: 'payment_status' },
          'chapter61ServiceGrossPayAmount' => { float: true },
          'chapter61EffectiveDate' => { date: true },
          'retirementDateDifferencCode' => {},
          'survivorBenefitPlanPremiumMonthlyCostAmount' => { float: true },
          'directRemitterSurvivorBenefitPlanAmount' => { float: true },
          'directRemitterSurvivorBenefitPlanEffectiveDate' => { date: true },
          'projectedSurvivorBenefitPlanAnnuityAmount' => { float: true },
          'survivorBenefitPlanBeneficiaryTypeCode' => {},
          'originalRetirementPayDate' => { date: true },
          'functionalAccountNumberCode' => {}
        }
      end
    end
  end
end
