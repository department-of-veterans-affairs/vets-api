# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Paid Reserve drill days data
    class ReserveDrillDays
      include Virtus.model

      attribute :segment_identifier, String
      attribute :reserve_active_duty_monthly_current_paid_days, Integer
      attribute :reserve_drill_monthly_current_paid_days, Integer
      attribute :reserve_drill_current_monthly_paid_date, Date
    end
  end
end
