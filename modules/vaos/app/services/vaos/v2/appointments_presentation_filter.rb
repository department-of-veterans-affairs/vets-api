# frozen_string_literal: true

# these filters were derived from the web app front end code base
module VAOS
  module V2
    class AppointmentsPresentationFilter
      def initialize
        @now = DateTime.now.utc
      end

      def user_facing?(appointment)
        return true if valid_appointment?(appointment)

        presentable_requested_appointment?(appointment)
      end

      private

      def presentable_requested_appointment?(appointment)
        created_at = appointment[:created]
        return false unless created_at

        valid_appointment_request?(appointment) && appointment[:status].in?(%w[proposed cancelled]) &&
          created_at.between?(120.days.ago.beginning_of_day, 1.day.from_now.end_of_day)
      end

      def valid_appointment?(appointment)
        !valid_appointment_request?(appointment) && appointment[:start].present?
      end

      def valid_appointment_request?(appointment)
        appointment[:requested_periods].present?
      end
    end
  end
end
