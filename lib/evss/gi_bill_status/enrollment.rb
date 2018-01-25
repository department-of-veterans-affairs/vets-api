# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module GiBillStatus
    class Enrollment < Common::Base
      attribute :begin_date, DateTime
      attribute :end_date, DateTime
      attribute :facility_code, String
      attribute :facility_name, String
      attribute :participant_id
      attribute :training_type
      attribute :term_id
      attribute :hour_type
      attribute :full_time_hours, Integer
      attribute :full_time_credit_hour_under_grad, Integer
      attribute :vacation_day_count, Integer
      attribute :on_campus_hours, Float
      attribute :online_hours, Float
      attribute :yellow_ribbon_amount, Float
      attribute :status, String
      attribute :amendments, Array[Amendment]
    end
  end
end
