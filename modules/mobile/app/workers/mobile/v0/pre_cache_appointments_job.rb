# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheAppointmentsJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(uuid)
        user = IAMUser.find(uuid)
        start_date = (DateTime.now.utc.beginning_of_day - 1.year)
        end_date = (DateTime.now.utc.beginning_of_day + 1.year)

        appointments, errors = appointments_proxy(user).get_appointments(
          start_date: start_date,
          end_date: end_date
        )

        if errors.size.positive?
          Rails.logger.warn('mobile appointments pre-cache set failed', user_uuid: uuid, errors: errors)
        else
          Mobile::V0::Appointment.set_cached(user, appointments)
          Rails.logger.info('mobile appointments pre-cache set succeeded', user_uuid: uuid)
        end
      end

      private

      def appointments_proxy(user)
        Mobile::V0::Appointments::Proxy.new(user)
      end
    end
  end
end
