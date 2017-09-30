# frozen_string_literal: true

module EMIS
  module Models
    class RetirementPay
      include Virtus.model

      attribute :segment_identifier, String
      attribute :monthly_gross_amount, Float
      attribute :begin_date, Date
      attribute :end_date, String
      attribute :termination_reason, String
      attribute :stop_payment_reason, String
      attribute :dod_disability_percentage_code, String
      attribute :payment_status, String
      attribute :chapter61_service_gross_pay_amount, Float
      attribute :chapter61_effective_date, Date
      attribute :retirement_date_differenc_code, String
      attribute :survivor_benefit_plan_premium_monthly_cost_amount, Float
      attribute :direct_remitter_survivor_benefit_plan_amount, Float
      attribute :direct_remitter_survivor_benefit_plan_effective_date, Date
      attribute :projected_survivor_benefit_plan_annuity_amount, Float
      attribute :survivor_benefit_plan_beneficiary_type_code, String
      attribute :original_retirement_pay_date, String
      attribute :functional_account_number_code, String
    end
  end
end
