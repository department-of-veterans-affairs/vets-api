# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Guard and Reserve service period data
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each Guard/Reserve
    #     Active Service record.
    # @!attribute begin_date
    #   @return [Date] date on which a Service member began a period, or consecutive periods,
    #     of active service that total, or will total, more than 30 consecutive days. The data
    #     is received daily and monthly from personnel data feeds. The data is used to
    #     determine eligibility for active duty benefits (medical, educational, etc.).
    # @!attribute end_date
    #   @return [Date] date on which a Service member on a period, or consecutive periods, of
    #     active service that total, or will total, more than 30 consecutive days terminates,
    #     or will terminate. The data is received daily and monthly from personnel data feeds.
    #     The data is used to determine eligibility for active duty benefits (medical,
    #     educational, etc.).
    # @!attribute termination_reason
    #   @return [String] code that represents the reason the service member went off active
    #     duty.
    #       C => Completion of Active Service period
    #       D => Terminated by death
    #       F => Invalid entry
    #       S => Separation from personnel category or organization
    #       W => Not applicable
    # @!attribute character_of_service_code
    #   @return [String] character of service code. The data is received daily and monthly
    #     from personnel data feeds as well as via DD214 Feeds. DD214 data is uses
    #     transformation rules to map data into standard DoD codes. The data is used for
    #     personnel reporting and dissimination to other state and federal agencies for
    #     veteran's benefit processing.
    #       A => Honorable
    #       B => Under honorable conditions (general)
    #       D => Bad conduct
    #       E => Under other than honorable conditions
    #       F => Dishonorable
    #       H => Under honorable conditions (absence of a negative report)
    #       J => Honorable for VA Purposes (Administrative use by VA only)
    #       K => Dishonorable for VA Purposes (Administrative use by VA only)
    #       Y => Uncharacterized
    #       Z => Unknown
    # @!attribute narrative_reason_for_separation_code
    #   @return [String] narrative reason for the member's separation from the Service. This
    #     data element is used by VA in lieu of the Separation Program Designator Code (
    #     SPD_CD).
    # @!attribute statute_code
    #   @return [String] legal authority under which a Guard or Reserve member is called up to
    #     Active Duty. Required under DoDI 7730.54 Enclosure 8.
    #       A => Section 688 of 10 U.S.C.
    #       B => Section 12301(a) of 10 U.S.C.
    #       C => Section 12301(d) of 10 U.S.C.
    #       D => Section 12302 of 10 U.S.C.
    #       E => Section 12304 of 10 U.S.C.
    #       F => Section 331 of 14 U.S.C.
    #       G => Section 359 of 14 U.S.C.
    #       H => Section 367 of 14 U.S.C.
    #       I => Section 12406 of 10 U.S.C.
    #       J => Section 502(f) of 32 U.S.C.
    #       K => Section 12301(h) of 10 U.S.C.
    #       L => Section 712 of 14 U.S.C.
    #       M => Section 12301(b) of 10 U.S.C.
    #       N => Section 502(f)(1)(B) of 32 U.S.C.
    #       O => Section 10147 of 10 U.S.C.
    #       P => Section 502(a) of 32 U.S.C.
    #       Q => Section 502(f)(1)(A) of 32 U.S.C.
    #       R => Section 12322 of 10 U.S.C.
    #       S => Section 12301(g) of 10 U.S.C.
    #       T => Section 10148 of 10 U.S.C.
    #       U => Section 12303 of 10 U.S.C.
    #       V => Section 322 of 10 U.S.C.
    #       W => Section 333 of 10 U.S.C.
    #       X => Section 12402 of 10 U.S.C.
    #       Y => Section 802 of 10 U.S.C.
    #       Z => Unknown (for use with Project Code A99 or B99)
    # @!attribute project_code
    #   (see EMIS::Models::Deployment#project_code)
    # @!attribute post_911_gibill_loss_category_code
    #   @return [String] This is a DMDC derived data element created by grouping the
    #     Separation Program Designator code into categories used by the Department of
    #     Veterans Affairs in determining Post-9/11 GI Bill eligibility. The data is created
    #     daily and monthly. The data is used to update DEERS.
    #       01 => Service connected disability
    #       02 => Disability existed prior to Military Service
    #       03 => Physical or mental condition interfering with perf of duty
    #       04 => Hardship
    #       05 => Reduction in force/Force Shaping
    #       06 => Qualifying Active Duty Period
    #       07 => Disqualifying Active Duty Period
    #       99 => Unknown/Not Applicable
    # @!attribute training_indicator_code
    #   @return [String] Y if period is training only; N otherwise
    class GuardReserveServicePeriodV2
      include Virtus.model

      attribute :personnel_category_type_code, String
      attribute :personnel_organization_code, String
      attribute :personnel_segment_identifier, String
      attribute :narrative_reason_for_separation_txt, String
      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason, String
      attribute :character_of_service_code, String
      attribute :narrative_reason_for_separation_code, String
      attribute :statute_code, String
      attribute :project_code, String
      attribute :post_911_gibill_loss_category_code, String
      attribute :training_indicator_code, String
    end
  end
end
