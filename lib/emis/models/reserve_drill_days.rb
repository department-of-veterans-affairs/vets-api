# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Paid Reserve drill days data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each Reserve Drill
    #     Pay record.
    # @!attribute reserve_active_duty_monthly_current_paid_days
    #   @return [Integer] number of Active Duty days that were paid in the current month.
    # @!attribute reserve_drill_monthly_current_paid_days
    #   @return [Integer] number of drill days that were paid in the current month.
    # @!attribute reserve_drill_current_monthly_paid_date
    #   @return [Date] date for which an ETL submission processing output files are created.
    #     Master files should have month end dates, transaction files should have end of year
    #     dates, and PFT files have daily dates.  The data is created automatically by the ETL
    #     submission processing framework from the submitted file date.  The data is used to
    #     group output records together for output.
    class ReserveDrillDays
      include Virtus.model

      attribute :segment_identifier, String
      attribute :reserve_active_duty_monthly_current_paid_days, Integer
      attribute :reserve_drill_monthly_current_paid_days, Integer
      attribute :reserve_drill_current_monthly_paid_date, Date
    end
  end
end
