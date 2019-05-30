# frozen_string_literal: true

module EMIS
  module Models
    # EMIS separation pay data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each Separation Pay
    #     record.
    # @!attribute type
    #   @return [String] code that indicates the type of separation
    #     pay.
    #       00 => Not Applicable
    #       01 => Separation Pay
    #       02 => Readjustment Pay
    #       03 => Non-Disability Severance
    #       04 => Disability Severance Pay
    #       05 => Discharge Gratuity
    #       06 => Death Gratuity
    #       07 => Spec Separation Benefit
    #       08 => Vol Sep Incentive Pay
    #       09 => Vol Separation Pay (VSP)
    #       10 => Contract Cancellation Pay and Allowances
    # @!attribute gross_amount
    #   @return [Float] amount of pay related to codes in the Separation Pay Type Code (
    #     SEP_PAY_TYP_CD). May have a negative value.
    # @!attribute net_amount
    #   @return [Float] amount of pay related to codes in Separation Pay Type Code (
    #     SEP_PAY_TYP_CD). May have a negative value.
    # @!attribute begin_date
    #   @return [Date] begin date for the Separation Pay. This value is not available from the
    #     pay files, and is defaulted to "01".
    # @!attribute end_date
    #   @return [Date] termination date of the Separation Pay. If the Member is not on the
    #     current master pay file, this date is defaulted to the end of the previous month.
    # @!attribute termination_reason
    #   @return [String] code that explains why a Separation Pay Segment was
    #     terminated.
    #       C => Pay Condition Terminated
    #       F => Invalid Segment
    #       W => Not Applicable/Not Term'd
    # @!attribute disability_severance_pay_combat_code
    #   @return [String] code that indicates whether the disability severance pay was
    #     combat-related or not.
    #       N => Disability severance is not combat-related
    #       W => Not applicable
    #       Y => Disability severance pay is for disability from combat zone
    #       Z => Unknown
    # @!attribute federal_income_tax_amount
    #   @return [Float] amount of federal income taxes withheld from Separation Gross Pay
    #     Amount.
    # @!attribute status_code
    #   @return [String] code indicating whether the pay amount in the transaction is
    #     projected or final.
    #       F => Final Pay Amount
    #       P => Projected Pay Amount
    #       Z => Unknown Status
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
