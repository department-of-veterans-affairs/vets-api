# frozen_string_literal: true

module EMIS
  module Models
    # EMIS retirement data
    #
    # @!attribute service_code
    #   (see EMIS::Models::MilitaryServiceEpisode#branch_of_service_code)
    # @!attribute begin_date
    #   @return [Date] date when a sponsor's personnel category and organizational affiliation
    #     began.
    # @!attribute end_date
    #   @return [Date] date when the personnel segment terminated.
    # @!attribute termination_reason_code
    #   @return [String] code that represents the reason that the personnel segment
    #     terminated.
    #       D => Death while in PNL CAT or ORG
    #       F => Invalid entry into segment
    #       S => Separation fr PNL CAT or ORG
    #       W => N/A
    class Retirement
      include Virtus.model

      attribute :service_code, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason_code, String
    end
  end
end
