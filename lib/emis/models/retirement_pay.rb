# frozen_string_literal: true

module EMIS
  module Models
    # EMIS retirement pay data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each Retired Pay
    #     record.
    # @!attribute monthly_gross_amount
    #   @return [Float] amount of gross monthly retired pay.
    # @!attribute begin_date
    #   @return [Date] effective date of the person's retirement pay.
    # @!attribute end_date
    #   @return [String] date of suspension or termination of the military retired pay.
    #     Applicable if Retired pay Status Code equals 2-5. If the Stop Pay Reason Code equals
    #     'A', then the Retirement Pay Termination Date should equal the Member Death Date.
    # @!attribute termination_reason
    #   @return [String] code representing the reason Retired Pay was terminated for an
    #     individual.
    #       C => Pay Cond Terminated
    #       F => Invalid segment
    #       S => Pay term, see Stop Pmt CD
    #       W => Not applcbl/Not trmnt'd
    # @!attribute stop_payment_reason
    #   @return [String] code that represents the reason for the total reduction or waiver (
    #     including refusal) or the suspension or termination of military retired pay.
    #     Applicable if Retired Pay Status Code equals 2-5.
    #       A => Member died
    #       B => Recalled to Active Duty
    #       C => Rmvd fm TDRL to AD
    #       D => Rmvd fm TDRL to Civilian
    #       E => Pay susp, no TDRL phys
    #       F => Civil Svc retirement wvr
    #       G => VA compensation wvr
    #       H => Dual comp, pay cap offset
    #       J => Refused retired pay
    #       K => Pay susp, whereabouts unk
    #       L => Suspected death
    #       M => Pay suspended, misc.
    #       N => TDRL removal greater than 5 years
    #       P => Discharge from TDRL not finalized
    #       Z => Not applicable
    # @!attribute dod_disability_percentage_code
    #   @return [String] code that represents the rating of percentage of disability.
    # @!attribute payment_status
    #   @return [String] code representing the status of Retired
    #     Pay.
    #       1 => Receiving DoD Retirement pay
    #       2 => Eligible, but not receiving DoD Ret pay. Not pyg SBP.
    #       3 => Eligible, but not receiving DoD Ret pay. Pyg into SBP.
    #       4 => Terminated
    #       5 => Suspended
    # @!attribute chapter61_service_gross_pay_amount
    #   @return [Float] amount of the person's gross pay in dollars and cents according to 10
    #     U.S. Code Chapter 61.
    # @!attribute chapter61_effective_date
    #   @return [Date] date the member is entitled to retirement under 10 U.S. Code Chapter 61.
    # @!attribute retirement_date_differenc_code
    #   @return [String] code that represents a change to gross retired pay benefits based on
    #     a non-COLA effective date.
    #       A => 30-year advancement
    #       D => TDRL to PDRL
    #       F => Fleet Reserve Retirement
    #       Z => Not Applicable
    # @!attribute survivor_benefit_plan_premium_monthly_cost_amount
    #   @return [Float] monthly amount of the Survivor Benefit Plan premium payment in dollars
    #     and cents.
    # @!attribute direct_remitter_survivor_benefit_plan_amount
    #   @return [Float] monthly Survivor Benefit Plan premium to be deducted from VA benefits
    #     for direct remitters.
    # @!attribute direct_remitter_survivor_benefit_plan_effective_date
    #   @return [Date] date that Survivor Benefit Plan premium deductions began for direct
    #     remitters.
    # @!attribute projected_survivor_benefit_plan_annuity_amount
    #   @return [Float] current amount of anticipated Survivor Benefit Plan payments to the
    #     annuitant.
    # @!attribute survivor_benefit_plan_beneficiary_type_code
    #   @return [String] code that represents what type of beneficiary was elected as
    #     annuitant for the Survivor Benefit Plan.
    #       0 => Unknown, no election, or not applicable
    #       1 => Spouse only
    #       2 => Children only
    #       3 => Spouse and children
    #       5 => Insurable interest, other than former spouse
    #       6 => Insurable interest, former spouse
    #       7 => Former spouse only
    #       8 => Former spouse and children
    #       9 => No eligible beneficiary
    # @!attribute original_retirement_pay_date
    #   @return [String] original date the retiree began receiving retired pay.
    # @!attribute functional_account_number_code
    #   @return [String] code that represents the entitlement basis for military retired pay.
    #     Known as FANCode in DFAS files.
    #       01 => Act Svc, Reg Officer
    #       02 => Act Svc, Reg Enlisted
    #       03 => Act Svc, Nonreg Officer
    #       04 => Act Svc, Nonreg Enlisted
    #       07 => Rsv Svc, Nonreg Officer
    #       08 => Rsv Svc, Nonreg Enlisted
    #       11 => TDRL, Reg Officer
    #       12 => TDRL, Reg Enlisted
    #       13 => TDRL, Nonreg Officer
    #       14 => TDRL, Nonreg Enlisted
    #       21 => PDRL, Reg Officer
    #       22 => PDRL Reg Enlisted
    #       23 => PDRL, Nonreg Officer
    #       24 => PDRL Nonreg Enlisted
    #       31 => Act Svc to FR/FMCR Reg En
    #       32 => Act Svc to FR/FMCR Nonreg
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
