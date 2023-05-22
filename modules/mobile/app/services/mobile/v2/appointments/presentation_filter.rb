# frozen_string_literal: true

# these filters were derived from the web app front end code base
module Mobile
  module V2
    module Appointments
      class PresentationFilter
        def initialize(include_pending:)
          @include_pending = include_pending
          @now = DateTime.now.utc
        end

        def user_facing?(appointment)
          return true if valid_appointment?(appointment) &&
                         (presentable_upcoming_appointment?(appointment) ||
                          presentable_past_appointment?(appointment) ||
                          presentable_cancelled_appointment?(appointment))

          return false unless @include_pending

          presentable_requested_appointment?(appointment)
        end

        private

        def presentable_upcoming_appointment?(appointment)
          appointment[:start] >= @now
        end

        def presentable_past_appointment?(appointment)
          appointment[:start] < @now && appointment[:status] != 'cancelled'
        end

        def presentable_cancelled_appointment?(appointment)
          appointment[:status] == 'cancelled' && appointment[:start] >= 30.days.ago.beginning_of_day
        end

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
end
