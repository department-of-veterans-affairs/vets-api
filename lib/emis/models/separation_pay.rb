# frozen_string_literal: true

module EMIS
  module Models
    class SeparationPay
      include Virtus.model

      attribute :segment_identifier, String
      attribute :type, String
      attribute :gross_amount, Float
      attribute :net_amount, Float
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason, String
      attribute :disability_severance_pay_combat_code, String
      attribute :federal_income_tax_amount, Float
      attribute :status_code, String
    end
  end
end
