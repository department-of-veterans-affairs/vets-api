# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Combat Pay data for a veteran
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each Military Pay record
    # @!attribute begin_date
    #   @return [Date] date the specified pay began. Day is not available from the pay files and is defaulted to "01"
    # @!attribute end_date
    #   @return [Date] date the specified pay terminated.
    #     Day is not available from the pay files and is defaulted to the end of the month
    # @!attribute type_code
    #   @return [String] code that indicates the type of pay being
    #     reported.
    #       01 => Combat Zone Tax Exclusion (CZTE)
    #       02 => Hostile Fire/Imminent Danger
    #       03 => Hazardous Duty incentive
    # @!attribute combat_zone_country_code
    #   @return [String] 2 letter ISO code that represents the country designated a Combat Zone.
    #     Used only when CZTE is indicated by +type_code+
    class CombatPay
      include Virtus.model

      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :type_code, String
      attribute :combat_zone_country_code, String
    end
  end
end
