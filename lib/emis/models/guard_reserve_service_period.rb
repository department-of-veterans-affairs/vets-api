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
    class GuardReserveServicePeriod
      include Virtus.model

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
